namespace PricingApi.Models;

public class CompetenciaSnapshotDto
{
    public long SnapshotID { get; set; }
    public int PublicacionID { get; set; }
    public string CompetidorItemID { get; set; } = string.Empty;
    public string? CompetidorVendedorID { get; set; }
    public decimal PrecioCompetidor { get; set; }
    public int? StockCompetidor { get; set; }
    public string? TipoPublicacion { get; set; }
    public bool OfreceEnvioGratis { get; set; }
    public bool EsCompetidorDirecto { get; set; }
    public int NivelRelevancia { get; set; }
    public DateTime FechaCaptura { get; set; }
}