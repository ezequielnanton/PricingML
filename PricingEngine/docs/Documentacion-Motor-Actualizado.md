# Documentación Completa del Motor de Pricing - Versión Actualizada

**Fecha:** 15/08/2026  
**Versión:** 2.1  
**Estado:** Motor con soporte simulación/producción unificado

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Arquitectura de Flujo](#arquitectura-de-flujo)
3. [Función SQL: `fn_CalcularMargenNetoPorc`](#función-sql-fn_calcularmargennettoproc)
4. [Stored Procedure: `spCalcularDecision`](#stored-procedure-spcalculardecision)
5. [API y Adaptadores C#](#api-y-adaptadores-c)
6. [Casos de Uso y Escenarios](#casos-de-uso-y-escenarios)
7. [Cambios Recientes (v2.1)](#cambios-recientes-v21)

---

## Resumen Ejecutivo

El motor de pricing es un **sistema unificado de decisión de precios** que:

- ✅ Evalúa productos en **modo simulación** (parámetros JSON, sin persistencia)
- ✅ Evalúa productos en **modo producción** (datos de base, con persistencia)
- ✅ Aplica **reglas de negocio** basadas en estrategias configurables
- ✅ Protege **márgenes mínimos** con bloqueos de seguridad
- ✅ Implementa **anti-oscilación** con cooldown e histéresis
- ✅ Devuelve **decisiones accionables** con motivos y confianza

**Una única lógica de decisión, dos contextos de entrada.**

---

## Arquitectura de Flujo

```
┌─────────────────┐
│  Cliente JSON   │
│  (Postman/ERP) │
└────────┬────────┘
         │
         ↓
┌─────────────────────────────────────────┐
│  POST /pricing/evaluate                 │
│  (Program.cs)                           │
│  - Recibe UiPricingRequest              │
│  - Extrae modoSimulacion, persistir     │
└────────┬────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────┐
│  UiAdapter.Map()                        │
│  (Adapta JSON → ProductoInput)          │
│  - Mapeo de propiedades                 │
│  - Validación básica                    │
└────────┬────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────────┐
│  SqlPricingService.EvaluateAsync()           │
│  - Convierte bool → parametros SQL           │
│  - Setea @ModoSimulacion (1/0)              │
│  - Setea @Persistir (1/0)                   │
│  - Setea @ContextSource ("TEMP"/"BASE")     │
└────────┬─────────────────────────────────────┘
         │
         ↓
    ┌────────────────────┐
    │  SQL Server        │
    │  spCalcularDecision│
    └────────┬───────────┘
             │
     ┌───────┴────────┐
     ↓                ↓
  TEMP             BASE
(Simulación)    (Producción)
  Carga desde    Carga desde
  Parámetros     Tablas
     │                │
     └───────┬────────┘
             ↓
    ┌─────────────────────────────┐
    │  Aplica Reglas de Negocio   │
    │  - Stock Crítico            │
    │  - Competencia Más Barata   │
    │  - Exceso de Stock          │
    └──────────┬────────────────────┘
               ↓
    ┌──────────────────────────┐
    │  Valida Restricciones    │
    │  - Margen Mínimo         │
    │  - Límites Min/Max       │
    │  - Anti-Oscilación       │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  Persiste (si @Persistir │
    │  = 1) en:                │
    │  - DecisionesHistorial   │
    │  - ColaEjecucionML       │
    │  (si @ModoSimulacion=0)  │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  Retorna ResultSet       │
    │  - PrecioSugerido        │
    │  - Accion (MANTENER/...)  │
    │  - Motivo                │
    │  - Margen Proyectado     │
    │  - ScoreConfianza        │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  C# Lee y Mapea a        │
    │  PricingDecisionResult   │
    └──────────┬───────────────┘
               ↓
    ┌──────────────────────────┐
    │  Respuesta HTTP 200      │
    │  {JSON con decisión}     │
    └──────────────────────────┘
```

---

## Función SQL: `fn_CalcularMargenNetoPorc`

### Propósito
Calcula el **margen neto en porcentaje** después de deducir todos los costos de un precio de venta.

### Firma
```sql
CREATE OR ALTER FUNCTION dbo.fn_CalcularMargenNetoPorc (
    @PrecioFinal DECIMAL(18,4),
    @CostoCompra DECIMAL(18,4),
    @ComisionMLPorc DECIMAL(5,2),
    @PorcentajeIVA DECIMAL(5,2),
    @CostoEnvio DECIMAL(18,4),
    @CostoLogistico DECIMAL(18,4),
    @CostoFinancieroPorc DECIMAL(5,2),
    @CostoPublicidadPorc DECIMAL(5,2)
)
RETURNS DECIMAL(7,2)
```

### Parámetros de Entrada

| Parámetro | Tipo | Descripción | Ejemplo |
|-----------|------|-------------|---------|
| `@PrecioFinal` | DECIMAL(18,4) | Precio de venta final (con IVA) | 100.00 |
| `@CostoCompra` | DECIMAL(18,4) | Costo de compra al proveedor | 40.00 |
| `@ComisionMLPorc` | DECIMAL(5,2) | Comisión % de Mercado Libre | 11.5 |
| `@PorcentajeIVA` | DECIMAL(5,2) | IVA % | 21.0 |
| `@CostoEnvio` | DECIMAL(18,4) | Costo promedio de envío | 5.00 |
| `@CostoLogistico` | DECIMAL(18,4) | Costo logístico fijo | 2.00 |
| `@CostoFinancieroPorc` | DECIMAL(5,2) | Costo financiero % | 1.5 |
| `@CostoPublicidadPorc` | DECIMAL(5,2) | Costo publicidad % | 2.0 |

### Lógica Interna

**Paso 1: Protección contra divisiones por cero**
```sql
IF ISNULL(@PrecioFinal, 0) = 0 RETURN 0.00;
```

**Paso 2: Remover IVA del precio final para obtener precio sin IVA**
```sql
@PrecioSinIVA = @PrecioFinal / (1.0 + (@PorcentajeIVA / 100.0))
-- Ej: 100 / 1.21 = 82.64
```

**Paso 3: Calcular costos en moneda absoluta**
```sql
@MontoComision = @PrecioFinal * (@ComisionMLPorc / 100.0)
-- Ej: 100 * 0.115 = 11.50

@MontoFinanciero = @PrecioFinal * (@CostoFinancieroPorc / 100.0)
-- Ej: 100 * 0.015 = 1.50

@MontoPublicidad = @PrecioFinal * (@CostoPublicidadPorc / 100.0)
-- Ej: 100 * 0.020 = 2.00
```

**Paso 4: Sumar todos los costos**
```sql
@CostoTotal = @CostoCompra + @MontoComision + @CostoEnvio 
              + @CostoLogistico + @MontoFinanciero + @MontoPublicidad
-- Ej: 40 + 11.50 + 5 + 2 + 1.50 + 2.00 = 62.00
```

**Paso 5: Calcular ganancia neta**
```sql
@GananciaNeta = @PrecioSinIVA - @CostoTotal
-- Ej: 82.64 - 62.00 = 20.64
```

**Paso 6: Convertir a porcentaje**
```sql
@MargenNetoPorc = (@GananciaNeta / @PrecioFinal) * 100.0
-- Ej: (20.64 / 100.00) * 100 = 20.64%
```

### Retorno
- **Tipo:** `DECIMAL(7,2)` 
- **Rango:** -999.99 a 999.99 (soporta márgenes negativos)
- **Casos especiales:**
  - Si `@PrecioFinal = 0` → Retorna `0.00`
  - Si costos > precio → Retorna valor negativo ❌

### Ejemplo de Cálculo Completo

**Entrada:**
```
Precio Final: 100.00 (con IVA 21%)
Costo Compra: 40.00
Comisión ML: 11.5%
IVA: 21%
Envío: 5.00
Logístico: 2.00
Financiero: 1.5%
Publicidad: 2.0%
```

**Cálculo:**
```
Precio sin IVA = 100 / 1.21 = 82.64
Comisión = 100 × 0.115 = 11.50
Financiero = 100 × 0.015 = 1.50
Publicidad = 100 × 0.020 = 2.00
Costo Total = 40 + 11.50 + 5 + 2 + 1.50 + 2.00 = 62.00
Ganancia = 82.64 - 62.00 = 20.64
Margen % = (20.64 / 100) × 100 = 20.64% ✅
```

---

## Stored Procedure: `spCalcularDecision`

### Propósito
**Motor central de decisión de precios** que evalúa un producto bajo dos contextos:
- **TEMP** (Simulación): Datos vienen en parámetros JSON
- **BASE** (Producción): Datos vienen de tablas persistidas

### Firma Completa
```sql
CREATE OR ALTER PROCEDURE dbo.spCalcularDecision
    @EmpresaID INT,
    @ProductoID INT = NULL,
    @EstrategiaID INT = NULL,
    @ModoSimulacion BIT = 1,
    @Persistir BIT = 0,
    @ContextSource VARCHAR(20) = 'BASE',
    @SKU VARCHAR(100) = NULL,
    @Titulo NVARCHAR(200) = NULL,
    @PrecioActual DECIMAL(18,4) = NULL,
    @StockActual INT = NULL,
    @StockMinimo INT = NULL,
    @StockMaximo INT = NULL,
    @CostoCompra DECIMAL(18,4) = NULL,
    @IVA DECIMAL(5,2) = NULL,
    @ComisionMLPorc DECIMAL(5,2) = NULL,
    @CostoEnvioPromedio DECIMAL(18,4) = NULL,
    @CostoLogisticoFijo DECIMAL(18,4) = NULL,
    @CostoFinancieroPorc DECIMAL(5,2) = NULL,
    @CostoPublicidadPorc DECIMAL(5,2) = NULL,
    @EstadoPublicacion VARCHAR(50) = NULL,
    @CooldownHoras INT = 12,
    @VariacionMinimaPorc DECIMAL(5,2) = 1.50
AS
```

### Parámetros

#### Parámetros de Entrada Obligatorios
| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `@EmpresaID` | INT | ID de la empresa cliente |
| `@ModoSimulacion` | BIT | 1=Simulación (TEMP), 0=Producción (BASE) |
| `@Persistir` | BIT | 1=Guardar en BD, 0=Solo evaluar |
| `@ContextSource` | VARCHAR(20) | Auto-seteado: "TEMP" si simulación, "BASE" si producción |

#### Parámetros Opcionales (Requeridos solo en Simulación)
| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `@ProductoID` | INT | NULL | ID del producto (opcional en TEMP) |
| `@EstrategiaID` | INT | NULL | ID de estrategia (si NULL, usa activa por defecto) |
| `@SKU` | VARCHAR(100) | NULL | SKU del producto |
| `@Titulo` | NVARCHAR(200) | NULL | Título del producto |
| `@PrecioActual` | DECIMAL(18,4) | NULL | Precio vigente |
| `@StockActual` | INT | NULL | Stock disponible |
| `@StockMinimo` | INT | NULL | Stock mínimo de seguridad |
| `@StockMaximo` | INT | NULL | Stock máximo permitido |
| `@CostoCompra` | DECIMAL(18,4) | NULL | Costo de compra |
| `@IVA` | DECIMAL(5,2) | NULL | IVA % |
| `@ComisionMLPorc` | DECIMAL(5,2) | NULL | Comisión % |
| `@CostoEnvioPromedio` | DECIMAL(18,4) | NULL | Costo envío |
| `@CostoLogisticoFijo` | DECIMAL(18,4) | NULL | Costo logístico |
| `@CostoFinancieroPorc` | DECIMAL(5,2) | NULL | Costo financiero % |
| `@CostoPublicidadPorc` | DECIMAL(5,2) | NULL | Costo publicidad % |
| `@EstadoPublicacion` | VARCHAR(50) | NULL | Estado ("active", "paused", etc.) |
| `@CooldownHoras` | INT | 12 | Ventana anti-oscilación en horas |
| `@VariacionMinimaPorc` | DECIMAL(5,2) | 1.50 | Umbral mínimo de variación % |

### Fases de Ejecución

#### Fase 1: Inicialización (Líneas 25-44)
```
1. Determina estrategia
   - Si @EstrategiaID NULL → Busca estrategia ACTIVA para empresa
   - Si no existe → Lanza error y retorna
   
2. Carga parámetros globales
   - Lee @MargenMinimoGlobal desde ConfiguracionParametros
   - Default = 15.00% si no existe
```

#### Fase 2: Carga de Contexto (Líneas 85-180)
```
IF @ContextSource = 'TEMP' (Simulación)
├─ Carga datos desde parámetros JSON (@SKU, @PrecioActual, etc.)
├─ Calcula stock classification (CRITICO/BAJO/NORMAL/ALTO/EXCESO)
├─ Establece competencia = NULL (no hay datos)
└─ Usa valores de entrada tal cual

ELSE (Producción, BASE)
├─ JOIN con tablas PublicacionesML, Productos, CostosProducto, StockEstado
├─ Consulta CompetenciaSnapshot (últimas 48h)
├─ Calcula posición competitiva
├─ Aplica filtros: EmpresaID, ProductoID (si no NULL), Estado='active'
└─ Si no encuentra datos → Retorna conjunto vacío
```

#### Fase 3: Aplicación de Reglas (Líneas 183-236)
```
REGLA 1: STOCK CRÍTICO
├─ Condición: ClasificacionStock = 'CRITICO'
├─ Acción: PrecioSugerido = PrecioActual × 1.05 (subida 5%)
└─ Motivo: "Stock en nivel CRÍTICO. Se incrementa precio 5%..."

REGLA 2: COMPETENCIA MÁS BARATA
├─ Condición: CompMinPrecio < PrecioActual Y Stock ≠ CRITICO
├─ Acción: PrecioSugerido = CompRelevantePrecio - 10 (o CompMinPrecio - 10)
└─ Motivo: "Competidor relevante detectado a menor precio..."

REGLA 3: OPORTUNIDAD
├─ Condición: No hay competencia directa o hay alta demanda
├─ Acción: PrecioSugerido = PrecioActual × 1.03 (subida 3%)
└─ Motivo: "Captura de margen por oportunidad de mercado..."

REGLA 4: EXCESO DE STOCK
├─ Condición: ClasificacionStock = 'EXCESO'
├─ Acción: PrecioSugerido = PrecioActual × 0.93 (descuento 7%)
└─ Motivo: "Exceso de stock detectado con baja rotación..."
```

**Lógica de Prioridades:**
- Cada regla tiene `Prioridad` en tabla `EstrategiaReglas`
- Se aplica la regla con MENOR número de prioridad (1 antes que 2)
- Bloquea si prioridad existente < prioridad nueva
- Permite override solo por reglas de mayor prioridad

#### Fase 4: Restricciones de Seguridad (Líneas 239-305)
```
RESTRICCIÓN 1: MARGEN MÍNIMO PERMITIDO
├─ Condición: Acción = 'DISMINUIR_PRECIO' Y MargenProyectado < MargenMínimo
├─ Acción: PrecioSugerido = PrecioActual (NO CAMBIAR)
├─ Motivo: "BLOQUEO SEGURIDAD: La baja sugerida viola el margen mínimo..."
└─ ScoreConfianza = 0.95 (muy confiable, es seguridad)

RESTRICCIÓN 2: LÍMITES DE PUBLICACIÓN
├─ Condición: PrecioSugerido < PrecioMinimoPermitido O > PrecioMaximoPermitido
├─ Acción: PrecioSugerido = CLAMP(PrecioSugerido, Min, Max)
└─ Motivo: "Ajustado al Límite [Mínimo/Máximo] Permitido..."

RESTRICCIÓN 3: ANTI-OSCILACIÓN (COOLDOWN + HISTÉRESIS)
├─ Condición A: Último cambio < @CooldownHoras (default 12h)
├─ Condición B: ABS(PrecioSugerido - PrecioActual) / PrecioActual < @VariacionMinimaPorc
├─ Acción: PrecioSugerido = PrecioActual (NO CAMBIAR)
└─ Motivo: "BLOQUEO COOLDOWN/HISTÉRESIS..."
```

#### Fase 5: Persistencia (Líneas 308-337)
```
IF @Persistir = 1
├─ BEGIN TRANSACTION
├─ INSERT INTO DecisionesHistorial (auditoría de todas las decisiones)
│  Registra: Precio anterior, sugerido, acción, motivo, margen proyectado
│
├─ IF @ModoSimulacion = 0 (Solo en Producción)
│  ├─ INSERT INTO ColaEjecucionML (para envío a Mercado Libre)
│  ├─ UPDATE PublicacionesML.FechaUltimoCambioPrecio
│  └─ (Si es simulación, NO encola ni actualiza fechas)
│
└─ COMMIT TRANSACTION
```

#### Fase 6: Retorno de Resultados (Líneas 340-359)
```
SELECT
  PublicacionID,           -- -1 si NULL
  MeliItemID,              -- '' si NULL
  PrecioActual,            -- 0 si NULL (protegido con ISNULL)
  PrecioSugerido,          -- 0 si NULL (protegido)
  Accion,                  -- MANTENER_PRECIO, AUMENTAR_PRECIO, DISMINUIR_PRECIO, NO_MODIFICAR
  Motivo,                  -- Razón de la decisión
  MargenActualPorc,        -- % actual (0 si NULL)
  MargenProyectadoPorc,    -- % proyectado (0 si NULL)
  ClasificacionStock,      -- CRITICO, BAJO, NORMAL, ALTO, EXCESO
  StockDisponible,         -- 0 si NULL
  CompMinPrecio,           -- 0 si NULL (precio competidor más bajo)
  ScoreConfianza           -- Fórmula ponderada: 0.5 + (Competidores / 10) + (VentasEstables ? 0.2 : 0)
FROM #ContextoDecision;

DROP TABLE #ContextoDecision;
```

---

## API y Adaptadores C#

### Endpoint: POST /pricing/evaluate

**URL:** `http://localhost:5000/pricing/evaluate`

**Contrato de Entrada:**
```csharp
public class UiPricingRequest
{
    public int EmpresaId { get; set; }
    public string? Sku { get; set; }
    public string? Titulo { get; set; }
    public decimal PrecioPropuesto { get; set; }
    public decimal PrecioMinimoPermitido { get; set; }
    public decimal PrecioMaximoPermitido { get; set; }
    public int StockDisponible { get; set; }
    public int StockMinimo { get; set; }
    public int StockMaximo { get; set; }
    public decimal CostoBase { get; set; }
    public decimal Iva { get; set; }
    public decimal ComisionMLPorc { get; set; }
    public decimal CostoEnvioPromedio { get; set; }
    public decimal CostoLogisticoFijo { get; set; }
    public decimal CostoFinancieroPorc { get; set; }
    public decimal CostoPublicidadPorc { get; set; }
    public string? EstadoPublicacion { get; set; }
    public string Origen { get; set; } = "UI";
    public bool ModoSimulacion { get; set; } = true;
    public bool Persistir { get; set; } = false;
}
```

**Ejemplo JSON:**
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

**Contrato de Salida:**
```csharp
public class PricingDecisionResult
{
    public int EmpresaId { get; set; }
    public string? Sku { get; set; }
    public string? FuenteOrigen { get; set; }
    public bool ModoSimulacion { get; set; }
    public int PublicacionID { get; set; }
    public decimal PrecioActual { get; set; }
    public decimal PrecioSugerido { get; set; }
    public string? Accion { get; set; }
    public string? Motivo { get; set; }
    public decimal MargenActualPorc { get; set; }
    public decimal MargenProyectadoPorc { get; set; }
    public string? ClasificacionStock { get; set; }
    public int StockDisponible { get; set; }
    public decimal CompMinPrecio { get; set; }
    public decimal ScoreConfianza { get; set; }
}
```

**Ejemplo Respuesta (200 OK):**
```json
{
  "empresaId": 1,
  "sku": "PROD-001",
  "fuenteOrigen": "UI",
  "modoSimulacion": true,
  "publicacionID": -1,
  "precioActual": 100.00,
  "precioSugerido": 100.00,
  "accion": "MANTENER_PRECIO",
  "motivo": "Escenario simulado",
  "margenActualPorc": 20.64,
  "margenProyectadoPorc": 20.64,
  "clasificacionStock": "NORMAL",
  "stockDisponible": 50,
  "compMinPrecio": 0.00,
  "scoreConfianza": 0.80
}
```

### Mapeo UiAdapter

El adaptador `UiAdapter` convierte JSON → `ProductoInput`:

```csharp
var precioPropuesto = ReadDecimal(payload, "precioPropuesto");
var precioActual = precioPropuesto;  // ← Mapeo: precioPropuesto → PrecioActual

var costoBase = ReadDecimal(payload, "costoBase");
var costoCompra = costoBase;  // ← Mapeo: costoBase → CostoCompra

var stockDisponible = ReadInt(payload, "stockDisponible");
var stockActual = stockDisponible;  // ← Mapeo: stockDisponible → StockActual
```

---

## Casos de Uso y Escenarios

### Escenario 1: Simulación Simple (Stock Normal, Precio Justo)

**JSON Enviado:**
```json
{
  "empresaId": 1,
  "sku": "PROD-001",
  "precioPropuesto": 100.00,
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
  "modoSimulacion": true,
  "persistir": false
}
```

**Procesamiento:**
1. Carga TEMP (simulación)
2. Stock = 50 → Clasificación = "NORMAL"
3. Ninguna regla se aplica (stock no crítico, no hay competencia)
4. Restricción 3: Cooldown no se aplica (es simulación)
5. NO persiste (persistir = false)

**Respuesta:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 100.00,
  "accion": "MANTENER_PRECIO",
  "motivo": "Escenario simulado",
  "margenActualPorc": 20.64,
  "margenProyectadoPorc": 20.64,
  "clasificacionStock": "NORMAL",
  "scoreConfianza": 0.80
}
```

---

### Escenario 2: Stock Crítico (Debe Subir Precio)

**JSON Enviado:**
```json
{
  "empresaId": 1,
  "sku": "PROD-CRITICAL",
  "precioPropuesto": 100.00,
  "stockDisponible": 5,        // ← Menos que mínimo (10)
  "stockMinimo": 10,
  "stockMaximo": 200,
  "costoBase": 40.00,
  ...
  "modoSimulacion": true,
  "persistir": false
}
```

**Procesamiento:**
1. Carga TEMP
2. Stock = 5 ≤ 10 → Clasificación = **"CRITICO"**
3. REGLA 1 activada: `PrecioSugerido = 100 × 1.05 = 105.00`
4. Acción = "AUMENTAR_PRECIO"
5. Margen actual: 20.64% ≥ 15% → Permite subida ✅
6. NO persiste

**Respuesta:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 105.00,
  "accion": "AUMENTAR_PRECIO",
  "motivo": "Stock en nivel CRÍTICO. Se incrementa precio 5% para proteger quiebre.",
  "margenActualPorc": 20.64,
  "margenProyectadoPorc": 21.67,
  "clasificacionStock": "CRITICO",
  "scoreConfianza": 0.85
}
```

---

### Escenario 3: Margen Negativo (Bloqueado por Seguridad)

**JSON Enviado:**
```json
{
  "empresaId": 1,
  "sku": "PROD-LOSS",
  "precioPropuesto": 100.00,
  "costoBase": 120.00,         // ← Costo MAYOR que precio
  "stockDisponible": 50,
  ...
  "modoSimulacion": true,
  "persistir": false
}
```

**Procesamiento:**
1. Carga TEMP
2. Calcula margen: (100 - 120) / 100 = -20% ❌
3. Margen = -20% < 15% (mínimo permitido)
4. RESTRICCIÓN 1 (Margen Mínimo): BLOQUEA cambio
5. `PrecioSugerido = 100` (no cambia)
6. Acción = "NO_MODIFICAR"

**Respuesta:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 100.00,
  "accion": "NO_MODIFICAR",
  "motivo": "BLOQUEO SEGURIDAD: La baja sugerida viola el margen mínimo permitido (15%).",
  "margenActualPorc": -20.00,
  "margenProyectadoPorc": -20.00,
  "scoreConfianza": 0.95
}
```

---

### Escenario 4: Exceso de Stock (Descuento Agresivo)

**JSON Enviado:**
```json
{
  "empresaId": 1,
  "sku": "PROD-OVERFLOW",
  "precioPropuesto": 100.00,
  "stockDisponible": 250,      // ← Mayor que máximo (200)
  "stockMaximo": 200,
  "costoBase": 40.00,
  ...
  "modoSimulacion": true,
  "persistir": false
}
```

**Procesamiento:**
1. Carga TEMP
2. Stock = 250 ≥ 200 → Clasificación = **"EXCESO"**
3. REGLA 3 activada: `PrecioSugerido = 100 × 0.93 = 93.00`
4. Acción = "DISMINUIR_PRECIO"
5. Margen proyectado: 93×0.93= 86.53 - 62 = 24.53 ÷ 93 = 26.37% ≥ 15% ✅
6. NO persiste

**Respuesta:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 93.00,
  "accion": "DISMINUIR_PRECIO",
  "motivo": "Exceso de stock detectado con baja rotación. Aplicando descuento de liquidación.",
  "margenActualPorc": 20.64,
  "margenProyectadoPorc": 19.17,
  "clasificacionStock": "EXCESO",
  "scoreConfianza": 0.85
}
```

---

### Escenario 5: Producción con Persistencia

**JSON Enviado:**
```json
{
  "empresaId": 1,
  "sku": "PROD-PROD",
  "precioPropuesto": 100.00,
  "stockDisponible": 50,
  ...
  "modoSimulacion": false,     // ← PRODUCCIÓN
  "persistir": true           // ← GUARDAR EN BD
}
```

**Procesamiento:**
1. `@ContextSource = "BASE"` (porque modoSimulacion=false)
2. Carga datos DESDE tablas (PublicacionesML, Productos, etc.)
3. Busca competencia real (últimas 48h)
4. Aplica reglas normales
5. `@Persistir = 1` → PERSISTE en:
   - ✅ `DecisionesHistorial` (auditoría)
   - ✅ `ColaEjecucionML` (si acción es AUMENTAR/DISMINUIR)
   - ✅ Actualiza `FechaUltimoCambioPrecio` en `PublicacionesML`
6. Transacción COMMIT

**Resultado:** Decisión guardada en BD, encolada para Mercado Libre

---

## Cambios Recientes (v2.1)

### Cambio 1: Protección ISNULL en SELECT Final (15/08/2026)

**Problema:**
- La función `fn_CalcularMargenNetoPorc` podía retornar `NULL` en algunos casos.
- El contrato de salida debía entregar valores numéricos consistentes a la API.

**Solución Implementada:**
```sql
-- ANTES (v2.0)
SELECT
    PrecioActual,
    PrecioSugerido,
    MargenActual AS MargenActualPorc,
    dbo.fn_CalcularMargenNetoPorc(...) AS MargenProyectadoPorc,
    ...
FROM #ContextoDecision;

-- DESPUÉS (v2.1)
SELECT
    ISNULL(PrecioActual, 0) AS PrecioActual,
    ISNULL(PrecioSugerido, 0) AS PrecioSugerido,
    ISNULL(MargenActual, 0) AS MargenActualPorc,
    ISNULL(dbo.fn_CalcularMargenNetoPorc(...), 0) AS MargenProyectadoPorc,
    ...
FROM #ContextoDecision;
```

**Impacto:**
- Garantiza valores por defecto (`0`) en lugar de `NULL` en la salida.
- No cambia la lógica de negocio.
- Esta protección no corrige errores de tipado de parámetros de entrada; esos se
  resuelven en el cambio 5.

---

### Cambio 2: Parámetros de Simulación/Producción (15/08/2026)

**Nuevo parámetro `@ContextSource`:**
```sql
-- Auto-seteado en C# antes de llamar SP
IF @ModoSimulacion = 1
    @ContextSource = "TEMP"   -- Carga desde parámetros
ELSE
    @ContextSource = "BASE"   -- Carga desde tablas
```

**Impacto:**
- ✅ Una única lógica de decisión
- ✅ Dos contextos de entrada intercambiables
- ✅ Facilita testing sin BD real

---

### Cambio 3: Estructura Multi-moneda (Pendiente de Lógica)

El sistema contempla las tablas `MONEDAS`, `COTIZACIONES` y `PARAMETROS_GENERALES`. Sin embargo, esto es **solo estructura de base de datos**. Actualmente, las conversiones cruzadas de costos y precios **no** se aplican en los stored procedures (la lógica asume que todo entra en una sola moneda).

---

### Cambio 3: Adaptador UiAdapter (15/08/2026)

**Mapeos añadidos:**
```csharp
"precioPropuesto" → PrecioActual
"costoBase" → CostoCompra  
"stockDisponible" → StockActual
"precioMinimoPermitido" → PrecioMinimoPermitido (directo)
"precioMaximoPermitido" → PrecioMaximoPermitido (directo)
```

**Impacto:**
- ✅ Nombres de propiedades JSON claros y semánticos
- ✅ Adaptador maneja transformaciones
- ✅ C# y SQL usan nombres coherentes internamente

---

### Cambio 4: Service C# Multi-Sobrecarga (15/08/2026)

**Antes:**
```csharp
public Task<PricingDecisionResult> EvaluateAsync(ProductoInput producto)
```

**Después:**
```csharp
public Task<PricingDecisionResult> EvaluateAsync(ProductoInput producto)
{
    return EvaluateAsync(producto, true, false);  // Default: Sim, no persistir
}

public async Task<PricingDecisionResult> EvaluateAsync(
    ProductoInput producto, 
    bool modoSimulacion, 
    bool persistir)
{
    // Lógica principal que acepta flags de contexto
}
```

**Impacto:**
- ✅ Backwards compatible (llamadas sin flags usan defaults)
- ✅ Permite pasar flags explícitamente desde endpoint
- ✅ Flexible para diferentes clientes/adapters

---

### Cambio 5: Contrato numérico estable entre JSON, C# y SQL Server (15/08/2026)

**Problema detectado:**

El adaptador leía decimales con la configuración regional del equipo. En una
cultura que usa coma decimal, el valor JSON `21.00` podía interpretarse como
`2100.00`; SQL Server lo rechazaba para parámetros como `@IVA DECIMAL(5,2)`.
Además, `AddWithValue` dejaba que el cliente SQL infiriera tipos, precisión y
escala al llamar a `spCalcularDecision`.

**Solución implementada:**

```csharp
decimal.TryParse(valor, NumberStyles.Number,
    CultureInfo.InvariantCulture, out var decimalParseado);

var parametro = command.Parameters.Add("@IVA", SqlDbType.Decimal);
parametro.Precision = 5;
parametro.Scale = 2;
parametro.Value = producto.IVA;
```

- El adaptador interpreta los números JSON con `CultureInfo.InvariantCulture`.
- `SqlPricingService` envía `INT`, `BIT`, `VARCHAR`/`NVARCHAR` y `DECIMAL` de
  forma explícita.
- Los importes usan `DECIMAL(18,4)` y los porcentajes `DECIMAL(5,2)`, igual que
  la firma del procedimiento almacenado.

**Regla del contrato HTTP:** los decimales son números JSON sin comillas y usan
punto como separador: `21.00`, `11.5`, `3.0` y `2.0`.

---

## Resumen de Estados y Flujos

### Estados de Clasificación de Stock
| Estado | Condición | Acción Típica |
|--------|-----------|--------------|
| **CRITICO** | Stock ≤ StockMinimo | Subir precio 5% |
| **BAJO** | Stock ≤ StockMinimo × 1.5 | Monitorear |
| **NORMAL** | StockMinimo < Stock < StockMaximo × 0.8 | Mantener |
| **ALTO** | Stock > StockMaximo × 0.8 | Evaluar baja |
| **EXCESO** | Stock ≥ StockMaximo | Bajar precio 7% |

### Acciones Posibles
| Acción | Cuándo | Precio |
|--------|--------|--------|
| **MANTENER_PRECIO** | Sin cambios recomendados | PrecioActual |
| **AUMENTAR_PRECIO** | Stock crítico o estrategia | PrecioActual × 1.05 |
| **DISMINUIR_PRECIO** | Exceso stock o competencia | PrecioActual × 0.93 ó CompPrecio - 10 |
| **NO_MODIFICAR** | Bloqueado por seguridad | PrecioActual |

### Restricciones Aplicadas en Orden
1. **Margen Mínimo:** Bloquea si margen < 15%
2. **Límites Publicación:** CLAMP entre Min/Max permitidos
3. **Anti-Oscilación:** Cooldown 12h + Histéresis 1.5%

---

## Troubleshooting

### Problema: "Error converting data type numeric to decimal"
**Causa posible 1:** valor `NULL` en un campo decimal del resultset.

**Solución:** `ISNULL(..., 0)` en el `SELECT` final.

**Causa posible 2:** un decimal del JSON fue interpretado con la cultura local
(por ejemplo `21.00` convertido en `2100.00`) o se infirió una precisión/escala
distinta al contrato SQL.

**Solución:** usar cultura invariante en el adaptador y parámetros SQL tipados.

### Problema: "El valor de parámetro '2100,00' está fuera del intervalo"
**Causa:** `21.00` se interpretó como `2100.00` antes de invocar SQL Server.

**Solución:** reiniciar la API con la versión que usa cultura invariante y enviar
decimales JSON con punto, sin comillas.

### Problema: "Procedure or function spCalcularDecision has too many arguments"
**Causa:** SP en BD no tiene la firma actualizada
**Solución:** Ejecutar `sqlcmd -i spCalcularDecision.sql` para actualizar

### Problema: "No existe una estrategia activa configurada"
**Causa:** No hay registro en `Estrategias` con Activa=1 para la empresa
**Solución:** Crear estrategia: `INSERT INTO Estrategias (EmpresaID, Nombre, Activa) VALUES (1, 'Default', 1)`

### Problema: Stock se clasifica como NULL
**Causa:** Modo TEMP sin parámetro `@StockActual`
**Solución:** Incluir `"stockDisponible"` en JSON (es obligatorio en simulación)

---

## Versión y Changelog

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | Jun 2026 | Motor base con reglas y restricciones |
| 2.0 | Jul 2026 | Arquitectura adaptadores, API endpoints |
| **2.1** | **15/08/2026** | **ISNULL protección, Simulación/Producción unificadas** |
| **2.2** | **15/08/2026** | **Parseo invariante de JSON y parámetros SQL tipados** |

---

**Documentación Versión:** 2.1  
**Última Actualización:** 15/08/2026  
**Responsable:** Sistema de Pricing - Motor v2.1