namespace PricingApi.Models;

// #integracionErp: campos canónicos que un ERP puede alimentar. Compartido entre el
// descubrimiento de campos, el mapeo configurable y la validación del mapeo guardado.
public static class ErpCamposCanonicos
{
    public const string SKU = "SKU";
    public const string Titulo = "Titulo";
    public const string CostoCompra = "CostoCompra";
    public const string PorcentajeIVA = "PorcentajeIVA";
    public const string ImpuestosInternos = "ImpuestosInternos";
    public const string StockActual = "StockActual";
    public const string StockMinimo = "StockMinimo";
    public const string StockMaximo = "StockMaximo";

    public static readonly string[] Requeridos = { SKU, CostoCompra, StockActual };
    public static readonly string[] Todos =
        { SKU, Titulo, CostoCompra, PorcentajeIVA, ImpuestosInternos, StockActual, StockMinimo, StockMaximo };
}

// #integracionErp: contrato canónico de un producto para sincronizar con un ERP, en
// cualquiera de los dos sentidos (POST entrante o GET saliente). Para el sentido
// saliente, el admin no necesita que el ERP devuelva exactamente esta forma: la
// pantalla de mapeo (ErpCampoMapeos) traduce los campos reales del ERP a este
// contrato sin escribir código nuevo por cliente.
public class ErpSyncItem
{
    public string SKU { get; set; } = string.Empty;
    public string? Titulo { get; set; }
    public decimal CostoCompra { get; set; }
    public decimal? PorcentajeIVA { get; set; }
    public decimal? ImpuestosInternos { get; set; }
    public int StockActual { get; set; }
    public int? StockMinimo { get; set; }
    public int? StockMaximo { get; set; }
}

public class ErpSyncRequest
{
    public List<ErpSyncItem> Items { get; set; } = new();
}

public class ErpSyncItemError
{
    public string SKU { get; set; } = string.Empty;
    public string Mensaje { get; set; } = string.Empty;
}

public class ErpSyncResult
{
    public int Procesados { get; set; }
    public int Errores { get; set; }
    public List<ErpSyncItemError> DetalleErrores { get; set; } = new();
}

public class ErpConexionCreateRequest
{
    public int EmpresaID { get; set; }
    public string? UrlSalida { get; set; }
    public string? ApiKeySaliente { get; set; }
}

public class ErpConexionCreateResponse
{
    public int ErpConexionID { get; set; }
    public string ApiKeyEntrante { get; set; } = string.Empty;
}

public class ErpPullSummary
{
    public int EmpresaID { get; set; }
    public string RazonSocial { get; set; } = string.Empty;
    public bool Ok { get; set; }
    public string? Error { get; set; }
    public ErpSyncResult? Resultado { get; set; }
}

public class ErpConexionDetail
{
    public int? ErpConexionID { get; set; }
    public int EmpresaID { get; set; }
    public string? UrlSalida { get; set; }
    public string? ApiKeySaliente { get; set; }
    public DateTime? UltimaSincronizacion { get; set; }
}

public class ErpConexionUpdateRequest
{
    public string? UrlSalida { get; set; }
    public string? ApiKeySaliente { get; set; }
}

public class ErpDescubrirCamposRequest
{
    public string Url { get; set; } = string.Empty;
    public string? ApiKey { get; set; }
}

public class ErpDescubrirCamposResponse
{
    public List<string> CamposDescubiertos { get; set; } = new();
    public Dictionary<string, string> Muestra { get; set; } = new();
}

public class ErpCampoMapeoDto
{
    public string CampoCanonico { get; set; } = string.Empty;
    public string CampoOrigen { get; set; } = string.Empty;
}

public class ErpMapeoUpdateRequest
{
    public List<ErpCampoMapeoDto> Mapeos { get; set; } = new();
}
