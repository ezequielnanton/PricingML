using System.Data;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

// #resumenVentasPantallaPrincipal: venta bruta / costo total / rentabilidad que se
// muestran al entrar a la pantalla Pricing. Ventana fija de 30 días (mismo default que
// ya usa el motor para la velocidad de venta, ver ADR 0008) porque no existe un
// registro de ventas histórico real (MetricasVentasHist guarda solo cantidades por
// ventana rodante, no un ledger de órdenes) — la venta y el costo son una
// aproximación: unidades vendidas en la ventana × precio/costo ACTUAL, no el precio al
// que realmente se vendió cada unidad en su momento.
public class ResumenVentasService
{
    private readonly string _connectionString;

    public ResumenVentasService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    public async Task<ResumenVentasResponse> GetResumenAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        // #costoTotalMismaFormulaQueElMotor: los mismos componentes de costo que usa
        // dbo.fn_CalcularMargenNetoPorc (compra + comisión + envío + logística +
        // financiero + publicidad) — a propósito NO se descuenta el IVA del precio acá
        // (a diferencia de esa función): "venta bruta" es literalmente lo que paga el
        // cliente, y "rentabilidad" es Venta Bruta - Costo Total tal cual, para que los
        // tres números de la pantalla se puedan verificar a simple vista con una resta.
        cmd.CommandText = @"
            SELECT
                SUM(ISNULL(mv.Ventas30D, 0) * pub.PrecioActual) AS VentaBrutaTotal,
                SUM(ISNULL(mv.Ventas30D, 0) * (
                    ISNULL(c.CostoCompra, 0)
                    + pub.PrecioActual * ISNULL(pub.ComisionMLPorc, 0) / 100.0
                    + ISNULL(c.CostoEnvioPromedio, 0)
                    + ISNULL(c.CostoLogisticoFijo, 0)
                    + pub.PrecioActual * ISNULL(c.CostoFinancieroPorc, 0) / 100.0
                    + pub.PrecioActual * ISNULL(c.CostoPublicidadPorc, 0) / 100.0
                )) AS CostoTotal,
                SUM(ISNULL(mv.Ventas7D, 0)) AS Ventas7D,
                SUM(ISNULL(mv.Ventas15D, 0)) AS Ventas15D,
                SUM(ISNULL(mv.Ventas30D, 0)) AS Ventas30D,
                SUM(ISNULL(mv.Ventas60D, 0)) AS Ventas60D,
                SUM(ISNULL(mv.Ventas90D, 0)) AS Ventas90D
            FROM PublicacionesML pub
            JOIN Productos p ON p.ProductoID = pub.ProductoID
            LEFT JOIN CostosProducto c ON c.ProductoID = p.ProductoID
            LEFT JOIN MetricasVentasHist mv ON mv.PublicacionID = pub.PublicacionID
            WHERE pub.Estado <> 'closed' AND p.Activo = 1";

        await using var reader = await cmd.ExecuteReaderAsync();
        var resultado = new ResumenVentasResponse { VentanaDias = 30 };
        if (await reader.ReadAsync())
        {
            resultado.VentaBrutaTotal = reader["VentaBrutaTotal"] is DBNull ? 0m : Convert.ToDecimal(reader["VentaBrutaTotal"]);
            resultado.CostoTotal = reader["CostoTotal"] is DBNull ? 0m : Convert.ToDecimal(reader["CostoTotal"]);
            resultado.VentasPorVentana = new List<VentanaVentaItem>
            {
                new() { Dias = 7, UnidadesVendidas = reader["Ventas7D"] is DBNull ? 0 : Convert.ToInt32(reader["Ventas7D"]) },
                new() { Dias = 15, UnidadesVendidas = reader["Ventas15D"] is DBNull ? 0 : Convert.ToInt32(reader["Ventas15D"]) },
                new() { Dias = 30, UnidadesVendidas = reader["Ventas30D"] is DBNull ? 0 : Convert.ToInt32(reader["Ventas30D"]) },
                new() { Dias = 60, UnidadesVendidas = reader["Ventas60D"] is DBNull ? 0 : Convert.ToInt32(reader["Ventas60D"]) },
                new() { Dias = 90, UnidadesVendidas = reader["Ventas90D"] is DBNull ? 0 : Convert.ToInt32(reader["Ventas90D"]) },
            };
        }

        resultado.Rentabilidad = resultado.VentaBrutaTotal - resultado.CostoTotal;
        resultado.RentabilidadPorc = resultado.VentaBrutaTotal > 0
            ? Math.Round(resultado.Rentabilidad / resultado.VentaBrutaTotal * 100m, 2)
            : null;

        return resultado;
    }
}
