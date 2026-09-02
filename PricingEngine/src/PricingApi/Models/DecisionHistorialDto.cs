namespace PricingApi.Models;

public class DecisionHistorialDto
{
    public long DecisionID { get; set; }
    public int EmpresaID { get; set; }
    public int PublicacionID { get; set; }
    public int EstrategiaID { get; set; }
    public decimal PrecioAnterior { get; set; }
    public decimal PrecioCalculado { get; set; }
    public decimal PrecioSugerido { get; set; }
    public string Accion { get; set; } = string.Empty;
    public string Motivo { get; set; } = string.Empty;
    public int? ReglaGanadoraID { get; set; }
    public int PrioridadAplicada { get; set; }
    public decimal MargenActualPorc { get; set; }
    public decimal MargenProyectadoPorc { get; set; }
    public int? PosicionCompetitiva { get; set; }
    public decimal? PrecioCompetenciaRef { get; set; }
    public int StockDisponible { get; set; }
    public string ClasificacionStock { get; set; } = string.Empty;
    public decimal ScoreConfianza { get; set; }
    public bool EsSimulacion { get; set; }
    public DateTime FechaDecision { get; set; }
}