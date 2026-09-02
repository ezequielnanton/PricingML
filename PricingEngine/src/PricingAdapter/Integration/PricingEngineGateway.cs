using PricingAdapter.Models;

namespace PricingAdapter.Integration;

public class PricingEngineGateway
{
    public PricingDecision EjecutarSimulacion(ProductoInput producto)
    {
        var margenActual = CalcularMargen(producto.PrecioActual, producto.CostoCompra, producto.ComisionMLPorc, producto.IVA,
            producto.CostoEnvioPromedio, producto.CostoLogisticoFijo, producto.CostoFinancieroPorc, producto.CostoPublicidadPorc);

        var decision = new PricingDecision
        {
            EmpresaId = producto.EmpresaId,
            Sku = producto.SKU,
            PrecioActual = producto.PrecioActual,
            Accion = margenActual < 10m ? "NO_MODIFICAR" : "MANTENER_PRECIO",
            Motivo = margenActual < 10m ? "Margen bajo: requiere revisión manual" : "Margen aceptable, mantiene precio actual",
            MargenActualPorc = margenActual,
            PrecioSugerido = producto.PrecioActual,
            ModoSimulacion = true,
            FuenteOrigen = producto.FuenteOrigen
        };

        if (producto.StockActual <= producto.StockMinimo)
        {
            decision.Accion = "AUMENTAR_PRECIO";
            decision.Motivo = "Stock crítico: se protege disponibilidad del producto.";
            decision.PrecioSugerido = producto.PrecioActual * 1.05m;
        }
        else if (producto.StockActual >= producto.StockMaximo)
        {
            decision.Accion = "DISMINUIR_PRECIO";
            decision.Motivo = "Exceso de stock: se liquida inventario.";
            decision.PrecioSugerido = producto.PrecioActual * 0.93m;
        }

        return decision;
    }

    private static decimal CalcularMargen(decimal precioFinal, decimal costoCompra, decimal comisionMlPorc, decimal ivaPorc,
        decimal costoEnvio, decimal costoLogistico, decimal costoFinancieroPorc, decimal costoPublicidadPorc)
    {
        if (precioFinal <= 0m)
        {
            return 0m;
        }

        var precioSinIva = precioFinal / (1 + (ivaPorc / 100m));
        var comisionMonto = precioFinal * (comisionMlPorc / 100m);
        var costoFinancieroMonto = precioFinal * (costoFinancieroPorc / 100m);
        var costoPublicidadMonto = precioFinal * (costoPublicidadPorc / 100m);

        var costoTotal = costoCompra + comisionMonto + costoEnvio + costoLogistico + costoFinancieroMonto + costoPublicidadMonto;
        var gananciaNeta = precioSinIva - costoTotal;

        return (gananciaNeta / precioFinal) * 100m;
    }
}

public class PricingDecision
{
    public int EmpresaId { get; set; }
    public string Sku { get; set; } = string.Empty;
    public decimal PrecioActual { get; set; }
    public decimal PrecioSugerido { get; set; }
    public string Accion { get; set; } = string.Empty;
    public string Motivo { get; set; } = string.Empty;
    public decimal MargenActualPorc { get; set; }
    public bool ModoSimulacion { get; set; }
    public string FuenteOrigen { get; set; } = string.Empty;
}
