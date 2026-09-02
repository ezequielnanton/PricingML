using System.Data;
using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;

namespace PricingApi.Services;

/// <summary>Read-only, whitelisted reports for the admin UI.</summary>
public sealed class AdminReportsService
{
    private static readonly Regex FilterKey = new("^filter\\[([^\\]]+)\\]\\[([^\\]]+)\\]$", RegexOptions.Compiled);
    // #idTextoNoNumerico: tiene que inicializarse antes que Definitions (más abajo),
    // que la usa indirectamente vía Kind() durante su propio inicializador estático.
    private static readonly HashSet<string> IdsDeTexto = new(StringComparer.Ordinal)
        { "MeliItemID", "CategoriaID", "CompetidorItemID", "CompetidorVendedorID" };
    private readonly string _connectionString;

    public AdminReportsService(IConfiguration configuration) =>
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");

    public async Task<PagedReport> GetAsync(string resource, IQueryCollection query)
    {
        if (!Definitions.TryGetValue(resource, out var definition))
            throw new ReportValidationException("El recurso de reporte no existe.");

        var request = ParseRequest(definition, query);
        var where = new List<string>();
        var parameters = new List<SqlParameter>();
        foreach (var filter in request.Filters)
            AddFilter(filter, where, parameters);

        var whereSql = where.Count == 0 ? "" : " WHERE " + string.Join(" AND ", where);
        var orderBy = request.Sort.Count == 0
            ? definition.DefaultOrder
            : string.Join(", ", request.Sort.Select(x => $"[{x.Column.DatabaseName}] {x.Direction}"));
        var select = string.Join(", ", definition.Columns.Select(c => $"[{c.DatabaseName}] AS [{c.Name}]"));
        var countSql = $"SELECT COUNT_BIG(1) FROM [{definition.Table}]{whereSql}";
        var dataSql = $"SELECT {select} FROM [{definition.Table}]{whereSql} ORDER BY {orderBy} OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
        long total;
        await using (var count = new SqlCommand(countSql, connection))
        {
            AddParameters(count, parameters);
            total = Convert.ToInt64(await count.ExecuteScalarAsync());
        }

        var items = new List<Dictionary<string, object?>>();
        await using (var command = new SqlCommand(dataSql, connection))
        {
            AddParameters(command, parameters);
            command.Parameters.Add("@offset", SqlDbType.Int).Value = checked((request.Page - 1) * request.PageSize);
            command.Parameters.Add("@pageSize", SqlDbType.Int).Value = request.PageSize;
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                var item = new Dictionary<string, object?>(StringComparer.Ordinal);
                for (var i = 0; i < reader.FieldCount; i++) item[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                items.Add(item);
            }
        }
        return new PagedReport(items, request.Page, request.PageSize, total);
    }

