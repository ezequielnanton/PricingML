using System.Data;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

// #cargaOperativaRepositor: lookup y recuento absoluto de stock para la pantalla de
// carga del repositor. Solo toca StockEstado.StockActual y deja un rastro inmutable
// en StockCargas; no conoce estrategias, costos ni publicaciones.
public class RepositorStockService
{
    private readonly string _connectionString;

    public RepositorStockService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    public async Task<StockLookupResponse?> LookupAsync(int empresaId, string sku)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT p.ProductoID, p.SKU, p.Titulo, se.StockActual
                             FROM Productos p
                             JOIN StockEstado se ON se.ProductoID = p.ProductoID
                             WHERE p.EmpresaID = @empresaId AND p.SKU = @sku AND p.Activo = 1";
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
        cmd.Parameters.Add("@sku", SqlDbType.VarChar, 50).Value = sku;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        return new StockLookupResponse
        {
            ProductoID = Convert.ToInt32(reader["ProductoID"]),
            SKU = reader["SKU"].ToString() ?? string.Empty,
            Titulo = reader["Titulo"].ToString() ?? string.Empty,
            StockActual = Convert.ToInt32(reader["StockActual"])
        };
    }

    public async Task<StockCargaResponse?> CargarStockAsync(int empresaId, int repositorId, StockCargaRequest request)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync();

        int productoId = 0;
        string titulo = string.Empty;
        int stockAnterior = 0;
        var encontrado = false;

        // #rollbackConReaderAbierto: el mismo defecto que ADR 0017 encontró en el reset de
        // contraseña -- llamar a tx.RollbackAsync() mientras el SqlDataReader de esta misma
        // conexión sigue abierto (adentro del "await using" que todavía no se disparó)
        // tira una excepción no controlada (500) en vez del 404 esperado para un SKU que no
        // existe. Se resuelve el reader/lookupCmd primero y se decide el rollback después,
        // ya fuera de su bloque "await using".
        await using (var lookupCmd = conn.CreateCommand())
        {
            lookupCmd.Transaction = tx;
            lookupCmd.CommandText = @"SELECT p.ProductoID, p.Titulo, se.StockActual
                                       FROM Productos p
                                       JOIN StockEstado se ON se.ProductoID = p.ProductoID
                                       WHERE p.EmpresaID = @empresaId AND p.SKU = @sku AND p.Activo = 1";
            lookupCmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
            lookupCmd.Parameters.Add("@sku", SqlDbType.VarChar, 50).Value = request.SKU;
            await using var reader = await lookupCmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                productoId = Convert.ToInt32(reader["ProductoID"]);
                titulo = reader["Titulo"].ToString() ?? string.Empty;
                stockAnterior = Convert.ToInt32(reader["StockActual"]);
                encontrado = true;
            }
        }

        if (!encontrado)
        {
            await tx.RollbackAsync();
            return null;
        }

        await using (var updateCmd = conn.CreateCommand())
        {
            updateCmd.Transaction = tx;
            updateCmd.CommandText = @"UPDATE StockEstado
                                       SET StockActual = @stockNuevo, FechaActualizacion = SYSDATETIME()
                                       WHERE ProductoID = @productoId";
            updateCmd.Parameters.Add("@stockNuevo", SqlDbType.Int).Value = request.StockNuevo;
            updateCmd.Parameters.Add("@productoId", SqlDbType.Int).Value = productoId;
            await updateCmd.ExecuteNonQueryAsync();
        }

        await using (var insertCmd = conn.CreateCommand())
        {
            insertCmd.Transaction = tx;
            insertCmd.CommandText = @"INSERT INTO StockCargas (ProductoID, RepositorID, StockAnterior, StockNuevo)
                                       VALUES (@productoId, @repositorId, @stockAnterior, @stockNuevo)";
            insertCmd.Parameters.Add("@productoId", SqlDbType.Int).Value = productoId;
            insertCmd.Parameters.Add("@repositorId", SqlDbType.Int).Value = repositorId;
            insertCmd.Parameters.Add("@stockAnterior", SqlDbType.Int).Value = stockAnterior;
            insertCmd.Parameters.Add("@stockNuevo", SqlDbType.Int).Value = request.StockNuevo;
            await insertCmd.ExecuteNonQueryAsync();
        }

        await tx.CommitAsync();

        return new StockCargaResponse
        {
            ProductoID = productoId,
            SKU = request.SKU,
            Titulo = titulo,
            StockAnterior = stockAnterior,
            StockNuevo = request.StockNuevo
        };
    }
}
