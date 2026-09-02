using System.Data;
using Microsoft.Data.SqlClient;
using PricingAdapter.Models;

namespace PricingApi.Services;

public class InputPersistenceService
{
    private readonly string _connectionString;

    public InputPersistenceService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    public async Task<int> PersistProductoInputAsync(ProductoInput producto)
    {
        if (producto is null) throw new ArgumentNullException(nameof(producto));

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        using var transaction = (SqlTransaction)connection.BeginTransaction();

        try
        {
            // 1. Validar Empresa
            await using (var cmdEmpresa = connection.CreateCommand())
            {
                cmdEmpresa.Transaction = transaction;
                cmdEmpresa.CommandText = "SELECT EmpresaID FROM Empresas WHERE EmpresaID = @EmpresaID";
                cmdEmpresa.Parameters.Add("@EmpresaID", SqlDbType.Int).Value = producto.EmpresaId;

                var obj = await cmdEmpresa.ExecuteScalarAsync();
                if (obj == null)
                {
                    throw new KeyNotFoundException($"Empresa {producto.EmpresaId} no encontrada.");
                }
            }

            int productoId = 0;

            // 2. Upsert Productos
            await using (var cmdProd = connection.CreateCommand())
            {
                cmdProd.Transaction = transaction;
                cmdProd.CommandText = "SELECT ProductoID, Titulo FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = @SKU";
                cmdProd.Parameters.Add("@EmpresaID", SqlDbType.Int).Value = producto.EmpresaId;
                cmdProd.Parameters.Add("@SKU", SqlDbType.VarChar, 50).Value = producto.SKU;

                await using var reader = await cmdProd.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    productoId = Convert.ToInt32(reader["ProductoID"]);
                    var tituloExistente = reader.IsDBNull(reader.GetOrdinal("Titulo")) ? string.Empty : reader["Titulo"].ToString();
                    await reader.CloseAsync();

                    // Actualizar título si cambió
                    if (!string.Equals(tituloExistente, producto.Titulo ?? string.Empty, StringComparison.Ordinal))
                    {
                        await using var cmdUpd = connection.CreateCommand();
                        cmdUpd.Transaction = transaction;
                        cmdUpd.CommandText = "UPDATE Productos SET Titulo = @Titulo WHERE ProductoID = @ProductoID";
                        cmdUpd.Parameters.Add("@Titulo", SqlDbType.NVarChar, 255).Value = (object?)producto.Titulo ?? string.Empty;
                        cmdUpd.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;
                        await cmdUpd.ExecuteNonQueryAsync();
                    }
                }
                else
                {
                    await reader.CloseAsync();

                    await using var cmdIns = connection.CreateCommand();
                    cmdIns.Transaction = transaction;
                    cmdIns.CommandText = "INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo, FechaCreacion) VALUES (@EmpresaID, @SKU, @Titulo, 1, SYSDATETIME()); SELECT SCOPE_IDENTITY();";
                    cmdIns.Parameters.Add("@EmpresaID", SqlDbType.Int).Value = producto.EmpresaId;
                    cmdIns.Parameters.Add("@SKU", SqlDbType.VarChar, 50).Value = producto.SKU;
                    cmdIns.Parameters.Add("@Titulo", SqlDbType.NVarChar, 255).Value = (object?)producto.Titulo ?? string.Empty;

                    var idObj = await cmdIns.ExecuteScalarAsync();
                    productoId = Convert.ToInt32(idObj);
                }
            }

            producto.ProductoId = productoId;

            // 3. Upsert CostosProducto
            await using (var cmdCostoSel = connection.CreateCommand())
            {
                cmdCostoSel.Transaction = transaction;
                cmdCostoSel.CommandText = "SELECT CostoID FROM CostosProducto WHERE ProductoID = @ProductoID";
                cmdCostoSel.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;

                var obj = await cmdCostoSel.ExecuteScalarAsync();
                if (obj != null)
                {
                    // Update
                    await using var cmdUpdCosto = connection.CreateCommand();
                    cmdUpdCosto.Transaction = transaction;
                    cmdUpdCosto.CommandText = @"
UPDATE CostosProducto SET
    CostoCompra = @CostoCompra,
    PorcentajeIVA = @PorcentajeIVA,
    CostoEnvioPromedio = @CostoEnvioPromedio,
    CostoLogisticoFijo = @CostoLogisticoFijo,
    CostoFinancieroPorc = @CostoFinancieroPorc,
    CostoPublicidadPorc = @CostoPublicidadPorc,
    OtrosCostosFijos = @OtrosCostosFijos,
    FechaUltimaActualizacion = SYSDATETIME()
WHERE ProductoID = @ProductoID";

                    cmdUpdCosto.Parameters.Add("@CostoCompra", SqlDbType.Decimal).Value = producto.CostoCompra;
                    cmdUpdCosto.Parameters.Add("@PorcentajeIVA", SqlDbType.Decimal).Value = producto.IVA;
                    cmdUpdCosto.Parameters.Add("@CostoEnvioPromedio", SqlDbType.Decimal).Value = producto.CostoEnvioPromedio;
                    cmdUpdCosto.Parameters.Add("@CostoLogisticoFijo", SqlDbType.Decimal).Value = producto.CostoLogisticoFijo;
                    cmdUpdCosto.Parameters.Add("@CostoFinancieroPorc", SqlDbType.Decimal).Value = producto.CostoFinancieroPorc;
                    cmdUpdCosto.Parameters.Add("@CostoPublicidadPorc", SqlDbType.Decimal).Value = producto.CostoPublicidadPorc;
                    cmdUpdCosto.Parameters.Add("@OtrosCostosFijos", SqlDbType.Decimal).Value = 0m;
                    cmdUpdCosto.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;

                    await cmdUpdCosto.ExecuteNonQueryAsync();
                }
                else
                {
                    // Insert
                    await using var cmdInsCosto = connection.CreateCommand();
                    cmdInsCosto.Transaction = transaction;
                    cmdInsCosto.CommandText = @"
INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, ImpuestosInternos, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc, OtrosCostosFijos, FechaUltimaActualizacion)
VALUES (@ProductoID, @CostoCompra, @PorcentajeIVA, 0, @CostoEnvioPromedio, @CostoLogisticoFijo, @CostoFinancieroPorc, @CostoPublicidadPorc, 0, SYSDATETIME());";

                    cmdInsCosto.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;
                    cmdInsCosto.Parameters.Add("@CostoCompra", SqlDbType.Decimal).Value = producto.CostoCompra;
                    cmdInsCosto.Parameters.Add("@PorcentajeIVA", SqlDbType.Decimal).Value = producto.IVA;
                    cmdInsCosto.Parameters.Add("@CostoEnvioPromedio", SqlDbType.Decimal).Value = producto.CostoEnvioPromedio;
                    cmdInsCosto.Parameters.Add("@CostoLogisticoFijo", SqlDbType.Decimal).Value = producto.CostoLogisticoFijo;
                    cmdInsCosto.Parameters.Add("@CostoFinancieroPorc", SqlDbType.Decimal).Value = producto.CostoFinancieroPorc;
                    cmdInsCosto.Parameters.Add("@CostoPublicidadPorc", SqlDbType.Decimal).Value = producto.CostoPublicidadPorc;

                    await cmdInsCosto.ExecuteNonQueryAsync();
                }
            }

