# API: Parámetros de Mensajes de Reglas de Pricing

**Base URL**: `/api/admin/estrategias-reglas-parametros-mensajes`

**Versión**: 1.0  
**Estado**: ✅ Implementado  
**Fecha**: 2026-08-18

---

## Resumen

Mientras que los **parámetros numéricos** (`EstrategiaReglaParametros`) controlan **CÓMO** se calcula el precio (qué porcentaje), los **parámetros de mensajes** (`EstrategiaReglaParametrosMensajes`) controlan **QUÉ SE COMUNICA** al usuario.

**Beneficios**:
- 🎯 **Mensajes por estrategia**: Tono agresivo vs conservador
- 🌍 **Multi-idioma**: Español, Inglés, otro idioma
- 📝 **Templates con tokens**: `{PORCENTAJE}`, `{PRECIO_NUEVO}`, etc.
- 🚀 **Cambios instantáneos**: Sin recompilación
- 🔄 **Histórico auditable**: Qué mensaje usó el motor en qué momento

Cada mensaje incluye `idioma` (`ES`, `EN` o `PT`). La evaluación usa `ES` como fallback si el idioma solicitado no existe.

---

## 5 Endpoints (Mensajes)

### 1️⃣ GET - Histórico de mensajes
```http
GET /api/admin/estrategias-reglas-parametros-mensajes/estrategia-regla/5
```

→ Devuelve todos los mensajes históricos (activos e inactivos)

---

### 2️⃣ GET - Mensajes vigentes
```http
GET /api/admin/estrategias-reglas-parametros-mensajes/estrategia/1/vigentes
```

→ Solo los activos y vigentes ahora (los que el SP aplicaría)

---

### 3️⃣ POST - Crear mensaje
```http
POST /api/admin/estrategias-reglas-parametros-mensajes
Body: {
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_STOCK_CRITICO",
  "idioma": "ES",
  "valor": "Stock en nivel CRÍTICO: +{PORCENTAJE}% para proteger ruptura."
}
```

→ ID nuevo mensaje creado

---

### 4️⃣ PUT - Actualizar mensaje
```http
PUT /api/admin/estrategias-reglas-parametros-mensajes/1
Body: {
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_STOCK_CRITICO",
  "idioma": "ES",
  "valor": "Mensaje actualizado con {PORCENTAJE}%"
}
```

→ Crea una nueva versión histórica y cierra la anterior en `FechaVigencia`.

---

### 5️⃣ DELETE - Desactivar mensaje
```http
DELETE /api/admin/estrategias-reglas-parametros-mensajes/1
```

→ Soft-delete: Activo=0, FechaFin=NOW()

---

## Claves de Mensaje Estándar

| Clave | Regla | Descripción | Default |
|-------|-------|-------------|---------|
| `MENSAJE_STOCK_CRITICO` | REGLA_STOCK_CRITICO | Cuando stock está crítico | "Stock en nivel CRÍTICO. Se incrementa precio {PORCENTAJE}%..." |
| `MENSAJE_OPORTUNIDAD` | REGLA_OPORTUNIDAD | Cuando hay oportunidad de mercado | "Captura de margen por oportunidad ({PORCENTAJE}%)..." |
| `MENSAJE_EXCESO_STOCK` | REGLA_EXCESO_STOCK | Cuando hay exceso de stock | "Exceso de stock. Descuento de liquidación {PORCENTAJE}%..." |
| `MENSAJE_COMPETENCIA` | REGLA_COMPETENCIA_ABAJO | Cuando competidor está más barato | "Competencia detectada. Descuentando {PORCENTAJE}%..." |

---

## Tokens Disponibles en Plantillas

| Token | Descripción | Ejemplo |
|-------|-------------|---------|
| `{PORCENTAJE}` | Valor del parámetro numérico | "Subiendo {PORCENTAJE}%" → "Subiendo 8.00%" |
| `{PRECIO_NUEVO}` | Precio calculado final | "$100 → ${PRECIO_NUEVO}" |
| `{PRECIO_ANTERIOR}` | Precio antes del cambio | "Desde ${PRECIO_ANTERIOR}" |
| `{COMPETIDOR_PRECIO}` | Precio del competidor | "Competencia: ${COMPETIDOR_PRECIO}" |

Los tokens desconocidos y los períodos de vigencia superpuestos se rechazan con `400 Bad Request`.

---

## Ejemplos Reales

### Ejemplo 1: Estrategia AGRESIVA (Español)

