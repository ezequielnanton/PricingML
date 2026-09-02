namespace PricingApi.Models;

public class CotizacionDto
{
    public long CotizacionID { get; set; }
    public int MonedaID { get; set; }
    public decimal Cotizacion { get; set; }
    public DateTime FechaCotizacion { get; set; }
}