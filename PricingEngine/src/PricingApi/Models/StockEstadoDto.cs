namespace PricingApi.Models;

public class StockEstadoDto
{
    public int StockID { get; set; }
    public int ProductoID { get; set; }
    public int StockActual { get; set; }
    public int StockReservado { get; set; }
    public int StockMinimo { get; set; }
    public int StockMaximo { get; set; }
    public int StockObjetivo { get; set; }
    public DateTime FechaActualizacion { get; set; }
}