using System.Text.Json;
using PricingAdapter.Models;

namespace PricingAdapter.Adapters;

public class UiAdapter : BaseInputAdapter
{
    public override string SourceName => "UI";

    public override ProductoInput Map(JsonElement payload)
    {
        var empresaId = ReadInt(payload, "empresaId");
        var sku = NormalizeSku(ReadString(payload, "sku"));
        var titulo = ReadString(payload, "titulo");
        var precioActual = ReadDecimal(payload, "precioPropuesto");
        var precioMinimo = ReadDecimal(payload, "precioMinimoPermitido", precioActual * 0.9m);
        var precioMaximo = ReadDecimal(payload, "precioMaximoPermitido", precioActual * 1.2m);
        var stockActual = ReadInt(payload, "stockDisponible");
        var stockMinimo = ReadInt(payload, "stockMinimo", 10);
        var stockMaximo = ReadInt(payload, "stockMaximo", 20);
        var costoCompra = ReadDecimal(payload, "costoBase");
        var iva = ReadDecimal(payload, "iva", 21m);
        var comisionMl = ReadDecimal(payload, "comisionMLPorc", 9m);
        var costoEnvio = ReadDecimal(payload, "costoEnvioPromedio", 0m);
        var costoLogistico = ReadDecimal(payload, "costoLogisticoFijo", 0m);
        var costoFinanciero = ReadDecimal(payload, "costoFinancieroPorc", 0m);
        var costoPublicidad = ReadDecimal(payload, "costoPublicidadPorc", 0m);
        var estado = ReadString(payload, "estadoPublicacion", "active");
        var idioma = ReadString(payload, "idioma", "ES").Trim().ToUpperInvariant();
        var origen = ReadString(payload, "origen", SourceName);

        if (string.IsNullOrWhiteSpace(sku))
        {
            throw new InvalidOperationException("El campo sku es obligatorio.");
        }

        if (precioActual <= 0m)
        {
            throw new InvalidOperationException("El campo precioPropuesto debe ser mayor a cero.");
        }

        if (costoCompra <= 0m)
        {
            throw new InvalidOperationException("El campo costoBase debe ser mayor a cero.");
        }

        return new ProductoInput
        {
            EmpresaId = empresaId,
            SKU = sku,
            Titulo = titulo,
            PrecioActual = precioActual,
            PrecioMinimoPermitido = precioMinimo,
            PrecioMaximoPermitido = precioMaximo,
            StockActual = stockActual,
            StockMinimo = stockMinimo,
            StockMaximo = stockMaximo,
            CostoCompra = costoCompra,
            IVA = iva,
            ComisionMLPorc = comisionMl,
            CostoEnvioPromedio = costoEnvio,
            CostoLogisticoFijo = costoLogistico,
            CostoFinancieroPorc = costoFinanciero,
            CostoPublicidadPorc = costoPublicidad,
            FechaCaptura = GetFechaCaptura(payload),
            FuenteOrigen = origen,
            EstadoPublicacion = estado,
            Idioma = idioma
        };
    }
}
