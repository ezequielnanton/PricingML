# Documentación Técnica del Pricing Engine (Versión 2)

## 1. Propósito del sistema

El Pricing Engine es un componente de decisión automatizada para optimizar el precio de publicaciones en Mercado Libre, teniendo en cuenta:

- el margen neto del producto
- el stock disponible y objetivo
- la competencia directa y relevante
- la velocidad de venta histórica
- la estrategia comercial configurada por empresa
- la necesidad de explicabilidad y auditoría

El sistema no busca únicamente maximizar el precio, sino equilibrar tres objetivos:

1. rentabilidad
2. competitividad
3. disponibilidad del producto

En términos de negocio, la decisión final se resume en una acción de pricing:

- mantener precio
- aumentar precio
- disminuir precio
- no modificar por bloqueo de seguridad

---

## 2. Estado de madurez del proyecto

Este proyecto se encuentra en una etapa de MVP funcional con base técnica sólida, pero aún con límites claros para producción real.

### 2.1 Lo que ya está bien resuelto

- modelo relacional para multiempresa
- normalización mínima de negocio y operativa
- estrategia y reglas desacopladas
- soporte para simulación
- auditoría explicable
- historial para evaluación y trazabilidad
- persistencia de resultados de backtesting

### 2.2 Lo que aún no es de producción

- backtesting no está apoyado por snapshots históricos completos
- no hay conversión de moneda integrada como regla explícita del motor
- falta validación automatizada real en SQL Server con fixture de pruebas
- no hay trazabilidad completa de cada regla evaluada por ejecución
- faltan mecanismos operativos de control de calidad y alertas

Conclusión:
- es viable como MVP de pricing inteligente
- no está todavía en nivel de producción industrial

---

## 3. Modelo de dominio

### 3.1 Entidades del negocio

#### Empresa
Representa a la organización que va a usar el motor. Todas las decisiones están acotadas a una empresa.

#### Cuenta ML
Cada empresa puede tener una o varias cuentas de Mercado Libre desde las cuales se toman decisiones y se publican productos.

#### Producto
Es el SKU o ítem comercial que se administra dentro de la empresa.

#### Publicación
Es la instancia de un producto dentro de Mercado Libre, con su precio actual, límites, comisión y estado.

#### Stock
Es el estado de inventario del producto. Aquí se define el nivel de disponibilidad y riesgo de quiebre.

#### Competencia
Es el conjunto de precios de competidores para una publicación determinada.

#### Estrategia
Es la política comercial que determina qué reglas tiene prioridad y cómo se decide.

#### Decisión
Es el resultado de la evaluación: precio sugerido, acción, motivo, reglas involucradas y margen proyectado.

---

## 4. Arquitectura del sistema

### 4.1 Patrón general

El sistema sigue un patrón de decisión centrado en base de datos:

- la capa de ingestión actualiza tablas del modelo
- el motor lee el contexto del producto
- aplica reglas sobre el conjunto de publicación
- persiste el resultado en historial
- si corresponde, la ejecución se encola para enviar a Mercado Libre

### 4.2 Capas del sistema

#### Capa 1: datos operativos
- Productos
- CostosProducto
- PublicacionesML
- StockEstado
- MetricasVentasHist
- CompetenciaSnapshot

#### Capa 2: configuración
- Estrategias
- ReglasNegocio
- EstrategiaReglas
- ConfiguracionParametros

#### Capa 3: decisión
- `spCalcularDecision`
- `fn_CalcularMargenNetoPorc`

#### Capa 4: auditoría y ejecución
- `DecisionesHistorial`
- `DecisionesDetalleAuditoria`
- `ColaEjecucionML`

#### Capa 5: análisis y optimización
- `spEjecutarBacktesting`
- `BacktestingResultados`

---

## 5. Base de datos y estructura

### 5.1 Entidades principales

#### Empresas
Aisla la operación por cliente/empresa.

Relacionamiento:
- 1:N con CuentasML
- 1:N con Productos
- 1:N con ConfiguracionParametros
- 1:N con Estrategias

