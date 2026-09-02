# Arquitectura de Adaptadores - Pricing Engine

**Última actualización**: 2026-08-18  
**Versión del Motor**: 2.0  
**Framework**: .NET 10.0 ASP.NET Core

---

## 1. Objetivo y Principio Central

### Objetivo
El motor de pricing es **agnóstico del origen de datos**. El mismo core debe poder consumir información desde múltiples fuentes:

- UI (interfaz web)
- API de Mercado Libre
- ERPs internos o externos
- Sistemas legacy
- Feeds de datos

Sin modificar la lógica del motor (`spCalcularDecision`).

### Principio Central
**Todos los orígenes normalizan a un modelo canónico interno: `ProductoInput`**

```
[Origen específico] 
    ↓ (adaptador único)
[Modelo canónico: ProductoInput]
    ↓ (siempre igual)
[Motor: spCalcularDecision]
    ↓
[Decisión de precio]
```

---

## 2. Modelo Canónico: ProductoInput

La única representación interna que el motor recibe.

```csharp
namespace PricingAdapter.Models
{
    public class ProductoInput
    {
        public int EmpresaId { get; set; }
        public int? ProductoId { get; set; }  // Opcional (new product)
        public string SKU { get; set; }
        public string Titulo { get; set; }
        
        public decimal PrecioActual { get; set; }
        public decimal PrecioMinimoPermitido { get; set; }
        public decimal PrecioMaximoPermitido { get; set; }
        
        public int StockActual { get; set; }
        public int StockMinimo { get; set; }
        public int StockMaximo { get; set; }
        
        public decimal CostoCompra { get; set; }
        public decimal PorcentajeIVA { get; set; }
        public decimal PorcentajeComisionML { get; set; }
        public decimal CostoEnvioPromedio { get; set; }
        public decimal CostoLogisticoFijo { get; set; }
        public decimal PorcentajeFinanciero { get; set; }
        public decimal PorcentajePublicidad { get; set; }
        
        public DateTime FechaCaptura { get; set; }
        public string FuenteOrigen { get; set; }  // "UI", "ML", "ERP_A", etc.
        public string EstadoPublicacion { get; set; }
    }
}
```

---

## 3. Arquitectura de Adaptadores Implementada

