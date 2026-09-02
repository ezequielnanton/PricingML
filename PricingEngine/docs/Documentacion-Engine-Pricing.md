# Documentación del Pricing Engine

> **Estado del documento:** referencia histórica y de detalle del modelo SQL.
> La fuente principal para el dominio, la arquitectura y el estado actual es
> [`Documentacion-Engine-Pricing-v2.md`](Documentacion-Engine-Pricing-v2.md).
> Para el comportamiento operativo vigente de API, adaptadores y troubleshooting,
> consultar [`Documentacion-Motor-Actualizado.md`](Documentacion-Motor-Actualizado.md).
>
> Este documento se conserva porque contiene el inventario detallado de tablas,
> procedimientos y reglas. Ante una contradicción, prevalecen v2 y la
> documentación actualizada del motor.

## 1. Visión general

El proyecto PRICES es un motor de pricing inteligente para publicaciones de Mercado Libre, pensado para automatizar decisiones sobre precios en función de:

- rentabilidad
- stock disponible
- competencia directa
- historial de ventas
- reglas de negocio configurables
- auditoría explicable de decisiones

El sistema está diseñado para operar en dos modos:

- modo simulación: calcula una recomendación sin ejecutar cambios reales
- modo producción: guarda la decisión y la encola para ejecución

La lógica principal se ejecuta sobre SQL Server usando T-SQL, con un enfoque set-based para transformar contexto en decisiones.

---

## 2. Alcance funcional

El motor permite:

- evaluar publicaciones activas por empresa
- calcular margen neto de una publicación
- revisar precio actual frente a competencia
- detectar stock crítico o exceso de stock
- aplicar reglas de negocio con prioridad
- bloquear cambios si violan márgenes mínimos o límites de publicación
- evitar oscilaciones de precio con cooldown e histéresis
- registrar toda decisión en historial
- ejecutar backtesting para comparar estrategias

---

## 3. Arquitectura del sistema

### 3.1 Componentes principales

- Base de datos SQL Server: fuente de verdad
- Tablas transaccionales: productos, costos, stock, publicaciones, competencia
- Motor de decisiones: procedimiento principal `spCalcularDecision`
- Función auxiliar de margen: `fn_CalcularMargenNetoPorc`
- Auditoría: historial de decisiones y detalle de auditoría
- Cola de ejecución: `ColaEjecucionML`
- Backtesting: `spEjecutarBacktesting`

### 3.2 Flujo de procesamiento

1. Se cargan publicaciones, costos, stock y competencia.
2. Se calcula el margen actual de la publicación.
3. Se identifica la estrategia activa de la empresa.
4. Se evalúan reglas según prioridad.
5. Se validan límites de seguridad.
6. Se aplica anti-oscilación.
7. Se persiste la decisión.
8. Si es producción, se encola la ejecución.
9. Si es simulación, solo se devuelve el resultado y se registra auditoría.

---

## 4. Modelo de datos

### 4.1 Tabla: Empresas

Propósito:
- agrupa la configuración de cada empresa

Campos principales:
- `EmpresaID` - identificador
- `RazonSocial` - nombre legal
- `CUIT` - clave fiscal
- `Activo` - estado activo
- `FechaCreacion` - fecha de alta

Reglas:
- CUIT único

---

### 4.2 Tabla: Monedas

Propósito:
- catálogo de monedas

Campos principales:
- `MonedaID`
- `CodigoISO`
- `Nombre`
- `Simbolo`
- `Activa`

Reglas:
- `CodigoISO` único

---

### 4.3 Tabla: Cotizaciones

Propósito:
- guardar cotizaciones históricas por moneda

Campos principales:
- `CotizacionID`
- `MonedaID`
- `Cotizacion`
- `FechaCotizacion`

Reglas:
- `MonedaID` referencia a `Monedas`
- `Cotizacion > 0`
- único por moneda y fecha

Uso:
- preparación para escenarios de multi-moneda o conversión futura

---

### 4.4 Tabla: ParametrosGenerales

Propósito:
- definir configuración global por empresa

Campos principales:
- `ParametroGeneralID`
- `EmpresaID`
- `MonedaPrincipalID`
- `MonedaSecundariaID`

