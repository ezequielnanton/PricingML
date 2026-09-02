# API: Administración de Parámetros de Reglas de Pricing

**Base URL**: `/api/admin/estrategias-reglas-parametros`

**Versión**: 1.0  
**Estado**: ✅ Implementado  
**Fecha**: 2026-08-18

---

## Endpoints

### 1. Obtener parámetros de una regla de estrategia

```http
GET /api/admin/estrategias-reglas-parametros/estrategia-regla/{estrategiaReglaID}
```

**Descripción**: Obtiene todos los parámetros históricos (activos e inactivos) de una vinculación Estrategia-Regla.

**Parámetros de ruta**:
- `estrategiaReglaID` (int): ID de la vinculación Estrategia-Regla

**Respuesta exitosa (200 OK)**:
```json
[
  {
    "parametroID": 1,
    "estrategiaReglaID": 5,
    "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
    "valor": 8.00,
    "descripcion": "Agresiva: Sube 8% si stock crítico",
    "fechaVigencia": "2026-08-18T00:00:00",
    "fechaFin": null,
    "activo": true,
    "fechaCreacion": "2026-08-18T10:30:00",
    "estrategiaNombre": "AGRESIVA",
    "reglaCodigo": "REGLA_STOCK_CRITICO",
    "reglaDescripcion": "Stock en nivel crítico"
  }
]
```

**Ordenamiento**: Por `FechaVigencia DESC` (más reciente primero)

**Casos de error**:
- `500 Internal Server Error`: Error en base de datos

---

### 2. Obtener parámetros vigentes de una estrategia

```http
GET /api/admin/estrategias-reglas-parametros/estrategia/{estrategiaID}/vigentes
```

**Descripción**: Obtiene solo los parámetros **activos y vigentes en este momento** de todas las reglas de una estrategia. Estos son los valores que el SP usa para calcular decisiones.

**Parámetros de ruta**:
- `estrategiaID` (int): ID de la estrategia

**Filtros aplicados automáticamente**:
- `Activo = 1` (solo parámetros activos)
- `FechaVigencia <= SYSDATETIME()` (ya empezó su vigencia)
- `FechaFin IS NULL OR FechaFin > SYSDATETIME()` (no ha terminado su vigencia)

**Respuesta exitosa (200 OK)**:
```json
[
  {
    "parametroID": 1,
    "estrategiaReglaID": 5,
    "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
    "valor": 8.00,
    "descripcion": "Agresiva: Sube 8% si stock crítico",
    "fechaVigencia": "2026-08-18T00:00:00",
    "fechaFin": null,
    "activo": true,
    "fechaCreacion": "2026-08-18T10:30:00",
    "estrategiaNombre": "AGRESIVA",
    "reglaCodigo": "REGLA_STOCK_CRITICO",
    "reglaDescripcion": "Stock en nivel crítico"
  },
  {
    "parametroID": 2,
    "estrategiaReglaID": 6,
    "clave": "PORCENTAJE_INCREMENTO_OPORTUNIDAD",
    "valor": 5.00,
    "descripcion": "Agresiva: Sube 5% si oportunidad",
    ...
  }
]
```

**Ordenamiento**: Por `ReglaCodigo`, luego `Clave`

**Casos de error**:
- `404 Not Found`: No hay parámetros vigentes
- `500 Internal Server Error`: Error en base de datos

---

### 3. Crear nuevo parámetro

```http
POST /api/admin/estrategias-reglas-parametros
Content-Type: application/json
```

**Descripción**: Crea un nuevo parámetro para una regla dentro de una estrategia.

**Body (JSON)**:
```json
{
  "estrategiaReglaID": 5,
  "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
  "valor": 8.00,
  "descripcion": "Agresiva: Sube 8% si stock crítico",
  "fechaVigencia": "2026-08-18T00:00:00",
  "fechaFin": null,
  "activo": true
}
```

**Campos opcionales**:
- `descripcion` (string, nullable): Descripción del parámetro
- `fechaVigencia` (datetime, optional): Default: `NOW()`. Cuándo comienza a ser vigente
- `fechaFin` (datetime, nullable): Cuándo deja de ser vigente (indefinido si null)
- `activo` (bool, optional): Default: `true`

