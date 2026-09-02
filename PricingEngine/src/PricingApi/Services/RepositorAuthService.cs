using System.Collections.Concurrent;
using System.Data;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

public record RepositorSession(int RepositorID, int EmpresaID, string NombreCompleto, DateTime ExpiraUtc);

// #cargaOperativaRepositor: login mínimo (Usuario+PIN) para la pantalla de carga de
// stock de un repositor sin ERP. Los tokens se guardan en memoria (no JWT, no tabla de
// sesión): alcanza para trazabilidad de auditoría y se pierden si la API reinicia, lo
// cual es aceptable para esta herramienta interna de bajo riesgo.
public class RepositorAuthService
{
    private const int PinIterations = 100_000;
    private const int PinHashSize = 32;
    private static readonly TimeSpan SessionDuration = TimeSpan.FromHours(12);

    private readonly string _connectionString;
    private readonly ConcurrentDictionary<string, RepositorSession> _sessions = new();

    public RepositorAuthService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    public async Task<int> CreateRepositorAsync(RepositorCreateRequest dto)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = HashPin(dto.Pin, salt);

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"INSERT INTO Repositores (EmpresaID, NombreCompleto, Usuario, PinHash, PinSalt)
                             VALUES (@empresaId, @nombre, @usuario, @hash, @salt);
                             SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 150).Value = dto.NombreCompleto;
        cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 50).Value = dto.Usuario;
        cmd.Parameters.Add("@hash", SqlDbType.VarBinary, 64).Value = hash;
        cmd.Parameters.Add("@salt", SqlDbType.VarBinary, 32).Value = salt;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task<RepositorLoginResponse?> LoginAsync(RepositorLoginRequest request)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT RepositorID, EmpresaID, NombreCompleto, PinHash, PinSalt
                             FROM Repositores
                             WHERE Usuario = @usuario AND Activo = 1";
        cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 50).Value = request.Usuario;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        var repositorId = Convert.ToInt32(reader["RepositorID"]);
        var empresaId = Convert.ToInt32(reader["EmpresaID"]);
        var nombre = reader["NombreCompleto"].ToString() ?? string.Empty;
        var storedHash = (byte[])reader["PinHash"];
        var salt = (byte[])reader["PinSalt"];

        var candidateHash = HashPin(request.Pin, salt);
        if (!CryptographicOperations.FixedTimeEquals(storedHash, candidateHash))
            return null;

        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        var session = new RepositorSession(repositorId, empresaId, nombre, DateTime.UtcNow.Add(SessionDuration));
        _sessions[token] = session;

        return new RepositorLoginResponse { Token = token, RepositorID = repositorId, NombreCompleto = nombre };
    }

    public RepositorSession? ResolveSession(HttpRequest request)
    {
        var header = request.Headers.Authorization.ToString();
        if (string.IsNullOrEmpty(header) || !header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return null;

        var token = header["Bearer ".Length..].Trim();
        if (!_sessions.TryGetValue(token, out var session))
            return null;

        if (session.ExpiraUtc < DateTime.UtcNow)
        {
            _sessions.TryRemove(token, out _);
            return null;
        }

        return session;
    }

    private static byte[] HashPin(string pin, byte[] salt)
    {
        return Rfc2898DeriveBytes.Pbkdf2(pin, salt, PinIterations, HashAlgorithmName.SHA256, PinHashSize);
    }
}