Reglas:
- `EmpresaID` único
- monedas distintas

---

### 4.5 Tabla: CuentasML

Propósito:
- representar cuentas de Mercado Libre asociadas a una empresa

Campos principales:
- `CuentaMLID`
- `EmpresaID`
- `UserIDML`
- `NicknameML`
- `AccessToken`
- `RefreshToken`
- `Activo`

Uso:
- conecta la empresa con una cuenta de anuncios publicitaria de Mercado Libre

---

### 4.6 Tabla: Productos

Propósito:
- mantener el catálogo base de productos por empresa

Campos principales:
- `ProductoID`
- `EmpresaID`
- `SKU`
- `Titulo`
- `CategoriaID`
- `Marca`
- `Modelo`
- `Activo`
- `FechaCreacion`

Reglas:
- `SKU` único por empresa

---

### 4.7 Tabla: CostosProducto

Propósito:
- guardar el costo base del producto

Campos principales:
- `CostoID`
- `ProductoID`
- `CostoCompra`
- `PorcentajeIVA`
- `ImpuestosInternos`
- `CostoEnvioPromedio`
- `CostoLogisticoFijo`
- `CostoFinancieroPorc`
- `CostoPublicidadPorc`
- `OtrosCostosFijos`
- `FechaUltimaActualizacion`

Reglas:
- un producto tiene un único costo activo

Uso:
- base para margen y evaluación de rentabilidad

---

### 4.8 Tabla: PublicacionesML

Propósito:
- representar la publicación real en Mercado Libre

Campos principales:
- `PublicacionID`
- `ProductoID`
- `CuentaMLID`
- `MeliItemID`
- `TipoPublicacion`
- `ComisionMLPorc`
- `Estado`
- `EsCatalogo`
- `PrecioActual`
- `PrecioMinimoPermitido`
- `PrecioMaximoPermitido`
- `PrecioObjetivo`
- `FechaUltimoCambioPrecio`

Reglas:
- `MeliItemID` único
- se procesan solo publicaciones con estado `active`

Uso:
- es la entidad central del motor de decisión

---

### 4.9 Tabla: StockEstado

Propósito:
- representar disponibilidad del inventario

Campos principales:
- `StockID`
- `ProductoID`
- `StockActual`
- `StockReservado`
- `StockDisponible` (calculado)
- `StockMinimo`
- `StockMaximo`
- `StockObjetivo`
- `FechaActualizacion`

Reglas:
- mỗi producto tiene una sola fila de stock

Uso:
- define si el producto está crítico, normal, alto o con exceso de stock

---

### 4.10 Tabla: MetricasVentasHist

Propósito:
- almacenar historial de ventas y velocidad de venta

Campos principales:
- `MetricaID`
- `PublicacionID`
- `VentasHoy`
- `Ventas7D`
- `Ventas15D`
- `Ventas30D`
- `Ventas60D`
- `Ventas90D`
- `VelocidadVentaDiaria`
- `TendenciaPorc`
- `FechaCalculo`

Uso:
- calculo de días de stock
- detecta si hay demanda alta o baja

---

### 4.11 Tabla: CompetenciaSnapshot

Propósito:
- guardar precios de otros competidores para una publicación

Campos principales:
- `SnapshotID`
- `PublicacionID`
- `CompetidorItemID`
- `CompetidorVendedorID`
- `PrecioCompetidor`
- `StockCompetidor`
- `TipoPublicacion`
- `OfreceEnvioGratis`
- `EsCompetidorDirecto`
- `NivelRelevancia`
- `FechaCaptura`

Uso:
- identifica precio mínimo y precio relevante
- ayuda a comparar la posición competitiva

---

### 4.12 Tabla: Estrategias

Propósito:
- definir estrategias por empresa

Campos principales:
- `EstrategiaID`
- `EmpresaID`
- `NombreEstrategia`
- `Descripcion`
- `Activa`

Uso:
- cada empresa puede tener una estrategia activa

---

### 4.13 Tabla: ReglasNegocio

Propósito:
- catalogar reglas de negocio del motor

