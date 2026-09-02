namespace PricingApi.Models;

public class ProductoDto
{
    public int ProductoID { get; set; }
    public int EmpresaID { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public string? CategoriaID { get; set; }
    public string? Marca { get; set; }
    public string? Modelo { get; set; }
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; }
}