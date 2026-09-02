namespace PricingApi.Models;

public class EstrategiaDto
{
    public int EstrategiaID { get; set; }
    public int EmpresaID { get; set; }
    public string NombreEstrategia { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activa { get; set; } = true;
}