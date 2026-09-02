using System.Data;
using System.Net;
using System.Net.Mail;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

// #recuperarPassword: servidor SMTP configurable desde la UI — una app de email por
// instalación, mismo patrón que ConfiguracionMercadoLibre (ADR 0006) e Integración
// MercadoLibre. Usa System.Net.Mail directamente en vez de sumar una librería nueva:
// alcanza para un envío simple de HTML por SMTP con o sin SSL.
public class EmailService
{
    private readonly string _connectionString;

    public EmailService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    private record ConfigEmail(string? Host, int? Port, string? Usuario, string? Password, bool UsarSsl, string? EmailDesde, string? NombreDesde, string? FrontendBaseUrl);

    private async Task<ConfigEmail> ObtenerConfigAsync(SqlConnection conn)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT TOP 1 SmtpHost, SmtpPort, SmtpUsuario, SmtpPassword, UsarSsl, EmailDesde, NombreDesde, FrontendBaseUrl
                             FROM ConfiguracionEmail ORDER BY ConfiguracionEmailID DESC";
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return new ConfigEmail(null, null, null, null, true, null, null, null);

        return new ConfigEmail(
            reader["SmtpHost"] as string,
            reader["SmtpPort"] as int?,
            reader["SmtpUsuario"] as string,
            reader["SmtpPassword"] as string,
            Convert.ToBoolean(reader["UsarSsl"]),
            reader["EmailDesde"] as string,
            reader["NombreDesde"] as string,
            reader["FrontendBaseUrl"] as string);
    }

    public async Task<EmailConfiguracionResponse> GetConfiguracionAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT TOP 1 SmtpHost, SmtpPort, SmtpUsuario, SmtpPassword, UsarSsl, EmailDesde, NombreDesde, FrontendBaseUrl, FechaActualizacion
                             FROM ConfiguracionEmail ORDER BY ConfiguracionEmailID DESC";
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return new EmailConfiguracionResponse { UsarSsl = true };

        var password = reader["SmtpPassword"] as string;
        return new EmailConfiguracionResponse
        {
            SmtpHost = reader["SmtpHost"] as string,
            SmtpPort = reader["SmtpPort"] as int?,
            SmtpUsuario = reader["SmtpUsuario"] as string,
            SmtpPasswordConfigurada = !string.IsNullOrWhiteSpace(password),
            UsarSsl = Convert.ToBoolean(reader["UsarSsl"]),
            EmailDesde = reader["EmailDesde"] as string,
            NombreDesde = reader["NombreDesde"] as string,
            FrontendBaseUrl = reader["FrontendBaseUrl"] as string,
            FechaActualizacion = reader["FechaActualizacion"] as DateTime?,
        };
    }

    public async Task UpdateConfiguracionAsync(EmailConfiguracionUpdateRequest dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        await using var existeCmd = conn.CreateCommand();
        existeCmd.CommandText = "SELECT TOP 1 ConfiguracionEmailID, SmtpPassword FROM ConfiguracionEmail ORDER BY ConfiguracionEmailID DESC";
        await using var reader = await existeCmd.ExecuteReaderAsync();
        int? existingId = null;
        string? existingPassword = null;
        if (await reader.ReadAsync())
        {
            existingId = Convert.ToInt32(reader["ConfiguracionEmailID"]);
            existingPassword = reader["SmtpPassword"] as string;
        }
        await reader.DisposeAsync();

        var passwordAGuardar = string.IsNullOrWhiteSpace(dto.SmtpPassword) ? existingPassword : dto.SmtpPassword;

        await using var cmd = conn.CreateCommand();
        if (existingId is null)
        {
            cmd.CommandText = @"INSERT INTO ConfiguracionEmail (SmtpHost, SmtpPort, SmtpUsuario, SmtpPassword, UsarSsl, EmailDesde, NombreDesde, FrontendBaseUrl, FechaActualizacion)
                                 VALUES (@host, @port, @usuario, @password, @ssl, @desde, @nombreDesde, @frontendUrl, SYSDATETIME())";
        }
        else
        {
            cmd.CommandText = @"UPDATE ConfiguracionEmail
                                 SET SmtpHost = @host, SmtpPort = @port, SmtpUsuario = @usuario, SmtpPassword = @password,
                                     UsarSsl = @ssl, EmailDesde = @desde, NombreDesde = @nombreDesde, FrontendBaseUrl = @frontendUrl,
                                     FechaActualizacion = SYSDATETIME()
                                 WHERE ConfiguracionEmailID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = existingId.Value;
        }
        cmd.Parameters.Add("@host", SqlDbType.VarChar, 200).Value = (object?)dto.SmtpHost ?? DBNull.Value;
        cmd.Parameters.Add("@port", SqlDbType.Int).Value = (object?)dto.SmtpPort ?? DBNull.Value;
        cmd.Parameters.Add("@usuario", SqlDbType.VarChar, 200).Value = (object?)dto.SmtpUsuario ?? DBNull.Value;
        cmd.Parameters.Add("@password", SqlDbType.VarChar, 200).Value = (object?)passwordAGuardar ?? DBNull.Value;
        cmd.Parameters.Add("@ssl", SqlDbType.Bit).Value = dto.UsarSsl;
        cmd.Parameters.Add("@desde", SqlDbType.VarChar, 200).Value = (object?)dto.EmailDesde ?? DBNull.Value;
        cmd.Parameters.Add("@nombreDesde", SqlDbType.VarChar, 150).Value = (object?)dto.NombreDesde ?? DBNull.Value;
        cmd.Parameters.Add("@frontendUrl", SqlDbType.VarChar, 300).Value = (object?)dto.FrontendBaseUrl ?? DBNull.Value;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<string> ObtenerFrontendBaseUrlAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        var config = await ObtenerConfigAsync(conn);
        return config.FrontendBaseUrl?.TrimEnd('/') ?? string.Empty;
    }

    public async Task EnviarAsync(string destinatario, string asunto, string cuerpoHtml)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        var config = await ObtenerConfigAsync(conn);

        if (string.IsNullOrWhiteSpace(config.Host) || config.Port is null || string.IsNullOrWhiteSpace(config.EmailDesde))
            throw new InvalidOperationException("Falta configurar el servidor SMTP (pantalla Integración Email).");

        using var mensaje = new MailMessage
        {
            From = new MailAddress(config.EmailDesde, config.NombreDesde ?? config.EmailDesde),
            Subject = asunto,
            Body = cuerpoHtml,
            IsBodyHtml = true,
        };
        mensaje.To.Add(destinatario);

        using var cliente = new SmtpClient(config.Host, config.Port.Value)
        {
            EnableSsl = config.UsarSsl,
        };
        if (!string.IsNullOrWhiteSpace(config.Usuario))
        {
            cliente.Credentials = new NetworkCredential(config.Usuario, config.Password ?? string.Empty);
        }

        await cliente.SendMailAsync(mensaje);
    }

    public Task EnviarPruebaAsync(string destinatario) =>
        EnviarAsync(destinatario, "Prueba de configuración — Pricing Engine",
            "<p>Este es un email de prueba para confirmar que la configuración SMTP de Pricing Engine funciona correctamente.</p>");

    public async Task EnviarResetPasswordAsync(string destinatario, string link)
    {
        var cuerpo = "<p>Pediste restablecer tu contraseña en Pricing Engine.</p>"
            + $"<p><a href=\"{link}\">Hacé clic acá para elegir una contraseña nueva</a>. El link vale por 1 hora.</p>"
            + "<p>Si no pediste esto, podés ignorar este email.</p>";
        await EnviarAsync(destinatario, "Restablecer tu contraseña — Pricing Engine", cuerpo);
    }
}
