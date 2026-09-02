namespace PricingAdapter.Models;

public class ProductoInput
{
    public int EmpresaId { get; set; }
    public int? ProductoId { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public decimal PrecioActual { get; set; }
    public decimal PrecioMinimoPermitido { get; set; }
    public decimal PrecioMaximoPermitido { get; set; }
    public int StockActual { get; set; }
    public int StockMinimo { get; set; }
    public int StockMaximo { get; set; }
    public decimal CostoCompra { get; set; }
    public decimal IVA { get; set; }
    public decimal ComisionMLPorc { get; set; }
    public decimal CostoEnvioPromedio { get; set; }
    public decimal CostoLogisticoFijo { get; set; }
    public decimal CostoFinancieroPorc { get; set; }
    public decimal CostoPublicidadPorc { get; set; }
    public DateTime FechaCaptura { get; set; }
    public string FuenteOrigen { get; set; } = string.Empty;
    public string EstadoPublicacion { get; set; } = string.Empty;
    public string Idioma { get; set; } = "ES";
}
