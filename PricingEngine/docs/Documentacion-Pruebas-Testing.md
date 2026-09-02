# Documentación de Pruebas del Pricing Engine

## 1. Objetivo

Este documento define un conjunto de pruebas de software para validar el comportamiento del Pricing Engine en SQL Server. Su objetivo es verificar que:

- el motor toma decisiones correctas según stock, costo, competencia y margen
- se respetan las reglas de seguridad
- la estrategia activa se aplica como corresponde
- el procedimiento no rompe la integridad de la base ni genera decisiones incoherentes
- el backtesting produce resultados utilizables para comparar estrategia vs estrategia

---

## 2. Alcance

Se cubren pruebas del siguiente alcance:

- cálculo de margen neto
- evaluación central de `spCalcularDecision`
- validaciones de negocio
- reglas del motor
- casos límite
- integridad de historial y auditoría
- comportamiento en simulación y producción
- backtesting

---

## 3. Criterios de aceptación

Una prueba será considerada exitosa cuando:

- la acción devuelta coincide con el resultado esperado
- el motivo de la decisión es coherente con la regla aplicada
- el margen proyectado cumple la regla de seguridad
- la publicación no queda fuera de rango permitido
- el historial refleja la decisión ejecutada
- la cola de ejecución se actualiza solo en modo producción

---

## 4. Supuestos y entorno de prueba

### 4.1 Base de datos de prueba
Debe existir una instancia de SQL Server con la base `PRICES_DB` creada y cargada con:

- [SQL/Estructura.sql](../SQL/Estructura.sql)
- [SQL/fn_CalcularMargenNetoPorc.sql](../SQL/fn_CalcularMargenNetoPorc.sql)
- [SQL/spCalcularDecision.sql](../SQL/spCalcularDecision.sql)
- [SQL/Simulacion.sql](../SQL/Simulacion.sql)
- [SQL/BackTesting.sql](../SQL/BackTesting.sql)

### 4.2 Datos base esperados
La seed de prueba incluye casos representativos de:

- stock crítico
- competencia más barata
- exceso de stock
- margen mínimo
- producto normal

### 4.3 Convenciones
- `PrecioActual` siempre en moneda local de la empresa
- `MargenActualPorc` y `MargenProyectadoPorc` expresados como porcentaje
- `Accion` puede ser:
  - `MANTENER_PRECIO`
  - `AUMENTAR_PRECIO`
  - `DISMINUIR_PRECIO`
  - `NO_MODIFICAR`

---

## 5. Matriz de pruebas

| ID | Área | Objetivo | Resultado esperado |
|---|---|---|---|
| TC-01 | Margen | Cálculo básico de margen | valor correcto |
| TC-02 | Margen | Precio nulo o cero | retorna 0.00 |
| TC-03 | Reglas | Stock crítico | sube precio 5% |
| TC-04 | Reglas | Competencia más barata | baja precio |
| TC-05 | Reglas | Exceso de stock | baja precio agresiva |
| TC-06 | Seguridad | Margen mínimo bloqueado | no modifica |
| TC-07 | Seguridad | Precio fuera de rango | ajusta mínimo/máximo |
| TC-08 | Anti-oscilación | Cooldown activo | mantiene precio |
| TC-09 | Anti-oscilación | Variación pequeña | mantiene precio |
| TC-10 | Estrategia | Sin estrategia activa | error |
| TC-11 | Integridad | Guardado en historial | una decisión registrada |
| TC-12 | Producción | Modo producción | encola la acción |
| TC-13 | Backtesting | Fecha válida | devuelve métricas por día |
| TC-14 | Backtesting | Fecha inválida | error |
| TC-15 | Edge | Publicación inactiva | no participa |
| TC-16 | Edge | Producto sin competencia | no falla |

---

## 6. Pruebas detalladas

## TC-01: Cálculo básico de margen neto

### Objetivo
Validar que la función devuelve un valor correcto de margen neto.

### Datos de entrada
- `@PrecioFinal = 100000.00`
- `@CostoCompra = 60000.00`
- `@ComisionMLPorc = 12.00`
- `@PorcentajeIVA = 21.00`
- `@CostoEnvio = 1500.00`
- `@CostoLogistico = 2000.00`
- `@CostoFinancieroPorc = 1.50`
- `@CostoPublicidadPorc = 2.00`

### Cálculo esperado
- precio sin IVA = 100000 / 1.21 = 82644.6281
- comisión = 12000
- financiero = 1500
- publicidad = 2000
- costo total = 60000 + 12000 + 1500 + 2000 + 1500 + 2000 = 77000
- ganancia neta = 82644.63 - 77000 = 5644.63
- margen neto % = 5644.63 / 100000 * 100 = 5.64%

### Resultado esperado
- función devuelve `5.64`

### Criterio de aceptación
- el valor devuelto coincide con el cálculo esperado, redondeado según el tipo `DECIMAL(7,2)`

---

## TC-02: Precio nulo o cero

### Objetivo
Verificar que la función no falla y devuelve 0 cuando el precio es nulo o cero.

### Datos de entrada
- `@PrecioFinal = 0.00`
- otros parámetros válidos

