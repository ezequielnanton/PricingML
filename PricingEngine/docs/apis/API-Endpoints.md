# API Endpoints - Pricing Engine

## Resumen general

Este documento describe todas las APIs expuestas por el Pricing Engine en el MVP actual. La implementación respeta la arquitectura de adaptadores, siendo el único punto activo de ingestión el adaptador UI (UiAdapter).

### Endpoints disponibles

**Salud y Evaluación**:
- `GET /health` - Estado del servicio
- `POST /pricing/evaluate` - Evaluación (legacy, con opción de persistir)
- `POST /api/input/ui/product` - Ingestión UI (recomendado)

**Admin CRUD** (bajo `/api/admin/`):
- Empresas, Estrategias, Reglas, Monedas, Cotizaciones, Parámetros, Cuentas ML, y más

**Reportes** (planeado, no activo):
- `GET /api/reports/*` - Próxima fase

---

## 1. Salud y Evaluación

### GET /health

**Propósito**: Verificar estado del servicio.

| Campo | Valor |
|-------|-------|
| METHOD | GET |
| URL | `/health` |
| Auth | Ninguno |
| Body | Vacío |

**Response** (200 OK):
```json
{
  "status": "ok"
}
```

**Códigos HTTP**:
- `200 OK` - Servicio operativo
- `500 Internal Server Error` - Error de conectividad

**Notas**: Usado por monitorización y health checks de orquestadores (Kubernetes, etc).

---

### POST /pricing/evaluate

**Propósito**: Evaluación directa de un producto (modo backward compatibility). Mapea payload con UiAdapter a ProductoInput, opcionalmente persiste datos, e invoca motor.

| Campo | Valor |
|-------|-------|
| METHOD | POST |
| URL | `/pricing/evaluate` |
| Auth | Ninguno (CORS habilitado) |
| Content-Type | application/json |

**Request Body** (UiPricingRequest):
```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "titulo": "Auriculares Bluetooth",
  "precioPropuesto": 46000.0,
  "precioMinimoPermitido": 41400.0,
  "precioMaximoPermitido": 55200.0,
  "stockDisponible": 8,
  "stockMinimo": 5,
  "stockMaximo": 20,
  "costoBase": 31000.0,
  "iva": 21.0,
  "comisionMLPorc": 9.0,
  "costoEnvioPromedio": 500.0,
  "costoLogisticoFijo": 1000.0,
  "costoFinancieroPorc": 2.5,
  "costoPublicidadPorc": 1.0,
  "estadoPublicacion": "active",
  "origen": "UI",
  "modoSimulacion": true,
  "persistir": false
}
```

**Response** (200 OK):
```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "precioActual": 46000.0,
  "precioSugerido": 45500.0,
  "accion": "MANTENER",
  "motivo": "Margen dentro de límites",
  "margenActualPorc": 22.5,
  "scoreConfianza": 87.3,
  "modoSimulacion": true,
  "fuenteOrigen": "UI"
}
```

**Códigos HTTP**:
- `200 OK` - Evaluación exitosa
- `400 Bad Request` - Validación fallida (SKU vacío, precio ≤ 0, costo ≤ 0)
- `404 Not Found` - Empresa inexistente (si `persistir == true`)
- `500 Internal Server Error` - Error de persistencia o motor

**Validaciones**:
- `sku` no puede ser vacío
- `precioPropuesto` debe ser > 0
- `costoBase` debe ser > 0
- `empresaId` debe existir (si `persistir == true`)

**Tablas Afectadas** (si `persistir == true`):
- `Productos` (upsert con clave: EmpresaID + SKU)
- `CostosProducto` (upsert)
- `StockEstado` (upsert)

**Flujo**:
```
1. Validar request
2. Si persistir == true:
   - Iniciar transacción
   - Upsert Productos
   - Upsert CostosProducto
   - Upsert StockEstado
   - Commit (o rollback on error)
3. Invocar spCalcularDecision
4. Retornar resultado
```

**Notas**:
- Si `persistir == false`, no hay efectos secundarios en BD
- Si `persistir == true` y falla, rollback automático
- El motor siempre se ejecuta en modo simulación (no encola para ejecución)

---

### POST /api/input/ui/product