#### CuentasML
Representa la conexión comercial con la cuenta de Mercado Libre.

#### Productos
Unidad económica central del sistema.

#### CostosProducto
Calcula la base de costo y gastos asociados.

#### PublicacionesML
Representa la venta activa en Mercado Libre.

#### StockEstado
Informa la disponibilidad del producto.

#### MetricasVentasHist
Mide demanda histórica y velocidad de venta.

#### CompetenciaSnapshot
Comparación del precio del producto con precio de competidores.

#### Estrategias y reglas
Configuración ejecutiva del motor.

#### Historial y auditoría
Registra la decisión y justificación.

#### Monedas, Cotizaciones y Parámetros
Soporte para operaciones multi-moneda y configuración paramétrica a nivel de empresa.

---

## 6. Descripción funcional por módulo

### 6.1 Módulo de catalogación

Responsabilidad:
- mantener productos y publicaciones de cada empresa

Tablas:
- `Productos`
- `PublicacionesML`
- `CostosProducto`

Objetivo:
- tener una fuente única del contexto de cada SKU actual

---

### 6.2 Módulo de inventario

Responsabilidad:
- rastrear stock, reservas y niveles de seguridad

Tablas:
- `StockEstado`

Objetivo:
- detectar quiebre, exceso o normalidad

---

### 6.3 Módulo de ventas y demanda

Responsabilidad:
- evaluar volumen histórico y velocidad de venta

Tablas:
- `MetricasVentasHist`

Objetivo:
- entender crecimiento, caída o estabilidad de demanda

---

### 6.4 Módulo de competencia

Responsabilidad:
- evaluar precios de rivales y relevancia competitiva

Tablas:
- `CompetenciaSnapshot`

Objetivo:
- medir ventaja o desventaja frente a mercado

---

### 6.5 Módulo de reglas y estrategia

Responsabilidad:
- definir cómo priorizar decisiones comerciales

Tablas:
- `Estrategias`
- `ReglasNegocio`
- `EstrategiaReglas`
- `ConfiguracionParametros`

Objetivo:
- separar lógica comercial de ejecución técnica

---

### 6.6 Módulo de decisiones

Responsabilidad:
- tomar la decisión final

Objetos:
- `spCalcularDecision`
- `fn_CalcularMargenNetoPorc`

Objetivo:
- transformar contexto en precio sugerido y acción

---

### 6.7 Módulo de auditoría y ejecución

Responsabilidad:
- explicar por qué se tomó una decisión y dejarla lista para ejecución

Tablas:
- `DecisionesHistorial`
- `DecisionesDetalleAuditoria`
- `ColaEjecucionML`

Objetivo:
- mantener trazabilidad y control operacional

---

## 7. Función principal de cálculo de margen

### 7.1 `fn_CalcularMargenNetoPorc`

#### propósito
Calcula el margen neto porcentual del producto sobre el precio final.

#### entradas
- `@PrecioFinal`
- `@CostoCompra`
- `@ComisionMLPorc`
- `@PorcentajeIVA`
- `@CostoEnvio`
- `@CostoLogistico`
- `@CostoFinancieroPorc`
- `@CostoPublicidadPorc`

#### lógica
- calcula el precio sin IVA
- calcula comisiones y costos adicionales
- determina el costo total
- obtiene la ganancia neta
- devuelve porcentaje del margen neto

#### validaciones
- si `@PrecioFinal` es 0 o nulo, retorna 0.00

#### importancia
Es el primer indicador objetivo de rentabilidad que usa el motor para bloquear decisiones que destruyen margen.

---

## 8. Procedimiento central: `spCalcularDecision`

### 8.1 propósito
Es la pieza central del motor. Toma el contexto de una empresa o producto y devuelve la decisión recomendada sobre el precio.

### 8.2 parámetros

