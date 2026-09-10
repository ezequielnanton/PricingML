using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using PricingAdapter.Adapters;
using PricingApi;
using PricingApi.Models;
using PricingApi.Services;

// #primerArranque: al distribuirse como ejecutable no hay appsettings.json editado a mano,
// asi que la primera vez se pregunta la conexion a SQL Server y se guarda.
if (!ArranqueMotor.AsegurarConfiguracion()) return 1;

var builder = WebApplication.CreateBuilder(args);

// #corsRedLocal: acepta localhost y cualquier IP de red privada (para entrar desde el
// celular u otro dispositivo en la misma WiFi) en los puertos típicos de dev del frontend.
var devFrontendOrigin = new Regex(
    @"^http://(localhost|127\.0\.0\.1|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}):(3000|4173|4200|5173|5174)$",
    RegexOptions.Compiled);
// #tunelDevTunnels: acepta el frontend servido vía Microsoft Dev Tunnels (subdominio
// "*-5173.<region>.devtunnels.ms"), usado temporalmente para ver la app desde afuera de
// la red local -- ver apiBase.js.
var devTunnelFrontendOrigin = new Regex(
    @"^https://.+-5173\..+\.devtunnels\.ms$",
    RegexOptions.Compiled);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy
            .SetIsOriginAllowed(origin => devFrontendOrigin.IsMatch(origin) || devTunnelFrontendOrigin.IsMatch(origin))
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddControllers();
builder.Services.AddSingleton<SqlPricingService>();
builder.Services.AddTransient<InputPersistenceService>();
builder.Services.AddSingleton<AdminCrudService>();
builder.Services.AddSingleton<AdminReportsService>();
builder.Services.AddSingleton<RepositorAuthService>();
builder.Services.AddSingleton<UsuarioAuthService>();
builder.Services.AddSingleton<EmailService>();
builder.Services.AddSingleton<RepositorStockService>();
builder.Services.AddHttpClient();
builder.Services.AddSingleton<ErpSyncService>();
builder.Services.AddSingleton<MercadoLibreSyncService>();
builder.Services.AddSingleton<EjecucionAutomaticaService>();
builder.Services.AddSingleton<ResumenVentasService>();
builder.Services.AddHostedService<EjecucionAutomaticaHostedService>();

// #escucharEnRed: sin esto, Kestrel solo escucha en localhost y un celular en la misma
// WiFi no puede llegar a la API aunque el frontend sí sea accesible por IP de red.
// #oauthMlRequiereHttps: MercadoLibre exige que el Redirect URI de la app OAuth sea https,
// y además rechaza "localhost" como host -- se agrega el puerto 5001 en https, escuchando
// en 0.0.0.0 (no solo localhost) para aceptar conexiones dirigidas a la IP de red de esta
// máquina, que sí acepta como Redirect URI. Usa el certificado de desarrollo de ASP.NET
// Core (CN=localhost, confiado con `dotnet dev-certs https --trust`); como no cubre la IP,
// el navegador va a mostrar una advertencia de certificado la primera vez -- esperado en
// desarrollo local, hay que aceptarla manualmente.
// #urlsConfigurables: el ejecutable distribuido escucha solo en http (el https de abajo
// depende del certificado de desarrollo, que no existe en una PC de destino). Si
// "Urls" esta definido en appsettings.json manda ese valor; si no, se mantiene el
// comportamiento de desarrollo con https en 5001 para el OAuth de MercadoLibre.
var urlsConfiguradas = builder.Configuration["Urls"];
if (string.IsNullOrWhiteSpace(urlsConfiguradas))
    builder.WebHost.UseUrls("http://0.0.0.0:5000", "https://0.0.0.0:5001");
else
    builder.WebHost.UseUrls(urlsConfiguradas.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));

var app = builder.Build();

// Swagger queda disponible tambien en el ejecutable distribuido: es la forma de verificar
// que el Motor arranco y responde sin depender del Cliente.
app.UseSwagger();
app.UseSwaggerUI();

app.UseCors("AllowFrontend");

// #manejoGlobalDeErrores: sin esto, una excepción sin capturar en cualquier ruta (ej. el
// RAISERROR de "no existe una estrategia activa" en spCalcularDecision) llegaba cruda hasta
// Kestrel, que cortaba la conexión a mitad de camino -- el navegador nunca recibía una
// respuesta HTTP completa y lo reportaba como "Failed to fetch" (parecía un problema de
// conexión/CORS, pero en realidad era un error de negocio bien concreto). Va ANTES que
// cualquier otro middleware/ruta, pero DESPUÉS de UseCors, para que la respuesta de error
// salga con los headers CORS que UseCors ya dejó preparados. Un RAISERROR de negocio (Msg
// 50000, la convención de SQL Server para errores levantados a propósito con RAISERROR, no
// errores de motor) ya trae un mensaje apto para mostrar tal cual; cualquier otra excepción
// se devuelve genérica, sin exponer detalles internos.
app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (Exception ex)
    {
        if (context.Response.HasStarted) throw;
        var esErrorDeNegocio = ex is SqlException sqlEx && sqlEx.Number == 50000;
        context.Response.StatusCode = esErrorDeNegocio ? StatusCodes.Status400BadRequest : StatusCodes.Status500InternalServerError;
        await context.Response.WriteAsJsonAsync(new { message = esErrorDeNegocio ? ex.Message : "Ocurrió un error inesperado. Intentá de nuevo en unos minutos." });
    }
});

// #loginGeneralApp: exige sesión de Usuario (Bearer token) para toda la superficie de
// la app que antes era de acceso libre (AdminPanel, Cola ML, Integraciones, Reportes,
// Pricing). Quedan afuera adrede: /health, /api/auth/* (el login mismo) y las rutas de
// integración externa que ya tienen su propio modelo de auth (Repositor por Usuario+PIN,
// ERP por ApiKey) — exigirles un token de Usuario rompería flujos que no opera una
// persona logueada en el navegador. Dentro de lo protegido, GET alcanza con cualquier
// sesión válida; los verbos que mutan datos (POST/PUT/DELETE/PATCH) requieren Rol=ADMIN,
// así que un Usuario LECTURA puede ver todo pero no aprobar/vincular/guardar nada.
var rutasProtegidas = new[] { "/api/admin", "/api/marketplace", "/pricing/evaluate", "/api/input/ui" };
// #oauthConexionCuentaMl: iniciar/callback son navegaciones de navegador comunes (un
// <a href> y la redirección que hace ML de vuelta), nunca llevan el header Authorization
// del login — su propia protección es el "state" de un solo uso, no un token de Usuario.
var rutasExcluidasDeLogin = new[] { "/api/marketplace/ml/oauth/iniciar", "/api/marketplace/ml/oauth/callback" };
app.Use(async (context, next) =>
{
    var path = context.Request.Path;
    if (rutasExcluidasDeLogin.Any(p => path.StartsWithSegments(p)) || !rutasProtegidas.Any(p => path.StartsWithSegments(p)))
    {
        await next();
        return;
    }

    var usuarioAuth = context.RequestServices.GetRequiredService<UsuarioAuthService>();
    var session = await usuarioAuth.ResolveSession(context.Request);
    if (session is null)
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await context.Response.WriteAsJsonAsync(new { message = "No autenticado. Iniciá sesión para continuar." });
        return;
    }

    var esMutacion = HttpMethods.IsPost(context.Request.Method) || HttpMethods.IsPut(context.Request.Method)
        || HttpMethods.IsDelete(context.Request.Method) || HttpMethods.IsPatch(context.Request.Method);
    if (esMutacion && !string.Equals(session.Rol, "ADMIN", StringComparison.OrdinalIgnoreCase))
    {
        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        await context.Response.WriteAsJsonAsync(new { message = "Tu usuario es de solo lectura." });
        return;
    }

    context.Items["Usuario"] = session;
    await next();
});