Campos principales:
- `ReglaID`
- `CodigoRegla`
- `Nombre`
- `TipoRegla`
- `Descripcion`
- `Activa`

Reglas:
- `CodigoRegla` único

Ejemplos:
- `REGLA_STOCK_CRITICO`
- `REGLA_COMPETENCIA_ABAJO`
- `REGLA_EXCESO_STOCK`

---

### 4.14 Tabla: EstrategiaReglas

Propósito:
- vincular reglas a estrategias con prioridad

Campos principales:
- `EstrategiaReglaID`
- `EstrategiaID`
- `ReglaID`
- `Prioridad`
- `ParametrosJSON`
- `Activa`

Reglas:
- una regla no puede repetirse dentro de la misma estrategia

Uso:
- define el orden de evaluación del motor

---

### 4.15 Tabla: ConfiguracionParametros

Propósito:
- almacenar parámetros configurables por empresa

Campos principales:
- `ParametroID`
- `EmpresaID`
- `ClaveParametro`
- `ValorParametro`
- `Descripcion`

Ejemplo:
- `MARGEN_MINIMO_PERMITIDO = 15.00`

---

### 4.16 Tabla: DecisionesHistorial

Propósito:
- guardar cada decisión realizada por el motor

Campos principales:
- `DecisionID`
- `EmpresaID`
- `PublicacionID`
- `EstrategiaID`
- `PrecioAnterior`
- `PrecioCalculado`
- `PrecioSugerido`
- `Accion`
- `Motivo`
- `ReglaGanadoraID`
- `PrioridadAplicada`
- `MargenActualPorc`
- `MargenProyectadoPorc`
- `PosicionCompetitiva`
- `PrecioCompetenciaRef`
- `StockDisponible`
- `ClasificacionStock`
- `ScoreConfianza`
- `EsSimulacion`
- `FechaDecision`

Uso:
- permite explicabilidad y auditoría

---

### 4.17 Tabla: DecisionesDetalleAuditoria

Propósito:
- detalle de la evaluación por regla

Campos principales:
- `AuditoriaID`
- `DecisionID`
- `ReglaID`
- `Prioridad`
- `EvaluacionResultado`
- `ValorPrecioPropuesto`
- `DetalleJSON`

Uso:
- explica qué reglas se evaluaron y cuál ganó o fue bloqueada

---

### 4.18 Tabla: ColaEjecucionML

Propósito:
- encolar tareas de ejecución en Mercado Libre

Campos principales:
- `ColaID`
- `PublicacionID`
- `MeliItemID`
- `PrecioNuevo`
- `AccionRequerida`
- `EstadoEjecucion`
- `MensajeError`
- `FechaCreacion`
- `FechaProcesado`

Uso:
- separa lógica de decisión de ejecución real

---

### 4.19 Índices

Índices principales:
- `IX_PublicacionesML_Producto_Cuenta`
- `IX_CompetenciaSnapshot_Publicacion_Fecha`
- `IX_DecisionesHistorial_Publicacion_Fecha`
- `IX_ColaEjecucionML_Estado`

Objetivo:
- mejorar reads por publicación, competencia y auditoría

---

## 5. Funciones y procedimientos del motor

### 5.1 `fn_CalcularMargenNetoPorc`

Propósito:
- calcular el margen neto porcentual de una publicación

Cómo se usa:
- se integra en `spCalcularDecision` para obtener margen actual y proyectado

Validaciones:
- si `@PrecioFinal` es nulo o cero devuelve 0

Resultado:
- devuelve porcentaje del margen neto

---

### 5.2 `spCalcularDecision`

Propósito:
- decidir si se debe cambiar el precio de una o más publicaciones

Parámetros:
- `@EmpresaID`
- `@ProductoID = NULL`
- `@EstrategiaID = NULL`
- `@ModoSimulacion = 1`
- `@CooldownHoras = 12`
- `@VariacionMinimaPorc = 1.50`

Cómo se usa:
- se ejecuta para una empresa y, opcionalmente, un producto
- si `@ModoSimulacion = 1` no se ejecutan cambios reales
- si `@ModoSimulacion = 0` se encola la operación

Salida:
- devuelve columnas como:
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
  - `ScoreConfianza`

---