- `@EmpresaID` - empresa a evaluar
- `@ProductoID` - opcional, filtra un producto específico
- `@EstrategiaID` - opcional, si no se envía usa la activa
- `@ModoSimulacion` - `1` para no ejecutar cambios reales, `0` para producción
- `@CooldownHoras` - ventana anti-oscilación
- `@VariacionMinimaPorc` - umbral de histéresis

### 8.3 flujo operativo

1. determina la estrategia activa
2. carga el margen mínimo permitido desde `ConfiguracionParametros`
3. arma tabla temporal `#ContextoDecision`
4. trae publicaciones activas con sus costos, stock y métricas
5. calcula el margen actual para cada publicación
6. calcula competencia mínima y relevante
7. aplica reglas según prioridad de estrategia
8. valida bloqueos de seguridad
9. aplica cooldown e histéresis
10. persiste el resultado en historial
11. si está en producción, encola la acción para Mercado Libre
12. devuelve el resultado final

### 8.4 reglas aplicadas

#### a) stock crítico
Si el stock disponible está por debajo del mínimo, se aumenta el precio un 5%.

#### b) competencia más barata
Si existe un competidor relevante más barato, se baja el precio para reubicar competitividad.

#### c) exceso de stock
Si el stock sobrepasa el máximo, se aplica descuento para liquidar inventario.

#### d) margen mínimo
Si la baja propuesta empuja el margen por debajo del mínimo configurable, se bloquea la acción.

#### e) anti-oscilación
Si el producto fue actualizado recientemente o la diferencia es pequeña, se mantiene el precio actual.

### 8.5 salidas del procedimiento
El resultado incluye:

- `PublicacionID`
- `MeliItemID`
- `PrecioActual`
- `PrecioSugerido`
- `Accion`
- `Motivo`
- `MargenActualPorc`
- `MargenProyectadoPorc`
- `ClasificacionStock`
- `StockDisponible`
- `CompMinPrecio`
- `ScoreConfianza` (Indicador ponderado 0.00 a 1.00 calculado en base a la cantidad de competidores y estabilidad de ventas, p. ej. `0.5 + (Competidores / 10) + (VentasEstables ? 0.2 : 0)`)

### 8.6 consideraciones técnicas

El procedimiento aplica lógica de forma vectorizada usando tablas temporales y `UPDATE` set-based. Esto es correcto para un motor de decisión sobre lotes, aunque requiere cuidado con:

- prioridad de reglas
- cambios secuenciales sobre la misma fila
- cálculo de margen y competencia
- validación de temperatura del mercado

---

## 9. Backtesting

### 9.1 `spEjecutarBacktesting`

#### propósito
Simular el comportamiento de una estrategia en una ventana de fechas para comparar el impacto en rentabilidad.

#### parámetros
- `@EmpresaID`
- `@EstrategiaID`
- `@FechaInicio`
- `@FechaFin`

#### lógica
- genera la lista de días comprendidos
- por cada día ejecuta la estrategia en modo simulación
- acumula el impacto de cada decisión
- guarda resultados por fecha en `BacktestingResultados`

#### salida esperada
- facturación proyectada
- ganancia neta proyectada
- cantidad de cambios de precio

### 9.2 `BacktestingResultados`

Campos:
- `ExecutionID`
- `EstrategiaID`
- `FechaSimulada`
- `FacturacionProyectada`
- `GananciaNetaProyectada`
- `CantidadCambiosPrecio`
- `FechaEjecucion`

#### utilidad
Permite comparar cómo una estrategia impacta la rentabilidad histórica o simulada.

---

## 10. Reglas de negocio resumidas

| Código | Nombre | Tipo | Acción principal |
|---|---|---|---|
| `REGLA_STOCK_CRITICO` | Aumento por stock crítico | Operativa | Sube precio 5% |
| `REGLA_COMPETENCIA_ABAJO` | Ajuste por competencia más barata | Mercado | Baja precio para competir |
| `REGLA_OPORTUNIDAD` | Captura de margen por oportunidad | Oportunidad | Sube precio 3% ante ausencia de competencia o alta demanda |
| `REGLA_EXCESO_STOCK` | Liquidación por exceso stock | Operativa | Baja precio 7% |
| `MARGEN_MINIMO_PERMITIDO` | Bloqueo de margen mínimo | Seguridad | Rechaza precio que dañe rentabilidad |
| `COOLDOWN` / `HISTERESIS` | Anti-oscilación | Protección | Mantiene precio reciente o sin variación suficiente |