app.MapControllers();

// Guía: docs/Guia-Tecnica-Continuar-API.md#crearGet
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

// #loginGeneralApp: login/logout de Usuario y el bootstrap del primer ADMIN. El
// bootstrap solo funciona mientras la tabla Usuarios esté vacía — una vez creado el
// primer usuario, alta de usuarios pasa a requerir sesión ADMIN (POST /api/admin/usuarios).
app.MapPost("/api/auth/setup-primer-admin", async (UsuarioCreateRequest dto, UsuarioAuthService authService) =>
{
    if (await authService.ExistenUsuariosAsync())
        return Results.Conflict(new { message = "Ya existe al menos un usuario. Pedile a un ADMIN que te cree una cuenta." });
    if (string.IsNullOrWhiteSpace(dto.Usuario) || string.IsNullOrWhiteSpace(dto.Password))
        return Results.BadRequest(new { message = "Usuario y contraseña son obligatorios." });
    if (dto.Password.Length < 8)
        return Results.BadRequest(new { message = "La contraseña debe tener al menos 8 caracteres." });

    dto.Rol = "ADMIN";
    dto.Secciones = UsuarioAuthService.TodasLasSecciones.ToList();
    await authService.CreateUsuarioAsync(dto);
    var login = await authService.LoginAsync(new UsuarioLoginRequest { Usuario = dto.Usuario, Password = dto.Password });
    return Results.Ok(login);
});

app.MapPost("/api/auth/login", async (UsuarioLoginRequest request, UsuarioAuthService authService) =>
{
    var login = await authService.LoginAsync(request);
    return login is null ? Results.Unauthorized() : Results.Ok(login);
});

app.MapPost("/api/auth/logout", async (HttpRequest request, UsuarioAuthService authService) =>
{
    var header = request.Headers.Authorization.ToString();
    if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        await authService.LogoutAsync(header["Bearer ".Length..].Trim());
    return Results.NoContent();
});

app.MapGet("/api/auth/me", async (HttpRequest request, UsuarioAuthService authService) =>
{
    var session = await authService.ResolveSession(request);
    if (session is null)
        return Results.Unauthorized();
    // #modoOscuroPorUsuario: a diferencia de NombreCompleto/Rol/Secciones (grabados en la
    // sesión al loguearse), ModoOscuro se relee en vivo de Usuarios en cada /me -- así un
    // toggle de tema se refleja sin tener que volver a loguearse.
    var modoOscuro = await authService.GetModoOscuroAsync(session.UsuarioID);
    return Results.Ok(new { session.UsuarioID, session.NombreCompleto, session.Rol, session.Secciones, ModoOscuro = modoOscuro });
});

app.MapPost("/api/auth/cambiar-password", async (UsuarioCambiarPasswordRequest dto, HttpRequest request, UsuarioAuthService authService) =>
{
    var session = await authService.ResolveSession(request);
    if (session is null)
        return Results.Unauthorized();
    if (string.IsNullOrWhiteSpace(dto.PasswordNueva) || dto.PasswordNueva.Length < 8)
        return Results.BadRequest(new { message = "La contraseña nueva debe tener al menos 8 caracteres." });

    var ok = await authService.ChangePasswordAsync(session.UsuarioID, dto.PasswordActual, dto.PasswordNueva);
    return ok ? Results.NoContent() : Results.BadRequest(new { message = "La contraseña actual no es correcta." });
});

// #modoOscuroPorUsuario: self-service (cualquier Usuario logueado, sin importar Rol, puede
// prender/apagar su propio tema) -- mismo patrón que /api/auth/cambiar-password, resuelve
// la sesión del propio token en vez de operar sobre un {id} ajeno como los PUT de admin en
// /api/admin/usuarios/{id}/*.
app.MapPut("/api/auth/modo-oscuro", async (UsuarioModoOscuroRequest dto, HttpRequest request, UsuarioAuthService authService) =>
{
    var session = await authService.ResolveSession(request);
    if (session is null)
        return Results.Unauthorized();
    await authService.SetModoOscuroAsync(session.UsuarioID, dto.ModoOscuro);
    return Results.NoContent();
});

app.MapGet("/api/auth/existe-usuario", async (UsuarioAuthService authService) =>
    Results.Ok(new { existeUsuario = await authService.ExistenUsuariosAsync() }));

// #recuperarPassword: "olvidé mi contraseña" — siempre responde el mismo mensaje
// genérico, exista o no el usuario, tenga o no email cargado, para no revelar por
// enumeración qué cuentas existen. El envío en sí puede fallar (SMTP mal configurado,
// etc.); ese error se loguea pero tampoco cambia la respuesta al front.
app.MapPost("/api/auth/olvide-password", async (OlvidePasswordRequest dto, UsuarioAuthService authService, EmailService emailService, ILoggerFactory loggerFactory) =>
{
    const string mensaje = "Si el usuario existe y tiene un email cargado, te enviamos instrucciones para restablecer la contraseña.";
    try
    {
        var solicitud = await authService.RequestPasswordResetAsync(dto.Usuario);
        if (solicitud is not null)
        {
            var frontendBaseUrl = await emailService.ObtenerFrontendBaseUrlAsync();
            var link = $"{frontendBaseUrl}/reset-password?token={Uri.EscapeDataString(solicitud.Token)}";
            await emailService.EnviarResetPasswordAsync(solicitud.Email, link);
        }
    }
    catch (Exception ex)
    {
        loggerFactory.CreateLogger("OlvidePassword").LogError(ex, "No se pudo enviar el email de recuperación.");
    }
    return Results.Ok(new { message = mensaje });
});

