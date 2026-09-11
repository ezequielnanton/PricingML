using System.Data;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

// #idaYVueltaMercadoLibre: consume ColaEjecucionML (que spCalcularDecision ya llena
// cuando persiste un cambio de precio en modo producción) y lo empuja a la API real
// de MercadoLibre. Antes de esta pieza, la cola se llenaba pero nadie la procesaba:
// el motor "decidía" pero el precio nunca cambiaba de verdad en ML.
public class MercadoLibreSyncService
{
    private readonly string _connectionString;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly string _apiBaseUrlPorDefecto;
    private readonly string _clientIdPorDefecto;
    private readonly string _clientSecretPorDefecto;

    public MercadoLibreSyncService(IConfiguration configuration, IHttpClientFactory httpClientFactory)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
        _httpClientFactory = httpClientFactory;
        _apiBaseUrlPorDefecto = configuration["MercadoLibre:ApiBaseUrl"]?.TrimEnd('/') ?? "https://api.mercadolibre.com";
        _clientIdPorDefecto = configuration["MercadoLibre:ClientId"] ?? string.Empty;
        _clientSecretPorDefecto = configuration["MercadoLibre:ClientSecret"] ?? string.Empty;
    }

    private record ColaPendiente(long ColaID, int PublicacionID, string MeliItemID, decimal PrecioNuevo, int CuentaMLID);
    private record CuentaTokenInfo(string? AccessToken, string? RefreshToken, DateTime? FechaVencimientoToken);
    private record ConfigEfectiva(string ApiBaseUrl, string ClientId, string ClientSecret, string SiteId, string? RedirectUri);

    // #integracionMlUiCredenciales: la config guardada en ConfiguracionMercadoLibre
    // (editable desde la UI) tiene prioridad; appsettings.json queda como default de
    // arranque para cuando todavía no se configuró nada desde la pantalla.
    private async Task<ConfigEfectiva> ObtenerConfigEfectivaAsync(SqlConnection conn)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT TOP 1 ClientId, ClientSecret, ApiBaseUrl, SiteId, RedirectUri FROM ConfiguracionMercadoLibre ORDER BY ConfiguracionMercadoLibreID DESC";
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var clientId = reader["ClientId"] as string;
            var clientSecret = reader["ClientSecret"] as string;
            var apiBaseUrl = reader["ApiBaseUrl"] as string;
            var siteId = reader["SiteId"] as string;
            var redirectUri = reader["RedirectUri"] as string;
            return new ConfigEfectiva(
                string.IsNullOrWhiteSpace(apiBaseUrl) ? _apiBaseUrlPorDefecto : apiBaseUrl!.TrimEnd('/'),
                string.IsNullOrWhiteSpace(clientId) ? _clientIdPorDefecto : clientId!,
                string.IsNullOrWhiteSpace(clientSecret) ? _clientSecretPorDefecto : clientSecret!,
                string.IsNullOrWhiteSpace(siteId) ? "MLA" : siteId!.ToUpperInvariant(),
                redirectUri);
        }
        return new ConfigEfectiva(_apiBaseUrlPorDefecto, _clientIdPorDefecto, _clientSecretPorDefecto, "MLA", null);
    }

    public async Task<MlConfiguracionResponse> GetConfiguracionAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT TOP 1 ClientId, ClientSecret, ApiBaseUrl, SiteId, RedirectUri, FechaActualizacion FROM ConfiguracionMercadoLibre ORDER BY ConfiguracionMercadoLibreID DESC";
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return new MlConfiguracionResponse { ClientId = _clientIdPorDefecto, ClientSecretConfigurado = !string.IsNullOrWhiteSpace(_clientSecretPorDefecto), ApiBaseUrl = _apiBaseUrlPorDefecto, SiteId = "MLA" };

        var clientSecret = reader["ClientSecret"] as string;
        return new MlConfiguracionResponse
        {
            ClientId = reader["ClientId"] as string,
            ClientSecretConfigurado = !string.IsNullOrWhiteSpace(clientSecret),
            ApiBaseUrl = reader["ApiBaseUrl"] as string,
            SiteId = reader["SiteId"] as string,
            RedirectUri = reader["RedirectUri"] as string,
            FechaActualizacion = reader["FechaActualizacion"] as DateTime?
        };
    }

    public async Task UpdateConfiguracionAsync(MlConfiguracionUpdateRequest dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        await using var existeCmd = conn.CreateCommand();
        existeCmd.CommandText = "SELECT TOP 1 ConfiguracionMercadoLibreID, ClientSecret FROM ConfiguracionMercadoLibre ORDER BY ConfiguracionMercadoLibreID DESC";
        await using var reader = await existeCmd.ExecuteReaderAsync();
        int? existingId = null;
        string? existingSecret = null;
        if (await reader.ReadAsync())
        {
            existingId = Convert.ToInt32(reader["ConfiguracionMercadoLibreID"]);
            existingSecret = reader["ClientSecret"] as string;
        }
        await reader.DisposeAsync();

        var secretAGuardar = string.IsNullOrWhiteSpace(dto.ClientSecret) ? existingSecret : dto.ClientSecret;

        await using var cmd = conn.CreateCommand();
        if (existingId is null)
        {
            cmd.CommandText = @"INSERT INTO ConfiguracionMercadoLibre (ClientId, ClientSecret, ApiBaseUrl, SiteId, RedirectUri)
                                 VALUES (@clientId, @clientSecret, @apiBaseUrl, @siteId, @redirectUri)";
        }
        else
        {
            cmd.CommandText = @"UPDATE ConfiguracionMercadoLibre
                                 SET ClientId = @clientId, ClientSecret = @clientSecret, ApiBaseUrl = @apiBaseUrl,
                                     SiteId = @siteId, RedirectUri = @redirectUri, FechaActualizacion = SYSDATETIME()
                                 WHERE ConfiguracionMercadoLibreID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = existingId.Value;
        }
        cmd.Parameters.Add("@clientId", SqlDbType.VarChar, 200).Value = (object?)dto.ClientId ?? DBNull.Value;
        cmd.Parameters.Add("@clientSecret", SqlDbType.VarChar, 200).Value = (object?)secretAGuardar ?? DBNull.Value;
        cmd.Parameters.Add("@apiBaseUrl", SqlDbType.VarChar, 300).Value = (object?)dto.ApiBaseUrl ?? DBNull.Value;
        cmd.Parameters.Add("@siteId", SqlDbType.VarChar, 10).Value = (object?)dto.SiteId ?? DBNull.Value;
        cmd.Parameters.Add("@redirectUri", SqlDbType.VarChar, 500).Value = (object?)dto.RedirectUri ?? DBNull.Value;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<MlProcesarColaResult> ProcesarColaAsync(int maxItems = 50)
    {
        var result = new MlProcesarColaResult();
        var tokensRefrescados = new Dictionary<int, string>();

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var config = await ObtenerConfigEfectivaAsync(conn);
        var pendientes = await ObtenerPendientesAsync(conn, maxItems);

        foreach (var item in pendientes)
        {
            try
            {
                var accessToken = tokensRefrescados.TryGetValue(item.CuentaMLID, out var cached)
                    ? cached
                    : await EnsureValidTokenAsync(conn, item.CuentaMLID, config);
                tokensRefrescados[item.CuentaMLID] = accessToken;

                await ActualizarPrecioEnMlAsync(item.MeliItemID, item.PrecioNuevo, accessToken, config.ApiBaseUrl);

                await MarcarColaAsync(conn, item.ColaID, "PROCESADO", null);
                await ActualizarPrecioActualAsync(conn, item.PublicacionID, item.PrecioNuevo);

                result.Procesados++;
                result.Detalle.Add(new MlColaItemResultado { ColaID = item.ColaID, MeliItemID = item.MeliItemID, Ok = true });
            }
            catch (Exception ex)
            {
                await MarcarColaAsync(conn, item.ColaID, "ERROR", ex.Message);
                result.Errores++;
                result.Detalle.Add(new MlColaItemResultado { ColaID = item.ColaID, MeliItemID = item.MeliItemID, Ok = false, Error = ex.Message });
            }
        }

        return result;
    }

    private async Task<List<ColaPendiente>> ObtenerPendientesAsync(SqlConnection conn, int maxItems)
    {
        var list = new List<ColaPendiente>();
        await using var cmd = conn.CreateCommand();
        // #aprobacionColaMl: no procesa filas que todavía esperan revisión humana
        // (RequiereAprobacion=1 y Aprobado IS NULL) ni las rechazadas (Aprobado=0).
        cmd.CommandText = @"SELECT TOP (@maxItems) c.ColaID, c.PublicacionID, c.MeliItemID, c.PrecioNuevo, p.CuentaMLID
                             FROM ColaEjecucionML c
                             JOIN PublicacionesML p ON p.PublicacionID = c.PublicacionID
                             WHERE c.EstadoEjecucion = 'PENDIENTE'
                               AND (c.RequiereAprobacion = 0 OR c.Aprobado = 1)
                             ORDER BY c.FechaCreacion";
        cmd.Parameters.Add("@maxItems", SqlDbType.Int).Value = maxItems;
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new ColaPendiente(
                Convert.ToInt64(reader["ColaID"]),
                Convert.ToInt32(reader["PublicacionID"]),
                reader["MeliItemID"].ToString() ?? string.Empty,
                Convert.ToDecimal(reader["PrecioNuevo"]),
                Convert.ToInt32(reader["CuentaMLID"])));
        }
        return list;
    }

    private async Task<string> EnsureValidTokenAsync(SqlConnection conn, int cuentaMlId, ConfigEfectiva config)
    {
        var info = await ObtenerTokenInfoAsync(conn, cuentaMlId);
        if (string.IsNullOrWhiteSpace(info.AccessToken))
            throw new InvalidOperationException("La Cuenta ML no tiene AccessToken configurado.");

        var vencePronto = info.FechaVencimientoToken is null || info.FechaVencimientoToken.Value <= DateTime.Now.AddMinutes(5);
        if (!vencePronto)
            return info.AccessToken;

        if (string.IsNullOrWhiteSpace(info.RefreshToken))
            throw new InvalidOperationException("El token de la Cuenta ML venció y no tiene RefreshToken para renovarlo.");
        if (string.IsNullOrWhiteSpace(config.ClientId) || string.IsNullOrWhiteSpace(config.ClientSecret))
            throw new InvalidOperationException("Faltan configurar ClientId/ClientSecret de MercadoLibre (pantalla Integración MercadoLibre).");

        var (nuevoAccess, nuevoRefresh, expiresIn) = await RefrescarTokenAsync(info.RefreshToken, config);
        await GuardarTokenAsync(conn, cuentaMlId, nuevoAccess, nuevoRefresh, DateTime.Now.AddSeconds(expiresIn));
        return nuevoAccess;
    }

    private async Task<CuentaTokenInfo> ObtenerTokenInfoAsync(SqlConnection conn, int cuentaMlId)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT AccessToken, RefreshToken, FechaVencimientoToken FROM CuentasML WHERE CuentaMLID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = cuentaMlId;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            throw new InvalidOperationException("Cuenta ML no encontrada.");

        return new CuentaTokenInfo(
            reader["AccessToken"] as string,
            reader["RefreshToken"] as string,
            reader["FechaVencimientoToken"] as DateTime?);
    }

    private async Task GuardarTokenAsync(SqlConnection conn, int cuentaMlId, string accessToken, string? refreshToken, DateTime vencimiento)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"UPDATE CuentasML SET AccessToken = @accessToken, RefreshToken = @refreshToken, FechaVencimientoToken = @vencimiento
                             WHERE CuentaMLID = @id";
        cmd.Parameters.Add("@accessToken", SqlDbType.VarChar).Value = accessToken;
        cmd.Parameters.Add("@refreshToken", SqlDbType.VarChar).Value = (object?)refreshToken ?? DBNull.Value;
        cmd.Parameters.Add("@vencimiento", SqlDbType.DateTime2).Value = vencimiento;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = cuentaMlId;
        await cmd.ExecuteNonQueryAsync();
    }

    // Forma real de la API de ML: POST /oauth/token, form-urlencoded.
    private async Task<(string AccessToken, string? RefreshToken, int ExpiresIn)> RefrescarTokenAsync(string refreshToken, ConfigEfectiva config)
    {
        var client = _httpClientFactory.CreateClient();
        var form = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "refresh_token",
            ["client_id"] = config.ClientId,
            ["client_secret"] = config.ClientSecret,
            ["refresh_token"] = refreshToken
        });

        var response = await client.PostAsync($"{config.ApiBaseUrl}/oauth/token", form);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"ML rechazó la renovación de token (status {(int)response.StatusCode}).");

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        var accessToken = root.GetProperty("access_token").GetString()
            ?? throw new InvalidOperationException("Respuesta de ML sin access_token.");
        var nuevoRefresh = root.TryGetProperty("refresh_token", out var rt) ? rt.GetString() : refreshToken;
        var expiresIn = root.TryGetProperty("expires_in", out var ei) ? ei.GetInt32() : 21600;
        return (accessToken, nuevoRefresh, expiresIn);
    }

    // #oauthConexionCuentaMl: dominio de login por site — Brasil usa "mercadolivre",
    // el resto "mercadolibre" con el TLD del país; por eso va como mapa explícito
    // y no derivado de una regla. SiteId sale de ConfiguracionMercadoLibre (UI),
    // nunca hardcodeado a Argentina.
    private static readonly Dictionary<string, string> DominioAuthPorSite = new(StringComparer.OrdinalIgnoreCase)
    {
        ["MLA"] = "auth.mercadolibre.com.ar",
        ["MLB"] = "auth.mercadolivre.com.br",
        ["MLM"] = "auth.mercadolibre.com.mx",
        ["MLC"] = "auth.mercadolibre.cl",
        ["MCO"] = "auth.mercadolibre.com.co",
        ["MLU"] = "auth.mercadolibre.com.uy",
        ["MPE"] = "auth.mercadolibre.com.pe",
        ["MLV"] = "auth.mercadolibre.com.ve",
        ["MEC"] = "auth.mercadolibre.com.ec",
    };

    // State en memoria: mismo patrón que RepositorAuthService. Alcanza porque la
    // ventana entre "iniciar" y "callback" es de segundos; un reinicio de la API
    // solo invalida conexiones en curso, no las ya completadas.
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, int> _estadosOAuthPendientes = new();

    public async Task<string> ConstruirUrlAutorizacionAsync(int cuentaMlId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        var config = await ObtenerConfigEfectivaAsync(conn);

        if (string.IsNullOrWhiteSpace(config.ClientId))
            throw new InvalidOperationException("Falta configurar ClientId de MercadoLibre (pantalla Integración MercadoLibre).");
        if (string.IsNullOrWhiteSpace(config.RedirectUri))
            throw new InvalidOperationException("Falta configurar RedirectUri de MercadoLibre (pantalla Integración MercadoLibre).");

        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT 1 FROM CuentasML WHERE CuentaMLID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = cuentaMlId;
            if (await cmd.ExecuteScalarAsync() is null)
                throw new InvalidOperationException("Cuenta ML no encontrada.");
        }

        var dominio = DominioAuthPorSite.TryGetValue(config.SiteId, out var d) ? d : DominioAuthPorSite["MLA"];
        var state = Guid.NewGuid().ToString("N");
        _estadosOAuthPendientes[state] = cuentaMlId;

        return $"https://{dominio}/authorization?response_type=code&client_id={Uri.EscapeDataString(config.ClientId)}&redirect_uri={Uri.EscapeDataString(config.RedirectUri!)}&state={state}";
    }

    // Forma real de la API de ML: POST /oauth/token, grant_type=authorization_code
    // (endpoint global, no el de auth por site) con el code que ML mandó al callback.
    public async Task ProcesarCallbackAutorizacionAsync(string code, string state)
    {
        if (!_estadosOAuthPendientes.TryRemove(state, out var cuentaMlId))
            throw new InvalidOperationException("Estado OAuth inválido o expirado. Reintentá la conexión desde la pantalla de Cuenta ML.");

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        var config = await ObtenerConfigEfectivaAsync(conn);

        var client = _httpClientFactory.CreateClient();
        var form = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code",
            ["client_id"] = config.ClientId,
            ["client_secret"] = config.ClientSecret,
            ["code"] = code,
            ["redirect_uri"] = config.RedirectUri ?? string.Empty
        });

        var response = await client.PostAsync($"{config.ApiBaseUrl}/oauth/token", form);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"ML rechazó el código de autorización (status {(int)response.StatusCode}).");

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        var accessToken = root.GetProperty("access_token").GetString()
            ?? throw new InvalidOperationException("Respuesta de ML sin access_token.");
        var refreshToken = root.TryGetProperty("refresh_token", out var rt) ? rt.GetString() : null;
        var expiresIn = root.TryGetProperty("expires_in", out var ei) ? ei.GetInt32() : 21600;
        var userIdMl = root.TryGetProperty("user_id", out var uid) ? uid.GetRawText() : null;

        await GuardarTokenAsync(conn, cuentaMlId, accessToken, refreshToken, DateTime.Now.AddSeconds(expiresIn));

        if (!string.IsNullOrWhiteSpace(userIdMl))
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = "UPDATE CuentasML SET UserIDML = @userIdMl WHERE CuentaMLID = @id";
            cmd.Parameters.Add("@userIdMl", SqlDbType.VarChar, 50).Value = userIdMl;
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = cuentaMlId;
            await cmd.ExecuteNonQueryAsync();
        }
    }

    // Forma real de la API de ML: PUT /items/{id} con {"price": nuevoPrecio}.
    private async Task ActualizarPrecioEnMlAsync(string meliItemId, decimal precioNuevo, string accessToken, string apiBaseUrl)
    {
        var client = _httpClientFactory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Put, $"{apiBaseUrl}/items/{meliItemId}");
        request.Headers.Add("Authorization", $"Bearer {accessToken}");
        var body = JsonSerializer.Serialize(new { price = precioNuevo });
        request.Content = new StringContent(body, Encoding.UTF8, "application/json");

        var response = await client.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            throw new InvalidOperationException($"ML respondió {(int)response.StatusCode}: {errorBody}");
        }
    }

    private async Task MarcarColaAsync(SqlConnection conn, long colaId, string estado, string? mensajeError)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"UPDATE ColaEjecucionML SET EstadoEjecucion = @estado, MensajeError = @mensaje, FechaProcesado = SYSDATETIME()
                             WHERE ColaID = @id";
        cmd.Parameters.Add("@estado", SqlDbType.VarChar, 20).Value = estado;
        cmd.Parameters.Add("@mensaje", SqlDbType.VarChar).Value = (object?)mensajeError ?? DBNull.Value;
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = colaId;
        await cmd.ExecuteNonQueryAsync();
    }

    private async Task ActualizarPrecioActualAsync(SqlConnection conn, int publicacionId, decimal precioNuevo)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE PublicacionesML SET PrecioActual = @precio WHERE PublicacionID = @id";
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = precioNuevo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = publicacionId;
        await cmd.ExecuteNonQueryAsync();
    }

    // #idaYVueltaMercadoLibre: sentido de entrada. Trae de ML el precio/estado real de
    // cada publicación (por si cambió algo fuera de este sistema, ej. el vendedor lo
    // tocó a mano en ML) y, para publicaciones de catálogo, la competencia real vía
    // price_to_win. ML no tiene un endpoint simple de "competencia" para publicaciones
    // que no son de catálogo — eso queda fuera de esta pieza (ver ADR).
    private record PublicacionParaSincronizar(int PublicacionID, string MeliItemID, bool EsCatalogo, int CuentaMLID);

    public async Task<MlSincronizarPublicacionesResult> SincronizarPublicacionesAsync(int maxItems = 50)
    {
        var result = new MlSincronizarPublicacionesResult();
        var tokensRefrescados = new Dictionary<int, string>();

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var config = await ObtenerConfigEfectivaAsync(conn);
        var publicaciones = await ObtenerPublicacionesParaSincronizarAsync(conn, maxItems);

        foreach (var pub in publicaciones)
        {
            try
            {
                var accessToken = tokensRefrescados.TryGetValue(pub.CuentaMLID, out var cached)
                    ? cached
                    : await EnsureValidTokenAsync(conn, pub.CuentaMLID, config);
                tokensRefrescados[pub.CuentaMLID] = accessToken;

                var (precio, estado) = await ObtenerItemMlAsync(pub.MeliItemID, accessToken, config.ApiBaseUrl);
                await ActualizarPublicacionAsync(conn, pub.PublicacionID, precio, estado);

                var competenciaActualizada = false;
                if (pub.EsCatalogo)
                {
                    var competencia = await ObtenerPriceToWinAsync(pub.MeliItemID, accessToken, config.ApiBaseUrl);
                    if (competencia is not null)
                        competenciaActualizada = await InsertarCompetenciaSnapshotAsync(conn, pub.PublicacionID, competencia);
                }
                // #competidoresManualesMl: para no-catálogo, ML no tiene price_to_win ni ninguna
                // otra forma de que la app lea el precio de un competidor por API -- confirmado
                // que GET /items/{id} devuelve 403 access_denied para cualquier publicación que
                // no sea de la cuenta conectada (ver ADR 0010). El precio del competidor vinculado
                // a mano lo carga y actualiza el usuario directamente, no "Sincronizar ML".

                result.Procesados++;
                if (competenciaActualizada) result.ConCompetenciaActualizada++;
                result.Detalle.Add(new MlPublicacionSyncResultado
                {
                    PublicacionID = pub.PublicacionID,
                    MeliItemID = pub.MeliItemID,
                    Ok = true,
                    CompetenciaActualizada = competenciaActualizada
                });
            }
            catch (Exception ex)
            {
                result.Errores++;
                result.Detalle.Add(new MlPublicacionSyncResultado
                {
                    PublicacionID = pub.PublicacionID,
                    MeliItemID = pub.MeliItemID,
                    Ok = false,
                    Error = ex.Message
                });
            }
        }

        await PersistirHistorialSincronizacionAsync(conn, result);
        return result;
    }

    // #historialSincronizacionMl: antes el detalle (qué publicación se actualizó bien y
    // cuál falló, y por qué) se calculaba en memoria y se descartaba apenas se armaba el
    // toast de resultado -- no quedaba ningún rastro para revisar después. Se persiste acá,
    // en la misma conexión/corrida, como tabla madre (una fila por corrida de "Sincronizar
    // ML") + tabla hija (una fila por publicación de esa corrida), consultable después como
    // Reporte de tabla (ver AdminReportsService.cs).
    private async Task PersistirHistorialSincronizacionAsync(SqlConnection conn, MlSincronizarPublicacionesResult result)
    {
        int historialId;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = @"INSERT INTO SincronizacionMLHistorial (TotalProcesados, TotalErrores, ConCompetenciaActualizada)
                                 VALUES (@procesados, @errores, @conCompetencia); SELECT CAST(SCOPE_IDENTITY() AS INT);";
            cmd.Parameters.Add("@procesados", SqlDbType.Int).Value = result.Procesados;
            cmd.Parameters.Add("@errores", SqlDbType.Int).Value = result.Errores;
            cmd.Parameters.Add("@conCompetencia", SqlDbType.Int).Value = result.ConCompetenciaActualizada;
            historialId = (int)(await cmd.ExecuteScalarAsync())!;
        }

        foreach (var item in result.Detalle)
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO SincronizacionMLDetalle (SincronizacionMLID, PublicacionID, MeliItemID, Ok, Error, CompetenciaActualizada)
                                 VALUES (@historialId, @publicacionId, @meliItemId, @ok, @error, @competencia);";
            cmd.Parameters.Add("@historialId", SqlDbType.Int).Value = historialId;
            cmd.Parameters.Add("@publicacionId", SqlDbType.Int).Value = item.PublicacionID;
            cmd.Parameters.Add("@meliItemId", SqlDbType.VarChar, 50).Value = item.MeliItemID;
            cmd.Parameters.Add("@ok", SqlDbType.Bit).Value = item.Ok;
            cmd.Parameters.Add("@error", SqlDbType.VarChar, 1000).Value = (object?)item.Error ?? DBNull.Value;
            cmd.Parameters.Add("@competencia", SqlDbType.Bit).Value = item.CompetenciaActualizada;
            await cmd.ExecuteNonQueryAsync();
        }
    }

    private async Task<List<PublicacionParaSincronizar>> ObtenerPublicacionesParaSincronizarAsync(SqlConnection conn, int maxItems)
    {
        var list = new List<PublicacionParaSincronizar>();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT TOP (@maxItems) PublicacionID, MeliItemID, EsCatalogo, CuentaMLID
                             FROM PublicacionesML
                             WHERE Estado <> 'closed'
                             ORDER BY PublicacionID";
        cmd.Parameters.Add("@maxItems", SqlDbType.Int).Value = maxItems;
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new PublicacionParaSincronizar(
                Convert.ToInt32(reader["PublicacionID"]),
                reader["MeliItemID"].ToString() ?? string.Empty,
                Convert.ToBoolean(reader["EsCatalogo"]),
                Convert.ToInt32(reader["CuentaMLID"])));
        }
        return list;
    }

    // Forma real de la API de ML: GET /items/{id} -> {"price": ..., "status": "active"}.
    private async Task<(decimal Precio, string Estado)> ObtenerItemMlAsync(string meliItemId, string accessToken, string apiBaseUrl)
    {
        var client = _httpClientFactory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{apiBaseUrl}/items/{meliItemId}");
        request.Headers.Add("Authorization", $"Bearer {accessToken}");

        var response = await client.SendAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            throw new InvalidOperationException($"ML respondió {(int)response.StatusCode}: {errorBody}");
        }

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        var precio = root.GetProperty("price").GetDecimal();
        var estado = root.TryGetProperty("status", out var st) ? st.GetString() ?? "active" : "active";
        return (precio, estado);
    }

    private record CompetenciaMl(string? CompetidorItemID, decimal PrecioCompetidor, bool GanandoNosotros);

    // Forma real de la API de ML: GET /items/{id}/price_to_win?version=v2, solo para
    // publicaciones de catálogo. El shape exacto puede variar; se lee de forma
    // defensiva porque no hay una app real de ML todavía para confirmarlo en vivo.
    private async Task<CompetenciaMl?> ObtenerPriceToWinAsync(string meliItemId, string accessToken, string apiBaseUrl)
    {
        var client = _httpClientFactory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, $"{apiBaseUrl}/items/{meliItemId}/price_to_win?version=v2");
        request.Headers.Add("Authorization", $"Bearer {accessToken}");

        var response = await client.SendAsync(request);
        if (!response.IsSuccessStatusCode)
            return null;

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        if (!root.TryGetProperty("price_to_win", out var precioGanadorEl))
            return null;

        var precioGanador = precioGanadorEl.GetDecimal();
        string? competidorItemId = null;
        if (root.TryGetProperty("winner", out var winnerEl) && winnerEl.TryGetProperty("item_id", out var itemIdEl))
            competidorItemId = itemIdEl.GetString();

        var status = root.TryGetProperty("current_status", out var statusEl) ? statusEl.GetString() : null;
        var ganandoNosotros = status is "winning" or "sharing_first_place";

        return new CompetenciaMl(competidorItemId, precioGanador, ganandoNosotros);
    }

    private async Task ActualizarPublicacionAsync(SqlConnection conn, int publicacionId, decimal precio, string estado)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE PublicacionesML SET PrecioActual = @precio, Estado = @estado WHERE PublicacionID = @id";
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = precio;
        cmd.Parameters.Add("@estado", SqlDbType.VarChar, 20).Value = estado;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = publicacionId;
        await cmd.ExecuteNonQueryAsync();
    }

    // Devuelve true solo si de verdad insertó una fila (si ya estamos ganando el buy
    // box no hay un "competidor" distinto que registrar).
    private async Task<bool> InsertarCompetenciaSnapshotAsync(SqlConnection conn, int publicacionId, CompetenciaMl competencia)
    {
        if (competencia.GanandoNosotros)
            return false;

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, EsCompetidorDirecto, NivelRelevancia)
                             VALUES (@publicacionId, @competidorItemId, @precioCompetidor, 1, 1)";
        cmd.Parameters.Add("@publicacionId", SqlDbType.Int).Value = publicacionId;
        cmd.Parameters.Add("@competidorItemId", SqlDbType.VarChar, 50).Value = (object?)competencia.CompetidorItemID ?? "GANADOR_CATALOGO";
        cmd.Parameters.Add("@precioCompetidor", SqlDbType.Decimal).Value = competencia.PrecioCompetidor;
        await cmd.ExecuteNonQueryAsync();
        return true;
    }

    // #idaYVueltaMercadoLibre: ventas históricas. ML no tiene un endpoint de "ventas
    // de los últimos N días" por publicación — sale de la API de Órdenes, agregando
    // por item las cantidades vendidas en los últimos 90 días y armando las ventanas
    // que necesita MetricasVentasHist (7/15/30/60/90 días + tendencia 15D vs 15D previos).
    private record PublicacionParaVentas(int PublicacionID, string MeliItemID, int CuentaMLID);
    private record OrdenVendida(string MeliItemID, DateTime Fecha, int Cantidad);

    public async Task<MlSincronizarVentasResult> SincronizarVentasAsync()
    {
        var result = new MlSincronizarVentasResult();

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var config = await ObtenerConfigEfectivaAsync(conn);
        var publicaciones = await ObtenerPublicacionesParaVentasAsync(conn);

        foreach (var grupo in publicaciones.GroupBy(p => p.CuentaMLID))
        {
            try
            {
                var accessToken = await EnsureValidTokenAsync(conn, grupo.Key, config);
                var userIdMl = await ObtenerUserIdMlAsync(conn, grupo.Key);
                var ordenes = await ObtenerOrdenesAsync(userIdMl, accessToken, config.ApiBaseUrl);

                var hoy = DateTime.Now.Date;
                foreach (var pub in grupo)
                {
                    var ventasItem = ordenes.Where(o => o.MeliItemID == pub.MeliItemID).ToList();

                    int SumaDesde(int diasAtras) =>
                        ventasItem.Where(o => o.Fecha.Date >= hoy.AddDays(-(diasAtras - 1))).Sum(o => o.Cantidad);

                    var ventasHoy = ventasItem.Where(o => o.Fecha.Date == hoy).Sum(o => o.Cantidad);
                    var ventas15D = SumaDesde(15);
                    var ventas30D = SumaDesde(30);
                    var previas15D = ventasItem
                        .Where(o => o.Fecha.Date >= hoy.AddDays(-29) && o.Fecha.Date < hoy.AddDays(-14))
                        .Sum(o => o.Cantidad);
                    var tendenciaPorc = previas15D == 0
                        ? (ventas15D > 0 ? 100m : 0m)
                        : Math.Round((decimal)(ventas15D - previas15D) / previas15D * 100m, 2);

                    var item = new MlVentasSyncItem
                    {
                        PublicacionID = pub.PublicacionID,
                        MeliItemID = pub.MeliItemID,
                        VentasHoy = ventasHoy,
                        Ventas7D = SumaDesde(7),
                        Ventas15D = ventas15D,
                        Ventas30D = ventas30D,
                        Ventas60D = SumaDesde(60),
                        Ventas90D = SumaDesde(90),
                        TendenciaPorc = tendenciaPorc
                    };

                    await UpsertMetricasVentasAsync(conn, item);
                    result.PublicacionesActualizadas++;
                    result.Detalle.Add(item);
                }

                result.CuentasProcesadas++;
            }
            catch (Exception ex)
            {
                result.Errores++;
                result.ErroresDetalle.Add($"Cuenta ML {grupo.Key}: {ex.Message}");
            }
        }

        return result;
    }

    private async Task<List<PublicacionParaVentas>> ObtenerPublicacionesParaVentasAsync(SqlConnection conn)
    {
        var list = new List<PublicacionParaVentas>();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT PublicacionID, MeliItemID, CuentaMLID FROM PublicacionesML WHERE Estado <> 'closed'";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new PublicacionParaVentas(
                Convert.ToInt32(reader["PublicacionID"]),
                reader["MeliItemID"].ToString() ?? string.Empty,
                Convert.ToInt32(reader["CuentaMLID"])));
        }
        return list;
    }

    private async Task<string> ObtenerUserIdMlAsync(SqlConnection conn, int cuentaMlId)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT UserIDML FROM CuentasML WHERE CuentaMLID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = cuentaMlId;
        var result = await cmd.ExecuteScalarAsync();
        return result?.ToString() ?? throw new InvalidOperationException("Cuenta ML sin UserIDML configurado.");
    }

    // Forma real de la API de ML: GET /orders/search?seller=...&order.status=paid&
    // order.date_created.from=...&order.date_created.to=...&offset=...&limit=...
    // Pagina hasta agotar los resultados (con un tope de seguridad de 40 páginas).
    private async Task<List<OrdenVendida>> ObtenerOrdenesAsync(string userIdMl, string accessToken, string apiBaseUrl)
    {
        var ordenes = new List<OrdenVendida>();
        var client = _httpClientFactory.CreateClient();
        var desde = DateTime.Now.AddDays(-90).ToString("yyyy-MM-ddTHH:mm:ss.000zzz");
        var hasta = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss.000zzz");

        const int limit = 50;
        var offset = 0;
        for (var pagina = 0; pagina < 40; pagina++)
        {
            var url = $"{apiBaseUrl}/orders/search?seller={userIdMl}&order.status=paid" +
                      $"&order.date_created.from={Uri.EscapeDataString(desde)}&order.date_created.to={Uri.EscapeDataString(hasta)}" +
                      $"&offset={offset}&limit={limit}";
            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Add("Authorization", $"Bearer {accessToken}");

            var response = await client.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                throw new InvalidOperationException($"ML respondió {(int)response.StatusCode}: {errorBody}");
            }

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!root.TryGetProperty("results", out var results) || results.GetArrayLength() == 0)
                break;

            foreach (var orden in results.EnumerateArray())
            {
                if (!orden.TryGetProperty("date_created", out var fechaEl) || !DateTime.TryParse(fechaEl.GetString(), out var fecha))
                    continue;
                if (!orden.TryGetProperty("order_items", out var items))
                    continue;

                foreach (var orderItem in items.EnumerateArray())
                {
                    if (!orderItem.TryGetProperty("item", out var itemEl) || !itemEl.TryGetProperty("id", out var idEl))
                        continue;
                    var cantidad = orderItem.TryGetProperty("quantity", out var qtyEl) ? qtyEl.GetInt32() : 0;
                    ordenes.Add(new OrdenVendida(idEl.GetString() ?? string.Empty, fecha, cantidad));
                }
            }

            var total = root.TryGetProperty("paging", out var paging) && paging.TryGetProperty("total", out var totalEl)
                ? totalEl.GetInt32() : results.GetArrayLength();

            offset += limit;
            if (offset >= total) break;
        }

        return ordenes;
    }

    private async Task UpsertMetricasVentasAsync(SqlConnection conn, MlVentasSyncItem item)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            MERGE MetricasVentasHist AS target
            USING (SELECT @publicacionId AS PublicacionID) AS src
            ON target.PublicacionID = src.PublicacionID
            WHEN MATCHED THEN UPDATE SET
                VentasHoy = @ventasHoy, Ventas7D = @ventas7D, Ventas15D = @ventas15D,
                Ventas30D = @ventas30D, Ventas60D = @ventas60D, Ventas90D = @ventas90D,
                VelocidadVentaDiaria = @velocidad, TendenciaPorc = @tendencia, FechaCalculo = SYSDATETIME()
            WHEN NOT MATCHED THEN INSERT
                (PublicacionID, VentasHoy, Ventas7D, Ventas15D, Ventas30D, Ventas60D, Ventas90D, VelocidadVentaDiaria, TendenciaPorc)
                VALUES (@publicacionId, @ventasHoy, @ventas7D, @ventas15D, @ventas30D, @ventas60D, @ventas90D, @velocidad, @tendencia);";
        cmd.Parameters.Add("@publicacionId", SqlDbType.Int).Value = item.PublicacionID;
        cmd.Parameters.Add("@ventasHoy", SqlDbType.Int).Value = item.VentasHoy;
        cmd.Parameters.Add("@ventas7D", SqlDbType.Int).Value = item.Ventas7D;
        cmd.Parameters.Add("@ventas15D", SqlDbType.Int).Value = item.Ventas15D;
        cmd.Parameters.Add("@ventas30D", SqlDbType.Int).Value = item.Ventas30D;
        cmd.Parameters.Add("@ventas60D", SqlDbType.Int).Value = item.Ventas60D;
        cmd.Parameters.Add("@ventas90D", SqlDbType.Int).Value = item.Ventas90D;
        cmd.Parameters.Add("@velocidad", SqlDbType.Decimal).Value = Math.Round(item.Ventas30D / 30.0m, 4);
        cmd.Parameters.Add("@tendencia", SqlDbType.Decimal).Value = item.TendenciaPorc;
        await cmd.ExecuteNonQueryAsync();
    }

    // #aprobacionColaMl: pantalla de aprobación — listar lo pendiente de revisión y
    // registrar la decisión humana (aprobar/rechazar) sobre una fila puntual de la cola.
    public async Task<List<ColaAprobacionItem>> GetColaPendienteAprobacionAsync()
    {
        var list = new List<ColaAprobacionItem>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT c.ColaID, c.PublicacionID, c.MeliItemID, p.SKU, p.Titulo,
                                    pub.PrecioActual, c.PrecioNuevo, c.AccionRequerida, c.Motivo,
                                    c.CompetidorItemIDRef, c.PrecioCompetidorRef, pub.EsCatalogo, c.FechaCreacion
                             FROM ColaEjecucionML c
                             JOIN PublicacionesML pub ON pub.PublicacionID = c.PublicacionID
                             JOIN Productos p ON p.ProductoID = pub.ProductoID
                             WHERE c.EstadoEjecucion = 'PENDIENTE' AND c.RequiereAprobacion = 1 AND c.Aprobado IS NULL
                             ORDER BY c.FechaCreacion";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new ColaAprobacionItem
            {
                ColaID = Convert.ToInt64(reader["ColaID"]),
                PublicacionID = Convert.ToInt32(reader["PublicacionID"]),
                MeliItemID = reader["MeliItemID"].ToString() ?? string.Empty,
                SKU = reader["SKU"].ToString() ?? string.Empty,
                Titulo = reader["Titulo"].ToString() ?? string.Empty,
                PrecioActual = Convert.ToDecimal(reader["PrecioActual"]),
                PrecioNuevo = Convert.ToDecimal(reader["PrecioNuevo"]),
                AccionRequerida = reader["AccionRequerida"].ToString() ?? string.Empty,
                Motivo = reader["Motivo"] as string,
                CompetidorItemIDRef = reader["CompetidorItemIDRef"] as string,
                PrecioCompetidorRef = reader["PrecioCompetidorRef"] as decimal?,
                EsCatalogo = Convert.ToBoolean(reader["EsCatalogo"]),
                FechaCreacion = Convert.ToDateTime(reader["FechaCreacion"])
            });
        }
        return list;
    }

    public async Task<bool> AprobarColaAsync(long colaId, int usuarioId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"UPDATE ColaEjecucionML SET Aprobado = 1, FechaAprobacion = SYSDATETIME(), UsuarioAprobacionID = @usuarioId
                             WHERE ColaID = @id AND RequiereAprobacion = 1 AND Aprobado IS NULL";
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = colaId;
        cmd.Parameters.Add("@usuarioId", SqlDbType.Int).Value = usuarioId;
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> RechazarColaAsync(long colaId, int usuarioId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"UPDATE ColaEjecucionML SET Aprobado = 0, FechaAprobacion = SYSDATETIME(), UsuarioAprobacionID = @usuarioId
                             WHERE ColaID = @id AND RequiereAprobacion = 1 AND Aprobado IS NULL";
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = colaId;
        cmd.Parameters.Add("@usuarioId", SqlDbType.Int).Value = usuarioId;
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    // #competidoresManualesMl: buscar/vincular/desvincular competidores para
    // publicaciones que no son de catálogo, y refrescar su precio en cada sincronización.
    private record CuentaYSite(int CuentaMLID, string SiteId);

    private async Task<CuentaYSite> ObtenerCuentaYSiteAsync(SqlConnection conn, int publicacionId)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT CuentaMLID, MeliItemID FROM PublicacionesML WHERE PublicacionID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = publicacionId;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            throw new InvalidOperationException("Publicación no encontrada.");

        var cuentaMlId = Convert.ToInt32(reader["CuentaMLID"]);
        var meliItemId = reader["MeliItemID"].ToString() ?? string.Empty;
        var siteId = meliItemId.Length >= 3 ? meliItemId[..3].ToUpperInvariant() : "MLA";
        return new CuentaYSite(cuentaMlId, siteId);
    }

    // MercadoLibre bloquea tanto GET /sites/{site}/search (403 "forbidden") como GET
    // /items/{id} para una publicación ajena (403 "access_denied") para apps de terceros,
    // confirmado contra la API real con token válido y sin él (ver ADR 0010) -- no hay
    // forma de que la app traiga el precio de un competidor, ni al vincularlo ni después.
    // El usuario carga a mano el ID/link, título y precio que ve en su propio navegador,
    // y los puede reescribir cuando quiera con "Actualizar precio". Esto solo normaliza
    // el ID pegado (extraerlo de un link real, o completar el prefijo de sitio si vino
    // como solo números) -- no llama a MercadoLibre en ningún momento.
    private static readonly Regex ItemIdEnUrl = new(@"([A-Za-z]{2,4})-(\d+)", RegexOptions.Compiled);
    private static readonly Regex ItemIdConGuion = new(@"^([A-Za-z]{2,4})-(\d+)$", RegexOptions.Compiled);
    private static readonly Regex SoloDigitos = new(@"^\d+$", RegexOptions.Compiled);

    private static string ExtraerItemId(string idOrLink, string siteIdPorDefecto)
    {
        var value = idOrLink.Trim();
        if (value.Contains("://") || value.Contains("mercadolibre.com", StringComparison.OrdinalIgnoreCase))
        {
            var enlaceMatch = ItemIdEnUrl.Match(value);
            if (!enlaceMatch.Success)
                throw new ArgumentException("No se reconoció un ID de publicación en el link pegado.");
            return $"{enlaceMatch.Groups[1].Value.ToUpperInvariant()}{enlaceMatch.Groups[2].Value}";
        }

        if (SoloDigitos.IsMatch(value))
            return $"{siteIdPorDefecto}{value}";

        var idMatch = ItemIdConGuion.Match(value);
        return idMatch.Success ? $"{idMatch.Groups[1].Value.ToUpperInvariant()}{idMatch.Groups[2].Value}" : value;
    }

    public async Task<List<MlCompetidorVinculado>> GetCompetidoresVinculadosAsync(int publicacionId)
    {
        var list = new List<MlCompetidorVinculado>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT v.VinculoID, v.CompetidorItemID, v.CompetidorTitulo, v.FechaVinculo, u.NombreCompleto AS UsuarioVinculoNombre,
                                    v.UltimoPrecio, v.FechaUltimoPrecio, v.MonedaID, m.CodigoISO AS MonedaCodigoISO, m.Simbolo AS MonedaSimbolo
                             FROM PublicacionCompetidoresManual v
                             LEFT JOIN Usuarios u ON u.UsuarioID = v.UsuarioVinculoID
                             LEFT JOIN Monedas m ON m.MonedaID = v.MonedaID
                             WHERE v.PublicacionID = @id AND v.Activo = 1
                             ORDER BY v.FechaVinculo DESC";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = publicacionId;
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new MlCompetidorVinculado
            {
                VinculoID = Convert.ToInt32(reader["VinculoID"]),
                CompetidorItemID = reader["CompetidorItemID"].ToString() ?? string.Empty,
                CompetidorTitulo = reader["CompetidorTitulo"] as string,
                FechaVinculo = Convert.ToDateTime(reader["FechaVinculo"]),
                UsuarioVinculoNombre = reader["UsuarioVinculoNombre"] as string,
                MonedaID = reader["MonedaID"] is DBNull ? null : Convert.ToInt32(reader["MonedaID"]),
                MonedaCodigoISO = reader["MonedaCodigoISO"] as string,
                MonedaSimbolo = reader["MonedaSimbolo"] as string,
                UltimoPrecio = reader["UltimoPrecio"] is DBNull ? null : Convert.ToDecimal(reader["UltimoPrecio"]),
                FechaUltimoPrecio = reader["FechaUltimoPrecio"] is DBNull ? null : Convert.ToDateTime(reader["FechaUltimoPrecio"])
            });
        }
        return list;
    }

    // La extensión de Chrome necesita que el usuario elija a qué publicación propia
    // corresponde el competidor que está viendo en ML: adivinarlo por parecido de título
    // vincularía en silencio al producto equivocado, y ese precio entra derecho al cálculo.
    // Trae la moneda sugerida acá para que el popup no tenga que pedirla por separado.
    public async Task<List<MlPublicacionParaVincular>> GetPublicacionesParaVincularAsync()
    {
        var list = new List<MlPublicacionParaVincular>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT pub.PublicacionID, pub.MeliItemID, pub.PrecioActual, p.Titulo, p.SKU, pg.MonedaPrincipalID
                             FROM PublicacionesML pub
                             JOIN Productos p ON p.ProductoID = pub.ProductoID
                             LEFT JOIN ParametrosGenerales pg ON pg.EmpresaID = p.EmpresaID
                             WHERE pub.Estado <> 'closed'
                             ORDER BY p.Titulo";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new MlPublicacionParaVincular
            {
                PublicacionID = Convert.ToInt32(reader["PublicacionID"]),
                MeliItemID = reader["MeliItemID"].ToString() ?? string.Empty,
                Titulo = reader["Titulo"].ToString() ?? string.Empty,
                SKU = reader["SKU"].ToString() ?? string.Empty,
                PrecioActual = Convert.ToDecimal(reader["PrecioActual"]),
                MonedaPrincipalID = reader["MonedaPrincipalID"] is DBNull ? null : Convert.ToInt32(reader["MonedaPrincipalID"])
            });
        }
        return list;
    }

    // La Moneda Principal de la Empresa dueña de la publicación (vía Producto) se sugiere
    // como valor por defecto al vincular un competidor nuevo -- el usuario puede elegir otra.
    public async Task<int?> ObtenerMonedaPrincipalAsync(int publicacionId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT pg.MonedaPrincipalID
                             FROM PublicacionesML pub
                             JOIN Productos p ON p.ProductoID = pub.ProductoID
                             JOIN ParametrosGenerales pg ON pg.EmpresaID = p.EmpresaID
                             WHERE pub.PublicacionID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = publicacionId;
        var result = await cmd.ExecuteScalarAsync();
        return result is null or DBNull ? null : Convert.ToInt32(result);
    }

    // Alta o actualización: hay un UNIQUE sobre (PublicacionID, CompetidorItemID), así que
    // reenviar un competidor ya vinculado tiene que refrescarle el precio en vez de fallar.
    // Es el único camino que tiene la extensión de Chrome para actualizar un precio, porque
    // traerlo sola es imposible (ver el comentario sobre el 403 de ML más arriba). El UNIQUE
    // no distingue Activo, así que un vínculo dado de baja se reactiva en vez de chocar.
    public async Task<(int VinculoID, bool EsNuevo, decimal? PrecioAnterior)> VincularCompetidorAsync(int publicacionId, MlVincularCompetidorRequest dto, int usuarioId)
    {
        if (string.IsNullOrWhiteSpace(dto.CompetidorItemID))
            throw new ArgumentException("Ingresá un ID o un link de MercadoLibre.");
        if (dto.MonedaID <= 0)
            throw new ArgumentException("Elegí una moneda.");

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        var cuentaYSite = await ObtenerCuentaYSiteAsync(conn, publicacionId);
        var itemId = ExtraerItemId(dto.CompetidorItemID, cuentaYSite.SiteId);

        var existente = await BuscarVinculoAsync(conn, publicacionId, itemId);

        int vinculoId;
        if (existente is null)
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO PublicacionCompetidoresManual (PublicacionID, CompetidorItemID, CompetidorTitulo, UsuarioVinculoID, MonedaID, UltimoPrecio, FechaUltimoPrecio)
                                 VALUES (@publicacionId, @competidorItemId, @competidorTitulo, @usuarioId, @monedaId, @precio, SYSDATETIME());
                                 SELECT SCOPE_IDENTITY();";
            cmd.Parameters.Add("@publicacionId", SqlDbType.Int).Value = publicacionId;
            cmd.Parameters.Add("@competidorItemId", SqlDbType.VarChar, 50).Value = itemId;
            cmd.Parameters.Add("@competidorTitulo", SqlDbType.VarChar, 255).Value = (object?)dto.CompetidorTitulo ?? DBNull.Value;
            cmd.Parameters.Add("@usuarioId", SqlDbType.Int).Value = usuarioId;
            cmd.Parameters.Add("@monedaId", SqlDbType.Int).Value = dto.MonedaID;
            cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = dto.Precio;
            vinculoId = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        }
        else
        {
            vinculoId = existente.Value.VinculoID;
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"UPDATE PublicacionCompetidoresManual
                                 SET UltimoPrecio = @precio, FechaUltimoPrecio = SYSDATETIME(), MonedaID = @monedaId,
                                     CompetidorTitulo = COALESCE(@competidorTitulo, CompetidorTitulo),
                                     UsuarioVinculoID = @usuarioId, Activo = 1
                                 WHERE VinculoID = @id";
            cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = dto.Precio;
            cmd.Parameters.Add("@monedaId", SqlDbType.Int).Value = dto.MonedaID;
            cmd.Parameters.Add("@competidorTitulo", SqlDbType.VarChar, 255).Value = (object?)dto.CompetidorTitulo ?? DBNull.Value;
            cmd.Parameters.Add("@usuarioId", SqlDbType.Int).Value = usuarioId;
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = vinculoId;
            await cmd.ExecuteNonQueryAsync();
        }

        await InsertarCompetenciaSnapshotManualAsync(conn, publicacionId, itemId, dto.Precio);
        return (vinculoId, existente is null, existente?.UltimoPrecio);
    }

    private static async Task<(int VinculoID, decimal? UltimoPrecio)?> BuscarVinculoAsync(SqlConnection conn, int publicacionId, string itemId)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT VinculoID, UltimoPrecio FROM PublicacionCompetidoresManual WHERE PublicacionID = @publicacionId AND CompetidorItemID = @competidorItemId";
        cmd.Parameters.Add("@publicacionId", SqlDbType.Int).Value = publicacionId;
        cmd.Parameters.Add("@competidorItemId", SqlDbType.VarChar, 50).Value = itemId;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;
        return (
            Convert.ToInt32(reader["VinculoID"]),
            reader["UltimoPrecio"] is DBNull ? null : Convert.ToDecimal(reader["UltimoPrecio"]));
    }

    public async Task DesvincularCompetidorAsync(int vinculoId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE PublicacionCompetidoresManual SET Activo = 0 WHERE VinculoID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = vinculoId;
        await cmd.ExecuteNonQueryAsync();
    }

    // El usuario reescribe el precio que ve en su propio navegador cuando quiere
    // refrescarlo -- no hay forma de traerlo solo (ver comentario arriba). Actualiza el
    // último precio conocido en el vínculo y agrega un snapshot nuevo a CompetenciaSnapshot
    // (mismo destino que alimenta al motor para catálogo vía price_to_win).
    public async Task ActualizarPrecioCompetidorAsync(int vinculoId, decimal precio)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        int publicacionId;
        string competidorItemId;
        await using (var selectCmd = conn.CreateCommand())
        {
            selectCmd.CommandText = "SELECT PublicacionID, CompetidorItemID FROM PublicacionCompetidoresManual WHERE VinculoID = @id AND Activo = 1";
            selectCmd.Parameters.Add("@id", SqlDbType.Int).Value = vinculoId;
            await using var reader = await selectCmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
                throw new InvalidOperationException("Vínculo no encontrado.");
            publicacionId = Convert.ToInt32(reader["PublicacionID"]);
            competidorItemId = reader["CompetidorItemID"].ToString() ?? string.Empty;
        }

        await using (var updateCmd = conn.CreateCommand())
        {
            updateCmd.CommandText = "UPDATE PublicacionCompetidoresManual SET UltimoPrecio = @precio, FechaUltimoPrecio = SYSDATETIME() WHERE VinculoID = @id";
            updateCmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = precio;
            updateCmd.Parameters.Add("@id", SqlDbType.Int).Value = vinculoId;
            await updateCmd.ExecuteNonQueryAsync();
        }

        await InsertarCompetenciaSnapshotManualAsync(conn, publicacionId, competidorItemId, precio);
    }

    private static async Task InsertarCompetenciaSnapshotManualAsync(SqlConnection conn, int publicacionId, string competidorItemId, decimal precio)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, EsCompetidorDirecto, NivelRelevancia)
                             VALUES (@publicacionId, @competidorItemId, @precio, 1, 1)";
        cmd.Parameters.Add("@publicacionId", SqlDbType.Int).Value = publicacionId;
        cmd.Parameters.Add("@competidorItemId", SqlDbType.VarChar, 50).Value = competidorItemId;
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = precio;
        await cmd.ExecuteNonQueryAsync();
    }
}
