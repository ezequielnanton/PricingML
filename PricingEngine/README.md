# PRICES Engine - Motor de Decisiones de Precios

**Estado**: MVP Funcional | **Framework**: .NET 10.0 ASP.NET Core | **DB**: SQL Server 2022+

## 1. Resumen ejecutivo

**PRICES** es un motor de pricing inteligente y multiusuario para automatizar decisiones de precio sobre la base de stock, margen, competencia y demanda histórica.

El objetivo principal es encontrar un equilibrio entre:
- **Rentabilidad**: maximizar margen neto manteniendo competitividad
- **Competitividad**: reaccionar a precios de mercado
- **Disponibilidad**: proteger stock crítico
- **Explicabilidad**: auditoría completa de cada decisión

El sistema implementa **dos flujos de operación**:
- **Simulación**: Evaluación síncrona de recomendaciones sin modificar datos
- **Producción**: Persistencia transaccional y encolamiento para ejecución

---

## 2. Alcance funcional (MVP actual)

### ✅ Implementado
- **Ingestión UI**: Formulario para evaluación de productos
- **Persistencia Transaccional**: Upsert seguro en Productos, Costos, Stock
- **Evaluación de Precios**: Invocación del motor spCalcularDecision
- **Multi-tenant**: Aislamiento por Empresa
- **Auditoría**: Historial completo de decisiones y detalle por regla
- **Reportes Seguros**: Acceso a datos con validación de inyección SQL
- **Admin CRUD**: Gestión de empresas, monedas, cotizaciones, cuentas ML
- **Adaptadores**: Patrón de normalización a modelo canónico (ProductoInput)

### ⚠️ Parcialmente implementado
- **Backtesting**: Estructura lista, requiere snapshots históricos completos
- **Conversión de Moneda**: Tablas definidas, no integrada en motor de reglas
- **Validación Integral**: Mínima en adapter, exhaustiva recomendada