```
┌─────────────────────────────────────────────────────────────┐
│                     ORIGEN DE DATOS                         │
│ (UI, ML, ERP, Sistema Legacy, Feeds, etc.)                  │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│              CAPA DE ADAPTADORES                            │
│                                                              │
│  ✅ UiAdapter              (IMPLEMENTADO)                   │
│  - Entrada: UiPricingRequest (JSON desde frontend)          │
│  - Transformaciones:                                        │
│    • SKU: trim() + uppercase()                             │
│    • Defaults: IVA=21%, ComisionML=9%                      │
│    • Validaciones: SKU no vacío, precio > 0, costo > 0     │
│  - Salida: ProductoInput                                    │
│                                                              │
│  ⏳ MeliAdapter             (FUTURO)                        │
│  - Entrada: Response de Mercado Libre API                  │
│  - Transformaciones: Normalizar a ProductoInput            │
│  - Requiere: CuentaMLID, AccessToken, MeliItemID          │
│                                                              │
│  ⏳ ErpAAdapter, ErpBAdapter (FUTURO)                       │
│  - Entrada: Schemas específicos de ERPs                     │
│  - Transformaciones: Mapeo a ProductoInput                 │
│  - Requiere: Conectores a BD de origen                      │
│                                                              │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼ [ProductoInput normalizado]
┌─────────────────────────────────────────────────────────────┐
│        INPUT PERSISTENCE SERVICE (Transient)                │
│                                                              │
│  - Responsabilidad: Ingestión y normalización              │
│  - Método: PersistProductoInputAsync(ProductoInput)        │
│  - Transacción: Upsert atómico en 3 tablas                 │
│                                                              │
│  Paso 1: Validar empresa existe                            │
│  Paso 2: Upsert Productos (clave: EmpresaID + SKU)        │
│  Paso 3: Upsert CostosProducto                             │
│  Paso 4: Upsert StockEstado                                │
│  → Rollback si alguno falla                                │
│                                                              │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼ [Datos persistidos en BD]
┌─────────────────────────────────────────────────────────────┐
│     SQL PRICING SERVICE (Singleton)                         │
│                                                              │
│  - Responsabilidad: Motor de decisiones                    │
│  - Método: EvaluateAsync(ProductoInput, modoSimulacion)    │
│  - Invoca: dbo.spCalcularDecision (stored procedure)       │
│  - Retorna: PricingDecisionResult                          │
│                                                              │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼ [Decisión de precio]
┌─────────────────────────────────────────────────────────────┐
│              AUDITORÍA Y PERSISTENCIA                       │
│                                                              │
│  DecisionesHistorial:          Registro de decisión        │
│  DecisionesDetalleAuditoria:   Detalle por regla           │
│  ColaEjecucionML:              Ejecución pendiente         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Adaptadores Implementados

### 4.1 UiAdapter (Activo)

**Ubicación**: `PricingAdapter/Adapters/UiAdapter.cs`

**Responsabilidad**: Transformar `UiPricingRequest` a `ProductoInput`

**Normalizaciones**:
```csharp
public static ProductoInput Map(UiPricingRequest request)
{
    // SKU: trim + uppercase
    var sku = request.Sku?.Trim().ToUpperInvariant();
    
    // Validaciones
    if (string.IsNullOrWhiteSpace(sku))
        throw new ValidationException("SKU cannot be empty");
    
    if (request.PrecioPropuesto <= 0)
        throw new ValidationException("Price must be > 0");
    
    if (request.CostoBase <= 0)
        throw new ValidationException("Cost must be > 0");
    
    // Defaults
    var iva = request.Iva > 0 ? request.Iva : 21.0m;
    var comision = request.ComisionMLPorc > 0 ? request.ComisionMLPorc : 9.0m;
    
    return new ProductoInput
    {
        EmpresaId = request.EmpresaId,
        SKU = sku,
        Titulo = request.Titulo,
        PrecioActual = request.PrecioPropuesto,
        // ... resto de campos ...
        FuenteOrigen = "UI",
        FechaCaptura = DateTime.UtcNow
    };
}
```

**Validaciones internas**:
- SKU no puede ser vacío
- PrecioPropuesto debe ser > 0
- CostoBase debe ser > 0
- Empresa debe existir (si persistir = true)

---

### 4.2 Adaptadores Futuros (Planeados)

#### MeliAdapter (Mercado Libre)
```csharp
public static ProductoInput Map(MeliListingDto meliData, CuentaMLDto cuenta)
{
    // Lógica de transformación desde Mercado Libre API
    return new ProductoInput
    {
        EmpresaId = cuenta.EmpresaId,
        ProductoId = meliData.ProductoId,
        SKU = meliData.SKU,
        PrecioActual = meliData.Price,
        StockActual = meliData.AvailableQuantity,
        FuenteOrigen = "MERCADO_LIBRE"
    };
}
```

#### ErpAAdapter
```csharp
public static ProductoInput Map(ErpProductDto erpData, int empresaId)
{
    // Lógica de transformación desde ERP A
    return new ProductoInput { /* ... */ };
}
```

---

## 5. Flujo de Datos Completo

### Escenario 1: Ingestión desde UI

```
┌─────────────────────────────────────────────┐
│ Frontend: Form Pricing                       │
│ POST /api/input/ui/product                  │
└────────────┬────────────────────────────────┘
             │
             ├─► UiAdapter.Map()
             │   (UiPricingRequest → ProductoInput)
             │
             ├─► InputPersistenceService
             │   .PersistProductoInputAsync()
             │   (Upsert transaccional)
             │
             ├─► SqlPricingService
             │   .EvaluateAsync()
             │   (Invoca spCalcularDecision)
             │
             └─► Response 201 Created
                 {
                   "productoId": 123,
                   "decision": { ... }
                 }