    public static ReportRequest ParseRequest(ReportDefinition definition, IQueryCollection query)
    {
        var page = ParsePositive(query["page"].FirstOrDefault(), 1, "page", 1, int.MaxValue);
        var pageSize = ParsePositive(query["pageSize"].FirstOrDefault(), 50, "pageSize", 1, 100);
        var filters = new List<ReportFilter>();
        foreach (var pair in query)
        {
            var match = FilterKey.Match(pair.Key);
            if (!match.Success) continue;
            if (!definition.ByName.TryGetValue(match.Groups[1].Value, out var column))
                throw new ReportValidationException("El campo de filtro no existe.", pair.Key);
            var op = match.Groups[2].Value;
            if (!AllowedOperators(column.Kind).Contains(op, StringComparer.Ordinal))
                throw new ReportValidationException("El operador de filtro no es compatible.", pair.Key);
            filters.Add(new ReportFilter(column, op, pair.Value.FirstOrDefault() ?? ""));
        }
        var sort = new List<ReportSort>();
        var rawSort = query["sort"].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(rawSort)) foreach (var criterion in rawSort.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var parts = criterion.Split(':', StringSplitOptions.TrimEntries);
            if (parts.Length != 2 || !definition.ByName.TryGetValue(parts[0], out var column) ||
                (parts[1] is not "asc" and not "desc"))
                throw new ReportValidationException("El ordenamiento es inválido.", criterion);
            sort.Add(new ReportSort(column, parts[1].ToUpperInvariant()));
        }
        return new ReportRequest(page, pageSize, filters, sort);
    }

    private static int ParsePositive(string? raw, int fallback, string name, int minimum, int maximum)
    {
        if (string.IsNullOrWhiteSpace(raw)) return fallback;
        if (!int.TryParse(raw, NumberStyles.None, CultureInfo.InvariantCulture, out var value) || value < minimum || value > maximum)
            throw new ReportValidationException($"{name} es inválido.", name);
        return value;
    }

    private static void AddFilter(ReportFilter filter, List<string> where, List<SqlParameter> parameters)
    {
        var column = $"[{filter.Column.DatabaseName}]";
        if (filter.Operator == "isNull")
        {
            if (!bool.TryParse(filter.Value, out var isNull)) throw new ReportValidationException("isNull debe ser true o false.", filter.Column.Name);
            where.Add($"{column} IS {(isNull ? "NULL" : "NOT NULL")}"); return;
        }
        var values = filter.Operator == "in" ? filter.Value.Split(',', StringSplitOptions.TrimEntries) : [filter.Value];
        if (values.Length == 0 || values.Any(string.IsNullOrWhiteSpace)) throw new ReportValidationException("El filtro in es inválido.", filter.Column.Name);
        var names = new List<string>();
        foreach (var value in values)
        {
            var name = "@p" + parameters.Count;
            var parsed = ParseValue(filter.Column, value);
            if (filter.Operator is "contains" or "startsWith" or "endsWith")
                parsed = filter.Operator switch { "contains" => $"%{EscapeLike(value)}%", "startsWith" => $"{EscapeLike(value)}%", _ => $"%{EscapeLike(value)}" };
            parameters.Add(new SqlParameter(name, filter.Column.SqlType) { Value = parsed ?? DBNull.Value }); names.Add(name);
        }
        if (filter.Operator == "in") where.Add($"{column} IN ({string.Join(", ", names)})");
        else if (filter.Operator is "contains" or "startsWith" or "endsWith") where.Add($"{column} LIKE {names[0]} ESCAPE '\\'");
        else where.Add($"{column} {OperatorSql(filter.Operator)} {names[0]}");
    }

    private static object ParseValue(ReportColumn column, string value) => column.Kind switch
    {
        ColumnKind.Int => int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : throw new ReportValidationException("El valor numérico es inválido.", column.Name),
        ColumnKind.Long => long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var n) ? n : throw new ReportValidationException("El valor numérico es inválido.", column.Name),
        ColumnKind.Decimal => decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var n) ? n : throw new ReportValidationException("El valor decimal es inválido.", column.Name),
        ColumnKind.Boolean => bool.TryParse(value, out var b) ? b : throw new ReportValidationException("El valor booleano es inválido.", column.Name),
        ColumnKind.DateTime => DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var d) ? d : throw new ReportValidationException("La fecha es inválida.", column.Name),
        _ => value
    };
    private static string EscapeLike(string value) => value.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_").Replace("[", "\\[");
    private static string OperatorSql(string op) => op switch { "eq" => "=", "gt" => ">", "gte" => ">=", "lt" => "<", "lte" => "<=", _ => throw new ReportValidationException("El operador de filtro es inválido.") };
    private static IEnumerable<string> AllowedOperators(ColumnKind kind) => kind switch { ColumnKind.Text => ["eq", "contains", "startsWith", "endsWith", "in", "isNull"], ColumnKind.Boolean => ["eq", "in", "isNull"], _ => ["eq", "gt", "gte", "lt", "lte", "in", "isNull"] };
    private static void AddParameters(SqlCommand command, IEnumerable<SqlParameter> parameters) { foreach (var p in parameters) command.Parameters.Add(new SqlParameter(p.ParameterName, p.SqlDbType) { Value = p.Value }); }

    // The schema is intentionally explicit: no request-controlled identifier reaches SQL.
    public static readonly IReadOnlyDictionary<string, ReportDefinition> Definitions = CreateDefinitions();
    private static IReadOnlyDictionary<string, ReportDefinition> CreateDefinitions()
    {
        var rows = new (string Resource, string Table, string Columns, string DefaultOrder)[] {
            ("empresas","Empresas","EmpresaID,RazonSocial,CUIT,Activo,FechaCreacion","[EmpresaID] ASC"),
            ("monedas","Monedas","MonedaID,CodigoISO,Nombre,Simbolo,Activa","[MonedaID] ASC"),
            ("cuentas-ml","CuentasML","CuentaMLID,EmpresaID,UserIDML,NicknameML,FechaVencimientoToken,Activo","[CuentaMLID] ASC"),
            ("estrategias","Estrategias","EstrategiaID,EmpresaID,NombreEstrategia,Descripcion,Activa","[EstrategiaID] ASC"),
            ("reglas","ReglasNegocio","ReglaID,CodigoRegla,Nombre,TipoRegla,Descripcion,Activa","[ReglaID] ASC"),
            ("estrategia-reglas","EstrategiaReglas","EstrategiaReglaID,EstrategiaID,ReglaID,Prioridad,ParametrosJSON,Activa","[EstrategiaReglaID] ASC"),
            ("estrategias-reglas-parametros","EstrategiaReglaParametros","ParametroID,EstrategiaReglaID,Clave,Valor,Descripcion,Activo,FechaVigencia,FechaFin,FechaCreacion","[ParametroID] ASC"),
            ("estrategias-reglas-parametros-mensajes","EstrategiaReglaParametrosMensajes","MensajeID,EstrategiaReglaID,Clave,Idioma,Valor,Descripcion,Activo,FechaVigencia,FechaFin,FechaCreacion","[MensajeID] ASC"),
            ("productos","Productos","ProductoID,EmpresaID,SKU,Titulo,CategoriaID,Marca,Modelo,Activo,FechaCreacion","[ProductoID] ASC"),
            ("costos-producto","CostosProducto","CostoID,ProductoID,CostoCompra,PorcentajeIVA,ImpuestosInternos,CostoEnvioPromedio,CostoLogisticoFijo,CostoFinancieroPorc,CostoPublicidadPorc,OtrosCostosFijos,FechaUltimaActualizacion","[CostoID] ASC"),
            ("publicaciones-ml","PublicacionesML","PublicacionID,ProductoID,CuentaMLID,MeliItemID,TipoPublicacion,ComisionMLPorc,Estado,EsCatalogo,PrecioActual,PrecioMinimoPermitido,PrecioMaximoPermitido,PrecioObjetivo,FechaUltimoCambioPrecio","[PublicacionID] ASC"),
            ("stock-estado","StockEstado","StockID,ProductoID,StockActual,StockReservado,StockDisponible,StockMinimo,StockMaximo,StockObjetivo,FechaActualizacion","[StockID] ASC"),
            ("cotizaciones","Cotizaciones","CotizacionID,MonedaID,Cotizacion,FechaCotizacion","[CotizacionID] ASC"),
            ("parametros-generales","ParametrosGenerales","ParametroGeneralID,EmpresaID,MonedaPrincipalID,MonedaSecundariaID,SubidaAutomaticaCatalogoML","[ParametroGeneralID] ASC"),
            ("configuracion-parametros","ConfiguracionParametros","ParametroID,EmpresaID,ClaveParametro,ValorParametro,Descripcion","[ParametroID] ASC"),
            ("decisiones","DecisionesHistorial","DecisionID,EmpresaID,PublicacionID,EstrategiaID,PrecioAnterior,PrecioCalculado,PrecioSugerido,Accion,Motivo,ReglaGanadoraID,PrioridadAplicada,MargenActualPorc,MargenProyectadoPorc,PosicionCompetitiva,PrecioCompetenciaRef,CompetidorItemIDRef,StockDisponible,ClasificacionStock,ScoreConfianza,EsSimulacion,FechaDecision","[FechaDecision] DESC, [DecisionID] DESC"),
            ("decisiones-detalle-auditoria","DecisionesDetalleAuditoria","AuditoriaID,DecisionID,ReglaID,Prioridad,EvaluacionResultado,ValorPrecioPropuesto,DetalleJSON","[AuditoriaID] DESC"),
            ("metricas-ventas-hist","MetricasVentasHist","MetricaID,PublicacionID,VentasHoy,Ventas7D,Ventas15D,Ventas30D,Ventas60D,Ventas90D,VelocidadVentaDiaria,TendenciaPorc,DiasStockDisponibles,FechaCalculo","[MetricaID] ASC"),
            ("competencia-snapshot","CompetenciaSnapshot","SnapshotID,PublicacionID,CompetidorItemID,CompetidorVendedorID,PrecioCompetidor,StockCompetidor,TipoPublicacion,OfreceEnvioGratis,EsCompetidorDirecto,NivelRelevancia,FechaCaptura","[SnapshotID] ASC"),
            ("cola-ejecucion-ml","ColaEjecucionML","ColaID,PublicacionID,MeliItemID,PrecioNuevo,AccionRequerida,EstadoEjecucion,MensajeError,Motivo,CompetidorItemIDRef,PrecioCompetidorRef,RequiereAprobacion,Aprobado,FechaAprobacion,FechaCreacion,FechaProcesado","[FechaCreacion] DESC, [ColaID] DESC"),
            ("sincronizaciones-ml","SincronizacionMLHistorial","SincronizacionMLID,FechaEjecucion,TotalProcesados,TotalErrores,ConCompetenciaActualizada","[FechaEjecucion] DESC, [SincronizacionMLID] DESC"),
            ("sincronizaciones-ml-detalle","SincronizacionMLDetalle","SincronizacionMLDetalleID,SincronizacionMLID,PublicacionID,MeliItemID,Ok,Error,CompetenciaActualizada","[SincronizacionMLID] DESC, [SincronizacionMLDetalleID] ASC") };
        return rows.ToDictionary(x => x.Resource, x => new ReportDefinition(x.Table, x.Columns.Split(',').Select(Column).ToArray(), x.DefaultOrder), StringComparer.OrdinalIgnoreCase);
    }
    private static ReportColumn Column(string db) => new(ToCamel(db), db, Kind(db));
    private static string ToCamel(string value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;
        if (value.All(char.IsUpper)) return value.ToLowerInvariant();
        return char.ToLowerInvariant(value[0]) + value[1..];
    }
    private static ColumnKind Kind(string c) => c is "Activo" or "Activa" or "EsCatalogo" or "EsSimulacion" or "OfreceEnvioGratis" or "EsCompetidorDirecto" ? ColumnKind.Boolean : c.StartsWith("Fecha", StringComparison.Ordinal) ? ColumnKind.DateTime : c is "CotizacionID" or "DecisionID" or "AuditoriaID" or "SnapshotID" or "ColaID" ? ColumnKind.Long : IdsDeTexto.Contains(c) ? ColumnKind.Text : c.EndsWith("ID", StringComparison.Ordinal) || c.StartsWith("Ventas", StringComparison.Ordinal) || c.StartsWith("Stock", StringComparison.Ordinal) || c is "Prioridad" or "PrioridadAplicada" or "PosicionCompetitiva" or "NivelRelevancia" or "DiasStockDisponibles" ? ColumnKind.Int : c.StartsWith("Precio", StringComparison.Ordinal) || c.StartsWith("Costo", StringComparison.Ordinal) || c is "PorcentajeIVA" or "ImpuestosInternos" or "ComisionMLPorc" or "MargenActualPorc" or "MargenProyectadoPorc" or "ScoreConfianza" or "VelocidadVentaDiaria" or "TendenciaPorc" ? ColumnKind.Decimal : ColumnKind.Text;
}

public sealed record PagedReport(IReadOnlyList<Dictionary<string, object?>> Items, int Page, int PageSize, long TotalCount);
public sealed record ReportDefinition(string Table, IReadOnlyList<ReportColumn> Columns, string DefaultOrder) { public IReadOnlyDictionary<string, ReportColumn> ByName { get; } = Columns.ToDictionary(x => x.Name, StringComparer.OrdinalIgnoreCase); }
public sealed record ReportColumn(string Name, string DatabaseName, ColumnKind Kind) { public SqlDbType SqlType => Kind switch { ColumnKind.Int => SqlDbType.Int, ColumnKind.Long => SqlDbType.BigInt, ColumnKind.Decimal => SqlDbType.Decimal, ColumnKind.Boolean => SqlDbType.Bit, ColumnKind.DateTime => SqlDbType.DateTime2, _ => SqlDbType.NVarChar }; }
public sealed record ReportRequest(int Page, int PageSize, IReadOnlyList<ReportFilter> Filters, IReadOnlyList<ReportSort> Sort);
public sealed record ReportFilter(ReportColumn Column, string Operator, string Value);
public sealed record ReportSort(ReportColumn Column, string Direction);
public enum ColumnKind { Text, Int, Long, Decimal, Boolean, DateTime }
public sealed class ReportValidationException(string message, string? detail = null) : Exception(message) { public string? Detail { get; } = detail; }
