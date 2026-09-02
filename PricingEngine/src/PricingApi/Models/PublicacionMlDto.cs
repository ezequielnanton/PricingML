namespace PricingApi.Models;

public class PublicacionMlDto
{
    public int PublicacionID { get; set; }
    public int ProductoID { get; set; }
    public int CuentaMLID { get; set; }
    public string MeliItemID { get; set; } = string.Empty;
    public string TipoPublicacion { get; set; } = string.Empty;
    public decimal ComisionMLPorc { get; set; }
    public string Estado { get; set; } = string.Empty;
    public bool EsCatalogo { get; set; }
    public decimal PrecioActual { get; set; }
    public decimal PrecioMinimoPermitido { get; set; }
    public decimal PrecioMaximoPermitido { get; set; }
    public decimal? PrecioObjetivo { get; set; }
    public DateTime? FechaUltimoCambioPrecio { get; set; }
}