namespace PricingApi.Models;

public class CompetidorCapturadoRequest
{
    public string MeliItemId { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public decimal Precio { get; set; }
    public int MonedaId { get; set; }
    public string? Vendedor { get; set; }
    public string? Link { get; set; }
}

public class CompetidorCapturadoResponse
{
    public bool Vinculado { get; set; }
    public int? PublicacionId { get; set; }
    public int? ProductoId { get; set; }
    public string? ProductoNombre { get; set; }
    public decimal? RecomendacionNueva { get; set; }
    public string? Motivo { get; set; }
    public string? Mensaje { get; set; }
}
