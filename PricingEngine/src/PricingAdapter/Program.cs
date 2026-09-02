using System.Text.Json;
using PricingAdapter.Adapters;
using PricingAdapter.Integration;

var payload = """
{
  "empresaId": 1,
  "sku": " SKU-001 ",
  "titulo": "Auriculares Bluetooth",
  "precioPropuesto": 46000,
  "precioMinimoPermitido": 42000,
  "precioMaximoPermitido": 58000,
  "stockDisponible": 8,
  "stockMinimo": 10,
  "stockMaximo": 20,
  "costoBase": 31000,
  "iva": 21,
  "comisionMLPorc": 9,
  "costoEnvioPromedio": 800,
  "costoLogisticoFijo": 500,
  "costoFinancieroPorc": 2,
  "costoPublicidadPorc": 4,
  "estadoPublicacion": "active",
  "origen": "UI"
}
""";

var document = JsonDocument.Parse(payload);
var uiAdapter = new UiAdapter();
var input = uiAdapter.Map(document.RootElement);

var engine = new PricingEngineGateway();
var decision = engine.EjecutarSimulacion(input);

Console.WriteLine("Contrato de entrada:");
Console.WriteLine(JsonSerializer.Serialize(input, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine();
Console.WriteLine("Salida del motor:");
Console.WriteLine(JsonSerializer.Serialize(decision, new JsonSerializerOptions { WriteIndented = true }));
