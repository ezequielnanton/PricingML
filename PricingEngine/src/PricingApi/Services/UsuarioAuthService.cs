using System.Data;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

public record UsuarioSession(int UsuarioID, string NombreCompleto, string Rol, IReadOnlyList<string> Secciones, DateTime ExpiraUtc);

public enum EliminarUsuarioResultado { Eliminado, NoEncontrado, TieneHistorial }

public enum ResetearPasswordResultado { Ok, TokenInvalido, TokenExpirado, TokenUsado }

public record SolicitudResetPassword(int UsuarioID, string Email, string Token);

// #loginGeneralApp: usuario+contraseña para toda la superficie de la app que antes
// era de acceso libre (AdminPanel, Cola ML, Integraciones, Reportes, Pricing). Alcance
// global (no por Empresa, a diferencia de Repositor): esas pantallas ya operan sobre
// todas las Empresas de la instalación sin filtrar, así que no cambia qué datos se ven,
// solo agrega la puerta de entrada.
// #sesionesPersistentes: las sesiones (token -> Usuario) viven en la tabla
// UsuarioSesiones, no en memoria — así un reinicio de la API no desloguea a todo el
// mundo (ver ADR 0018). NombreCompleto/Rol/Secciones quedan grabados tal cual estaban
// en el momento del login (no se releen de Usuarios/UsuarioSecciones en cada request),
// mismo diseño "cambios de permisos requieren volver a loguearse" que ya regía cuando
// las sesiones eran solo en memoria (ver ADR 0012/0013).
// #permisosPorSeccion: Secciones controla qué pantallas ve cada Usuario en la UI (menú
// y rutas) — es una lista abierta de ids de sección que la propia UI define (ver
// Sidebar.jsx), no un enum acá. El límite real de escritura sigue siendo el Rol,
// aplicado parejo a toda la API por el middleware de Program.cs: separar Formularios de
// Reportes a nivel de API hoy no es viable sin reorganizar esas rutas, que hoy comparten
// los mismos endpoints /api/admin/* (ver ADR 0013).
public class UsuarioAuthService
{
    private const int PasswordIterations = 100_000;
    private const int PasswordHashSize = 32;
    private static readonly TimeSpan SessionDuration = TimeSpan.FromHours(12);
    private static readonly HashSet<string> RolesValidos = new(StringComparer.OrdinalIgnoreCase) { "ADMIN", "LECTURA" };

    // Usada solo para el bootstrap del primer ADMIN, que debe ver todo sin tener que
    // tildar nada — para cualquier usuario creado después, las secciones las elige
    // explícitamente quien lo da de alta.
    public static readonly string[] TodasLasSecciones =
    {
        "pricing", "admin", "reports", "manual", "health", "erp", "ml-integracion", "email-integracion", "ejecucion-automatica", "cola-ml-aprobacion", "usuarios",
    };

    // El link de reseteo vale 1 hora; después el token queda inservible aunque nadie lo haya usado.
    private static readonly TimeSpan PasswordResetDuration = TimeSpan.FromHours(1);

    private readonly string _connectionString;

