namespace PricingApi.Models;

public class MonedaDto
{
    public int MonedaID { get; set; }
    public string CodigoISO { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? Simbolo { get; set; }
    public bool Activa { get; set; } = true;
}