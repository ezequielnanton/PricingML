namespace PricingApi.Models;

public class ReglaNegocioDto
{
    public int ReglaID { get; set; }
    public string CodigoRegla { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string TipoRegla { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activa { get; set; } = true;
}