    public UsuarioAuthService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    public async Task<bool> ExistenUsuariosAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT COUNT(1) FROM Usuarios";
        var count = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        return count > 0;
    }

    public async Task<int> CreateUsuarioAsync(UsuarioCreateRequest dto)
    {
        var rol = RolesValidos.Contains(dto.Rol) ? dto.Rol.ToUpperInvariant() : "ADMIN";
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = HashPassword(dto.Password, salt);

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync();

        int usuarioId;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.Transaction = tx;
            cmd.CommandText = @"INSERT INTO Usuarios (NombreCompleto, Usuario, PasswordHash, PasswordSalt, Rol, Email)
                                 VALUES (@nombre, @usuario, @hash, @salt, @rol, @email);
                                 SELECT SCOPE_IDENTITY();";
            cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 150).Value = dto.NombreCompleto;
            cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 50).Value = dto.Usuario;
            cmd.Parameters.Add("@hash", SqlDbType.VarBinary, 64).Value = hash;
            cmd.Parameters.Add("@salt", SqlDbType.VarBinary, 32).Value = salt;
            cmd.Parameters.Add("@rol", SqlDbType.VarChar, 20).Value = rol;
            cmd.Parameters.Add("@email", SqlDbType.VarChar, 200).Value = (object?)dto.Email ?? DBNull.Value;
            usuarioId = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        }

        await InsertarSeccionesAsync(conn, tx, usuarioId, dto.Secciones);
        await tx.CommitAsync();
        return usuarioId;
    }

    public async Task<bool> SetSeccionesAsync(int usuarioId, List<string> secciones)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync();

        await using (var existeCmd = conn.CreateCommand())
        {
            existeCmd.Transaction = tx;
            existeCmd.CommandText = "SELECT 1 FROM Usuarios WHERE UsuarioID = @id";
            existeCmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
            if (await existeCmd.ExecuteScalarAsync() is null)
            {
                await tx.RollbackAsync();
                return false;
            }
        }

        await using (var deleteCmd = conn.CreateCommand())
        {
            deleteCmd.Transaction = tx;
            deleteCmd.CommandText = "DELETE FROM UsuarioSecciones WHERE UsuarioID = @id";
            deleteCmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
            await deleteCmd.ExecuteNonQueryAsync();
        }

        await InsertarSeccionesAsync(conn, tx, usuarioId, secciones);
        await tx.CommitAsync();
        return true;
    }

    private static async Task InsertarSeccionesAsync(SqlConnection conn, SqlTransaction tx, int usuarioId, List<string> secciones)
    {
        foreach (var seccion in secciones.Distinct())
        {
            await using var cmd = conn.CreateCommand();
            cmd.Transaction = tx;
            cmd.CommandText = "INSERT INTO UsuarioSecciones (UsuarioID, Seccion) VALUES (@id, @seccion)";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
            cmd.Parameters.Add("@seccion", SqlDbType.VarChar, 50).Value = seccion;
            await cmd.ExecuteNonQueryAsync();
        }
    }

    private async Task<List<string>> GetSeccionesAsync(SqlConnection conn, int usuarioId)
    {
        var secciones = new List<string>();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT Seccion FROM UsuarioSecciones WHERE UsuarioID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            secciones.Add(reader.GetString(0));
        return secciones;
    }

    public async Task<List<UsuarioResumen>> ListarAsync()
    {
        var list = new List<UsuarioResumen>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT u.UsuarioID, u.NombreCompleto, u.Usuario, u.Rol, u.Email, u.Activo, s.Seccion
                             FROM Usuarios u
                             LEFT JOIN UsuarioSecciones s ON s.UsuarioID = u.UsuarioID
                             ORDER BY u.NombreCompleto";
        await using var reader = await cmd.ExecuteReaderAsync();
        var porId = new Dictionary<int, UsuarioResumen>();
        while (await reader.ReadAsync())
        {
            var usuarioId = Convert.ToInt32(reader["UsuarioID"]);
            if (!porId.TryGetValue(usuarioId, out var resumen))
            {
                resumen = new UsuarioResumen
                {
                    UsuarioID = usuarioId,
                    NombreCompleto = reader["NombreCompleto"].ToString() ?? string.Empty,
                    Usuario = reader["Usuario"].ToString() ?? string.Empty,
                    Rol = reader["Rol"].ToString() ?? string.Empty,
                    Email = reader["Email"] as string,
                    Activo = Convert.ToBoolean(reader["Activo"]),
                };
                porId[usuarioId] = resumen;
                list.Add(resumen);
            }
            if (reader["Seccion"] is string seccion)
                resumen.Secciones.Add(seccion);
        }
        return list;
    }

    // #eliminarUsuarioDefinitivo: DELETE real (no un soft-delete) — a propósito no
    // hace SET NULL ni cascada sobre ColaEjecucionML.UsuarioAprobacionID ni
    // PublicacionCompetidoresManual.UsuarioVinculoID: si el Usuario aprobó/rechazó o
    // vinculó algo alguna vez, el motor de FK de SQL Server rechaza el DELETE (error
    // 547) y esa historia de auditoría queda intacta. La única salida para esas
    // cuentas es "Desactivar" (ver ADR 0012), nunca perder el rastro de quién hizo qué.
    public async Task<EliminarUsuarioResultado> DeleteUsuarioAsync(int usuarioId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        try
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = "DELETE FROM Usuarios WHERE UsuarioID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
            var rows = await cmd.ExecuteNonQueryAsync();
            return rows > 0 ? EliminarUsuarioResultado.Eliminado : EliminarUsuarioResultado.NoEncontrado;
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            return EliminarUsuarioResultado.TieneHistorial;
        }
    }

    public async Task<bool> SetEmailAsync(int usuarioId, string? email)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Usuarios SET Email = @email WHERE UsuarioID = @id";
        cmd.Parameters.Add("@email", SqlDbType.VarChar, 200).Value = (object?)email ?? DBNull.Value;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> SetActivoAsync(int usuarioId, bool activo)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Usuarios SET Activo = @activo WHERE UsuarioID = @id";
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = activo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    // #modoOscuroPorUsuario: preferencia de tema propia (no un permiso, ver Secciones) --
    // por eso se lee/escribe en vivo contra Usuarios en cada request en vez de viajar
    // grabada en UsuarioSesiones como NombreCompleto/Rol/Secciones (que exigen volver a
    // loguearse para reflejar un cambio); togglear el tema aplica al toque, sin relogin.
    public async Task<bool> SetModoOscuroAsync(int usuarioId, bool modoOscuro)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Usuarios SET ModoOscuro = @modoOscuro WHERE UsuarioID = @id";
        cmd.Parameters.Add("@modoOscuro", SqlDbType.Bit).Value = modoOscuro;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> GetModoOscuroAsync(int usuarioId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT ModoOscuro FROM Usuarios WHERE UsuarioID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
        var result = await cmd.ExecuteScalarAsync();
        return result is bool b && b;
    }

    // #loginGeneralApp: cambio de la propia contraseña — exige conocer la actual, igual
    // que cualquier flujo de "cambiar contraseña" normal. No invalida la sesión vigente
    // (el token no depende del hash de password); solo afecta logins futuros.
    public async Task<bool> ChangePasswordAsync(int usuarioId, string passwordActual, string passwordNueva)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        byte[] storedHash;
        byte[] salt;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT PasswordHash, PasswordSalt FROM Usuarios WHERE UsuarioID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
                return false;
            storedHash = (byte[])reader["PasswordHash"];
            salt = (byte[])reader["PasswordSalt"];
        }

        var candidateHash = HashPassword(passwordActual, salt);
        if (!CryptographicOperations.FixedTimeEquals(storedHash, candidateHash))
            return false;

        var nuevoSalt = RandomNumberGenerator.GetBytes(16);
        var nuevoHash = HashPassword(passwordNueva, nuevoSalt);

        await using var updateCmd = conn.CreateCommand();
        updateCmd.CommandText = "UPDATE Usuarios SET PasswordHash = @hash, PasswordSalt = @salt WHERE UsuarioID = @id";
        updateCmd.Parameters.Add("@hash", SqlDbType.VarBinary, 64).Value = nuevoHash;
        updateCmd.Parameters.Add("@salt", SqlDbType.VarBinary, 32).Value = nuevoSalt;
        updateCmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
        await updateCmd.ExecuteNonQueryAsync();
        return true;
    }

    // #recuperarPassword: genera un token de un solo uso si el Usuario existe, está
    // activo y tiene un email cargado. Devuelve null en cualquier otro caso — el
    // endpoint siempre responde el mismo mensaje genérico ("si existe, te mandamos
    // instrucciones") sin importar cuál de esos casos fue, para no revelar por
    // enumeración qué usuarios existen en la instalación.
    public async Task<SolicitudResetPassword?> RequestPasswordResetAsync(string usuario)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        int usuarioId;
        string email;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT UsuarioID, Email FROM Usuarios WHERE Usuario = @usuario AND Activo = 1";
            cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 50).Value = usuario;
            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
                return null;
            if (reader["Email"] is not string emailValor || string.IsNullOrWhiteSpace(emailValor))
                return null;
            usuarioId = Convert.ToInt32(reader["UsuarioID"]);
            email = emailValor;
        }

        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .Replace('+', '-').Replace('/', '_').TrimEnd('=');

        await using var insertCmd = conn.CreateCommand();
        insertCmd.CommandText = @"INSERT INTO PasswordResetTokens (UsuarioID, Token, FechaExpiracion)
                                   VALUES (@usuarioId, @token, @expira)";
        insertCmd.Parameters.Add("@usuarioId", SqlDbType.Int).Value = usuarioId;
        insertCmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
        insertCmd.Parameters.Add("@expira", SqlDbType.DateTime2).Value = DateTime.UtcNow.Add(PasswordResetDuration);
        await insertCmd.ExecuteNonQueryAsync();

        return new SolicitudResetPassword(usuarioId, email, token);
    }

    public async Task<ResetearPasswordResultado> ResetPasswordViaTokenAsync(string token, string passwordNueva)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync();

        int usuarioId = 0;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.Transaction = tx;
            cmd.CommandText = "SELECT TokenID, UsuarioID, FechaExpiracion, Usado FROM PasswordResetTokens WHERE Token = @token";
            cmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
            ResetearPasswordResultado? fallo = null;
            await using (var reader = await cmd.ExecuteReaderAsync())
            {
                if (!await reader.ReadAsync())
                {
                    fallo = ResetearPasswordResultado.TokenInvalido;
                }
                else if (Convert.ToBoolean(reader["Usado"]))
                {
                    fallo = ResetearPasswordResultado.TokenUsado;
                }
                else if (Convert.ToDateTime(reader["FechaExpiracion"]) < DateTime.UtcNow)
                {
                    fallo = ResetearPasswordResultado.TokenExpirado;
                }
                else
                {
                    usuarioId = Convert.ToInt32(reader["UsuarioID"]);
                }
            }
            // #cerrarReaderAntesDeRollback: SqlClient no permite tx.RollbackAsync() con un
            // DataReader todavía abierto en la misma conexión — el reader se cierra al salir
            // del bloque `await using` de arriba, recién ahí es seguro hacer rollback.
            if (fallo is ResetearPasswordResultado valorFallo)
            {
                await tx.RollbackAsync();
                return valorFallo;
            }
        }

        var nuevoSalt = RandomNumberGenerator.GetBytes(16);
        var nuevoHash = HashPassword(passwordNueva, nuevoSalt);

        await using (var updateCmd = conn.CreateCommand())
        {
            updateCmd.Transaction = tx;
            updateCmd.CommandText = "UPDATE Usuarios SET PasswordHash = @hash, PasswordSalt = @salt WHERE UsuarioID = @id";
            updateCmd.Parameters.Add("@hash", SqlDbType.VarBinary, 64).Value = nuevoHash;
            updateCmd.Parameters.Add("@salt", SqlDbType.VarBinary, 32).Value = nuevoSalt;
            updateCmd.Parameters.Add("@id", SqlDbType.Int).Value = usuarioId;
            await updateCmd.ExecuteNonQueryAsync();
        }

        await using (var marcarCmd = conn.CreateCommand())
        {
            marcarCmd.Transaction = tx;
            marcarCmd.CommandText = "UPDATE PasswordResetTokens SET Usado = 1 WHERE Token = @token";
            marcarCmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
            await marcarCmd.ExecuteNonQueryAsync();
        }

        await tx.CommitAsync();
        return ResetearPasswordResultado.Ok;
    }

    public async Task<UsuarioLoginResponse?> LoginAsync(UsuarioLoginRequest request)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT UsuarioID, NombreCompleto, Rol, PasswordHash, PasswordSalt, ModoOscuro
                             FROM Usuarios
                             WHERE Usuario = @usuario AND Activo = 1";
        cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 50).Value = request.Usuario;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        var usuarioId = Convert.ToInt32(reader["UsuarioID"]);
        var nombre = reader["NombreCompleto"].ToString() ?? string.Empty;
        var rol = reader["Rol"].ToString() ?? "ADMIN";
        var storedHash = (byte[])reader["PasswordHash"];
        var salt = (byte[])reader["PasswordSalt"];
        var modoOscuro = reader["ModoOscuro"] is bool mo && mo;
        await reader.DisposeAsync();

        var candidateHash = HashPassword(request.Password, salt);
        if (!CryptographicOperations.FixedTimeEquals(storedHash, candidateHash))
            return null;

        var secciones = await GetSeccionesAsync(conn, usuarioId);
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        var expira = DateTime.UtcNow.Add(SessionDuration);

        await using (var insertCmd = conn.CreateCommand())
        {
            insertCmd.CommandText = @"INSERT INTO UsuarioSesiones (Token, UsuarioID, NombreCompleto, Rol, SeccionesCsv, FechaExpiracion)
                                       VALUES (@token, @usuarioId, @nombre, @rol, @seccionesCsv, @expira)";
            insertCmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
            insertCmd.Parameters.Add("@usuarioId", SqlDbType.Int).Value = usuarioId;
            insertCmd.Parameters.Add("@nombre", SqlDbType.VarChar, 150).Value = nombre;
            insertCmd.Parameters.Add("@rol", SqlDbType.VarChar, 20).Value = rol;
            insertCmd.Parameters.Add("@seccionesCsv", SqlDbType.VarChar, 500).Value = (object?)string.Join(',', secciones) ?? DBNull.Value;
            insertCmd.Parameters.Add("@expira", SqlDbType.DateTime2).Value = expira;
            await insertCmd.ExecuteNonQueryAsync();
        }

        return new UsuarioLoginResponse { Token = token, UsuarioID = usuarioId, NombreCompleto = nombre, Rol = rol, Secciones = secciones, ModoOscuro = modoOscuro };
    }

    public async Task LogoutAsync(string token)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM UsuarioSesiones WHERE Token = @token";
        cmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<UsuarioSession?> ResolveSession(HttpRequest request)
    {
        var header = request.Headers.Authorization.ToString();
        if (string.IsNullOrEmpty(header) || !header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return null;
        return await ResolveToken(header["Bearer ".Length..].Trim());
    }

    public async Task<UsuarioSession?> ResolveToken(string token)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        int usuarioId;
        string nombre;
        string rol;
        string? seccionesCsv;
        DateTime expiraUtc;
        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SELECT UsuarioID, NombreCompleto, Rol, SeccionesCsv, FechaExpiracion FROM UsuarioSesiones WHERE Token = @token";
            cmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
            await using var reader = await cmd.ExecuteReaderAsync();
            if (!await reader.ReadAsync())
                return null;
            usuarioId = Convert.ToInt32(reader["UsuarioID"]);
            nombre = reader["NombreCompleto"].ToString() ?? string.Empty;
            rol = reader["Rol"].ToString() ?? "ADMIN";
            seccionesCsv = reader["SeccionesCsv"] as string;
            expiraUtc = Convert.ToDateTime(reader["FechaExpiracion"]);
        }

        if (expiraUtc < DateTime.UtcNow)
        {
            await using var deleteCmd = conn.CreateCommand();
            deleteCmd.CommandText = "DELETE FROM UsuarioSesiones WHERE Token = @token";
            deleteCmd.Parameters.Add("@token", SqlDbType.VarChar, 100).Value = token;
            await deleteCmd.ExecuteNonQueryAsync();
            return null;
        }

        var secciones = string.IsNullOrEmpty(seccionesCsv)
            ? new List<string>()
            : seccionesCsv.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList();
        return new UsuarioSession(usuarioId, nombre, rol, secciones, expiraUtc);
    }

    private static byte[] HashPassword(string password, byte[] salt)
    {
        return Rfc2898DeriveBytes.Pbkdf2(password, salt, PasswordIterations, HashAlgorithmName.SHA256, PasswordHashSize);
    }
}