### 5.3 `spEjecutarBacktesting`

Propósito:
- simular decisiones históricas de precio para una estrategia en un rango de fechas

Parámetros:
- `@EmpresaID`
- `@EstrategiaID = NULL`
- `@FechaInicio`
- `@FechaFin`

Cómo se usa:
- recorre días entre fechas
- invoca la decisión del motor por cada día
- acumula métricas por fecha
- guarda resultados en `BacktestingResultados`

Resultado esperado:
- facturación proyectada por fecha
- ganancia neta proyectada por fecha
- número de cambios de precio

---

## 6. Reglas de negocio

### 6.1 Regla de stock crítico

Condición:
- `StockDisponible <= StockMinimo`

Acción:
- se incrementa el precio un 5%

Motivo:
- proteger contra quiebre o pérdida de disponibilidad

---

### 6.2 Regla de competencia más barata

Condición:
- un competidor relevante o mínimo tiene un precio menor al precio actual

Acción:
- ajustar precio hacia precio competidor

Motivo:
- mantener posición competitiva

---

### 6.3 Regla de exceso de stock

Condición:
- `StockDisponible >= StockMaximo`

Acción:
- disminuir el precio un 7%

Motivo:
- mover inventario más rápido

---

### 6.4 Regla de margen mínimo

Condición:
- margen proyectado es menor que el margen mínimo permitido

Acción:
- bloquear cambio

Motivo:
- evitar destruir rentabilidad

---

### 6.5 Regla de cooldown / histéresis

Condición:
- el precio fue cambiado recientemente o el cambio es muy pequeño

Acción:
- mantener el precio actual

Motivo:
- prevenir oscilaciones agresivas

---

## 7. Validaciones implementadas

### 7.1 Validación de estrategia
- si la empresa no tiene estrategia activa, el sistema falla con error explícito

### 7.2 Validación de parámetros
- `EmpresaID` requerido y positivo
- `FechaInicio` y `FechaFin` requeridos
- `FechaInicio` no puede ser mayor que `FechaFin`

### 7.3 Validación de margen mínimo
- el sistema nunca acepta una baja sugerida que deje por debajo del margen mínimo global

### 7.4 Validación de límites de publicación
- si la sugerencia cae debajo de `PrecioMinimoPermitido`, se corrige al mínimo
- si la sugerencia supera `PrecioMaximoPermitido`, se corrige al máximo

### 7.5 Validación anti-oscilación
- si la diferencia porcentual es menor al umbral configurado, no se cambia el precio
- si el tiempo desde último cambio es menor a `CooldownHoras`, no se cambia el precio

---

## 8. Cómo se interpreta la salida del motor

La salida de `spCalcularDecision` devuelve una fila por publicación con:

- `PrecioActual`: precio vigente
- `PrecioSugerido`: valor recomendado
- `Accion`: MANTENER_PRECIO, AUMENTAR_PRECIO, DISMINUIR_PRECIO, NO_MODIFICAR
- `Motivo`: explicación de la decisión
- `MargenActualPorc`: margen actual
- `MargenProyectadoPorc`: margen si se aplica la sugerencia
- `ClasificacionStock`: crítico, bajo, normal, alto, exceso
- `CompMinPrecio`: precio mínimo competitivo
- `ScoreConfianza`: nivel de confianza del cálculo

Ejemplo de acción:
- `AUMENTAR_PRECIO` por stock crítico
- `DISMINUIR_PRECIO` por competencia más barata
- `NO_MODIFICAR` por margen mínimo bloqueado
- `MANTENER_PRECIO` por cooldown / histeresis

---

## 9. Casos de uso

### Caso de uso 1: ajustar precio ante stock crítico
Se ejecuta cuando el stock disponible es menor o igual al mínimo.

Resultado esperado:
- aumento del precio para desacelerar ventas
- preservar disponibilidad

### Caso de uso 2: competir contra un precio más bajo
Se ejecuta cuando hay competidores directos o relevantes por debajo.

Resultado esperado:
- disminución del precio hasta un nivel competitivo

### Caso de uso 3: liquidar inventario con exceso de stock
Se ejecuta cuando el stock supera el máximo.

