# PricingAdapter

Ejemplo de implementación del contrato de entrada y el adaptador de la UI para el engine de pricing.

## Objetivo

- definir el modelo canónico de entrada
- crear un adaptador específico para la UI
- simular el flujo desde la pantalla hasta el motor

## Flujo

```text
UI -> Json payload -> UiAdapter -> ProductoInput -> PricingEngineGateway -> Decision
```

## Ejecutar

```bash
dotnet run --project src/PricingAdapter/PricingAdapter.csproj
```

## Notas de implementación y uso

- Adaptador implementado: UiAdapter (PricingAdapter.Adapters.UiAdapter). Este adaptador toma el payload desde la UI y lo convierte al contrato canónico ProductoInput.
- En la etapa actual, la única entrada permitida al sistema es la proveniente de la UI. No se deben invocar ni implementar cambios directos al procedimiento del motor `spCalcularDecision` sin autorización expresa.
- Para detalles de los endpoints expuestos y ejemplos de payload/response, ver `docs/API-Endpoints.md`.
- Para notas de implementación y decisiones operativas ver `docs/Implementation-Notes.md`.
- Se eliminaron adaptadores de ejemplo vacíos (ErpAAdapter.cs, ErpBAdapter.cs, MeliAdapter.cs) para mantener el proyecto limpio. Si se desea reintroducir adaptadores plantilla, generación via scripts o plantillas es recomendada.
