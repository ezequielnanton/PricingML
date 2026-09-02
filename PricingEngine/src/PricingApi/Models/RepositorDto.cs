namespace PricingApi.Models;

public class RepositorCreateRequest
{
    public int EmpresaID { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
    public string Usuario { get; set; } = string.Empty;
    public string Pin { get; set; } = string.Empty;
}

public class RepositorLoginRequest
{
    public string Usuario { get; set; } = string.Empty;
    public string Pin { get; set; } = string.Empty;
}

public class RepositorLoginResponse
{
    public string Token { get; set; } = string.Empty;
    public int RepositorID { get; set; }
    public string NombreCompleto { get; set; } = string.Empty;
}

public class StockLookupResponse
{
    public int ProductoID { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public int StockActual { get; set; }
}

public class StockCargaRequest
{
    public string SKU { get; set; } = string.Empty;
    public int StockNuevo { get; set; }
}

public class StockCargaResponse
{
    public int ProductoID { get; set; }
    public string SKU { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public int StockAnterior { get; set; }
    public int StockNuevo { get; set; }
}