---

## 11. Validaciones del sistema

### 11.1 Validación de estrategia
Se valida que exista una estrategia activa para la empresa.

### 11.2 Validación de fechas
En backtesting:
- la fecha de inicio no puede ser mayor que la de fin
- ambas deben existir

### 11.3 Validación de margen mínimo
Si una acción de descuento reduce el margen por debajo del mínimo configurado, la decisión es bloqueada.

### 11.4 Validación de límites de publicación
Se corrige el precio sugerido al rango permitido:
- si es menor al mínimo, se ajusta al mínimo
- si es mayor al máximo, se ajusta al máximo

### 11.5 Validación anti-oscilación
Si:
- hubo un cambio muy reciente
- o la variación es pequeña

entonces se mantiene el precio actual.

---

## 12. Casos de uso funcionales

### Caso de uso 1: proteger disponibilidad del producto
El producto tiene stock crítico.

Resultado esperado:
- acción `AUMENTAR_PRECIO`
- motivo por stock crítico

### Caso de uso 2: competir contra un rival más barato
Hay una publicación competidora relevante más barata.

Resultado esperado:
- acción `DISMINUIR_PRECIO`
- motivo por pierde competitividad

### Caso de uso 3: liquidar inventario
El producto tiene exceso de stock.

Resultado esperado:
- acción `DISMINUIR_PRECIO`
- descuento de liquidación

### Caso de uso 4: evitar decisiones no rentables
Se detecta margen insuficiente.

Resultado esperado:
- `NO_MODIFICAR` o `MANTENER_PRECIO`

### Caso de uso 5: simulación operativa
El usuario quiere evaluar una estrategia sin tocar el sitio real.

Resultado esperado:
- resultado de recomendación sin ejecutarse en producción

### Caso de uso 6: backtesting de estrategia
Se compara una política de pricing en una ventana de tiempo.

Resultado esperado:
- medición del impacto en facturación y margen

---

## 13. Casos de prueba recomendados

### 13.1 Caso: margen mínimo bloqueado
Entrada:
- precio actual = 100.000
- margen proyectado = 12%
- margen mínimo permitido = 15%

Esperado:
- la recomendación es `NO_MODIFICAR`

### 13.2 Caso: stock crítico
Entrada:
- stock actual = 2
- stock mínimo = 5

Esperado:
- `AUMENTAR_PRECIO`

### 13.3 Caso: competencia más barata
Entrada:
- precio actual = 60.000
- competidor relevante = 56.000

Esperado:
- `DISMINUIR_PRECIO`

### 13.4 Caso: exceso de stock
Entrada:
- stock actual = 120
- stock máximo = 80

Esperado:
- `DISMINUIR_PRECIO`

### 13.5 Caso: cooldown activo
Entrada:
- último cambio hace 3 horas
- estrategia activa requiere opacidad de cambio

Esperado:
- `MANTENER_PRECIO`

### 13.6 Caso: histéresis
Entrada:
- variación propuesta = 0.8%
- umbral = 1.5%

Esperado:
- `MANTENER_PRECIO`

### 13.7 Caso: precio fuera del rango permitido
Entrada:
- sugerencia menor al mínimo permitido

Esperado:
- le ajusta al mínimo

### 13.8 Caso: empresa sin estrategia activa
Entrada:
- `@EstrategiaID` nulo y sin estrategia para la empresa

Esperado:
- error con mensaje claro

### 13.9 Caso: backtesting con fechas inválidas
Entrada:
- `FechaInicio > FechaFin`

Esperado:
- error

### 13.10 Caso: producto sin competencia reciente
Entrada:
- `CompetenciaSnapshot` vacío para 48 horas