**Respuesta exitosa (201 Created)**:
```json
1
```
(Devuelve solo el ID del parámetro creado)

**Casos de error**:
- `400 Bad Request`: Validación fallida (clave vacía, EstrategiaReglaID inválido)
- `500 Internal Server Error`: Error en base de datos

---

### 4. Actualizar parámetro existente

```http
PUT /api/admin/estrategias-reglas-parametros/{parametroID}
Content-Type: application/json
```

**Descripción**: Actualiza un parámetro existente. No modifica `FechaCreacion`.

**Parámetros de ruta**:
- `parametroID` (int): ID del parámetro a actualizar

**Body (JSON)**:
```json
{
  "estrategiaReglaID": 5,
  "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
  "valor": 9.00,
  "descripcion": "Agresiva: Sube 9% si stock crítico (ajustado)",
  "fechaVigencia": "2026-08-19T00:00:00",
  "fechaFin": null,
  "activo": true
}
```

**Respuesta exitosa (200 OK)**:
```json
{
  "message": "Parámetro actualizado correctamente",
  "parametroID": 1
}
```

**Casos de error**:
- `400 Bad Request`: ParametroID inválido o validación de body fallida
- `500 Internal Server Error`: Error en base de datos

---

### 5. Desactivar parámetro

```http
DELETE /api/admin/estrategias-reglas-parametros/{parametroID}
```

**Descripción**: **Desactiva** un parámetro en lugar de borrarlo (soft delete). Establece `Activo = 0` y `FechaFin = NOW()` para auditoría completa.

**Parámetros de ruta**:
- `parametroID` (int): ID del parámetro a desactivar

**Respuesta exitosa (200 OK)**:
```json
{
  "message": "Parámetro desactivado correctamente",
  "parametroID": 1
}
```

**Casos de error**:
- `400 Bad Request`: ParametroID inválido
- `500 Internal Server Error`: Error en base de datos

---

## Claves de parámetro estándar

Las siguientes claves son las soportadas por el motor de pricing:

| Clave | Descripción | Valor Típico | Rango Recomendado |
|-------|-------------|--------------|-------------------|
| `PORCENTAJE_INCREMENTO_STOCK_CRITICO` | Incremento cuando stock es crítico | 5.00 | 1.00 - 15.00 |
| `PORCENTAJE_INCREMENTO_OPORTUNIDAD` | Incremento cuando hay oportunidad de mercado | 3.00 | 0.50 - 10.00 |
| `PORCENTAJE_DECREMENTO_EXCESO_STOCK` | Decremento cuando hay exceso de stock | 7.00 | 2.00 - 20.00 |
| `PORCENTAJE_DESCUENTO_COMPETENCIA` | Descuento respecto a competidor | 1.00 | 0.10 - 5.00 |

---

## Ciclo de vida de un parámetro

### Estado 1: Creación
```json
{
  "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
  "valor": 5.00,
  "activo": true,
  "fechaVigencia": "2026-08-18",
  "fechaFin": null
}
```
✅ El parámetro está activo desde ahora, indefinidamente.

### Estado 2: Actualización (cambio de valor)
```http
PUT /api/admin/estrategias-reglas-parametros/1
{
  "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
  "valor": 8.00,  // ← cambió
  "activo": true,
  "fechaVigencia": "2026-08-19",
  "fechaFin": null
}
```
✅ El nuevo valor es vigente desde 2026-08-19.

### Estado 3: Desactivación (soft delete)
```http
DELETE /api/admin/estrategias-reglas-parametros/1
```
Internamente:
```sql
UPDATE EstrategiaReglaParametros 
SET Activo = 0, FechaFin = SYSDATETIME() 
WHERE ParametroID = 1
```
✅ El parámetro está marcado como inactivo, pero la auditoría permanece.

---

## Casos de uso