app.MapPost("/api/auth/resetear-password", async (ResetearPasswordRequest dto, UsuarioAuthService authService) =>
{
    if (string.IsNullOrWhiteSpace(dto.PasswordNueva) || dto.PasswordNueva.Length < 8)
        return Results.BadRequest(new { message = "La contraseña nueva debe tener al menos 8 caracteres." });

    var resultado = await authService.ResetPasswordViaTokenAsync(dto.Token, dto.PasswordNueva);
    return resultado switch
    {
        ResetearPasswordResultado.Ok => Results.NoContent(),
        ResetearPasswordResultado.TokenUsado => Results.BadRequest(new { message = "Este link ya fue usado. Pedí uno nuevo desde \"Olvidé mi contraseña\"." }),
        ResetearPasswordResultado.TokenExpirado => Results.BadRequest(new { message = "Este link venció. Pedí uno nuevo desde \"Olvidé mi contraseña\"." }),
        _ => Results.BadRequest(new { message = "El link no es válido." }),
    };
});

app.MapGet("/api/admin/email-configuracion", async (EmailService emailService) =>
    Results.Ok(await emailService.GetConfiguracionAsync()));

app.MapPut("/api/admin/email-configuracion", async (EmailConfiguracionUpdateRequest dto, EmailService emailService) =>
{
    await emailService.UpdateConfiguracionAsync(dto);
    return Results.NoContent();
});

app.MapPost("/api/admin/email-configuracion/probar", async (EmailPruebaRequest dto, EmailService emailService) =>
{
    if (string.IsNullOrWhiteSpace(dto.Destinatario))
        return Results.BadRequest(new { message = "Indicá un destinatario para la prueba." });
    try
    {
        await emailService.EnviarPruebaAsync(dto.Destinatario);
        return Results.Ok(new { message = "Email de prueba enviado." });
    }
    catch (Exception ex)
    {
        return Results.BadRequest(new { message = $"No se pudo enviar: {ex.Message}" });
    }
});

// #ejecucionAutomatica: ciclo completo (ERP -> evaluar todos los productos -> procesar
// cola ML -> sincronizar ML) sin apretar los 4 botones del header a mano.
app.MapGet("/api/admin/ejecucion-automatica", async (EjecucionAutomaticaService service) =>
    Results.Ok(await service.GetConfiguracionAsync()));

app.MapPut("/api/admin/ejecucion-automatica", async (EjecucionAutomaticaConfiguracionUpdateRequest dto, EjecucionAutomaticaService service) =>
{
    await service.UpdateConfiguracionAsync(dto);
    return Results.NoContent();
});

app.MapPost("/api/admin/ejecucion-automatica/ejecutar-ahora", async (EjecucionAutomaticaService service) =>
{
    await service.EjecutarCicloAsync();
    return Results.Ok(await service.GetConfiguracionAsync());
});

// #resumenVentasPantallaPrincipal: venta bruta / costo total / rentabilidad de los
// últimos 30 días, mostrado al entrar a Pricing.
app.MapGet("/api/admin/resumen-ventas", async (ResumenVentasService service) =>
    Results.Ok(await service.GetResumenAsync()));

app.MapGet("/api/admin/usuarios", async (UsuarioAuthService authService) =>
    Results.Ok(await authService.ListarAsync()));

app.MapPost("/api/admin/usuarios", async (UsuarioCreateRequest dto, UsuarioAuthService authService) =>
{
    if (string.IsNullOrWhiteSpace(dto.Usuario) || string.IsNullOrWhiteSpace(dto.Password))
        return Results.BadRequest(new { message = "Usuario y contraseña son obligatorios." });
    if (dto.Password.Length < 8)
        return Results.BadRequest(new { message = "La contraseña debe tener al menos 8 caracteres." });

    var id = await authService.CreateUsuarioAsync(dto);
    return Results.Created($"/api/admin/usuarios/{id}", new { UsuarioID = id });
});

app.MapPut("/api/admin/usuarios/{id:int}/activo", async (int id, UsuarioActivoRequest dto, UsuarioAuthService authService) =>
{
    var ok = await authService.SetActivoAsync(id, dto.Activo);
    return ok ? Results.NoContent() : Results.NotFound();
});

app.MapPut("/api/admin/usuarios/{id:int}/secciones", async (int id, UsuarioSeccionesRequest dto, UsuarioAuthService authService) =>
{
    var ok = await authService.SetSeccionesAsync(id, dto.Secciones);
    return ok ? Results.NoContent() : Results.NotFound();
});

app.MapPut("/api/admin/usuarios/{id:int}/email", async (int id, UsuarioEmailRequest dto, UsuarioAuthService authService) =>
{
    var ok = await authService.SetEmailAsync(id, dto.Email);
    return ok ? Results.NoContent() : Results.NotFound();
});

app.MapDelete("/api/admin/usuarios/{id:int}", async (int id, HttpContext ctx, UsuarioAuthService authService) =>
{
    var sesion = (UsuarioSession)ctx.Items["Usuario"]!;
    if (sesion.UsuarioID == id)
        return Results.BadRequest(new { message = "No podés eliminar tu propio usuario mientras estás logueado con él." });

    var resultado = await authService.DeleteUsuarioAsync(id);
    return resultado switch
    {
        EliminarUsuarioResultado.Eliminado => Results.NoContent(),
        EliminarUsuarioResultado.NoEncontrado => Results.NotFound(),
        EliminarUsuarioResultado.TieneHistorial => Results.Conflict(new
        {
            message = "No se puede eliminar: tiene aprobaciones o vínculos registrados en su historial. Desactivalo en su lugar para conservar la trazabilidad.",
        }),
        _ => Results.Problem(),
    };
});

// Guía: docs/Guia-Tecnica-Continuar-API.md#crearPost
// Existing evaluation endpoint (keeps behavior) - will persist first if requested
app.MapPost("/pricing/evaluate", async (UiPricingRequest request, SqlPricingService pricingService, InputPersistenceService persistenceService) =>
{
    var payload = JsonSerializer.SerializeToElement(request);
    var adapter = new UiAdapter();
    var producto = adapter.Map(payload);

    if (request.Persistir)
    {
        await persistenceService.PersistProductoInputAsync(producto);
    }

    var decision = await pricingService.EvaluateAsync(
        producto,
        request.ModoSimulacion,
        request.Persistir);

    return Results.Ok(decision);
});

