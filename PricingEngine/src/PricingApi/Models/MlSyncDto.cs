namespace PricingApi.Models;

public class MlColaItemResultado
{
    public long ColaID { get; set; }
    public string MeliItemID { get; set; } = string.Empty;
    public bool Ok { get; set; }
    public string? Error { get; set; }
}

public class MlProcesarColaResult
{
    public int Procesados { get; set; }
    public int Errores { get; set; }
    public List<MlColaItemResultado> Detalle { get; set; } = new();
}

public class MlConfiguracionResponse
{
    public string? ClientId { get; set; }
    public bool ClientSecretConfigurado { get; set; }
    public string? ApiBaseUrl { get; set; }
    public string? SiteId { get; set; }
    public string? RedirectUri { get; set; }
    public DateTime? FechaActualizacion { get; set; }
}

public class MlConfiguracionUpdateRequest
{
    public string? ClientId { get; set; }
    // Vacío/null: no se toca el secreto ya guardado. Mandar un valor lo reemplaza.
    public string? ClientSecret { get; set; }
    public string? ApiBaseUrl { get; set; }
    public string? SiteId { get; set; }
    public string? RedirectUri { get; set; }
}

public class MlPublicacionSyncResultado
{
    public int PublicacionID { get; set; }
    public string MeliItemID { get; set; } = string.Empty;
    public bool Ok { get; set; }
    public string? Error { get; set; }
    public bool CompetenciaActualizada { get; set; }
}

public class MlSincronizarPublicacionesResult
{
    public int Procesados { get; set; }
    public int Errores { get; set; }
    public int ConCompetenciaActualizada { get; set; }
    public List<MlPublicacionSyncResultado> Detalle { get; set; } = new();
}

public class MlVentasSyncItem
{
    public int PublicacionID { get; set; }
    public string MeliItemID { get; set; } = string.Empty;
    public int VentasHoy { get; set; }
    public int Ventas7D { get; set; }
    public int Ventas15D { get; set; }
    public int Ventas30D { get; set; }
    public int Ventas60D { get; set; }
    public int Ventas90D { get; set; }
    public decimal TendenciaPorc { get; set; }
}

public class MlSincronizarVentasResult
{
    public int CuentasProcesadas { get; set; }
    public int PublicacionesActualizadas { get; set; }
    public int Errores { get; set; }
    public List<string> ErroresDetalle { get; set; } = new();
    public List<MlVentasSyncItem> Detalle { get; set; } = new();
}

// #competidoresManualesMl: para publicaciones que NO son de catálogo, ML no define
// automáticamente quién es la competencia. MercadoLibre bloquea tanto la búsqueda
// pública por texto (GET /sites/{site}/search) como la lectura de una publicación
// ajena por ID (GET /items/{id}) para apps de terceros -- 403 confirmado contra la
// API real de las dos formas, con token válido o sin él (ver ADR 0010). No hay forma
// de traer el precio del competidor por API, ni al vincular ni después: el usuario
// escribe el ID/link, título y precio que ve en su propio navegador, y los puede
// reescribir cuando quiera con "Actualizar precio" -- no hay refresco automático.
public class MlVincularCompetidorRequest
{
    public string CompetidorItemID { get; set; } = string.Empty;
    public string? CompetidorTitulo { get; set; }
    public int MonedaID { get; set; }
    public decimal Precio { get; set; }
}

public class MlActualizarPrecioCompetidorRequest
{
    public decimal Precio { get; set; }
}

public class MlCompetidorVinculado
{
    public int VinculoID { get; set; }
    public string CompetidorItemID { get; set; } = string.Empty;
    public string? CompetidorTitulo { get; set; }
    public DateTime FechaVinculo { get; set; }
    public string? UsuarioVinculoNombre { get; set; }
    public int? MonedaID { get; set; }
    public string? MonedaCodigoISO { get; set; }
    public string? MonedaSimbolo { get; set; }
    public decimal? UltimoPrecio { get; set; }
    public DateTime? FechaUltimoPrecio { get; set; }
}

public class MlMonedaPrincipal
{
    public int? MonedaID { get; set; }
}

// #aprobacionColaMl: fila de la cola esperando revisión humana, con todo el contexto
// necesario para decidir (nuestra publicación, el precio sugerido y por qué, y el
// competidor puntual contra el que se comparó) sin tener que ir a buscarlo a otro lado.
public class ColaAprobacionItem
{
    public long ColaID { get; set; }
    public int PublicacionID { get; set; }
    public string MeliItemID { get; set; } = string.Empty;
    public string SKU { get; set; } = string.Empty;
    public string Titulo { get; set; } = string.Empty;
    public decimal PrecioActual { get; set; }
    public decimal PrecioNuevo { get; set; }
    public string AccionRequerida { get; set; } = string.Empty;
    public string? Motivo { get; set; }
    public string? CompetidorItemIDRef { get; set; }
    public decimal? PrecioCompetidorRef { get; set; }
    public bool EsCatalogo { get; set; }
    public DateTime FechaCreacion { get; set; }
}