```

### Escenario 2: Integración con Mercado Libre (Futuro)

```
┌──────────────────────────────────────────────┐
│ ML API: WebHook o Pull                       │
│ POST /webhooks/ml/publication-updated        │
└────────────┬─────────────────────────────────┘
             │
             ├─► MeliAdapter.Map()
             │   (MeliListingDto → ProductoInput)
             │
             ├─► InputPersistenceService
             │   .PersistProductoInputAsync()
             │
             ├─► SqlPricingService
             │   .EvaluateAsync()
             │
             └─► ColaEjecucionML
                 (Enqueue cambios)
```

### Escenario 3: Integración con ERP

```
┌─────────────────────────────────────────────┐
│ ERP Feed: Batch o Real-time                 │
│ POST /api/input/erp/products                │
└────────────┬─────────────────────────────────┘
             │
             ├─► ErpAAdapter.Map()
             │   (ErpProductDto → ProductoInput)
             │
             ├─► InputPersistenceService
             │   .PersistProductoInputAsync()
             │
             ├─► SqlPricingService
             │   .EvaluateAsync()
             │
             └─► Response 201 Created
```

---

## 6. Garantías de la Arquitectura

### Agnósticismo del Motor
- El motor **nunca ve** formatos específicos de origen
- Recibe siempre `ProductoInput` normalizado
- Cambiar origen **no requiere** cambiar lógica de pricing

### Validación en Capas
| Capa | Validaciones |
|------|--------------|
| Adapter | Formato específico del origen, campos obligatorios |
| Persistence | Integridad de datos, claves foráneas |
| Motor | Lógica de negocio, reglas de pricing |

### Transaccionalidad Garantizada
- Todo el upsert: **todo o nada**
- Error en alguna tabla: **rollback automático**
- Sin datos parcialmente persistidos

### Trazabilidad
- Cada registro contiene `FuenteOrigen`
- Auditoría completa en `DecisionesHistorial`
- Reprocesable: reingesta no crea duplicados

---

## 7. Extensión: Agregar Nuevo Adaptador

### Pasos para agregar MeliAdapter:

**Paso 1**: Crear clase adaptador
```csharp
// PricingAdapter/Adapters/MeliAdapter.cs
public class MeliAdapter : IInputAdapter
{
    public ProductoInput Map(MeliListingDto meliData, CuentaMLDto cuenta)
    {
        return new ProductoInput { /* ... */ };
    }
}
```

**Paso 2**: Implementar interfaz (si existe)
```csharp
public interface IInputAdapter
{
    ProductoInput Map(object sourceData);
}
```

**Paso 3**: Registrar en DI
```csharp
// Program.cs
services.AddTransient<IInputAdapter, MeliAdapter>();
```

**Paso 4**: Crear endpoint
```csharp
// PricingApi/Controllers/InputController.cs
[HttpPost("api/input/ml/publication")]
public async Task<IActionResult> IngestionFromML([FromBody] MeliListingDto request)
{
    var productInput = MeliAdapter.Map(request, ...);
    var result = await _persistenceService.PersistProductoInputAsync(productInput);
    return CreatedAtAction(nameof(IngestionFromML), result);
}
```

**✅ Ventajas**:
- Cambio localizado (solo nuevo adapter)
- Motor intacto
- Reutilizables: InputPersistenceService, SqlPricingService

---

## 8. Desafíos y Mitigaciones

| Desafío | Mitigación |
|---------|-----------|
| Validaciones incompletas en adapter | Agregar validaciones exhaustivas + tests unitarios |
| Conflictos en SKU de orígenes distintos | Prefijo de origen: "ML_", "ERP_", etc. |
| Datos inconsistentes en tiempo real | Snapshots históricos, reconciliación offline |
| Performance de upsert en tablas grandes | Índices en (EmpresaID, SKU), batch inserts |
| Tokens expirados (ML, ERP) | Refresh logic en adapter, manejo de errores |

---

## 9. Modelo Relacional

```
┌──────────────────────────────────────────────────────────┐
│                    EMPRESAS                              │
│  PK: EmpresaID                                           │
│  UK: CUIT                                                │
└──────────────────────────────────────────────────────────┘
                         │
                         │ 1:N
                         ▼