// Guía: docs/Guia-Tecnica-Continuar-API.md#crearPost
// New ingestion endpoint following adapter architecture
app.MapPost("/api/input/ui/product", async (UiPricingRequest request, InputPersistenceService persistenceService, SqlPricingService pricingService) =>
{
    // Map via UiAdapter (adapter responsibility)
    var payload = JsonSerializer.SerializeToElement(request);
    var adapter = new UiAdapter();
    var producto = adapter.Map(payload);

    // Persist to core tables (transactional)
    var productoId = await persistenceService.PersistProductoInputAsync(producto);

    // Optionally evaluate (simulation by default)
    var decision = await pricingService.EvaluateAsync(producto, request.ModoSimulacion, request.Persistir);

    var result = new {
        ProductoId = productoId,
        Decision = decision
    };

    return Results.Created($"/api/products/{productoId}", result);
});

// #cargaOperativaRepositor: alta de cuenta de repositor (provisión por admin/soporte,
// sin UI propia todavía). Usuario global único; PIN se hashea server-side.
app.MapPost("/api/admin/repositores", async (RepositorCreateRequest dto, RepositorAuthService authService) =>
{
    if (string.IsNullOrWhiteSpace(dto.Usuario) || string.IsNullOrWhiteSpace(dto.Pin))
        return Results.BadRequest(new { message = "Usuario y Pin son obligatorios." });
    if (dto.Pin.Length < 4)
        return Results.BadRequest(new { message = "El Pin debe tener al menos 4 dígitos." });

    var id = await authService.CreateRepositorAsync(dto);
    return Results.Created($"/api/admin/repositores/{id}", new { RepositorID = id });
});

// #cargaOperativaRepositor: login del repositor (Usuario+PIN) -> token en memoria.
app.MapPost("/api/input/repositor/login", async (RepositorLoginRequest request, RepositorAuthService authService) =>
{
    var login = await authService.LoginAsync(request);
    return login is null
        ? Results.Unauthorized()
        : Results.Ok(login);
});

// #cargaOperativaRepositor: consulta el stock vigente de un SKU antes de sobrescribirlo.
app.MapGet("/api/input/stock/lookup", async (string sku, HttpRequest httpRequest, RepositorAuthService authService, RepositorStockService stockService) =>
{
    var session = authService.ResolveSession(httpRequest);
    if (session is null) return Results.Unauthorized();

    var result = await stockService.LookupAsync(session.EmpresaID, sku);
    return result is null ? Results.NotFound(new { message = "SKU no encontrado." }) : Results.Ok(result);
});

// #cargaOperativaRepositor: recuento absoluto de stock; pisa StockActual y deja rastro en StockCargas.
app.MapPost("/api/input/stock", async (StockCargaRequest request, HttpRequest httpRequest, RepositorAuthService authService, RepositorStockService stockService) =>
{
    var session = authService.ResolveSession(httpRequest);
    if (session is null) return Results.Unauthorized();
    if (request.StockNuevo < 0)
        return Results.BadRequest(new { message = "El stock no puede ser negativo." });

    var result = await stockService.CargarStockAsync(session.EmpresaID, session.RepositorID, request);
    return result is null ? Results.NotFound(new { message = "SKU no encontrado." }) : Results.Ok(result);
});

// #integracionErp: provisión de una conexión ERP para una empresa. Devuelve la
// ApiKeyEntrante una sola vez. La pantalla "Integración ERP" de la UI la crea.
app.MapPost("/api/admin/erp-conexiones", async (ErpConexionCreateRequest dto, ErpSyncService erpService) =>
{
    var created = await erpService.CreateConexionAsync(dto);
    return Results.Created($"/api/admin/erp-conexiones/{created.ErpConexionID}", created);
});

app.MapGet("/api/admin/erp-conexiones/{empresaId:int}", async (int empresaId, ErpSyncService erpService) =>
{
    var conexion = await erpService.GetConexionAsync(empresaId);
    return conexion is null ? Results.NotFound() : Results.Ok(conexion);
});