Esperado:
- no falla, decide basado en otros criterios

---

## 14. Riesgos y puntos de mejora

### Riesgos actuales

- dependencia de la calidad de `CompetenciaSnapshot`
- cálculo de margen altamente sensible a costos y comisiones
- ausencia de snapshots históricos robustos para backtesting serio
- uso de valores fijos para stock y cooldown sin parametrización empresarial fuerte

### Mejora recomendada

- incluir snapshots históricos por día
- parametrizar más variables por empresa
- separar regla de margen mínimo por categoría / canal / tipo de publicación
- expandir la auditoría del detalle de reglas evaluadas
- construir pruebas automatizadas por escenario

---

## 15. Conclusión técnica

El Pricing Engine ya define una base sólida para automatizar decisiones de precio con una lógica de negocio clara y un modelo de datos decente para un MVP.

Tiene fuerza en:

- claridad conceptual
- separación de responsabilidades
- trazabilidad y explicabilidad
- decisiones basadas en margen + stock + competencia

Tiene limitaciones en:

- madurez operativa
- backtesting histórico real
- validación automatizada completa
- producción con alta carga de reglas y volumen

En resumen: es una base arquitectónica fuerte y útil para construir un motor de pricing real, pero aún requiere validación y evolución para pasar de prototipo a sistema productivo.

---

## 16. Archivos base del proyecto

- [SQL/Estructura.sql](../SQL/Estructura.sql)
- [SQL/fn_CalcularMargenNetoPorc.sql](../SQL/fn_CalcularMargenNetoPorc.sql)
- [SQL/spCalcularDecision.sql](../SQL/spCalcularDecision.sql)
- [SQL/BackTesting.sql](../SQL/BackTesting.sql)
- [SQL/Simulacion.sql](../SQL/Simulacion.sql)
- [Requerimiento/RequerimientoEngine.txt](../Requerimiento/RequerimientoEngine.txt)
# Pricing Engine — Documentación vigente

**Versión:** 2.2  
**Estado:** documento canónico  
**Actualizado:** 15/08/2026

## 1. Propósito

El Pricing Engine decide precios de publicaciones de Mercado Libre según margen,
stock, competencia, demanda y reglas configurables por empresa. Las acciones
son `MANTENER_PRECIO`, `AUMENTAR_PRECIO`, `DISMINUIR_PRECIO` y `NO_MODIFICAR`.

Opera en dos contextos:

- **Simulación (`TEMP`)**: usa los datos del request y no modifica la base.
- **Producción (`BASE`)**: consulta datos persistidos; con `persistir=true`
  registra auditoría y, si corresponde, encola una acción para Mercado Libre.

Es un MVP funcional: simulación, decisiones y auditoría están resueltas. Para
producción faltan integración outbound, observabilidad y controles operativos.

## 2. Arquitectura

```text
Postman / cliente HTTP
  -> POST /pricing/evaluate
  -> UiAdapter
  -> ProductoInput (modelo canónico)
  -> SqlPricingService
  -> dbo.spCalcularDecision + dbo.fn_CalcularMargenNetoPorc
  -> SQL Server (PRICES_DB)
```

| Componente | Responsabilidad |
|---|---|
| `PricingApi` | Endpoints HTTP `/health` y `/pricing/evaluate`. |
| `UiPricingRequest` | Contrato de entrada HTTP. |
| `UiAdapter` | Mapea y valida UI hacia el modelo canónico. |
| `ProductoInput` | Contrato interno de producto para los adaptadores. |
| `SqlPricingService` | Invoca SQL Server con parámetros tipados. |
| `spCalcularDecision` | Contexto, reglas, restricciones y persistencia. |
| `fn_CalcularMargenNetoPorc` | Margen neto actual o proyectado. |

Los adaptadores aíslan cada sistema origen (UI, ERP o canal) de la lógica de
pricing. Las reglas comerciales viven en SQL, no en el adaptador.

## 3. Modelo de datos

