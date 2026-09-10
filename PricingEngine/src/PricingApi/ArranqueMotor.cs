using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Data.SqlClient;

namespace PricingApi;

/// Configuracion asistida de la conexion a SQL Server para el Motor distribuido como .exe.
public static class ArranqueMotor
{
    const string NombreConexion = "PricingDb";

    static string RutaAppSettings => Path.Combine(AppContext.BaseDirectory, "appsettings.json");

    /// Devuelve false solo si el usuario decide abortar el arranque.
    public static bool AsegurarConfiguracion()
    {
        var cadena = LeerCadenaGuardada();

        if (string.IsNullOrWhiteSpace(cadena))
        {
            Titulo("PricingML - Configuracion inicial del Motor");
            Console.WriteLine("  No hay una conexion a SQL Server configurada todavia.");
            Console.WriteLine();
            return ConfigurarInteractivo();
        }

        var error = ProbarConexion(cadena);
        if (error is null) return true;

        Titulo("PricingML - No se pudo conectar a SQL Server");
        Console.WriteLine($"  {error}");
        Console.WriteLine();
        Console.WriteLine("  Revisa que SQL Server este iniciado y que los datos sean correctos.");
        Console.WriteLine();

        var quiereReconfigurar = Preguntar("  Queres reconfigurar la conexion ahora? (s/N)", "N")
            .StartsWith("s", StringComparison.OrdinalIgnoreCase);

        return quiereReconfigurar ? ConfigurarInteractivo() : true;
    }

    static bool ConfigurarInteractivo()
    {
        for (var intento = 1; ; intento++)
        {
            var cadena = PedirDatosDeConexion();

            Console.WriteLine();
            Console.WriteLine("  Probando la conexion...");
            var error = ProbarConexion(cadena);

            if (error is null)
            {
                Console.WriteLine("  Conexion correcta.");
                if (!Guardar(cadena)) return false;
                Console.WriteLine($"  Configuracion guardada en {RutaAppSettings}");
                Console.WriteLine();
                return true;
            }

            Console.WriteLine();
            Console.WriteLine($"  [ERROR] {error}");
            Console.WriteLine();

            // Sin consola interactiva las respuestas vuelven vacias: guardar igual evita
            // repreguntar en cada arranque y deja el archivo listo para editar a mano.
            if (!HayConsolaInteractiva())
            {
                Guardar(cadena);
                Console.WriteLine($"  Se guardo la configuracion en {RutaAppSettings} para que puedas corregirla.");
                return false;
            }

            if (intento >= 3 && !Preguntar("  Reintentar? (S/n)", "S").StartsWith("n", StringComparison.OrdinalIgnoreCase))
                return false;
        }
    }

    static string PedirDatosDeConexion()
    {
        Console.WriteLine("  Presiona Enter para aceptar el valor entre corchetes.");
        Console.WriteLine();

        var servidor = Preguntar("  Servidor SQL", "localhost\\SQLEXPRESS");
        var baseDatos = Preguntar("  Base de datos", "PRICES_DB");
        var usaWindows = !Preguntar("  Autenticacion de Windows? (S/n)", "S")
            .StartsWith("n", StringComparison.OrdinalIgnoreCase);

        var constructor = new SqlConnectionStringBuilder
        {
            DataSource = servidor,
            InitialCatalog = baseDatos,
            TrustServerCertificate = true,
            ConnectTimeout = 10
        };

        if (usaWindows)
        {
            constructor.IntegratedSecurity = true;
        }
        else
        {
            constructor.UserID = Preguntar("  Usuario SQL", "sa");
            constructor.Password = PreguntarContrasena("  Contrasena");
        }

        return constructor.ConnectionString;
    }

    static string? ProbarConexion(string cadena)
    {
        try
        {
            using var conexion = new SqlConnection(cadena);
            conexion.Open();
            return null;
        }
        catch (Exception ex) when (ex is SqlException or InvalidOperationException or ArgumentException)
        {
            return ex.Message;
        }
    }

    static string? LeerCadenaGuardada()
    {
        try
        {
            if (!File.Exists(RutaAppSettings)) return null;
            var raiz = JsonNode.Parse(File.ReadAllText(RutaAppSettings));
            return raiz?["ConnectionStrings"]?[NombreConexion]?.GetValue<string>();
        }
        catch (Exception ex) when (ex is JsonException or IOException or InvalidOperationException)
        {
            return null;
        }
    }

    static bool Guardar(string cadena)
    {
        try
        {
            var raiz = File.Exists(RutaAppSettings)
                ? JsonNode.Parse(File.ReadAllText(RutaAppSettings)) as JsonObject ?? new JsonObject()
                : new JsonObject();

            if (raiz["ConnectionStrings"] is not JsonObject conexiones)
            {
                conexiones = new JsonObject();
                raiz["ConnectionStrings"] = conexiones;
            }
            conexiones[NombreConexion] = cadena;

            File.WriteAllText(RutaAppSettings,
                raiz.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            return true;
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            Console.WriteLine();
            Console.WriteLine($"  [ERROR] No se pudo guardar {RutaAppSettings}: {ex.Message}");
            Console.WriteLine("  Proba mover el programa a una carpeta donde tengas permisos de escritura.");
            return false;
        }
    }

    static string Preguntar(string etiqueta, string porDefecto)
    {
        Console.Write($"{etiqueta} [{porDefecto}]: ");
        var respuesta = Console.ReadLine();
        return string.IsNullOrWhiteSpace(respuesta) ? porDefecto : respuesta.Trim();
    }

    static string PreguntarContrasena(string etiqueta)
    {
        Console.Write($"{etiqueta}: ");

        if (!HayConsolaInteractiva()) return Console.ReadLine()?.Trim() ?? string.Empty;

        var contrasena = new System.Text.StringBuilder();
        while (true)
        {
            var tecla = Console.ReadKey(intercept: true);
            if (tecla.Key == ConsoleKey.Enter) break;

            if (tecla.Key == ConsoleKey.Backspace)
            {
                if (contrasena.Length == 0) continue;
                contrasena.Length--;
                Console.Write("\b \b");
                continue;
            }

            if (char.IsControl(tecla.KeyChar)) continue;
            contrasena.Append(tecla.KeyChar);
            Console.Write('*');
        }

        Console.WriteLine();
        return contrasena.ToString();
    }

    static bool HayConsolaInteractiva()
    {
        try
        {
            return !Console.IsInputRedirected;
        }
        catch (IOException)
        {
            return false;
        }
    }

    static void Titulo(string texto)
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 60));
        Console.WriteLine("  " + texto);
        Console.WriteLine(new string('=', 60));
        Console.WriteLine();
    }
}