┌──────────────────────────────────────────────────────────┐
│                  PRODUCTOS                               │
│  PK: ProductoID                                          │
│  FK: EmpresaID                                           │
│  UK: (EmpresaID, SKU)   ← Clave para upsert             │
└──────────────────────────────────────────────────────────┘
          │                    │
          │ 1:1                │ 1:1
          ▼                    ▼
    ┌──────────────┐    ┌──────────────┐
    │ COSTOS       │    │ STOCK        │
    │              │    │              │
    │ FK: Prod.ID  │    │ FK: Prod.ID  │
    └──────────────┘    └──────────────┘
```

---

## 10. Checklist para Producción

- [ ] Todos los adaptadores soportados están implementados
- [ ] Validaciones exhaustivas en cada adapter
- [ ] Tests unitarios para cada adapter
- [ ] Manejo de errores y excepciones
- [ ] Logging estructurado en transformación
- [ ] Rollback garantizado en persistencia
- [ ] Índices en BD para claves únicas
- [ ] Documentación de formato esperado por adapter
- [ ] Plan de compatibilidad backward (versioning)

---

**Responsable**: Equipo Arquitectura  
**Próxima revisión**: 2026-09-18
[AdaptadorML]
      |
      v
[Normalizador / Validador]
      |
      v
[Modelo Canónico]
      |
      v
[Motor de pricing]

[Origen 4: UI]
      |
      v
[AdaptadorUI]
      |
      v
[Normalizador / Validador]
      |
      v
[Modelo Canónico]
      |
      v
[Motor de pricing]
```

---

## 4. Qué es un adaptador realmente

Un adaptador es una pieza encargada de convertir la información de un sistema externo al modelo canónico que entiende el motor.

### Funciones del adaptador

1. recibir payload del origen
2. validar campos mínimos
3. mapear nombres y formatos
4. transformar valores
5. aplicar reglas de negocio del origen si hace falta
6. devolver un `ProductoInput` listo para el core

### Ejemplo mínimo

```text
ERP A envía:
- cod_sku
- precio_lista
- stock
- costo

AdaptadorERP_A:
- cod_sku -> SKU
- precio_lista -> PrecioActual
- stock -> StockActual
- costo -> CostoCompra

Salida:
ProductoInput con campos normalizados
```

---

## 5. Cuándo conviene un adaptador configurable

Sí puede existir un adaptador configurable, pero no como reemplazo del diseño de adaptadores por fuente.

### Opción recomendada

- un adaptador base reutilizable
- y un mapeo configurable por origen

Esto permite reducir repetición sin perder claridad.

### Ejemplo de mapeo configurable

```json
{
  "source": "ERP_A",
  "fieldMap": {
    "cod_sku": "SKU",
    "precio_lista": "PrecioActual",
    "stock": "StockActual",
    "costo": "CostoCompra",
    "iva": "IVA"
  },
  "transformRules": {
    "SKU": "trim|upper",
    "PrecioActual": "decimal:2",
    "StockActual": "int"
  }
}
```

Esto puede vivir en una tabla o configuración JSON.

### Ventajas
- menos código repetido
- más flexibilidad para nuevos ERP

### Riesgos
- si se vuelve demasiado genérico, se vuelve difícil de mantener
- la lógica de transformación puede volverse un “mini lenguaje” sin control

---

## 6. Modelo recomendado de implementación

### 6.1 Interfaz base

```csharp
public interface IInputAdapter
{
    string SourceName { get; }
    bool CanHandle(string sourceType);
    ProductoInput Map(dynamic payload);
}
```

### 6.2 Adaptador base común

```csharp
public abstract class BaseInputAdapter : IInputAdapter
{
    protected ProductoInput NormalizeCommonFields(dynamic payload) { ... }
    protected decimal ParseDecimal(object value) { ... }
    protected int ParseInt(object value) { ... }
    protected string NormalizeSku(string sku) { ... }
}
```