            // 4. Upsert StockEstado
            await using (var cmdStockSel = connection.CreateCommand())
            {
                cmdStockSel.Transaction = transaction;
                cmdStockSel.CommandText = "SELECT StockID FROM StockEstado WHERE ProductoID = @ProductoID";
                cmdStockSel.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;

                var obj = await cmdStockSel.ExecuteScalarAsync();
                if (obj != null)
                {
                    // Update
                    await using var cmdUpdStock = connection.CreateCommand();
                    cmdUpdStock.Transaction = transaction;
                    cmdUpdStock.CommandText = @"
UPDATE StockEstado SET
    StockActual = @StockActual,
    StockReservado = ISNULL(StockReservado, 0),
    StockMinimo = @StockMinimo,
    StockMaximo = @StockMaximo,
    FechaActualizacion = SYSDATETIME()
WHERE ProductoID = @ProductoID";

                    cmdUpdStock.Parameters.Add("@StockActual", SqlDbType.Int).Value = producto.StockActual;
                    cmdUpdStock.Parameters.Add("@StockMinimo", SqlDbType.Int).Value = producto.StockMinimo;
                    cmdUpdStock.Parameters.Add("@StockMaximo", SqlDbType.Int).Value = producto.StockMaximo;
                    cmdUpdStock.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;

                    await cmdUpdStock.ExecuteNonQueryAsync();
                }
                else
                {
                    // Insert
                    await using var cmdInsStock = connection.CreateCommand();
                    cmdInsStock.Transaction = transaction;
                    cmdInsStock.CommandText = @"
INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo, FechaActualizacion)
VALUES (@ProductoID, @StockActual, 0, @StockMinimo, @StockMaximo, 30, SYSDATETIME());";

                    cmdInsStock.Parameters.Add("@ProductoID", SqlDbType.Int).Value = productoId;
                    cmdInsStock.Parameters.Add("@StockActual", SqlDbType.Int).Value = producto.StockActual;
                    cmdInsStock.Parameters.Add("@StockMinimo", SqlDbType.Int).Value = producto.StockMinimo;
                    cmdInsStock.Parameters.Add("@StockMaximo", SqlDbType.Int).Value = producto.StockMaximo;

                    await cmdInsStock.ExecuteNonQueryAsync();
                }
            }

            transaction.Commit();
            return productoId;
        }
        catch (Exception)
        {
            try
            {
                transaction.Rollback();
            }
            catch
            {
                // ignore rollback errors
            }

            throw;
        }
    }
}
