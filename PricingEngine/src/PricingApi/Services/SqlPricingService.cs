using System.Data;
using Microsoft.Data.SqlClient;
using PricingAdapter.Adapters;
using PricingAdapter.Models;

namespace PricingApi.Services;

public class SqlPricingService
{
    private readonly string _connectionString;

    public SqlPricingService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    public Task<PricingDecisionResult> EvaluateAsync(ProductoInput producto)
    {
        return EvaluateAsync(producto, true, false);
    }

    public async Task<PricingDecisionResult> EvaluateAsync(ProductoInput producto, bool modoSimulacion, bool persistir)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "dbo.spCalcularDecision";

        command.Parameters.Add("@EmpresaID", SqlDbType.Int).Value = producto.EmpresaId;
        command.Parameters.Add("@ProductoID", SqlDbType.Int).Value = (object?)producto.ProductoId ?? DBNull.Value;
        command.Parameters.Add("@EstrategiaID", SqlDbType.Int).Value = DBNull.Value;
        command.Parameters.Add("@ModoSimulacion", SqlDbType.Bit).Value = modoSimulacion;
        command.Parameters.Add("@Persistir", SqlDbType.Bit).Value = persistir;
        command.Parameters.Add("@ContextSource", SqlDbType.VarChar, 20).Value = modoSimulacion ? "TEMP" : "BASE";
        command.Parameters.Add("@SKU", SqlDbType.VarChar, 100).Value = producto.SKU ?? string.Empty;
        command.Parameters.Add("@Titulo", SqlDbType.NVarChar, 200).Value = producto.Titulo ?? string.Empty;
        AddDecimal(command, "@PrecioActual", producto.PrecioActual, 18, 4);
        command.Parameters.Add("@StockActual", SqlDbType.Int).Value = producto.StockActual;
        command.Parameters.Add("@StockMinimo", SqlDbType.Int).Value = producto.StockMinimo;
        command.Parameters.Add("@StockMaximo", SqlDbType.Int).Value = producto.StockMaximo;
        AddDecimal(command, "@CostoCompra", producto.CostoCompra, 18, 4);
        AddDecimal(command, "@IVA", producto.IVA, 5, 2);
        AddDecimal(command, "@ComisionMLPorc", producto.ComisionMLPorc, 5, 2);
        AddDecimal(command, "@CostoEnvioPromedio", producto.CostoEnvioPromedio, 18, 4);
        AddDecimal(command, "@CostoLogisticoFijo", producto.CostoLogisticoFijo, 18, 4);
        AddDecimal(command, "@CostoFinancieroPorc", producto.CostoFinancieroPorc, 5, 2);
        AddDecimal(command, "@CostoPublicidadPorc", producto.CostoPublicidadPorc, 5, 2);
        command.Parameters.Add("@EstadoPublicacion", SqlDbType.VarChar, 50).Value = string.IsNullOrWhiteSpace(producto.EstadoPublicacion) ? "active" : producto.EstadoPublicacion ?? "active";
        command.Parameters.Add("@CooldownHoras", SqlDbType.Int).Value = 12;
        AddDecimal(command, "@VariacionMinimaPorc", 1.50m, 5, 2);
        command.Parameters.Add("@Idioma", SqlDbType.VarChar, 5).Value = NormalizeLanguage(producto.Idioma);

        var result = new PricingDecisionResult
        {
            EmpresaId = producto.EmpresaId,
            Sku = producto.SKU ?? string.Empty,
            FuenteOrigen = producto.FuenteOrigen ?? string.Empty,
            ModoSimulacion = modoSimulacion
        };

        await using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            result.PrecioActual = reader.IsDBNull(reader.GetOrdinal("PrecioActual")) ? 0m : Convert.ToDecimal(reader["PrecioActual"]);
            result.PrecioSugerido = reader.IsDBNull(reader.GetOrdinal("PrecioSugerido")) ? 0m : Convert.ToDecimal(reader["PrecioSugerido"]);
            result.Accion = reader.IsDBNull(reader.GetOrdinal("Accion")) ? string.Empty : reader["Accion"].ToString() ?? string.Empty;
            result.Motivo = reader.IsDBNull(reader.GetOrdinal("Motivo")) ? string.Empty : reader["Motivo"].ToString() ?? string.Empty;
            result.MargenActualPorc = reader.IsDBNull(reader.GetOrdinal("MargenActualPorc")) ? 0m : Convert.ToDecimal(reader["MargenActualPorc"]);
            result.ScoreConfianza = reader.IsDBNull(reader.GetOrdinal("ScoreConfianza")) ? 0m : Convert.ToDecimal(reader["ScoreConfianza"]);
        }

        return result;
    }

    // #ejecucionAutomatica: evalúa en modo producción (BASE, Persistir=1) cada producto
    // con una publicación ML abierta — el mismo llamado mínimo que ya usa la suite de
    // regresión del motor (@EmpresaID/@ProductoID nada más; el resto de los parámetros
    // de EvaluateAsync quedan con su valor por default porque la rama BASE del SP los
    // ignora y lee todo de las tablas reales). Es el paso "evaluar todos los productos"
    // que hoy no existe como acción manual, solo automática (ver ADR 0019).
    public async Task<(int Evaluados, int CambiosDePrecio)> EvaluarTodosLosProductosAsync()
    {
        var pares = new List<(int EmpresaId, int ProductoId)>();
        await using (var conn = new SqlConnection(_connectionString))
        {
            await conn.OpenAsync();
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = @"SELECT DISTINCT p.ProductoID, p.EmpresaID
                                 FROM PublicacionesML pub
                                 JOIN Productos p ON p.ProductoID = pub.ProductoID
                                 WHERE pub.Estado <> 'closed' AND p.Activo = 1";
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
                pares.Add((Convert.ToInt32(reader["EmpresaID"]), Convert.ToInt32(reader["ProductoID"])));
        }

        var cambios = 0;
        foreach (var (empresaId, productoId) in pares)
        {
            var producto = new ProductoInput { EmpresaId = empresaId, ProductoId = productoId };
            var resultado = await EvaluateAsync(producto, modoSimulacion: false, persistir: true);
            if (resultado.Accion is "AUMENTAR_PRECIO" or "DISMINUIR_PRECIO")
                cambios++;
        }

        return (pares.Count, cambios);
    }

    private static void AddDecimal(SqlCommand command, string name, decimal value, byte precision, byte scale)
    {
        var parameter = command.Parameters.Add(name, SqlDbType.Decimal);
        parameter.Precision = precision;
        parameter.Scale = scale;
        parameter.Value = value;
    }

    private static string NormalizeLanguage(string? idioma)
    {
        var normalized = idioma?.Trim().ToUpperInvariant();
        return normalized is "ES" or "EN" or "PT" ? normalized : "ES";
    }
}

public class PricingDecisionResult
{
    public int EmpresaId { get; set; }
    public string Sku { get; set; } = string.Empty;
    public decimal PrecioActual { get; set; }
    public decimal PrecioSugerido { get; set; }
    public string Accion { get; set; } = string.Empty;
    public string Motivo { get; set; } = string.Empty;
    public decimal MargenActualPorc { get; set; }
    public decimal ScoreConfianza { get; set; }
    public bool ModoSimulacion { get; set; }
    public string FuenteOrigen { get; set; } = string.Empty;
}
