namespace PricingApi.Models;

public class ResumenVentasResponse
{
    public int VentanaDias { get; set; } = 30;
    public decimal VentaBrutaTotal { get; set; }
    public decimal CostoTotal { get; set; }
    public decimal Rentabilidad { get; set; }
    public decimal? RentabilidadPorc { get; set; }
    public List<VentanaVentaItem> VentasPorVentana { get; set; } = new();
}

// #ventasPorVentana: no hay ventas por día reales (ver comentario en ResumenVentasService),
// así que el gráfico de tendencia usa las ventanas rodantes que ya existen en
// MetricasVentasHist (7/15/30/60/90 días) en vez de inventar una granularidad diaria
// que el sistema no tiene.
public class VentanaVentaItem
{
    public int Dias { get; set; }
    public int UnidadesVendidas { get; set; }
}