| Entidad | Propósito |
|---|---|
| `Empresas`, `CuentasML` | Tenant y cuenta comercial. |
| `Productos`, `CostosProducto` | Catálogo y estructura de costos. |
| `PublicacionesML`, `StockEstado` | Precio, límites y disponibilidad. |
| `MetricasVentasHist`, `CompetenciaSnapshot` | Demanda y competencia reciente. |
| `Monedas`, `Cotizaciones`, `ParametrosGenerales` | Solo esquema, pendiente de implementación lógica multi-moneda. |
| `Estrategias`, `ReglasNegocio`, `EstrategiaReglas` | Estrategia y prioridades. |
| `ConfiguracionParametros` | Parámetros por empresa. |
| `DecisionesHistorial`, `ColaEjecucionML` | Auditoría y ejecución pendiente. |
| `BacktestingResultados` | Resultados de backtesting. |

Cada empresa necesita una estrategia activa. El margen mínimo se lee de
`ConfiguracionParametros` con clave `MARGEN_MINIMO_PERMITIDO`; si no existe, el
procedimiento usa 15.00%.

## 4. Reglas de decisión

| Regla | Condición | Efecto inicial |
|---|---|---|
| Stock crítico | `StockDisponible <= StockMinimo` | Aumenta 5%. |
| Competencia menor | competidor más barato y stock no crítico | Baja a competidor menos 10. |
| Oportunidad | sin competencia directa o alta demanda | Sube precio 3%. |
| Exceso de stock | `StockDisponible >= StockMaximo` | Reduce 7%. |

Se selecciona la regla activa de menor prioridad numérica y se aplican estas
restricciones, en orden:

1. Margen mínimo: bloquea una baja no rentable con `NO_MODIFICAR`.
2. Límites de publicación: ajusta al mínimo o máximo permitido.
3. Anti-oscilación: conserva el precio con cooldown menor a 12 horas o cambio
   menor a 1,50%.

La clasificación de stock es `CRITICO`, `BAJO`, `NORMAL`, `ALTO` o `EXCESO`.

## 5. Margen neto

`fn_CalcularMargenNetoPorc` usa `DECIMAL(18,4)` para importes,
`DECIMAL(5,2)` para porcentajes y devuelve `DECIMAL(7,2)`.

```text
precio sin IVA = precio final / (1 + IVA / 100)
costo total = compra + comisión + envío + logística + financiero + publicidad
margen % = (precio sin IVA - costo total) / precio final * 100
```

Con precio 100.00, compra 40.00, IVA 21.00, comisión 11.5%, envío 5.00,
logística 2.00, financiero 3.0% y publicidad 2.0%, el margen es **19.14%**.

## 6. API y configuración

### Inicio local

Se requiere .NET SDK, SQL Server, `PRICES_DB`, la estructura SQL, la función y
el procedimiento instalados.

```powershell
cd "C:\PricingEngine\src\PricingApi"
$env:ConnectionStrings__PricingDb="Server=localhost\SQLEXPRESS;Database=PRICES_DB;Integrated Security=True;TrustServerCertificate=True;"
dotnet restore
dotnet build
dotnet run
```

La API escucha por defecto en `http://localhost:5000`. En cada instalación se
sobrescribe solo `ConnectionStrings__PricingDb`; no hace falta recompilar.

| Método | Ruta | Resultado |
|---|---|---|
| `GET` | `/health` | `{ "status": "ok" }` |
| `POST` | `/pricing/evaluate` | Resumen de una decisión. |

### Request de simulación

Enviar `Content-Type: application/json` a
`http://localhost:5000/pricing/evaluate`:

```json
{
  "empresaId": 1,
  "sku": "PROD-001",
  "titulo": "Mi Producto",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 50,
  "stockMinimo": 10,
  "stockMaximo": 200,
  "costoBase": 40.00,
  "iva": 21.00,
  "comisionMLPorc": 11.5,
  "costoEnvioPromedio": 5.00,
  "costoLogisticoFijo": 2.00,
  "costoFinancieroPorc": 3.0,
  "costoPublicidadPorc": 2.0,
  "estadoPublicacion": "active",
  "modoSimulacion": true,
  "persistir": false
}
```

