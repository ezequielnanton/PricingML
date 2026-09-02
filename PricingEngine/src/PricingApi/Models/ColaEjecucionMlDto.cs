namespace PricingApi.Models;

public class ColaEjecucionMlDto
{
    public long ColaID { get; set; }
    public int PublicacionID { get; set; }
    public string MeliItemID { get; set; } = string.Empty;
    public decimal PrecioNuevo { get; set; }
    public string AccionRequerida { get; set; } = string.Empty;
    public string EstadoEjecucion { get; set; } = "PENDIENTE";
    public string? MensajeError { get; set; }
    public DateTime FechaCreacion { get; set; }
    public DateTime? FechaProcesado { get; set; }
}