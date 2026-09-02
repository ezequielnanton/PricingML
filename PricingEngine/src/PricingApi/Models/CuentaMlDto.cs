namespace PricingApi.Models;

public class CuentaMlDto
{
    public int CuentaMLID { get; set; }
    public int EmpresaID { get; set; }
    public string UserIDML { get; set; } = string.Empty;
    public string NicknameML { get; set; } = string.Empty;
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
    public DateTime? FechaVencimientoToken { get; set; }
    public bool Activo { get; set; } = true;
}