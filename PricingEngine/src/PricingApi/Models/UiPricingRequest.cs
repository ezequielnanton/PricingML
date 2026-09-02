namespace PricingApi.Models;

public class UiPricingRequest
{
    public int EmpresaId { get; set; }
    public string? Sku { get; set; }
    public string? Titulo { get; set; }
    public decimal PrecioPropuesto { get; set; }
    public decimal PrecioMinimoPermitido { get; set; }
    public decimal PrecioMaximoPermitido { get; set; }
    public int StockDisponible { get; set; }
    public int StockMinimo { get; set; }
    public int StockMaximo { get; set; }
    public decimal CostoBase { get; set; }
    public decimal Iva { get; set; }
    public decimal ComisionMLPorc { get; set; }
    public decimal CostoEnvioPromedio { get; set; }
    public decimal CostoLogisticoFijo { get; set; }
    public decimal CostoFinancieroPorc { get; set; }
    public decimal CostoPublicidadPorc { get; set; }
    public string? EstadoPublicacion { get; set; }
    public string Idioma { get; set; } = "ES";
    public string Origen { get; set; } = "UI";
    public bool ModoSimulacion { get; set; } = true;
    public bool Persistir { get; set; } = false;
}
