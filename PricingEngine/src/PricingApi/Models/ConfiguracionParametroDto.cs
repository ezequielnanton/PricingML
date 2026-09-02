namespace PricingApi.Models;

public class ConfiguracionParametroDto
{
    public int ParametroID { get; set; }
    public int EmpresaID { get; set; }
    public string ClaveParametro { get; set; } = string.Empty;
    public string ValorParametro { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
}