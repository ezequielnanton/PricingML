namespace PricingApi.Models;

public class ParametroGeneralDto
{
    public int ParametroGeneralID { get; set; }
    public int EmpresaID { get; set; }
    public int MonedaPrincipalID { get; set; }
    public int MonedaSecundariaID { get; set; }
    // #aprobacionColaMl: si está activo, las publicaciones de catálogo suben el precio a
    // ML sin aprobación humana. Las que no son de catálogo siempre piden aprobación.
    public bool SubidaAutomaticaCatalogoML { get; set; }
}