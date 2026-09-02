namespace PricingApi.Models;

public class MetricasVentasDto
{
    public int MetricaID { get; set; }
    public int PublicacionID { get; set; }
    public int VentasHoy { get; set; }
    public int Ventas7D { get; set; }
    public int Ventas15D { get; set; }
    public int Ventas30D { get; set; }
    public int Ventas60D { get; set; }
    public int Ventas90D { get; set; }
    public decimal VelocidadVentaDiaria { get; set; }
    public decimal TendenciaPorc { get; set; }
    public DateTime FechaCalculo { get; set; }
}