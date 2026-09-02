namespace PricingApi.Models;

public class EmailConfiguracionResponse
{
    public string? SmtpHost { get; set; }
    public int? SmtpPort { get; set; }
    public string? SmtpUsuario { get; set; }
    public bool SmtpPasswordConfigurada { get; set; }
    public bool UsarSsl { get; set; }
    public string? EmailDesde { get; set; }
    public string? NombreDesde { get; set; }
    public string? FrontendBaseUrl { get; set; }
    public DateTime? FechaActualizacion { get; set; }
}

public class EmailConfiguracionUpdateRequest
{
    public string? SmtpHost { get; set; }
    public int? SmtpPort { get; set; }
    public string? SmtpUsuario { get; set; }
    // Vacío/null: no se toca la contraseña ya guardada. Mandar un valor la reemplaza.
    public string? SmtpPassword { get; set; }
    public bool UsarSsl { get; set; } = true;
    public string? EmailDesde { get; set; }
    public string? NombreDesde { get; set; }
    public string? FrontendBaseUrl { get; set; }
}

public class EmailPruebaRequest
{
    public string Destinatario { get; set; } = string.Empty;
}

public class OlvidePasswordRequest
{
    public string Usuario { get; set; } = string.Empty;
}

public class ResetearPasswordRequest
{
    public string Token { get; set; } = string.Empty;
    public string PasswordNueva { get; set; } = string.Empty;
}