**Propósito**: Ingestión desde UI (punto de entrada recomendado). Recibe datos, normaliza con UiAdapter, persiste transaccionalmente en tablas core, opcionalmente ejecuta evaluación.

| Campo | Valor |
|-------|-------|
| METHOD | POST |
| URL | `/api/input/ui/product` |
| Auth | Ninguno (CORS habilitado) |
| Content-Type | application/json |

**Request Body**: Idéntico a `/pricing/evaluate` (UiPricingRequest)

**Response** (201 Created):
```json
{
  "productoId": 123,
  "sku": "SKU-001",
  "empresaId": 1,
  "decision": {
    "empresaId": 1,
    "sku": "SKU-001",
    "precioActual": 46000.0,
    "precioSugerido": 45500.0,
    "accion": "MANTENER",
    "motivo": "Margen dentro de límites",
    "margenActualPorc": 22.5,
    "scoreConfianza": 87.3,
    "modoSimulacion": true,
    "fuenteOrigen": "UI"
  }
}
```

**Códigos HTTP**:
- `201 Created` - Ingesta y persistencia correcta
- `400 Bad Request` - Validación fallida
- `404 Not Found` - Empresa inexistente
- `500 Internal Server Error` - Error SQL o de negocio

**Transacción**: SÍ — todo el upsert se realiza en una única transacción para garantizar integridad.

**Tablas Afectadas**:
- `Productos`
- `CostosProducto`
- `StockEstado`
- `DecisionesHistorial` (si se ejecuta evaluación)
- `DecisionesDetalleAuditoria` (si se ejecuta evaluación)

**Notas**:
- La ingesta siempre persiste (no hay flag de skip)
- La decisión se ejecuta según `modoSimulacion` en el request
- Duplicados SKU: la implementación hace upsert, no insert único
- On error: rollback automático de toda transacción

---

## 2. Admin CRUD Endpoints

Todos bajo `/api/admin/`. Realizan operaciones CRUD sobre datos maestros.

### Empresas

**GET /api/admin/empresas/{id}**
- Obtener empresa por ID
- Response: `EmpresaDto` { id, razonSocial, cuit, activo, fechaCreacion }

**POST /api/admin/empresas**
- Crear nueva empresa
- Body: `{ razonSocial, cuit }`
- Response: 201 Created con `EmpresaDto`

**PUT /api/admin/empresas/{id}**
- Actualizar empresa
- Body: `{ razonSocial, cuit, activo }`
- Response: 200 OK con `EmpresaDto`

**DELETE /api/admin/empresas/{id}**
- Eliminar empresa
- Response: 204 No Content

---

### Productos

**GET /api/admin/productos/{id}**
- Obtener producto por ID
- Response: `ProductoDto`

**POST /api/admin/productos**
- Crear producto
- Body: `{ empresaId, sku, titulo, categoriaId?, marca?, modelo? }`
- Response: 201 Created

---

### Estrategias y Reglas

**GET /api/admin/estrategias/{id}**
- Obtener estrategia (read-only en MVP)
- Response: `EstrategiaDto` { id, nombre, descripcion, activa }

**GET /api/admin/reglas/{id}**
- Obtener regla (read-only en MVP)
- Response: `ReglaNegocioDto` { id, codigo, tipo, descripcion }

---

### Monedas y Cotizaciones

**POST /api/admin/monedas**
- Crear moneda
- Body: `{ codigoISO, nombre, simbolo }`
- Response: 201 Created con `MonedaDto`

**POST /api/admin/cotizaciones**
- Registrar cotización histórica
- Body: `{ monedaId, cotizacion, fechaCotizacion }`
- Response: 201 Created con `CotizacionDto`

---

### Cuentas Mercado Libre

**POST /api/admin/cuentas-ml**
- Registrar cuenta de Mercado Libre
- Body: `{ empresaId, userIdMl, nicknameMl, accessToken, refreshToken }`
- Response: 201 Created con `CuentaMlDto`

---

### Parámetros de Configuración

**POST /api/admin/parametros-generales**
- Configurar monedas por empresa
- Body: `{ empresaId, monedaPrincipalId, monedaSecundariaId }`
- Response: 201 Created

**GET /api/admin/configuracion-parametros?empresaId=X&clave=Y**
- Obtener parámetro de config
- Response: `ConfiguracionParametroDto`

---

## 3. Reportes (Futuro)

### GET /api/reports/decisiones