### Caso 1: Crear estrategia "AGRESIVA"
```bash
curl -X POST http://localhost:5000/api/admin/estrategias-reglas-parametros \
  -H "Content-Type: application/json" \
  -d '{
    "estrategiaReglaID": 1,
    "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
    "valor": 8.00,
    "descripcion": "Agresiva: Sube 8% si stock crítico"
  }'
```

### Caso 2: Consultar parámetros vigentes de estrategia
```bash
curl http://localhost:5000/api/admin/estrategias-reglas-parametros/estrategia/1/vigentes
```
✅ El motor usa estos valores en `spCalcularDecision`

### Caso 3: Cambiar agresividad de estrategia en tiempo real
```bash
# Obtener parámetro actual
curl http://localhost:5000/api/admin/estrategias-reglas-parametros/estrategia-regla/5

# Actualizar valor (sin recompilar SP)
curl -X PUT http://localhost:5000/api/admin/estrategias-reglas-parametros/1 \
  -H "Content-Type: application/json" \
  -d '{
    "estrategiaReglaID": 5,
    "clave": "PORCENTAJE_INCREMENTO_STOCK_CRITICO",
    "valor": 12.00,
    "fechaVigencia": "2026-08-18T15:00:00"
  }'
```

✅ Cambio efectivo inmediatamente en próximas evaluaciones de `spCalcularDecision`

### Caso 4: Rollback (volver a valor anterior)
```bash
# Desactivar parámetro nuevo
curl -X DELETE http://localhost:5000/api/admin/estrategias-reglas-parametros/3

# Crear nuevo parámetro con valor anterior (si se necesita)
curl -X POST http://localhost:5000/api/admin/estrategias-reglas-parametros \
  -d '{ "estrategiaReglaID": 5, "clave": "...", "valor": 5.00, ... }'
```

---

## Validaciones

- **EstrategiaReglaID**: Debe existir en tabla `EstrategiaReglas`
- **Clave**: No puede estar vacía, max 100 caracteres
- **Valor**: Decimal con hasta 18 dígitos, 4 decimales (DECIMAL(18,4))
- **FechaVigencia**: Debe ser <= FechaFin (si esta existe)
- **Activo**: Boolean (true/false)

---

## Auditoría

Todos los parámetros tienen:
- `FechaCreacion`: Cuándo se creó (inmutable)
- `FechaVigencia`: Desde cuándo es vigente
- `FechaFin`: Hasta cuándo es vigente (NULL = indefinido)
- `Activo`: Flag booleano

**Ejemplo de histórico**:
```
ParametroID | Valor | FechaVigencia | FechaFin | Activo
1           | 5.00  | 2026-08-18    | 2026-08-19 | 0  ← Deactivated
2           | 8.00  | 2026-08-19    | NULL   | 1  ← Current
```

Esto permite rastrear exactamente qué parámetro usó el motor en cualquier punto en el tiempo.

---

## Rendimiento

- Llamadas `GET /vigentes` usan índices en `Activo`, `FechaVigencia`, `FechaFin`
- `POST`, `PUT`, `DELETE` son operaciones lightweight (sin locks de tabla)
- Sin impacto en `spCalcularDecision` (carga parámetros 1 sola vez/ejecución)

---

## Integración con Frontend

### Componente: Administrador de Parámetros por Estrategia

Pseudo-código:
```javascript
async function showParameterAdmin(estrategiaID) {
  // Obtener parámetros vigentes
  const response = await fetch(
    `/api/admin/estrategias-reglas-parametros/estrategia/${estrategiaID}/vigentes`
  );
  const parametros = await response.json();
  
  // Renderizar tabla editable
  renderParameterTable(parametros);
}

async function updateParameter(parametroID, nuevoValor) {
  await fetch(
    `/api/admin/estrategias-reglas-parametros/${parametroID}`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ valor: nuevoValor, ... })
    }
  );
  // Refrescar y notificar
}
```

---

**Responsable**: Equipo de Backend/API  
**Última actualización**: 2026-08-18  
**Ver también**: [ADR: Parametrización de Reglas](../0001-parametrizacion-reglas-pricing.md)
