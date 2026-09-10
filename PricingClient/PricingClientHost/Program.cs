using System.Diagnostics;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

var config = ClienteConfig.Cargar(args);

var (paginaIndex, archivos) = RecursosWeb.Cargar(config.ApiUrl);
if (paginaIndex.Length == 0)
{
    Consola.Error("El ejecutable no contiene el build del Cliente (falta index.html).");
    Consola.EsperarSalida();
    return 1;
}

var builder = WebApplication.CreateBuilder();
builder.Logging.ClearProviders();
builder.WebHost.UseUrls($"http://0.0.0.0:{config.Puerto}");
var app = builder.Build();

app.Run(async contexto =>
{
    var ruta = contexto.Request.Path.Value ?? "/";

    if (ruta != "/" && archivos.TryGetValue(ruta, out var archivo))
    {
        contexto.Response.ContentType = RecursosWeb.TipoDeContenido(ruta);
        contexto.Response.Headers.CacheControl = "public, max-age=31536000, immutable";
        await contexto.Response.Body.WriteAsync(archivo);
        return;
    }

    // Cualquier otra ruta cae en index.html: el ruteo lo resuelve React (SPA).
    contexto.Response.ContentType = "text/html; charset=utf-8";
    contexto.Response.Headers.CacheControl = "no-cache, no-store, must-revalidate";
    await contexto.Response.Body.WriteAsync(paginaIndex);
});

var direccion = $"http://localhost:{config.Puerto}";
try
{
    await app.StartAsync();
}
catch (IOException)
{
    Consola.Error($"El puerto {config.Puerto} ya esta en uso.");
    Console.WriteLine($"  Cerra el programa que lo ocupa, o edita \"puerto\" en {ClienteConfig.RutaArchivo}");
    Consola.EsperarSalida();
    return 1;
}

Consola.Titulo("PricingML - Cliente");
Console.WriteLine($"  Cliente disponible en : {direccion}");
Console.WriteLine($"  Motor (API)           : {(string.IsNullOrWhiteSpace(config.ApiUrl) ? "automatico (mismo equipo, puerto 5000)" : config.ApiUrl)}");
Console.WriteLine($"  Configuracion         : {ClienteConfig.RutaArchivo}");
Console.WriteLine();
Console.WriteLine("  Para cerrar el Cliente, cerra esta ventana.");
Console.WriteLine();

if (config.AbrirNavegador) Consola.AbrirNavegador(direccion);

await app.WaitForShutdownAsync();
return 0;

