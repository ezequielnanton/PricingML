# Pricing Engine

Contexto de decisión de precios multifuente para publicaciones de venta y su
operación por empresa.

## Language

**Simulación**:
Evaluación síncrona de un producto que no modifica datos operativos ni encola una acción externa.
_Avoid_: producción, carga real

**Ingesta productiva**:
Recepción asíncrona de datos operativos de una fuente externa para normalizarlos y procesarlos de forma trazable.
_Avoid_: simulación, importación directa al motor

**Fuente de origen**:
Sistema externo que aporta datos al motor, como Mercado Libre, Amazon, un ERP o una interfaz interna.
_Avoid_: canal de ejecución

**Evento de ingesta**:
Mensaje universal que identifica una fuente, un tipo de dato y su contenido original para su normalización asíncrona.
_Avoid_: endpoint por marketplace, modelo canónico

**Tipo de evento**:
Clasificación del dato recibido: `catalog.product`, `inventory.stock`, `costs.product`, `offers.publication`, `sales.metrics` o `competition.snapshot`.
_Avoid_: endpoint de una fuente específica

**Vinculación de producto**:
Equivalencia entre un identificador externo y el SKU canónico de una empresa.
_Avoid_: coincidencia aproximada, asignación implícita

**Parámetro de Regla**:
Valor configurable por estrategia que modula cómo se aplica cada regla de pricing sin recompilar.
Ejemplos: porcentaje de incremento para stock crítico (+5%), descuento para competencia (-1%).
Permite ajustar la agresividad del motor por estrategia y empresa, con histórico de cambios.
_Avoid_: hardcoding de porcentajes en stored procedure

**Idioma de Mensaje**:
Código de idioma solicitado para generar el motivo de una decisión, por defecto `ES`.
El motor debe utilizarlo para seleccionar la plantilla parametrizada correspondiente.
_Avoid_: codificar el idioma únicamente dentro de la clave del mensaje

## Relationships

- Una **Fuente de origen** envía una o más **Ingestas productivas**.
- Una **Ingesta productiva** contiene uno o más **Eventos de ingesta** que se normalizan al modelo canónico.
- Cada **Evento de ingesta** tiene un **Tipo de evento**.
- Una **Vinculación de producto** pertenece a una empresa y conecta una **Fuente de origen** con un SKU canónico.
- Una **Simulación** evalúa un único producto sin crear una **Ingesta productiva**.
- Un **Parámetro de Regla** modula el comportamiento de una regla dentro de una estrategia específica.
- Un **Idioma de Mensaje** determina la plantilla localizada utilizada por el motor para el motivo de una decisión.

## Example dialogue

> **Dev:** "¿Una carga de Amazon debe cambiar el precio en la misma llamada?"
> **Domain expert:** "No; es una **Ingesta productiva** asíncrona. Una **Simulación** es el único flujo inmediato."

## Flagged ambiguities

- "Productivo" no significa publicar un cambio en un marketplace; significa ingresar datos operativos reales para procesamiento asíncrono.
- La **Vinculación de producto** se crea automáticamente solo si el SKU externo coincide exactamente con un SKU canónico existente; otros casos quedan pendientes y no alimentan pricing.
- Las **Vinculaciones de producto** pendientes se resuelven manualmente y habilitan el reproceso de sus **Eventos de ingesta**.