### 6.3 Adaptadores concretos

```csharp
public class MeliAdapter : BaseInputAdapter
{
    public override ProductoInput Map(dynamic payload) { ... }
}

public class ErpAAdapter : BaseInputAdapter
{
    public override ProductoInput Map(dynamic payload) { ... }
}

public class ErpBAdapter : BaseInputAdapter
{
    public override ProductoInput Map(dynamic payload) { ... }
}

public class UiAdapter : BaseInputAdapter
{
    public override ProductoInput Map(dynamic payload) { ... }
}
```

Esto te permite mantener la lógica del core estable y reutilizar la lógica común.

### 6.4 Implementación inicial propuesta en C#

Para empezar de forma concreta, se puede materializar esta arquitectura con una pequeña capa en C#:

- `ProductoInput` como contrato canónico
- `IInputAdapter` como interfaz base
- `BaseInputAdapter` con validación y normalización común
- `UiAdapter` para transformar el payload de la pantalla
- `PricingEngineGateway` para encapsular la llamada al motor

Esto permite modelar el flujo real:

```text
UI -> Json payload -> UiAdapter -> ProductoInput -> PricingEngineGateway -> spCalcularDecision
```

La idea es que la UI no conozca el motor SQL directamente, sino que entregue un payload manejable y luego se convierta en el contrato interno del pricing engine.

### 6.5 Integración con SQL Server real

La capa de entrada ya puede dejarse preparada para invocar la base real en lugar de quedarse en simulación en memoria.

#### Patrón recomendado

```text
UI -> API -> UiAdapter -> ProductoInput -> SqlPricingService -> spCalcularDecision (SQL Server)
```

#### Requerimientos

- una instancia SQL Server disponible y accesible
- base de datos `PRICES_DB`
- tablas creadas desde `SQL/Estructura.sql`
- procedimiento `dbo.spCalcularDecision` ejecutable
- cadena de conexión válida con usuario/seguridad configurada

#### Observación importante

La integración real no puede validarse en este entorno si no hay una instancia SQL Server corriendo o si la cadena de conexión apunta a un servidor inexistente. La capa de código sí queda lista para conectarse al motor real, pero la ejecución final depende del entorno de base de datos.

---

## 7. Enfoque práctico para tu proyecto SQL Server

Como tu motor actual está basado en SQL Server, lo más práctico es mantener esta separación conceptual:

### 7.1 Capa de ingestión (fuera del core)
- sistema externo
- adaptador
- normalización
- staging tables

### 7.2 Capa de validación y persistencia
- insert en tablas del core (`Productos`, `PublicacionesML`, `CostosProducto`, etc.)

### 7.3 Capa de pricing
- `spCalcularDecision`
- `fn_CalcularMargenNetoPorc`

### 7.4 Capa de salida
- historial
- cola de ejecución
- UI
- logs

---

## 8. Ejemplo de adaptador para Mercado Libre

### Fuente ML
Payload típico:

```json
{
  "id": "MLA123456",
  "title": "Auriculares Bluetooth",
  "price": 35000,
  "available_quantity": 12,
  "status": "active"
}
```

### Transformación

```text
MeliItemID = id
Titulo = title
PrecioActual = price
StockActual = available_quantity
Estado = status
```

### Modelo canónico resultante

```text
ProductoInput:
- EmpresaID = 1
- SKU = null o derivado desde SKU map
- Titulo = Auriculares Bluetooth
- PrecioActual = 35000
- StockActual = 12
- EstadoPublicacion = active
- FuenteOrigen = ML
```

---

## 9. Ejemplo de adaptador para ERP A

### Entrada ERP A

```json
{
  "cod_sku": "SKU-001",
  "precio_lista": 42000,
  "stock": 9,
  "costo": 28000,
  "iva": 21,
  "moneda": "ARS"
}
```

### Mapeo