file sealed class ClienteConfig
{
    public int Puerto { get; init; } = 3000;
    public string ApiUrl { get; init; } = "";
    public bool AbrirNavegador { get; init; } = true;

    public static string RutaArchivo { get; } =
        Path.Combine(AppContext.BaseDirectory, "PricingCliente.config.json");

    public static ClienteConfig Cargar(string[] args)
    {
        var guardado = LeerArchivo();
        var config = guardado ?? PreguntarConfiguracionInicial();

        var puerto = LeerEntero(args, "--puerto") ?? LeerEntero(args, "--port") ?? config.Puerto;
        var apiUrl = LeerTexto(args, "--api") ?? config.ApiUrl;
        var abrir = !args.Contains("--sin-navegador") && !args.Contains("--no-browser");

        return new ClienteConfig { Puerto = puerto, ApiUrl = apiUrl, AbrirNavegador = abrir };
    }

    static ClienteConfig? LeerArchivo()
    {
        if (!File.Exists(RutaArchivo)) return null;
        try
        {
            if (JsonNode.Parse(File.ReadAllText(RutaArchivo)) is not JsonObject raiz) return null;
            return new ClienteConfig
            {
                Puerto = raiz["puerto"]?.GetValue<int>() ?? 3000,
                ApiUrl = raiz["apiUrl"]?.GetValue<string>() ?? ""
            };
        }
        catch (Exception ex) when (ex is JsonException or IOException or InvalidOperationException or FormatException)
        {
            Consola.Error($"No se pudo leer {RutaArchivo}, se usan los valores por defecto.");
            return null;
        }
    }

    // Primer arranque: si no se puede preguntar (doble clic sin consola, servicio), los
    // valores por defecto ya sirven para el caso normal de Motor y Cliente en el mismo equipo.
    static ClienteConfig PreguntarConfiguracionInicial()
    {
        Consola.Titulo("PricingML - Configuracion inicial del Cliente");
        Console.WriteLine("  Presiona Enter para aceptar el valor entre corchetes.");
        Console.WriteLine();

        var puerto = Consola.PreguntarEntero("  Puerto para el Cliente", 3000);
        Console.WriteLine();
        Console.WriteLine("  Direccion del Motor. Dejalo vacio si el Motor corre en este mismo equipo.");
        Console.WriteLine("  Si esta en otra PC, escribi por ejemplo: http://192.168.1.50:5000");
        var apiUrl = Consola.PreguntarTexto("  Direccion del Motor", "").TrimEnd('/');

        var config = new ClienteConfig { Puerto = puerto, ApiUrl = apiUrl };
        config.Guardar();
        return config;
    }

    void Guardar()
    {
        try
        {
            var json = JsonSerializer.Serialize(
                new { puerto = Puerto, apiUrl = ApiUrl },
                new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(RutaArchivo, json);
            Console.WriteLine();
            Console.WriteLine($"  Configuracion guardada en {RutaArchivo}");
        }
        catch (IOException ex)
        {
            Consola.Error($"No se pudo guardar la configuracion: {ex.Message}");
        }
    }

    static string? LeerTexto(string[] args, string nombre)
    {
        var i = Array.IndexOf(args, nombre);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }

    static int? LeerEntero(string[] args, string nombre) =>
        int.TryParse(LeerTexto(args, nombre), out var v) ? v : null;
}

file static class RecursosWeb
{
    public static (byte[] Index, Dictionary<string, byte[]> Archivos) Cargar(string apiUrl)
    {
        var ensamblado = Assembly.GetExecutingAssembly();
        var archivos = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);

        foreach (var recurso in ensamblado.GetManifestResourceNames())
        {
            var normalizado = recurso.Replace('\\', '/');
            if (!normalizado.StartsWith("web/", StringComparison.OrdinalIgnoreCase)) continue;

            using var origen = ensamblado.GetManifestResourceStream(recurso);
            if (origen is null) continue;
            using var memoria = new MemoryStream();
            origen.CopyTo(memoria);
            archivos["/" + normalizado[4..]] = memoria.ToArray();
        }

        var index = archivos.TryGetValue("/index.html", out var original)
            ? Inyectar(original, apiUrl)
            : Array.Empty<byte>();

        return (index, archivos);
    }

    // La URL del Motor se resuelve en tiempo de ejecucion (no al compilar React): se inyecta
    // como variable global que apiBase.js lee antes de su deteccion automatica.
    static byte[] Inyectar(byte[] index, string apiUrl)
    {
        if (string.IsNullOrWhiteSpace(apiUrl)) return index;

        var html = Encoding.UTF8.GetString(index);
        var etiqueta = $"<script>window.__PRICING_API_BASE__={JsonSerializer.Serialize(apiUrl)};</script>";
        var cierre = html.IndexOf("</head>", StringComparison.OrdinalIgnoreCase);

        html = cierre >= 0
            ? html[..cierre] + etiqueta + html[cierre..]
            : etiqueta + html;

        return Encoding.UTF8.GetBytes(html);
    }

    public static string TipoDeContenido(string ruta) => Path.GetExtension(ruta).ToLowerInvariant() switch
    {
        ".html" => "text/html; charset=utf-8",
        ".js" or ".mjs" => "text/javascript; charset=utf-8",
        ".css" => "text/css; charset=utf-8",
        ".json" => "application/json; charset=utf-8",
        ".svg" => "image/svg+xml",
        ".png" => "image/png",
        ".jpg" or ".jpeg" => "image/jpeg",
        ".gif" => "image/gif",
        ".webp" => "image/webp",
        ".ico" => "image/x-icon",
        ".woff" => "font/woff",
        ".woff2" => "font/woff2",
        ".ttf" => "font/ttf",
        ".map" => "application/json; charset=utf-8",
        _ => "application/octet-stream"
    };
}

file static class Consola
{
    public static void Titulo(string texto)
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 60));
        Console.WriteLine("  " + texto);
        Console.WriteLine(new string('=', 60));
        Console.WriteLine();
    }

    public static void Error(string mensaje)
    {
        Console.WriteLine();
        Console.WriteLine("  [ERROR] " + mensaje);
    }

    public static string PreguntarTexto(string etiqueta, string porDefecto)
    {
        Console.Write($"{etiqueta} [{porDefecto}]: ");
        var respuesta = Console.ReadLine();
        return string.IsNullOrWhiteSpace(respuesta) ? porDefecto : respuesta.Trim();
    }

    public static int PreguntarEntero(string etiqueta, int porDefecto)
    {
        while (true)
        {
            var texto = PreguntarTexto(etiqueta, porDefecto.ToString());
            if (int.TryParse(texto, out var valor) && valor is > 0 and < 65536) return valor;
            Console.WriteLine("  Ingresa un numero de puerto valido (1-65535).");
        }
    }

    public static void AbrirNavegador(string direccion)
    {
        try
        {
            Process.Start(new ProcessStartInfo(direccion) { UseShellExecute = true });
        }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            Console.WriteLine($"  Abri manualmente {direccion} en tu navegador.");
        }
    }

    public static void EsperarSalida()
    {
        Console.WriteLine();
        Console.WriteLine("  Presiona Enter para cerrar.");
        Console.ReadLine();
    }
}