app.MapPut("/api/admin/erp-conexiones/{empresaId:int}", async (int empresaId, ErpConexionUpdateRequest dto, ErpSyncService erpService) =>
{
    try
    {
        await erpService.UpdateConexionAsync(empresaId, dto);
        return Results.NoContent();
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
});

// #integracionErp: prueba el GET del ERP (sin necesidad de haberlo guardado todavía)
// y devuelve los nombres de campo encontrados, para armar el mapeo sin adivinar.
app.MapPost("/api/admin/erp-conexiones/descubrir-campos", async (ErpDescubrirCamposRequest dto, ErpSyncService erpService) =>
{
    try
    {
        var result = await erpService.DescubrirCamposAsync(dto);
        return Results.Ok(result);
    }
    catch (Exception ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
});

app.MapGet("/api/admin/erp-conexiones/{empresaId:int}/mapeo", async (int empresaId, ErpSyncService erpService) =>
{
    var mapeo = await erpService.GetMapeoAsync(empresaId);
    return Results.Ok(mapeo);
});

app.MapPut("/api/admin/erp-conexiones/{empresaId:int}/mapeo", async (int empresaId, ErpMapeoUpdateRequest dto, ErpSyncService erpService) =>
{
    try
    {
        await erpService.SaveMapeoAsync(empresaId, dto);
        return Results.NoContent();
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
});

// #integracionErp: entrante — el ERP nos hace POST con su lote de productos/costos/stock.
// Autenticado con la ApiKeyEntrante emitida al crear la conexión (header X-Api-Key).
app.MapPost("/api/erp/sync", async (ErpSyncRequest request, HttpRequest httpRequest, ErpSyncService erpService) =>
{
    var apiKey = httpRequest.Headers["X-Api-Key"].ToString();
    if (string.IsNullOrEmpty(apiKey))
        return Results.Unauthorized();

    var empresaId = await erpService.ResolveEmpresaByApiKeyAsync(apiKey);
    if (empresaId is null)
        return Results.Unauthorized();

    var result = await erpService.UpsertItemsAsync(empresaId.Value, request.Items);
    await erpService.LogSincronizacionAsync(empresaId.Value, "ENTRANTE", result);
    return Results.Ok(result);
});

// #integracionErp: saliente — botón "Actualizar desde ERP" de la UI. Recorre todas las
// conexiones activas con UrlSalida configurada, les hace GET y aplica el mismo upsert.
app.MapPost("/api/erp/pull", async (ErpSyncService erpService) =>
{
    var summaries = await erpService.PullFromAllConfiguredErpsAsync();
    return Results.Ok(summaries);
});

// #idaYVueltaMercadoLibre: consume ColaEjecucionML (llenada por spCalcularDecision) y
// empuja cada precio pendiente a la API real de ML, con refresco de token si hace falta.
app.MapPost("/api/marketplace/ml/procesar-cola", async (MercadoLibreSyncService mlService) =>
{
    var result = await mlService.ProcesarColaAsync();
    return Results.Ok(result);
});

// #integracionMlUiCredenciales: client_id/client_secret de la app de ML configurables
// desde la UI en vez de solo por appsettings.json. Nunca devuelve el secreto guardado.
app.MapGet("/api/admin/ml-configuracion", async (MercadoLibreSyncService mlService) =>
{
    var config = await mlService.GetConfiguracionAsync();
    return Results.Ok(config);
});

app.MapPut("/api/admin/ml-configuracion", async (MlConfiguracionUpdateRequest dto, MercadoLibreSyncService mlService) =>
{
    await mlService.UpdateConfiguracionAsync(dto);
    return Results.NoContent();
});

// #idaYVueltaMercadoLibre: sentido de entrada. Trae precio/estado real de ML para cada
// publicación y, para las de catálogo, la competencia real vía price_to_win.
app.MapPost("/api/marketplace/ml/sincronizar-publicaciones", async (MercadoLibreSyncService mlService) =>
{
    var result = await mlService.SincronizarPublicacionesAsync();
    return Results.Ok(result);
});

// #idaYVueltaMercadoLibre: ventas históricas vía API de Órdenes -> MetricasVentasHist.
app.MapPost("/api/marketplace/ml/sincronizar-ventas", async (MercadoLibreSyncService mlService) =>
{
    var result = await mlService.SincronizarVentasAsync();
    return Results.Ok(result);
});

// #aprobacionColaMl: pantalla de aprobación de la cola de MercadoLibre.
app.MapGet("/api/marketplace/ml/cola-aprobacion", async (MercadoLibreSyncService mlService) =>
{
    var items = await mlService.GetColaPendienteAprobacionAsync();
    return Results.Ok(items);
});

app.MapPost("/api/marketplace/ml/cola-aprobacion/{colaId:long}/aprobar", async (long colaId, HttpContext ctx, MercadoLibreSyncService mlService) =>
{
    var usuario = (UsuarioSession)ctx.Items["Usuario"]!;
    var ok = await mlService.AprobarColaAsync(colaId, usuario.UsuarioID);
    return ok ? Results.NoContent() : Results.NotFound();
});

app.MapPost("/api/marketplace/ml/cola-aprobacion/{colaId:long}/rechazar", async (long colaId, HttpContext ctx, MercadoLibreSyncService mlService) =>
{
    var usuario = (UsuarioSession)ctx.Items["Usuario"]!;
    var ok = await mlService.RechazarColaAsync(colaId, usuario.UsuarioID);
    return ok ? Results.NoContent() : Results.NotFound();
});

// #competidoresManualesMl: vincular/desvincular/actualizar precio de competidores para
// publicaciones que no son de catálogo. Ningún vínculo se crea sin confirmación explícita.
// MercadoLibre bloquea tanto la búsqueda por texto (GET /sites/{site}/search) como leer
// una publicación ajena por ID (GET /items/{id}) para apps de terceros -- 403 confirmado
// contra la API real, con token válido o sin él -- así que el usuario carga a mano el
// ID/link, título y precio que ve en su propio navegador, y los puede reescribir cuando
// quiera; no hay ningún llamado a MercadoLibre en este flujo.
app.MapGet("/api/marketplace/ml/publicaciones/{publicacionId:int}/competidores", async (int publicacionId, MercadoLibreSyncService mlService) =>
{
    var vinculados = await mlService.GetCompetidoresVinculadosAsync(publicacionId);
    return Results.Ok(vinculados);
});

app.MapGet("/api/marketplace/ml/publicaciones/{publicacionId:int}/moneda-principal", async (int publicacionId, MercadoLibreSyncService mlService) =>
{
    var monedaId = await mlService.ObtenerMonedaPrincipalAsync(publicacionId);
    return Results.Ok(new MlMonedaPrincipal { MonedaID = monedaId });
});

app.MapPost("/api/marketplace/ml/publicaciones/{publicacionId:int}/competidores", async (int publicacionId, MlVincularCompetidorRequest dto, HttpContext ctx, MercadoLibreSyncService mlService) =>
{
    try
    {
        var usuario = (UsuarioSession)ctx.Items["Usuario"]!;
        var id = await mlService.VincularCompetidorAsync(publicacionId, dto, usuario.UsuarioID);
        return Results.Created($"/api/marketplace/ml/publicaciones/{publicacionId}/competidores/{id}", new { VinculoID = id });
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
});

app.MapDelete("/api/marketplace/ml/publicaciones/{publicacionId:int}/competidores/{vinculoId:int}", async (int publicacionId, int vinculoId, MercadoLibreSyncService mlService) =>
{
    await mlService.DesvincularCompetidorAsync(vinculoId);
    return Results.NoContent();
});

app.MapPut("/api/marketplace/ml/publicaciones/{publicacionId:int}/competidores/{vinculoId:int}/precio", async (int publicacionId, int vinculoId, MlActualizarPrecioCompetidorRequest dto, MercadoLibreSyncService mlService) =>
{
    try
    {
        await mlService.ActualizarPrecioCompetidorAsync(vinculoId, dto.Precio);
        return Results.NoContent();
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { message = ex.Message });
    }
});

// #oauthConexionCuentaMl: flujo real de autorización de ML para conectar una Cuenta
// ML. "iniciar" redirige al login de ML; ML vuelve a "callback" con el code, que acá
// se cambia por los tokens reales (reemplaza el pegado manual de tokens por SQL).
app.MapGet("/api/marketplace/ml/oauth/iniciar", async (int cuentaMlId, MercadoLibreSyncService mlService) =>
{
    try
    {
        var url = await mlService.ConstruirUrlAutorizacionAsync(cuentaMlId);
        return Results.Redirect(url);
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { message = ex.Message });
    }
});

app.MapGet("/api/marketplace/ml/oauth/callback", async (string? code, string? state, MercadoLibreSyncService mlService) =>
{
    string TituloYMensaje(bool ok, string mensaje)
    {
        var titulo = ok ? "Conexión con MercadoLibre" : "Error de conexión";
        var encabezado = ok ? "Cuenta conectada" : "No se pudo conectar";
        var color = ok ? "#2e7d32" : "#c62828";
        var estilo = "body{font-family:sans-serif;text-align:center;padding:60px 20px;background:#f5f5f5}"
            + ".card{max-width:420px;margin:0 auto;padding:32px;border-radius:8px;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.1)}"
            + $"h1{{font-size:20px;color:{color}}}";
        return $"<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\"><title>{titulo}</title>"
            + $"<style>{estilo}</style></head>"
            + $"<body><div class=\"card\"><h1>{encabezado}</h1><p>{mensaje}</p>"
            + "<p>Podés cerrar esta pestaña y volver a la pantalla de Cuenta ML.</p></div></body></html>";
    }

    if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(state))
        return Results.Content(TituloYMensaje(false, "ML no envió el código de autorización esperado."), "text/html; charset=utf-8");

    try
    {
        await mlService.ProcesarCallbackAutorizacionAsync(code, state);
        return Results.Content(TituloYMensaje(true, "La cuenta de MercadoLibre quedó vinculada correctamente."), "text/html; charset=utf-8");
    }
    catch (InvalidOperationException ex)
    {
        return Results.Content(TituloYMensaje(false, ex.Message), "text/html; charset=utf-8");
    }
});

// Guía: docs/Guia-Tecnica-Continuar-API.md#crearGet, #crearPost, #crearPut y #crearDelete
// ADMIN CRUD endpoints (typed) - write operations and individual lookups.
app.MapGet("/api/admin/empresas/{id:int}", async (int id, AdminCrudService svc) =>
{
    var e = await svc.GetEmpresaAsync(id);
    return e is null ? Results.NotFound() : Results.Ok(e);
});
app.MapPost("/api/admin/empresas", async (EmpresaDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateEmpresaAsync(dto);
    return Results.Created($"/api/admin/empresas/{id}", new { EmpresaID = id });
});
app.MapPut("/api/admin/empresas/{id:int}", async (int id, EmpresaDto dto, AdminCrudService svc) =>
{
    await svc.UpdateEmpresaAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/empresas/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteEmpresaAsync(id);
    return Results.NoContent();
});

app.MapGet("/api/admin/estrategias/{id:int}", async (int id, AdminCrudService svc) =>
{
    var e = await svc.GetEstrategiaAsync(id);
    return e is null ? Results.NotFound() : Results.Ok(e);
});

app.MapGet("/api/admin/reglas/{id:int}", async (int id, AdminCrudService svc) =>
{
    var r = await svc.GetReglaAsync(id);
    return r is null ? Results.NotFound() : Results.Ok(r);
});

// Monedas
app.MapPost("/api/admin/monedas", async (MonedaDto dto, AdminCrudService svc) =>
{
    dto.CodigoISO = dto.CodigoISO.Trim().ToUpperInvariant();
    dto.Nombre = dto.Nombre.Trim();
    if (dto.CodigoISO.Length != 3)
        return Results.BadRequest(new { message = "CodigoISO debe tener exactamente 3 caracteres." });
    if (string.IsNullOrWhiteSpace(dto.Nombre))
        return Results.BadRequest(new { message = "Nombre es obligatorio." });

    try
    {
        var id = await svc.CreateMonedaAsync(dto);
        return Results.Created($"/api/admin/monedas/{id}", new { MonedaID = id });
    }
    catch (SqlException ex) when (ex.Number is 2601 or 2627)
    {
        return Results.Conflict(new { message = $"Ya existe una moneda con CodigoISO '{dto.CodigoISO}'." });
    }
});
app.MapPut("/api/admin/monedas/{id:int}", async (int id, MonedaDto dto, AdminCrudService svc) =>
{
    await svc.UpdateMonedaAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/monedas/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteMonedaAsync(id);
    return Results.NoContent();
});

// Cotizaciones
app.MapPost("/api/admin/cotizaciones", async (CotizacionDto dto, AdminCrudService svc) =>
{
    if (dto.MonedaID <= 0)
        return Results.BadRequest(new { message = "MonedaID debe ser mayor que cero." });
    if (dto.Cotizacion <= 0)
        return Results.BadRequest(new { message = "Cotizacion debe ser mayor que cero." });
    if (dto.FechaCotizacion == default)
        return Results.BadRequest(new { message = "FechaCotizacion es obligatoria." });

    try
    {
        var id = await svc.CreateCotizacionAsync(dto);
        return Results.Created($"/api/admin/cotizaciones/{id}", new { CotizacionID = id });
    }
    catch (SqlException ex) when (ex.Number == 547)
    {
        return Results.BadRequest(new { message = "La moneda indicada no existe." });
    }
});
app.MapPut("/api/admin/cotizaciones/{id:long}", async (long id, CotizacionDto dto, AdminCrudService svc) =>
{
    await svc.UpdateCotizacionAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/cotizaciones/{id:long}", async (long id, AdminCrudService svc) =>
{
    await svc.DeleteCotizacionAsync(id);
    return Results.NoContent();
});

// ParametrosGenerales
app.MapPost("/api/admin/parametros-generales", async (ParametroGeneralDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateParametroGeneralAsync(dto);
    return Results.Created($"/api/admin/parametros-generales/{id}", new { ParametroGeneralID = id });
});
app.MapPost("/api/admin/parametrosgenerales", async (ParametroGeneralDto dto, AdminCrudService svc) =>
    await app.Services.GetRequiredService<AdminCrudService>().CreateParametroGeneralAsync(dto) is var id
        ? Results.Created($"/api/admin/parametros-generales/{id}", new { ParametroGeneralID = id })
        : Results.BadRequest());
app.MapPut("/api/admin/parametros-generales/{id:int}", async (int id, ParametroGeneralDto dto, AdminCrudService svc) =>
{
    await svc.UpdateParametroGeneralAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/parametros-generales/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteParametroGeneralAsync(id);
    return Results.NoContent();
});

// CuentasML
app.MapPost("/api/admin/cuentas-ml", async (CuentaMlDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateCuentaMlAsync(dto);
    return Results.Created($"/api/admin/cuentas-ml/{id}", new { CuentaMLID = id });
});
app.MapPost("/api/admin/cuentasml", async (CuentaMlDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateCuentaMlAsync(dto);
    return Results.Created($"/api/admin/cuentas-ml/{id}", new { CuentaMLID = id });
});
app.MapPut("/api/admin/cuentas-ml/{id:int}", async (int id, CuentaMlDto dto, AdminCrudService svc) =>
{
    await svc.UpdateCuentaMlAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/cuentas-ml/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteCuentaMlAsync(id);
    return Results.NoContent();
});

// Productos
app.MapPost("/api/admin/productos", async (ProductoDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateProductoAsync(dto);
    return Results.Created($"/api/admin/productos/{id}", new { ProductoID = id });
});
app.MapPut("/api/admin/productos/{id:int}", async (int id, ProductoDto dto, AdminCrudService svc) =>
{
    await svc.UpdateProductoAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/productos/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteProductoAsync(id);
    return Results.NoContent();
});

// CostosProducto
app.MapPost("/api/admin/costos-producto", async (CostoProductoDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateCostoProductoAsync(dto);
    return Results.Created($"/api/admin/costos-producto/{id}", new { CostoID = id });
});
app.MapPost("/api/admin/costos", async (CostoProductoDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateCostoProductoAsync(dto);
    return Results.Created($"/api/admin/costos-producto/{id}", new { CostoID = id });
});
app.MapPut("/api/admin/costos-producto/{id:int}", async (int id, CostoProductoDto dto, AdminCrudService svc) =>
{
    await svc.UpdateCostoProductoAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/costos-producto/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteCostoProductoAsync(id);
    return Results.NoContent();
});

// PublicacionesML
app.MapPost("/api/admin/publicaciones-ml", async (PublicacionMlDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreatePublicacionMlAsync(dto);
    return Results.Created($"/api/admin/publicaciones-ml/{id}", new { PublicacionID = id });
});
app.MapPost("/api/admin/publicacionesml", async (PublicacionMlDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreatePublicacionMlAsync(dto);
    return Results.Created($"/api/admin/publicaciones-ml/{id}", new { PublicacionID = id });
});
app.MapPut("/api/admin/publicaciones-ml/{id:int}", async (int id, PublicacionMlDto dto, AdminCrudService svc) =>
{
    await svc.UpdatePublicacionMlAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/publicaciones-ml/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeletePublicacionMlAsync(id);
    return Results.NoContent();
});

// StockEstado
app.MapPost("/api/admin/stock-estado", async (StockEstadoDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateStockEstadoAsync(dto);
    return Results.Created($"/api/admin/stock-estado/{id}", new { StockID = id });
});
app.MapPost("/api/admin/stock", async (StockEstadoDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateStockEstadoAsync(dto);
    return Results.Created($"/api/admin/stock-estado/{id}", new { StockID = id });
});
app.MapPut("/api/admin/stock-estado/{id:int}", async (int id, StockEstadoDto dto, AdminCrudService svc) =>
{
    await svc.UpdateStockEstadoAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/stock-estado/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteStockEstadoAsync(id);
    return Results.NoContent();
});

// MetricasVentasHist
app.MapPost("/api/admin/metricas-ventas-hist", async (MetricasVentasDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateMetricasVentasAsync(dto);
    return Results.Created($"/api/admin/metricas-ventas-hist/{id}", new { MetricaID = id });
});
app.MapPost("/api/admin/metricas", async (MetricasVentasDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateMetricasVentasAsync(dto);
    return Results.Created($"/api/admin/metricas-ventas-hist/{id}", new { MetricaID = id });
});

// CompetenciaSnapshot
app.MapPost("/api/admin/competencia-snapshot", async (CompetenciaSnapshotDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateCompetenciaSnapshotAsync(dto);
    return Results.Created($"/api/admin/competencia-snapshot/{id}", new { SnapshotID = id });
});
app.MapPost("/api/admin/competencia", async (CompetenciaSnapshotDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateCompetenciaSnapshotAsync(dto);
    return Results.Created($"/api/admin/competencia-snapshot/{id}", new { SnapshotID = id });
});

// Estrategias
app.MapPost("/api/admin/estrategias", async (EstrategiaDto dto, AdminCrudService svc) =>
{
    try
    {
        var id = await svc.CreateEstrategiaAsync(dto);
        return Results.Created($"/api/admin/estrategias/{id}", new { EstrategiaID = id });
    }
    catch (Exception ex)
    {
        var message = ex.Message;
        if (message.Contains("FK_", StringComparison.OrdinalIgnoreCase) || message.Contains("empresa", StringComparison.OrdinalIgnoreCase))
            return Results.BadRequest(new { message = "La empresa indicada no existe o no es válida.", detail = message });

        return Results.BadRequest(new { message = "No se pudo crear la estrategia.", detail = message });
    }
});
app.MapPut("/api/admin/estrategias/{id:int}", async (int id, EstrategiaDto dto, AdminCrudService svc) =>
{
    await svc.UpdateEstrategiaAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/estrategias/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteEstrategiaAsync(id);
    return Results.NoContent();
});

// ReglasNegocio
app.MapPost("/api/admin/reglas", async (ReglaNegocioDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateReglaNegocioAsync(dto);
    return Results.Created($"/api/admin/reglas/{id}", new { ReglaID = id });
});
app.MapPut("/api/admin/reglas/{id:int}", async (int id, ReglaNegocioDto dto, AdminCrudService svc) =>
{
    await svc.UpdateReglaNegocioAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/reglas/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteReglaNegocioAsync(id);
    return Results.NoContent();
});

// EstrategiaReglas
app.MapPost("/api/admin/estrategia/{estrategiaId:int}/reglas", async (EstrategiaReglaDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateEstrategiaReglaAsync(dto);
    return Results.Created($"/api/admin/estrategia/{dto.EstrategiaID}/reglas/{id}", new { EstrategiaReglaID = id });
});
app.MapPut("/api/admin/estrategia/{estrategiaId:int}/reglas/{id:int}", async (int id, EstrategiaReglaDto dto, AdminCrudService svc) =>
{
    await svc.UpdateEstrategiaReglaAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/estrategia/{estrategiaId:int}/reglas/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteEstrategiaReglaAsync(id);
    return Results.NoContent();
});

// EstrategiaReglaParametros / EstrategiaReglaParametrosMensajes -- alta/edición simple
// (Activo/Inactivo, ver Migrar-ParametrosMensajesReglaActivoSimple.sql), mismo patrón CRUD
// plano que el resto de los ABMs (antes vivían en controllers MVC aparte, con un modelo
// versionado por fecha -- ver AdminCrudService.cs). El historial de valores pasados se ve
// por Reportes (recursos "estrategias-reglas-parametros"/"...-mensajes", registrados en
// AdminReportsService.Definitions, que además son los que le dan de comer al listado del
// ABM vía el foreach de GET más abajo).
var clavesParametroPermitidas = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
{
    "PORCENTAJE_INCREMENTO_STOCK_CRITICO", "PORCENTAJE_INCREMENTO_OPORTUNIDAD",
    "PORCENTAJE_DECREMENTO_EXCESO_STOCK", "PORCENTAJE_DESCUENTO_COMPETENCIA",
};
string? ValidarParametroRegla(EstrategiaReglaParametroDto dto)
{
    if (dto.EstrategiaReglaID <= 0) return "Seleccioná una Estrategia-Regla válida.";
    dto.Clave = dto.Clave.Trim().ToUpperInvariant();
    if (!clavesParametroPermitidas.Contains(dto.Clave)) return "La clave del parámetro no está permitida.";
    if (dto.Valor <= 0 || dto.Valor > 100) return "El valor debe ser mayor que 0 y menor o igual que 100.";
    return null;
}
app.MapGet("/api/admin/estrategias-reglas-parametros/{id:int}", async (int id, AdminCrudService svc) =>
{
    var p = await svc.GetEstrategiaReglaParametroAsync(id);
    return p is null ? Results.NotFound() : Results.Ok(p);
});
app.MapPost("/api/admin/estrategias-reglas-parametros", async (EstrategiaReglaParametroDto dto, AdminCrudService svc) =>
{
    var error = ValidarParametroRegla(dto);
    if (error is not null) return Results.BadRequest(new { message = error });
    var id = await svc.CreateEstrategiaReglaParametroAsync(dto);
    return Results.Created($"/api/admin/estrategias-reglas-parametros/{id}", new { ParametroID = id });
});
app.MapPut("/api/admin/estrategias-reglas-parametros/{id:int}", async (int id, EstrategiaReglaParametroDto dto, AdminCrudService svc) =>
{
    var error = ValidarParametroRegla(dto);
    if (error is not null) return Results.BadRequest(new { message = error });
    await svc.UpdateEstrategiaReglaParametroAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/estrategias-reglas-parametros/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteEstrategiaReglaParametroAsync(id);
    return Results.NoContent();
});

var clavesMensajePermitidas = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
{
    "MENSAJE_STOCK_CRITICO", "MENSAJE_OPORTUNIDAD", "MENSAJE_EXCESO_STOCK", "MENSAJE_COMPETENCIA",
};
var idiomasPermitidos = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "ES", "EN", "PT" };
var tokensPermitidos = new HashSet<string>(StringComparer.Ordinal) { "PORCENTAJE", "PRECIO_NUEVO", "PRECIO_ANTERIOR", "COMPETIDOR_PRECIO" };
var patronToken = new System.Text.RegularExpressions.Regex(@"\{([A-Z_]+)\}");
string? ValidarMensajeRegla(EstrategiaReglaParametroMensajeDto dto)
{
    if (dto.EstrategiaReglaID <= 0) return "Seleccioná una Estrategia-Regla válida.";
    dto.Clave = dto.Clave.Trim().ToUpperInvariant();
    dto.Idioma = dto.Idioma.Trim().ToUpperInvariant();
    if (!clavesMensajePermitidas.Contains(dto.Clave)) return "La clave del mensaje no está permitida.";
    if (!idiomasPermitidos.Contains(dto.Idioma)) return "El idioma debe ser ES, EN o PT.";
    if (string.IsNullOrWhiteSpace(dto.Valor)) return "El mensaje es obligatorio.";
    foreach (System.Text.RegularExpressions.Match match in patronToken.Matches(dto.Valor))
        if (!tokensPermitidos.Contains(match.Groups[1].Value)) return $"Token no soportado: {{{match.Groups[1].Value}}}";
    return null;
}
app.MapGet("/api/admin/estrategias-reglas-parametros-mensajes/{id:int}", async (int id, AdminCrudService svc) =>
{
    var m = await svc.GetEstrategiaReglaParametroMensajeAsync(id);
    return m is null ? Results.NotFound() : Results.Ok(m);
});
app.MapPost("/api/admin/estrategias-reglas-parametros-mensajes", async (EstrategiaReglaParametroMensajeDto dto, AdminCrudService svc) =>
{
    var error = ValidarMensajeRegla(dto);
    if (error is not null) return Results.BadRequest(new { message = error });
    var id = await svc.CreateEstrategiaReglaParametroMensajeAsync(dto);
    return Results.Created($"/api/admin/estrategias-reglas-parametros-mensajes/{id}", new { MensajeID = id });
});
app.MapPut("/api/admin/estrategias-reglas-parametros-mensajes/{id:int}", async (int id, EstrategiaReglaParametroMensajeDto dto, AdminCrudService svc) =>
{
    var error = ValidarMensajeRegla(dto);
    if (error is not null) return Results.BadRequest(new { message = error });
    await svc.UpdateEstrategiaReglaParametroMensajeAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/estrategias-reglas-parametros-mensajes/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteEstrategiaReglaParametroMensajeAsync(id);
    return Results.NoContent();
});

// ConfiguracionParametros
app.MapPost("/api/admin/configuracion-parametros", async (ConfiguracionParametroDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateConfiguracionParametroAsync(dto);
    return Results.Created($"/api/admin/configuracion-parametros/{id}", new { ParametroID = id });
});
app.MapPost("/api/admin/configuracion", async (ConfiguracionParametroDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateConfiguracionParametroAsync(dto);
    return Results.Created($"/api/admin/configuracion-parametros/{id}", new { ParametroID = id });
});
app.MapPut("/api/admin/configuracion-parametros/{id:int}", async (int id, ConfiguracionParametroDto dto, AdminCrudService svc) =>
{
    await svc.UpdateConfiguracionParametroAsync(id, dto);
    return Results.NoContent();
});
app.MapDelete("/api/admin/configuracion-parametros/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteConfiguracionParametroAsync(id);
    return Results.NoContent();
});