### Resultado esperado
- `RETURN 0.00`

### Criterio de aceptación
- la función no lanza error
- el valor retornado es `0.00`

---

## TC-03: Stock crítico provoca aumento de precio

### Objetivo
Verificar que stock crítico dispara la regla `REGLA_STOCK_CRITICO`.

### Datos de entrada
- empresa activa
- producto con `StockDisponible <= StockMinimo`
- precio actual 60000
- competencia no mayormente relevante
- margen actual aceptable

### Resultado esperado
- `Accion = 'AUMENTAR_PRECIO'`
- `PrecioSugerido = PrecioActual * 1.05`
- `Motivo` contiene texto relacionado con stock crítico

### Criterio de aceptación
- la fila devuelta refleja aumento del 5%
- la regla ganadora coincide con `REGLA_STOCK_CRITICO`

---

## TC-04: Competencia más barata provoca reducción de precio

### Objetivo
Verificar que la regla de competencia más barata aplica correctamente.

### Datos de entrada
- publicación activa
- competidor relevante más barato que el precio actual
- stock normal
- margen actual por encima del mínimo

Ejemplo:
- `PrecioActual = 60000`
- `CompRelevantePrecio = 56000`

### Resultado esperado
- `Accion = 'DISMINUIR_PRECIO'`
- `PrecioSugerido` se aproxima a `56000 - 10` o la regla de ajuste aplicada
- motivo menciona la competencia

### Criterio de aceptación
- la decisión es bajar precio y no mantenerlo

---

## TC-05: Exceso de stock provoca liquidación

### Objetivo
Validar la reducción agresiva por exceso de stock.

### Datos de entrada
- `StockDisponible >= StockMaximo`
- precio actual estable
- demanda limitada

Ejemplo:
- `PrecioActual = 12000`
- `StockActual = 120`
- `StockMaximo = 80`

### Resultado esperado
- `Accion = 'DISMINUIR_PRECIO'`
- `PrecioSugerido = PrecioActual * 0.93`
- motivo menciona liquidación o exceso de stock

### Criterio de aceptación
- la acción es reducción del 7% aproximadamente

---

## TC-06: Margen mínimo bloquea la baja

### Objetivo
Verificar que el sistema rechaza una decisión que rompe el margen mínimo configurado.

### Datos de entrada
- `@MargenMinimoGlobal = 15.00`
- publicación con precio actual 100000
- costo de compra y gastos altos
- regla de competencia o exceso de stock quiere disminuir precio

### Resultado esperado
- `Accion = 'NO_MODIFICAR'`
- `Motivo` menciona bloqueo de seguridad
- el margen proyectado no es menor a 15%

### Criterio de aceptación
- la baja sugerida es anulada
- la decisión final preserva margen

---

## TC-07: Precio fuera de rango permitido

### Objetivo
Comprobar que el motor ajusta precio sugerido al mínimo o máximo permitido por publicación.

### Datos de entrada
- `PrecioSugerido` calculado fuera del rango
- `PrecioMinimoPermitido = 35000`
- `PrecioMaximoPermitido = 90000`

### Casos
#### Caso A: precio sugerido debajo del mínimo
- sugerencia = 30000
- esperado: `PrecioSugerido = 35000`

#### Caso B: precio sugerido encima del máximo
- sugerencia = 95000
- esperado: `PrecioSugerido = 90000`

### Resultado esperado
- el valor final quedará en el límite permitido

### Criterio de aceptación
- el precio final no sale del rango configurado

---

## TC-08: Cooldown activo impide cambio

### Objetivo
Validar el bloqueo por anti-oscilación.

### Datos de entrada
- `FechaUltimoCambioPrecio` muy reciente
- regla de stock o competencia intenta cambiar precio
- `@CooldownHoras = 12`

### Resultado esperado
- `Accion = 'MANTENER_PRECIO'`
- `Motivo` menciona cooldown o histéresis

### Criterio de aceptación
- no se modifica el precio si el tiempo desde el último cambio es menor al umbral

---

## TC-09: Variación menor al umbral de histéresis

### Objetivo
Verificar que el motor evita cambios muy pequeños.

### Datos de entrada
- `@VariacionMinimaPorc = 1.50`
- una regla produce un cambio menor al 1.5%

Ejemplo:
- `PrecioActual = 100000`
- nuevo precio sugerido = 100800
- cambio = 0.8%

### Resultado esperado
- `Accion = 'MANTENER_PRECIO'`
- no se acepta el cambio

### Criterio de aceptación
- el sistema bloquea la variación pequeña

---

## TC-10: Empresa sin estrategia activa

### Objetivo
Verificar el manejo de errores cuando la empresa no tiene estrategia habilitada.

### Datos de entrada
- `@EmpresaID` válido
- no hay `Estrategias` con `Activa = 1` para esa empresa

### Resultado esperado
- `RAISERROR('No existe una estrategia activa configurada para la empresa.', 16, 1);`

### Criterio de aceptación
- el procedimiento termina con error y no continúa

---

## TC-11: Registro en historial de decisiones

### Objetivo
Validar que cada decisión se registra correctamente en `DecisionesHistorial`.