### ❌ No implementado (Futuro)
- **Adaptador ML**: Integración con API de Mercado Libre
- **Adaptadores ERP**: Conectores para sistemas externos
- **Endpoints de Reportes**: GET /api/reports/* no activos
- **Auto-creación de Publicaciones**: Desde UI requiere adaptador ML
- **Structured Logging**: Integración completa de ILogger
- **ML Execution Integration**: Auto-envío de cambios a Mercado Libre

---

## 3. Objetivos de negocio

1. Maximizar margen neto sin sacrificar competitividad
2. Evitar quiebre de stock por subprecio
3. Liquidar exceso de inventario sin destruir rentabilidad
4. Soportar decisiones auditables y explicables
5. Evolucionar reglas y estrategias por empresa

---

## 4. Arquitectura general

### 4.1 Proyectos y componentes

| Proyecto | Rol | Tecnología |
|----------|-----|-----------|
| **PricingApi** | API REST + Lógica de negocio | ASP.NET Core 10.0 |
| **PricingAdapter** | Normalización de datos | .NET Class Library |
| **PricingApi.Tests** | Pruebas unitarias | XUnit 2.9.3 |
| **SqlProbe** | Validación de conexión DB | Console App |

### 4.2 Servicios principales (PricingApi/Services/)

#### 1. **SqlPricingService** (Singleton)
- **Responsabilidad**: Motor de decisiones
- **Método clave**: `EvaluateAsync(ProductoInput, modoSimulacion, persistir)`
- **Invoca**: `dbo.spCalcularDecision` stored procedure
- **Retorna**: `PricingDecisionResult` (precio sugerido, acción, margen %, confianza)

#### 2. **InputPersistenceService** (Transient)
- **Responsabilidad**: Ingestión y normalización de datos
- **Método clave**: `PersistProductoInputAsync(ProductoInput)`
- **Transaccionalidad**: Upsert en Productos, CostosProducto, StockEstado
- **Validaciones**: Empresa existe, datos coherentes, rollback on error

#### 3. **AdminCrudService** (Singleton)
- **Responsabilidad**: Gestión de datos maestros
- **Entidades**: Empresas, Monedas, Cotizaciones, ParametrosGenerales, CuentasML
- **Operaciones**: GetAsync, CreateAsync, UpdateAsync, DeleteAsync
- **Nota**: Usa SQL directo (no ORM) para rendimiento

#### 4. **AdminReportsService** (Singleton)
- **Responsabilidad**: Reportes seguros sin inyección SQL
- **Características**:
  - Whitelist de tablas/columnas accesibles
  - Filtros con validación de tipos
  - Paginación (default 50, máximo 100)
  - Sorting multi-columna
  - Conversión camelCase para frontend
- **Ejemplo**: Consulta `DecisionesHistorial` con filtros y ordenamiento

### 4.3 Flujo de datos

```
[UI Form] 
    |
    v
[UiAdapter: ProductoInput]
    |
    v
[Validation & Transformation]
    |
    +---> [Simulation Mode] --> [Decision Result]
    |
    +---> [Production Mode]
          |
          v
       [InputPersistenceService]
       (Upsert: Productos, Costos, Stock)
          |
          v
       [SqlPricingService]
       (spCalcularDecision)
          |
          v
       [DecisionesHistorial] + [ColaEjecucionML]
```

### 4.4 Diagrama conceptual

```text
[Origen de Datos: UI/ERP/ML]
          |
          v
[Adaptador: Normalización a ProductoInput]
          |
          v
[InputPersistenceService: Upsert transaccional]
          |
          v
[Productos / CostosProducto / StockEstado]
          |
          v
[SqlPricingService: spCalcularDecision]
          |
          +----> [DecisionesHistorial: Auditoría]
          |----> [DecisionesDetalleAuditoria: Detalle por regla]
          |----> [ColaEjecucionML: Ejecución pendiente]
```

---

## 5. Entidades principales

### 5.1 Empresas
Representa a cada organización que usa el engine.

### 5.2 Cuentas ML
Conexión de la empresa con una cuenta de Mercado Libre.

### 5.3 Productos
Catálogo de productos por empresa.

### 5.4 CostosProducto
Costo de compra, gastos, logística y comisiones asociadas.

### 5.5 PublicacionesML
Publicación real de un producto en Mercado Libre.

### 5.6 StockEstado
Stock actual, mínimo, máximo y nivel de disponibilidad.

### 5.7 MetricasVentasHist
Ventas y velocidad de venta histórica.

### 5.8 CompetenciaSnapshot
Precios de competidores para la publicación.

### 5.9 Estrategias
Configuración de política comercial.

### 5.10 ReglasNegocio
Reglas que pueden ser activas o no, según estrategia.

### 5.11 DecisionesHistorial
Historial completo de decisiones tomadas.

### 5.12 ColaEjecucionML
Cola de ejecución para producción.

---

## 6. Documentación técnica de archivos

### 6.1 [SQL/Estructura.sql](SQL/Estructura.sql)
Archivo principal del esquema SQL.

Incluye:
- tablas de empresa, productos, costos, stock, publicaciones, competencia, estrategias, auditoría
- claves primarias y foráneas
- restricciones de negocio
- índices principales

#### Importancia
Es la base del sistema y define el modelo relacional del motor.

---

### 6.2 [SQL/fn_CalcularMargenNetoPorc.sql](SQL/fn_CalcularMargenNetoPorc.sql)
Función auxiliar para cálculo de margen neto.

#### Propósito
Calcular el margen neto porcentual de una publicación.

#### Parámetros
- `@PrecioFinal`
- `@CostoCompra`
- `@ComisionMLPorc`
- `@PorcentajeIVA`
- `@CostoEnvio`
- `@CostoLogistico`
- `@CostoFinancieroPorc`
- `@CostoPublicidadPorc`

#### Validación
Si el precio final es nulo o cero, devuelve `0.00`.

#### Fórmula conceptual
- precio sin IVA = precio final / (1 + IVA/100)
- costo total = costo compra + comisión + envío + logística + financiera + publicidad
- ganancia neta = precio sin IVA - costo total
- margen neto % = (ganancia neta / precio final) * 100

---

### 6.3 [SQL/spCalcularDecision.sql](SQL/spCalcularDecision.sql)
Procedimiento central del motor.

#### Propósito
Tomar decisiones sobre precio para publicaciones de una empresa.

#### Parámetros
- `@EmpresaID`
- `@ProductoID = NULL`
- `@EstrategiaID = NULL`
- `@ModoSimulacion = 1`
- `@CooldownHoras = 12`
- `@VariacionMinimaPorc = 1.50`

#### Qué hace
- selecciona estrategia activa
- carga margen mínimo global
- calcula contexto de la publicación
- analiza stock, costos, competencia, ventas
- aplica reglas por prioridad
- valida bloqueos de seguridad
- aplica anti-oscilación
- persiste la decisión
- en producción, encola ejecución

#### Salida
Devuelve una fila por publicación con:
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

### 6.4 [SQL/Simulacion.sql](SQL/Simulacion.sql)
Script de carga de datos de prueba.

#### Propósito
Simular escenarios reales para validar el motor.

#### Qué incluye
- empresa de ejemplo
- cuentas de Mercado Libre
- estrategia de prueba
- reglas asociadas
- productos de prueba
- costos
- stock
- publicaciones
- competencia

#### Escenarios cubiertos
- stock crítico
- competencia por debajo
- exceso de stock
- margen mínimo
- stock normal

---

### 6.5 [SQL/BackTesting.sql](SQL/BackTesting.sql)
Procedimiento de evaluación histórica / simulada.

#### Propósito
Simular el rendimiento de una estrategia durante un rango de fechas.

#### Parámetros
- `@EmpresaID`
- `@EstrategiaID`
- `@FechaInicio`
- `@FechaFin`

#### Qué hace
- genera todos los días del rango
- ejecuta el motor por día en modo simulación
- acumula resultados de ganancia, facturación y cambios
- guarda todo en `BacktestingResultados`

#### Salida
Resultado ordenado por fecha con:
- `ExecutionID`
- `EstrategiaID`
- `FechaSimulada`
- `FacturacionProyectada`
- `GananciaNetaProyectada`
- `CantidadCambiosPrecio`

---

## 7. Reglas del motor

### 7.1 Regla: stock crítico
Condición:
- el stock disponible es menor o igual al mínimo

Acción:
- aumentar precio un 5%

Objetivo:
- proteger contra quiebre de stock

### 7.2 Regla: competencia más barata
Condición:
- existe un competidor relevante más barato que el precio actual

Acción:
- disminuir precio para recuperar competitividad

Objetivo:
- mejorar posición del mercado

### 7.3 Regla: exceso de stock
Condición:
- stock disponible supera el máximo

Acción:
- disminuir precio un 7%

Objetivo:
- liquidar inventario

### 7.4 Regla: margen mínimo permitido
Condición:
- el precio propuesto deja el margen por debajo del mínimo configurable

Acción:
- bloquear el cambio

Objetivo:
- evitar decisiones no rentables

### 7.5 Regla: cooldown e histéresis
Condición:
- el precio fue modificado recientemente
- o el cambio es muy pequeño

Acción:
- mantener el precio actual

Objetivo:
- evitar oscilaciones agresivas

---

## 8. Validaciones implícitas en el motor

### 8.1 Validación de estrategia
- la empresa debe tener una estrategia activa
- si no existe, el sistema falla con error claro

### 8.2 Validación de fechas de backtesting
- `FechaInicio` y `FechaFin` son obligatorios
- `FechaInicio` no puede ser mayor a `FechaFin`

### 8.3 Validación de margen mínimo
- la disminución de precio no puede romper el margen mínimo permitido

### 8.4 Validación de límites de publicación
- el precio sugerido no puede estar por debajo del mínimo permitido
- no puede exceder el máximo permitido

### 8.5 Validación anti-oscilación
- no se acepta variación muy pequeña
- no se acepta cambio antes de finalizar el periodo de cooldown

---

## 9. Casos de uso

### Caso de uso 1: precio ante stock crítico
- un producto está bajo el mínimo de stock
- el motor recomienda aumentar el precio para frenar ventas y preservar inventario

### Caso de uso 2: competencia por debajo
- un competidor relevante ofrece un precio más bajo
- el motor recomienda rebajar el precio para competir

### Caso de uso 3: exceso de stock
- el producto excede el nivel máximo de stock
- el motor recomienda descuento para liquidarlo

### Caso de uso 4: intención de vender sin destruir rentabilidad
- una baja propuesta empeoraría el margen
- el sistema bloquea la recomendación

### Caso de uso 5: evaluación de estrategia sin afectar producción
- se ejecuta en modo simulación
- el negocio puede revisar la recomendación antes de aplicar cambios

### Caso de uso 6: backtesting por estrategia
- se compara el comportamiento de una política durante fechas históricas o simuladas

---

## 10. Casos de prueba recomendados

### 10.1 Producto con margen insuficiente
Esperado:
- `NO_MODIFICAR`
- el margen proyectado queda por debajo del mínimo

### 10.2 Producto con stock crítico
Esperado:
- `AUMENTAR_PRECIO`

### 10.3 Producto con competencia más barata
Esperado:
- `DISMINUIR_PRECIO`

### 10.4 Producto con exceso de stock
Esperado:
- `DISMINUIR_PRECIO`

### 10.5 Producto con cooldown activo
Esperado:
- `MANTENER_PRECIO`

### 10.6 Producto con variación pequeña
Esperado:
- `MANTENER_PRECIO`

### 10.7 Precio fuera de rango permitido
Esperado:
- ajuste al mínimo o máximo permitido

### 10.8 Empresa sin estrategia activa
Esperado:
- error explícito

### 10.9 Backtesting con rango inválido
Esperado:
- error por fecha inválida

---

## 11. Riesgos y puntos de mejora

### Riesgos funcionales
- la calidad de los datos de competencia condiciona la decisión
- el motor depende de una estrategia activa bien definida
- una mala configuración de margen puede desalinear la política de precios

### Riesgos de operación
- si la cola de ejecución tiene fallas, no hay sincronización con Mercado Libre
- la falta de snapshots históricos reales limita la confiabilidad del backtesting

### Mejoras recomendadas
- crear snapshots históricos por día
- parametrizar más reglas por empresa
- automatizar tests de validación
- mejorar la auditoría de detalle por regla
- integrar conversión de moneda explícita

---

## 12. Estado actual del proyecto

El proyecto está en un nivel de:

- MVP funcional
- arquitectura base sólida
- validación manual posible
- aún no producción industrial

Se puede considerar listo para pruebas internas, pero no aún para operación crítica en producción sin más validación.

---

## 13. Cómo ejecutar el motor

### 13.1 Crear o actualizar Base de Datos
Ejecutar el DDL de [SQL/Estructura.sql](SQL/Estructura.sql).

### 13.2 Crear función de margen
Ejecutar [SQL/fn_CalcularMargenNetoPorc.sql](SQL/fn_CalcularMargenNetoPorc.sql).

### 13.3 Crear procedimiento central
Ejecutar [SQL/spCalcularDecision.sql](SQL/spCalcularDecision.sql).

### 13.4 Cargar datos de prueba
Ejecutar [SQL/Simulacion.sql](SQL/Simulacion.sql).

### 13.5 Validar recomendaciones
Ejecutar el procedimiento con una empresa y estrategia válida en modo simulación.

### 13.6 Ejecutar backtesting
Ejecutar [SQL/BackTesting.sql](SQL/BackTesting.sql) con rango de fechas.

---

## 14. Conclusión

PRICES es un motor de pricing inteligente con un enfoque razonable para automatizar decisiones comerciales en un entorno de Marketplace. Su fortaleza principal radica en la combinación de:

- análisis de margen
- stock
- competencia
- estrategia configurada
- auditoría y explicabilidad

Su principal limitación es que aún requiere validación real y refinamiento para llegar a un nivel de operación productiva robusta.

---

## 15. Enlaces útiles

- [SQL/Estructura.sql](SQL/Estructura.sql)
- [SQL/fn_CalcularMargenNetoPorc.sql](SQL/fn_CalcularMargenNetoPorc.sql)
- [SQL/spCalcularDecision.sql](SQL/spCalcularDecision.sql)
- [SQL/Simulacion.sql](SQL/Simulacion.sql)
- [SQL/BackTesting.sql](SQL/BackTesting.sql)
- [Requerimiento/RequerimientoEngine.txt](Requerimiento/RequerimientoEngine.txt)
- [docs/Documentacion-Engine-Pricing-v2.md](docs/Documentacion-Engine-Pricing-v2.md)
- [docs/Documentacion-Engine-Pricing-v2.md](docs/Documentacion-Engine-Pricing-v2.md)