// Decisiones / auditoria / cola ML
app.MapPost("/api/admin/decisiones", async (DecisionHistorialDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateDecisionHistorialAsync(dto);
    return Results.Created($"/api/admin/decisiones/{id}", new { DecisionID = id });
});
app.MapPost("/api/admin/decisiones/{decisionId:int}/auditoria", async (DecisionDetalleAuditoriaDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateDecisionDetalleAuditoriaAsync(dto);
    return Results.Created($"/api/admin/decisiones/{dto.DecisionID}/auditoria/{id}", new { AuditoriaID = id });
});
app.MapPost("/api/admin/decisiones-detalle-auditoria", async (DecisionDetalleAuditoriaDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateDecisionDetalleAuditoriaAsync(dto);
    return Results.Created($"/api/admin/decisiones-detalle-auditoria/{id}", new { AuditoriaID = id });
});
app.MapPost("/api/admin/cola-ejecucion-ml", async (ColaEjecucionMlDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateColaEjecucionMlAsync(dto);
    return Results.Created($"/api/admin/cola-ejecucion-ml/{id}", new { ColaID = id });
});
app.MapPost("/api/admin/colaejecucion", async (ColaEjecucionMlDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateColaEjecucionMlAsync(dto);
    return Results.Created($"/api/admin/cola-ejecucion-ml/{id}", new { ColaID = id });
});

// Guía: docs/Guia-Tecnica-Continuar-API.md#crearGet y sección 7 (reportes seguros).
// Uniform, read-only reports. Resource names and columns are explicitly whitelisted by AdminReportsService.
foreach (var resource in AdminReportsService.Definitions.Keys)
{
    app.MapGet($"/api/admin/{resource}", async (HttpRequest request, AdminReportsService reports) =>
    {
        try
        {
            return Results.Ok(await reports.GetAsync(resource, request.Query));
        }
        catch (ReportValidationException ex)
        {
            return Results.BadRequest(new { message = ex.Message, errors = ex.Detail is null ? Array.Empty<string>() : new[] { ex.Detail } });
        }
    })
    .WithName($"AdminReport{resource.Replace("-", string.Empty)}")
    .WithSummary($"Reporte paginado de {resource} (solo lectura)");
}

app.Run();