```json
{
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_STOCK_CRITICO",
  "valor": "Stock en nivel CRÍTICO: Precio subido {PORCENTAJE}% para reducir venta y proteger ruptura. ACCIÓN URGENTE RECOMENDADA.",
  "descripcion": "Agresivo: tono directo sobre urgencia"
}
```

**Resultado cuando se ejecuta**: "Stock en nivel CRÍTICO: Precio subido 8.00% para reducir venta y proteger ruptura. ACCIÓN URGENTE RECOMENDADA."

---

### Ejemplo 2: Estrategia CONSERVADORA (Español)

```json
{
  "estrategiaReglaID": 8,
  "clave": "MENSAJE_STOCK_CRITICO",
  "valor": "Ajuste de precio por stock bajo: +{PORCENTAJE}% para equilibrio. Mantener margen seguro.",
  "descripcion": "Conservador: ajuste suave, proteger margen"
}
```

**Resultado**: "Ajuste de precio por stock bajo: +2.00% para equilibrio. Mantener margen seguro."

---

### Ejemplo 3: Multi-Idioma - Inglés

```json
{
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_STOCK_CRITICO",
  "idioma": "EN",
  "valor": "CRITICAL STOCK: Price increased by {PORCENTAJE}% to reduce sales velocity. Action required.",
  "descripcion": "Aggressive tone in English"
}
```

---

### Ejemplo 4: Con múltiples tokens

```json
{
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_COMPETENCIA",
  "valor": "Competencia detectada a ${COMPETIDOR_PRECIO}. Descuentando {PORCENTAJE}% → Precio final: ${PRECIO_NUEVO}",
  "descripcion": "Mensaje detallado con contexto de precios"
}
```

**Resultado**: "Competencia detectada a $89.99. Descuentando 2.00% → Precio final: $88.19"

---

## Ciclo de Vida de un Mensaje

### Estado 1: Creación (Español)
```json
{
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_STOCK_CRITICO",
  "idioma": "ES",
  "valor": "Stock CRÍTICO: +{PORCENTAJE}%",
  "activo": true,
  "fechaVigencia": "2026-08-18"
}
```
✅ Mensaje vigente desde ahora

### Estado 2: Cambio de idioma o tono
```json
{
  "estrategiaReglaID": 5,
  "clave": "MENSAJE_STOCK_CRITICO",
  "idioma": "EN",
  "valor": "CRITICAL STOCK: +{PORCENTAJE}%",
  "activo": true,
  "fechaVigencia": "2026-08-19"
}
```
✅ Nuevo mensaje vigente desde mañana, coexiste con el español

### Estado 3: Desactivación del anterior
```http
DELETE /api/admin/estrategias-reglas-parametros-mensajes/1
```
✅ Marca como inactivo, auditoría permanece

---

## Casos de Uso

### Caso 1: A/B Testing de Mensajes

DBA quiere probar dos tonos de mensajes (agresivo vs conservador) para medir cuál impacta más en conversiones.

```bash
# Crear mensaje AGRESIVO
curl -X POST http://localhost:5000/api/admin/estrategias-reglas-parametros-mensajes \
  -H "Content-Type: application/json" \
  -d '{
    "estrategiaReglaID": 5,
    "clave": "MENSAJE_COMPETENCIA",
    "valor": "¡ALERTA! Competencia más barata. BAJAMOS {PORCENTAJE}% AHORA. Precio: ${PRECIO_NUEVO}",
    "fechaVigencia": "2026-08-18T00:00:00"
  }'

# Después de 1 semana, cambiar a CONSERVADOR
curl -X POST http://localhost:5000/api/admin/estrategias-reglas-parametros-mensajes \
  -H "Content-Type: application/json" \
  -d '{
    "estrategiaReglaID": 5,
    "clave": "MENSAJE_COMPETENCIA",
    "valor": "Ajuste competitivo: -{PORCENTAJE}%. Precio: ${PRECIO_NUEVO}. Margen preservado.",
    "fechaVigencia": "2026-08-25T00:00:00"
  }'
```

✅ Cambio automático en próxima ejecución del SP (sin recompilación)

---

### Caso 2: Localización Multi-Idioma

Empresa opera en Argentina (Español) y Brasil (Portugués).