```text
cod_sku -> SKU
precio_lista -> PrecioActual
stock -> StockActual
costo -> CostoCompra
iva -> IVA
moneda -> Moneda
```

### Resultado

```text
ProductoInput:
- SKU = SKU-001
- PrecioActual = 42000
- StockActual = 9
- CostoCompra = 28000
- IVA = 21
- FuenteOrigen = ERP_A
```

---

## 10. Ejemplo de adaptador para ERP B

### Entrada ERP B

```json
{
  "sku": "sku_001",
  "unit_price": 43000,
  "inventory": 11,
  "purchase_cost": 30000,
  "tax": 21
}
```

### Mapeo

```text
sku -> SKU
unit_price -> PrecioActual
inventory -> StockActual
purchase_cost -> CostoCompra
tax -> IVA
```

### Resultado

```text
ProductoInput:
- SKU = sku_001
- PrecioActual = 43000
- StockActual = 11
- CostoCompra = 30000
-IVA = 21
- FuenteOrigen = ERP_B
```

---

## 11. Ejemplo de adaptador para UI

### Entrada UI

```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "precioPropuesto": 46000,
  "stockDisponible": 8,
  "costoBase": 31000,
  "estrategia": "ESTRATEGIA_BALANCEADA"
}
```

### Mapeo

```text
empresaId -> EmpresaID
sku -> SKU
precioPropuesto -> PrecioActual
stockDisponible -> StockActual
costoBase -> CostoCompra
estrategia -> estrategia
```

### Resultado

```text
ProductoInput:
- EmpresaID = 1
- SKU = SKU-001
- PrecioActual = 46000
- StockActual = 8
- CostoCompra = 31000
- FuenteOrigen = UI
```

---

## 12. Qué conviene poner en una configuración y qué no

### Sí conviene poner en configuración
- nombres de campos del origen
- equivalencias entre origen y destino
- reglas de cast
- mapeo de moneda
- validación mínima

### No conviene poner en configuración
- lógica de pricing del negocio
- decisiones de estrategia
- reglas de prioridad de reglas
- margen mínimo permitido
- lógica de antioscilación

Esas cosas deben quedar en el motor central.

---

## 13. Recomendación final para tu proyecto

Yo haría esto:

1. un modelo canónico único
2. un adaptador base reutilizable
3. one-to-one por sistema origen, con posibilidad de configuración
4. una capa de validación antes de entrar al core
5. un motor de decisions sin conocimiento de cómo se generó la información

### En una frase

El motor debe ser “fuente agnóstica”; los adaptadores deben encargarse de traducir la entrada de cada sistema.

---

## 14. Fases de implementación recomendadas

La forma más segura de construirlo es en etapas, sin mezclar la lógica del core con la UI ni con los sistemas externos.

### Fase 0: definir el contrato de entrada del motor

Antes de escribir código, hay que definir exactamente qué necesita `spCalcularDecision` para operar.

#### Objetivo
- dejar fijo el payload mínimo que el motor puede aceptar
- evitar que cada sistema envíe campos distintos
- reducir ambigüedad entre UI, ERP y ML

#### Entregables
- modelo `ProductoInput`
- validaciones obligatorias
- nombres estandarizados
- tipos de dato esperados

#### Recomendación
- usar un contrato único para todos los orígenes
- no permitir que la UI o ERP “adivinen” qué campos necesita el core

---

### Fase 1: construir la capa base del adaptador

#### Objetivo
- centralizar lógica reutilizable
- evitar duplicación entre adaptadores

#### Componentes
- `IInputAdapter`
- `BaseInputAdapter`
- métodos de parseo y normalización
- validación genérica de campos críticos

#### Funcionalidad base
- normalizar `SKU`
- convertir texto a decimal
- convertir cantidades a enteros
- formatear fechas
- asignar `FuenteOrigen`

#### Entregables
- base reusable para todos los adaptadores
- pruebas unitarias de parseo y validación

---

### Fase 2: implementar el adaptador de la UI

Este es el punto clave para arrancar con un flujo real.