**Propósito**: Listar decisiones con filtros, paginación y ordenamiento.

**Query Parameters**:
- `page=1` (default)
- `pageSize=50` (default, máximo 100)
- `filters=...` (JSON de filtros, p.ej., `{"empresaId":1,"accion":"DISMINUIR"}`)
- `sort=...` (p.ej., `"fechaDecision:desc,margenPorc:asc"`)

**Response** (200 OK):
```json
{
  "page": 1,
  "pageSize": 50,
  "total": 342,
  "data": [
    {
      "decisonId": 1001,
      "empresaId": 1,
      "sku": "SKU-001",
      "precioSugerido": 45500.0,
      "accion": "MANTENER",
      "margenPorc": 22.5,
      "fechaDecision": "2026-08-18T14:30:00Z"
    }
  ]
}
```

**Filtros soportados** (type-aware):
- `contains`: búsqueda textual
- `eq`: igualdad exacta
- `gte`: mayor o igual
- `lt`: menor que

**Notas**: 
- SQL injection protegido (whitelist de columnas y validación de operadores)
- Campos camelCase en response (conversión desde snake_case de BD)

---

## 4. Consideraciones generales

### Autenticación y Autorización
- MVP sin autenticación (CORS habilitado para localhost:3000, localhost:4200, localhost:5173)
- Fase 2: Implementar JWT o similar

### CORS
```csharp
AllowedOrigins: ["http://localhost:3000", "http://localhost:4200", "http://localhost:5173"]
AllowedMethods: GET, POST, PUT, DELETE, OPTIONS
AllowedHeaders: *
```

### Documentación interactiva
- Swagger disponible en `/swagger` (desarrollo)
- Deshabilitar en producción

### Errores comunes
| Error | Causa | Solución |
|-------|-------|----------|
| 404 Empresa | EmpresaId no existe | Crear empresa primero con POST /api/admin/empresas |
| 400 SKU vacío | Validación adapter | Proporcionar sku válido |
| 500 Connection timeout | BD desconectada | Verificar PRICES_DB existe y connection string |

### Modelos de datos principales

**UiPricingRequest** → Entrada de UI
**PricingDecisionResult** → Salida de evaluación
**ProductoDto, EmpresaDto, etc.** → DTOs para Admin CRUD
**AdminReportsQuery** → Filtros y paginación para reportes

---

## 5. Ejemplos completos

### Ejemplo 1: Evaluar un producto en simulación

```bash
curl -X POST http://localhost:5000/pricing/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "empresaId": 1,
    "sku": "TEST-001",
    "titulo": "Producto Test",
    "precioPropuesto": 1000.0,
    "precioMinimoPermitido": 800.0,
    "precioMaximoPermitido": 1200.0,
    "stockDisponible": 10,
    "stockMinimo": 5,
    "stockMaximo": 50,
    "costoBase": 600.0,
    "iva": 21.0,
    "comisionMLPorc": 9.0,
    "modoSimulacion": true,
    "persistir": false
  }'
```

### Ejemplo 2: Ingerir datos desde UI (con persistencia)

```bash
curl -X POST http://localhost:5000/api/input/ui/product \
  -H "Content-Type: application/json" \
  -d '{
    "empresaId": 1,
    "sku": "PROD-001",
    "titulo": "Producto Persistido",
    "precioPropuesto": 5000.0,
    "precioMinimoPermitido": 4000.0,
    "precioMaximoPermitido": 6000.0,
    "stockDisponible": 20,
    "stockMinimo": 10,
    "stockMaximo": 100,
    "costoBase": 3000.0,
    "iva": 21.0,
    "comisionMLPorc": 9.0,
    "modoSimulacion": false,
    "persistir": true
  }'
```

### Ejemplo 3: Crear empresa

```bash
curl -X POST http://localhost:5000/api/admin/empresas \
  -H "Content-Type: application/json" \
  -d '{
    "razonSocial": "Mi Empresa LTDA",
    "cuit": "30123456789"
  }'
```

---

## 6. Recursos adicionales

- [CONTEXT.md](../../CONTEXT.md) - Lenguaje de dominio y relaciones
- [Arquitectura-Adaptadores.md](../Arquitectura-Adaptadores.md) - Patrón de normalización
- [README.md](../../README.md) - Visión general del proyecto