Resultado esperado:
- descuento promocional para mover stock

### Caso de uso 4: evitar pérdida de margen
Se ejecuta si una decisión de precio destruye rentabilidad.

Resultado esperado:
- bloqueo del cambio

### Caso de uso 5: evitar cambios constantes y agresivos
Se ejecuta cuando el precio fue modificado recientemente o la propuesta es muy pequeña.

Resultado esperado:
- mantener precio actual

### Caso de uso 6: prueba de estrategia sin afectar producción
Se ejecuta en simulación.

Resultado esperado:
- visualizar impacto sin enviar cambios a Mercado Libre

### Caso de uso 7: comparación de estrategias con backtesting
Se ejecuta por ventana temporal.

Resultado esperado:
- métricas comparativas por fecha

---

## 10. Casos de prueba

### Caso de prueba 1: producto con margen insuficiente
- precio actual: 100000
- costo compra: 90000
- margen proyectado: bajo 15%
- esperado: `NO_MODIFICAR`

### Caso de prueba 2: producto con stock crítico
- stock disponible = 2
- stock mínimo = 5
- esperado: `AUMENTAR_PRECIO`

### Caso de prueba 3: producto con competencia más barata
- precio actual: 60000
- competidor relevante: 58000
- esperado: `DISMINUIR_PRECIO`

### Caso de prueba 4: producto con exceso de stock
- stock disponible = 120
- stock máximo = 80
- esperado: `DISMINUIR_PRECIO`

### Caso de prueba 5: cooldown activo
- fecha último cambio reciente
- diferencia sugerida pequeña
- esperado: `MANTENER_PRECIO`

### Caso de prueba 6: ajuste menor al umbral de histéresis
- sugerencia cambia 0.7%
- umbral = 1.5%
- esperado: `MANTENER_PRECIO`

### Caso de prueba 7: precio menor que mínimo permitido
- precio sugerido = 5000
- mínimo permitido = 8000
- esperado: ajuste a 8000

### Caso de prueba 8: precio mayor que máximo permitido
- sugerencia = 200000
- máximo permitido = 150000
- esperado: ajuste a 150000

### Caso de prueba 9: empresa sin estrategia activa
- esperado: error

### Caso de prueba 10: backtesting con rango inválido
- fecha inicio > fecha fin
- esperado: error

### Caso de prueba 11: producto sin data de competencia
- no hay snapshots recientes
- esperado: decisión basada en stock o margen, sin error

### Caso de prueba 12: publicación cerrada o inactiva
- `Estado <> 'active'`
- esperado: no participa en la decisión

---

## 11. Observaciones de madurez del proyecto

### Estado actual
El proyecto se encuentra en un nivel de MVP/validación técnica. Tiene una base sólida para:

- definir una estrategia
- validar decisiones por reglas
- auditar decisiones
- simular cambios
- evaluar resultados por backtesting

### Faltantes para producción real
- snapshots históricos de mayor calidad
- integración de conversión monetaria real
- ejecución de validaciones de negocio en entorno real con datos vivos
- más cobertura de prueba automatizada
- monitoreo y alertas sobre cola de ejecución

---

## 12. Conclusión

El engine está diseñado para tomar decisiones de pricing con lógica transparente, protección de margen y control de stock/competencia. Tiene una estructura robusta para un MVP funcional, pero aún requiere validación real y refinamiento para llegar a producción completa.

El gran valor del sistema está en la combinación de:

- reglas negociables por prioridad
- auditoría explicable
- manejo de stock y competencia
- soporte a simulación y backtesting
- separación entre decisión y ejecución

---

## 13. Archivos clave del proyecto

- [SQL/Estructura.sql](../SQL/Estructura.sql)
- [SQL/fn_CalcularMargenNetoPorc.sql](../SQL/fn_CalcularMargenNetoPorc.sql)
- [SQL/spCalcularDecision.sql](../SQL/spCalcularDecision.sql)
- [SQL/Simulacion.sql](../SQL/Simulacion.sql)
- [SQL/BackTesting.sql](../SQL/BackTesting.sql)
- [Requerimiento/RequerimientoEngine.txt](../Requerimiento/RequerimientoEngine.txt)
