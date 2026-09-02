namespace PricingApi.Models;

// #activoSimple: Parámetros/Mensajes de Regla pasaron de un modelo versionado por fecha a
// un simple Activo/Inactivo (ver Migrar-ParametrosMensajesReglaActivoSimple.sql) -- estos
// DTOs sirven tanto para leer un registro como para crear/actualizarlo, igual que
// ReglaNegocioDto y el resto de los ABMs simples. FechaVigencia/FechaFin quedaron en la
// tabla (columnas históricas, no se tocan más desde acá) pero no en el DTO: no hace falta
// mandarlas ni de ida ni de vuelta para un alta/edición simple.
public class EstrategiaReglaParametroDto
{
    public int ParametroID { get; set; }
    public int EstrategiaReglaID { get; set; }
    public string Clave { get; set; } = string.Empty;
    public decimal Valor { get; set; }
    public string? Descripcion { get; set; }
    public bool Activo { get; set; } = true;
}

public class EstrategiaReglaParametroMensajeDto
{
    public int MensajeID { get; set; }
    public int EstrategiaReglaID { get; set; }
    public string Clave { get; set; } = string.Empty;
    public string Idioma { get; set; } = "ES";
    public string Valor { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activo { get; set; } = true;
}
