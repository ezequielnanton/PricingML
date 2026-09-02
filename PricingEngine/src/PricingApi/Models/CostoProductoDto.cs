namespace PricingApi.Models;

public class CostoProductoDto
{
    public int CostoID { get; set; }
    public int ProductoID { get; set; }
    public decimal CostoCompra { get; set; }
    public decimal PorcentajeIVA { get; set; }
    public decimal ImpuestosInternos { get; set; }
    public decimal CostoEnvioPromedio { get; set; }
    public decimal CostoLogisticoFijo { get; set; }
    public decimal CostoFinancieroPorc { get; set; }
    public decimal CostoPublicidadPorc { get; set; }
    public decimal OtrosCostosFijos { get; set; }
    public DateTime FechaUltimaActualizacion { get; set; }
}