#### Objetivo
- que la UI pueda enviar un payload estándar
- que no conozca la estructura interna del pricing engine

#### Entrada típica desde UI

```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "titulo": "Auriculares Bluetooth",
  "precioPropuesto": 46000,
  "stockDisponible": 8,
  "costoBase": 31000,
  "iva": 21,
  "estrategia": "ESTRATEGIA_BALANCEADA",
  "origen": "UI"
}
```

#### Mapeo del adaptador UI

```text
empresaId -> EmpresaID
sku -> SKU
titulo -> Titulo
precioPropuesto -> PrecioActual
stockDisponible -> StockActual
costoBase -> CostoCompra
iva -> IVA
origen -> FuenteOrigen
```

#### Lo que debe hacer `UiAdapter`
1. recibir el payload de la pantalla
2. validar campos mínimos
3. normalizar valores
4. mapear a `ProductoInput`
5. devolver un objeto listo para el motor

#### Entregables
- `UiAdapter`
- validación de errores de ingreso
- registro de payloads rechazados

---

### Fase 3: validar y persistir antes del core

#### Objetivo
- asegurar que los datos que llegan al motor sean consistentes

#### Qué va aquí
- tabla de staging para ingestión
- validación por negocio
- auditoría de errores
- rechazo de payloads corruptos

#### Ejemplo
- cantidad no numérica
- SKU vacío
- costo menor a cero
- precio fuera del rango permitido

#### Mejor práctica
- no mandar datos directamente al core si falla la validación
- trabajar con un registro intermedio de errores

---

### Fase 4: UI MVP y flujo de decisión

#### Objetivo
- que el usuario pueda cargar un producto y ver la decisión del pricing

#### Pantallas sugeridas
- listado de productos
- alta / edición de producto
- evaluación de estrategia
- resultado final con decisión, margen y motivo

#### Flujo recomendado

```text
UI -> UiAdapter -> Validación -> ProductoInput -> spCalcularDecision -> Resultado
```

#### Entregables
- pantalla de carga
- resultado legible para negocio
- historial de decisiones

---

### Fase 5: adaptar ERP y ML con la misma base

Cuando la base ya esté establecida, agregar ERP y ML es más simple.

#### Estrategia
- mantener un adaptador específico por origen
- reutilizar `BaseInputAdapter`
- usar configuración opcional para campos difíciles

#### Ejemplos
- `ErpAAdapter`
- `ErpBAdapter`
- `MeliAdapter`

#### Beneficio
- no duplicar reglas de validación ni de normalización
- todas las fuentes terminan en el mismo `ProductoInput`

---

### Fase 6: evolución y escalabilidad

#### Objetivo
- dejar la arquitectura preparada para crecimiento

#### Qué agregar después
- colas de procesamiento
- logging centralizado
- control de versión de mappings
- testing de regresión por origen
- mapeos configurables por fuente

---

## 15. Orden recomendado en este proyecto

Si querés ir de forma segura y sin construir sobre arena movediza, yo ordenaría así:

1. definir `ProductoInput`
2. definir `IInputAdapter` y `BaseInputAdapter`
3. crear `UiAdapter`
4. validación del payload
5. UI MVP
6. luego ERP/ML adapters
7. luego configuraciones avanzadas

Esto te deja una base clara, modular y mantenible.

---

## 16. Beneficios de este diseño

- se evita acoplamiento con un sistema en particular
- se facilita la incorporación de nuevas fuentes
- se mejora testabilidad
- se reduce el riesgo de romper el core al cambiar un adaptador
- se mantiene el engine central estable
- la UI se vuelve un cliente más del sistema y no su dependencia directa

---

## 17. Conclusión

Sí, un adaptador configurable puede existir como ayuda, pero no reemplaza la necesidad de un diseño por fuente si los sistemas son distintos.

La estrategia más segura y mantenible es:

- contrato único de entrada
- adaptadores por origen
- lógica común reutilizable
- separación clara entre ingestión y pricing

Esto te permite crecer con ERP, ML, UI y otros sistemas sin romper el motor.