Mapeos clave: `precioPropuesto -> PrecioActual`, `costoBase -> CostoCompra` y
`stockDisponible -> StockActual`. El adaptador exige SKU no vacío, precio mayor
a cero y costo mayor a cero.

### Contrato decimal

Los decimales son números JSON sin comillas y usan punto (`.`), sin depender de
la cultura de Windows: `21.00`, `11.5`, `3.0`. El adaptador usa
`CultureInfo.InvariantCulture`, por lo que `21.00` nunca se interpreta como
`2100.00`. No enviar valores como `"21,00"`.

### Respuesta REST actual

```json
{
  "empresaId": 1,
  "sku": "PROD-001",
  "precioActual": 100.00,
  "precioSugerido": 100.00,
  "accion": "MANTENER_PRECIO",
  "motivo": "Escenario simulado",
  "margenActualPorc": 19.14,
  "scoreConfianza": 0.80,
  "modoSimulacion": true,
  "fuenteOrigen": "UI"
}
```

El procedimiento también devuelve margen proyectado, clasificación de stock,
stock disponible y competencia; esos campos aún no están expuestos por la API.

## 7. Integración SQL vigente y limitaciones

`SqlPricingService` usa tipos SQL explícitos: `INT`, `BIT`, `VARCHAR`/
`NVARCHAR`, `DECIMAL(18,4)` para importes y `DECIMAL(5,2)` para porcentajes.
No se usa `AddWithValue`, para impedir inferencias de precisión o escala.

Limitaciones actuales:

- En simulación, el procedimiento deriva límites en 90% y 120% del precio;
  aunque la API acepta límites personalizados, todavía no los transmite a SQL.
- En producción, el request no incluye `ProductoId`; el procedimiento puede
  evaluar varias publicaciones y el servicio devuelve solo la primera fila.
  El endpoint actual está orientado a simulación de un producto.

## 8. Pruebas

El request de la sección 6 es la prueba base: debe devolver HTTP 200,
`MANTENER_PRECIO`, precio 100.00 y margen aproximado 19.14%. También verifica
que `21.00`, `11.5`, `3.0` y `2.0` no se conviertan en 2100, 115, 30 y 20.

Cubrir además: stock crítico, stock bajo, exceso, margen negativo, límites,
cooldown, histéresis, empresa sin estrategia y producción con persistencia.
Las columnas no expuestas por HTTP se validan ejecutando
`spCalcularDecision` directamente.

## 9. Troubleshooting

| Síntoma | Acción |
|---|---|
| No conecta a SQL | Revisar instancia, permisos y `ConnectionStrings__PricingDb`. |
| Procedimiento inexistente | Aplicar estructura SQL, función y procedimiento. |
| Sin estrategia activa | Crear o activar estrategia para la empresa. |
| `2100,00` fuera del intervalo | Reiniciar con la API actual y enviar decimales JSON con punto. |
| `numeric` a `decimal` | Verificar parámetros tipados e `ISNULL` en el SELECT final. |
| DLL bloqueada | Detener la API con `Ctrl+C` y volver a compilar. |

## 10. Próximos pasos

1. Pasar límites personalizados al procedimiento durante simulación.
2. Agregar `ProductoId` y definir contrato de producción por producto o lote.
3. Exponer el detalle completo de la decisión en la API.
4. Agregar autenticación, observabilidad y pruebas automatizadas API/SQL.
5. Implementar worker idempotente para `ColaEjecucionML`.
6. Completar snapshots históricos para backtesting.

## 11. Changelog

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | Jun 2026 | Motor SQL base. |
| 2.0 | Jul 2026 | Adaptadores y endpoint HTTP. |
| 2.1 | 15/08/2026 | Contextos TEMP/BASE y protección de nulos. |
| 2.2 | 15/08/2026 | Parseo JSON invariante y parámetros SQL tipados. |

Este archivo es la única fuente de verdad documental del Pricing Engine.