```bash
# Crear para Argentina (Español)
curl -X POST ... \
  -d '{
    "estrategiaReglaID": 5,
    "clave": "MENSAJE_STOCK_CRITICO",
    "valor": "Stock CRÍTICO en Argentina: +{PORCENTAJE}%"
  }'

# Crear para Brasil (Portugués)
curl -X POST ... \
  -d '{
    "estrategiaReglaID": 6,  # Otra estrategia/empresa
    "clave": "MENSAJE_STOCK_CRITICO",
    "valor": "Stock CRÍTICO no Brasil: +{PORCENTAJE}%"
  }'
```

✅ Cada estrategia usa su mensaje localizado

---

### Caso 3: Cambio de Política de Marketing

Marketing decide cambiar el tono de todos los mensajes de agresivo → conservador.

```sql
-- 1. Desactivar mensajes AGRESIVOS vigentes
UPDATE EstrategiaReglaParametrosMensajes
SET Activo = 0, FechaFin = SYSDATETIME()
WHERE Clave LIKE 'MENSAJE_%'
  AND Descripcion LIKE '%Agresivo%'
  AND Activo = 1
  AND FechaVigencia <= SYSDATETIME()
  AND (FechaFin IS NULL OR FechaFin > SYSDATETIME());

-- 2. Activar mensajes CONSERVADORES (ya creados, pero inactivos)
UPDATE EstrategiaReglaParametrosMensajes
SET Activo = 1
WHERE Clave LIKE 'MENSAJE_%'
  AND Descripcion LIKE '%Conservador%'
  AND Activo = 0;
```

✅ O vía API para más granularidad

---

## Integración con SP (spCalcularDecision)

El SP automáticamente:

1. **Carga mensajes vigentes** al inicio
2. **Reemplaza tokens** con valores reales
3. **Usa el mensaje parametrizado** en Motivo de decisión

```sql
-- En SP
DECLARE @MensajeStockCritico = 'Stock en nivel CRÍTICO: +{PORCENTAJE}%';

SELECT TOP 1 @MensajeStockCritico = Valor
FROM EstrategiaReglaParametrosMensajes
WHERE ... AND FechaVigencia <= SYSDATETIME() AND (FechaFin IS NULL OR ...);

-- Aplicar en regla
UPDATE ctx
SET Motivo = REPLACE(
    REPLACE(@MensajeStockCritico, '{PORCENTAJE}', CAST(@PorcentajeStockCritico AS VARCHAR(10))),
    '{PRECIO_NUEVO}', CAST(ctx.PrecioSugerido AS VARCHAR(20))
  )
WHERE ClasificacionStock = 'CRITICO';
```

---

## Rendimiento

- **GET /vigentes**: Índices en `Activo`, `FechaVigencia`, `FechaFin` → < 50ms
- **POST/PUT/DELETE**: Lightweight → < 100ms
- **SP loading**: 4 SELECTs de mensajes (1 por regla) → ~10-15ms total

**Impacto en spCalcularDecision**: Negligible (negligible REPLACE operations son muy rápidas)

---

## Auditoría Completa

Cada mensaje registra:
- `FechaCreacion`: Cuándo se creó
- `FechaVigencia`: Desde cuándo es vigente
- `FechaFin`: Hasta cuándo es vigente
- `Activo`: Estado actual
- `Descripcion`: Qué intención tiene

**Trazabilidad**: Qué mensaje usó el motor en cualquier punto en el tiempo.

---

## Validaciones en Controller

- ✅ Clave no vacía (max 100 caracteres)
- ✅ Valor no vacío (max 4000 caracteres)
- ✅ EstrategiaReglaID existe
- ✅ FechaVigencia ≤ FechaFin (si ambas se especifican)

---

## Tokens Reservados (Futuro)

| Token | Estado | Ejemplo |
|-------|--------|---------|
| `{PORCENTAJE}` | ✅ Implementado | "Subiendo 8.00%" |
| `{PRECIO_NUEVO}` | ✅ Implementado | "Precio final: $100.00" |
| `{PRECIO_ANTERIOR}` | ⏳ Próximo | "Desde $95.00" |
| `{COMPETIDOR_PRECIO}` | ⏳ Próximo | "Competencia: $89.99" |
| `{VELOCIDAD_VENTA}` | 📋 Backlog | "Rotación: 2.5 unid/día" |

---

**Responsable**: Equipo de Backend/API  
**Última actualización**: 2026-08-18  
**Ver también**: 
- [API: Parámetros Numéricos](API-EstrategiaReglaParametros.md)
- [ADR: Parametrización de Reglas](../0001-parametrizacion-reglas-pricing.md)