### Datos de entrada
- ejecución de `spCalcularDecision` en modo simulación o producción

### Resultado esperado
- se inserta una fila para cada publicación evaluada
- `EmpresaID`, `PublicacionID`, `EstrategiaID`, `PrecioAnterior`, `PrecioSugerido`, `Accion` y `Motivo` completados

### Criterio de aceptación
- se puede revisar la decisión y su contexto en la tabla `DecisionesHistorial`

---

## TC-12: Modo producción encola ejecución

### Objetivo
Validar que la acción se encola si `@ModoSimulacion = 0`.

### Datos de entrada
- `@ModoSimulacion = 0`
- actualización de precio sugerido que implica cambio

### Resultado esperado
- se inserta fila en `ColaEjecucionML`
- `EstadoEjecucion = 'PENDIENTE'`
- `FechaUltimoCambioPrecio` se actualiza en `PublicacionesML`

### Criterio de aceptación
- en producción se genera una cola y no solo una recomendación visual

---

## TC-13: Backtesting con rango válido

### Objetivo
Verificar que `spEjecutarBacktesting` genera métricas por día.

### Datos de entrada
- `@EmpresaID = 1`
- `@EstrategiaID = 1`
- `@FechaInicio = '2026-06-01'`
- `@FechaFin = '2026-06-10'`

### Resultado esperado
- se generan filas de `BacktestingResultados` para cada día del rango
- valores de facturación proyectada y ganancia neta no son nulos
- `CantidadCambiosPrecio` tiene valor numérico

### Criterio de aceptación
- los resultados se ordenan por fecha y hay una fila por día evaluado

---

## TC-14: Backtesting con rango inválido

### Objetivo
Verificar la validación de fechas.

### Datos de entrada
- `@FechaInicio > @FechaFin`

### Resultado esperado
- error con mensaje apropiado

### Criterio de aceptación
- el procedimiento no ejecuta backtesting ni inserta resultados

---

## TC-15: Publicación inactiva no participa

### Objetivo
Validar que ciertas publicaciones no se evaluan.

### Datos de entrada
- `PublicacionesML.Estado = 'paused'` o `closed`

### Resultado esperado
- no aparece en la salida de `spCalcularDecision`
- no se calcula margen para esa publicación

### Criterio de aceptación
- solo publicaciones `active` participan

---

## TC-16: Producto sin competencia reciente

### Objetivo
Validar que el sistema no falla si no hay snapshot de competencia.

### Datos de entrada
- `CompetenciaSnapshot` vacío para la publicación

### Resultado esperado
- la lógica del motor sigue ejecutándose
- toma decisión basada en stock y costo si aplica

### Criterio de aceptación
- sin error por `NULL` en competencia
- salida consistente o `MANTENER_PRECIO`

---

## 7. Pruebas de regresión sugeridas

### Regresión 1: duración de margen mínimo
- verificar que el bloqueo de margen se mantiene aunque la competencia baje mucho

### Regresión 2: combinaciones de stock y competencia
- verificar prioridad correcta entre stock crítico y competencia más barata

### Regresión 3: cambios repetidos en producción
- verificar que una publicación no se encola múltiples veces sin control

### Regresión 4: historial consistente
- verificar que el historial no genere filas con precio sugerido fuera de rango

---

## 8. Evidencia y reporte de pruebas

Para cada prueba se debe registrar:

- ID de prueba
- datos de entrada
- acción ejecutada
- resultado real
- resultado esperado
- estado: PASS / FAIL
- observaciones
- responsable
- fecha

### Plantilla recomendada

```text
ID: TC-03
Nombre: Stock crítico provoca aumento de precio
Datos de entrada: ...
Acción ejecutada: EXEC spCalcularDecision ...
Resultado real: ...
Resultado esperado: ...
Estado: PASS/FAIL
Observaciones: ...
```

---

## 9. Riesgos de pruebas

### Riesgos de entorno
- datos no actualizados
- falta de estrategia activa
- inconsistencia en `CompetenciaSnapshot`
- falta de métricas de ventas

### Riesgos de negocio
- decisiones correctas desde un punto de vista técnico, pero no alineadas con estrategia comercial
- un pequeño cambio en margen puede cambiar masivamente la decisión

---

## 10. Conclusión

La validación del Pricing Engine debe centrarse en tres aspectos principales:

1. corrección técnica de la decisión
2. cumplimiento de reglas de seguridad y prioridad
3. trazabilidad y reproducibilidad de la decisión

El conjunto de pruebas propuesto cubre la mayor parte del comportamiento crítico del sistema y representa una base sólida para validación funcional antes de pasar a producción.

---

## 11. Archivos relevantes

- [SQL/Estructura.sql](../SQL/Estructura.sql)
- [SQL/fn_CalcularMargenNetoPorc.sql](../SQL/fn_CalcularMargenNetoPorc.sql)
- [SQL/spCalcularDecision.sql](../SQL/spCalcularDecision.sql)
- [SQL/Simulacion.sql](../SQL/Simulacion.sql)
- [SQL/BackTesting.sql](../SQL/BackTesting.sql)
- [README.md](../README.md)