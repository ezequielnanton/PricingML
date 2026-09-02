namespace PricingApi.Models;

public class EjecucionAutomaticaConfiguracionResponse
{
    public bool Activo { get; set; }
    public int IntervaloMinutos { get; set; }
    public DateTime? UltimaEjecucion { get; set; }
    public bool? UltimoResultadoOk { get; set; }
    public string? UltimoResultadoResumen { get; set; }
}

public class EjecucionAutomaticaConfiguracionUpdateRequest
{
    public bool Activo { get; set; }
    public int IntervaloMinutos { get; set; } = 30;
}
