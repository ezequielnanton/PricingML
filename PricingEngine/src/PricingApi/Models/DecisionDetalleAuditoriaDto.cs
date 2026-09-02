namespace PricingApi.Models;

public class DecisionDetalleAuditoriaDto
{
    public long AuditoriaID { get; set; }
    public long DecisionID { get; set; }
    public int ReglaID { get; set; }
    public int Prioridad { get; set; }
    public string EvaluacionResultado { get; set; } = string.Empty;
    public decimal? ValorPrecioPropuesto { get; set; }
    public string? DetalleJSON { get; set; }
}