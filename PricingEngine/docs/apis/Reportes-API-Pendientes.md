# Especificación de reportes para Backend

## Objetivo

Implementar reportes de solo lectura para todas las tablas del dominio de pricing. La UI consume estas rutas desde la sección Reportes y requiere un contrato uniforme, parametrizado y seguro.

## Relación con la navegación actual

La UI actual presenta Reportes como una sección principal con submenús por recurso. La carga de cada reporte no se dispara automáticamente con el cambio de pestaña: la acción explícita es Ejecutar. Esto mantiene la experiencia consistente con la lógica de filtros y validación definida por la aplicación.

> La regla clave del frontend es que el usuario selecciona un reporte, configura filtros, y presiona Ejecutar. La UI no dispara la consulta automáticamente al cambiar de pestaña ni por cada keystroke.

## Contrato común

Todos los endpoints usan `GET /api/admin/{recurso-en-plural}` y responden con `200 OK`:

```json
{
  "items": [{ "campoDeTabla": "valor" }],
  "page": 1,
  "pageSize": 50,
  "totalCount": 123
}
```

Requisitos:

- `items` es la proyección completa de los registros de la tabla, serializada en `camelCase`.
- Los nombres de campo en la respuesta deben ser los mismos que usa el frontend para parametrizar filtros.
- `page` es opcional, mínimo `1`, por defecto `1`.
- `pageSize` es opcional, por defecto `50`, mínimo `1` y máximo `100`.
- Si no hay registros, devolver `200` con `items: []` y `totalCount: 0`; nunca `404`.
- Solo se pueden omitir columnas sensibles, y esa omisión debe documentarse por recurso.

## Catálogo de reportes públicos

La UI genera los reportes desde el esquema SQL en [SQL/Estructura.sql](../../SQL/Estructura.sql). Los recursos publicados bajo `/api/admin` deben ser estos:

| Recurso | Endpoint | Tabla de origen |
| --- | --- | --- |
| empresas | `GET /api/admin/empresas` | `Empresas` |
| monedas | `GET /api/admin/monedas` | `Monedas` |
| cotizaciones | `GET /api/admin/cotizaciones` | `Cotizaciones` |
| parametrosGenerales | `GET /api/admin/parametros-generales` | `ParametrosGenerales` |
| cuentasMl | `GET /api/admin/cuentas-ml` | `CuentasML` |
| productos | `GET /api/admin/productos` | `Productos` |
| costosProducto | `GET /api/admin/costos-producto` | `CostosProducto` |
| publicacionesMl | `GET /api/admin/publicaciones-ml` | `PublicacionesML` |
| stockEstado | `GET /api/admin/stock-estado` | `StockEstado` |
| metricasVentas | `GET /api/admin/metricas-ventas-hist` | `MetricasVentasHist` |
| competencia | `GET /api/admin/competencia-snapshot` | `CompetenciaSnapshot` |
| estrategias | `GET /api/admin/estrategias` | `Estrategias` |
| reglas | `GET /api/admin/reglas` | `ReglasNegocio` |
| estrategiaReglas | `GET /api/admin/estrategia-reglas` | `EstrategiaReglas` |
| configuracionParametros | `GET /api/admin/configuracion-parametros` | `ConfiguracionParametros` |
| decisiones | `GET /api/admin/decisiones` | `DecisionesHistorial` |
| decisionesDetalle | `GET /api/admin/decisiones-detalle-auditoria` | `DecisionesDetalleAuditoria` |
| colaEjecucion | `GET /api/admin/cola-ejecucion-ml` | `ColaEjecucionML` |

> `GET /api/pricing/decisiones` queda obsoleto; la UI ya no debe consumirlo.

## Filtros dinámicos

La UI envía filtros como `filter[campo][operador]=valor` en todos los reportes.

### Sintaxis canónica

```http
GET /api/admin/empresas?filter[empresaID][gte]=100&filter[activo][eq]=true
GET /api/admin/productos?filter[sku][contains]=ABC&filter[precioActual][gte]=1500
GET /api/admin/decisiones?filter[fechaDecision][gte]=2026-01-01&filter[fechaDecision][lte]=2026-01-31
```

### Operadores permitidos

- `eq`
- `contains`
- `startsWith`
- `endsWith`
- `gt`
- `gte`
- `lt`
- `lte`
- `in`
- `isNull`

### Reglas por tipo

- Texto / strings: `contains` usa coincidencia parcial con `LIKE` parametrizado.
- Números: `eq`, `gt`, `gte`, `lt`, `lte` comparan numéricamente.
- Booleanos: usar `eq=true` o `eq=false`.
- Fechas / DateTime: usar ISO-8601 o una fecha SQL válida. En rango, si se usa `lte`, el límite superior debe incluir todo el día seleccionado.
- `in`: valores separados por coma.
- `isNull`: aceptar `true` o `false`.

### Validaciones del backend

Debe responder con `400 Bad Request` si:

- el campo no existe en la tabla/recurso;
- el operador no es válido para el tipo de dato;
- el valor no puede convertirse al tipo esperado;
- `pageSize` supera `100`;
- un rango tiene `from > to`;
- el `sort` incluye un campo inexistente o dirección inválida.

### Seguridad

No concatenar valores de usuario en SQL. Debe usarse:

- parámetros SQL;
- validación de whitelist de columnas y operadores;
- isomorfismo de tipos para cada recurso.

## Ordenamiento

```http
GET /api/admin/productos?sort=sku:asc,productoId:desc
```

Reglas:

- `sort` acepta uno o más criterios del tipo `campo:asc|desc`, separados por coma.
- Validar campos y dirección.
- Si no se envía `sort`, aplicar un orden determinista por default:
  - tablas maestras/operativas: clave primaria ascendente
  - historial/auditoría/cola: fecha descendente, luego ID descendente

## Validaciones para frontend y backend

La UI usa un patrón de ejecución manual:

1. seleccionar reporte;
2. completar filtros;
3. validar filtro/rango;
4. presionar Ejecutar;
5. enviar request con `page` y `pageSize`.

El backend no debe intentar ejecutar o auto-disparar búsquedas al cambiar de pestaña; eso es responsabilidad del cliente.

## Ejemplo de respuesta realista

```json
{
  "items": [
    {
      "empresaID": 1,
      "razonSocial": "ACME S.A.",
      "cUIT": "30-12345678-9",
      "activo": true,
      "fechaCreacion": "2026-01-15T10:30:00.000Z"
    }
  ],
  "page": 1,
  "pageSize": 50,
  "totalCount": 1
}
```

## Criterios de aceptación para el backend

1. Cada recurso expuesto bajo `/api/admin` responde con el envelope paginado común.
2. Cada campo público de cada tabla es filtrable y combinable con AND.
3. Los campos de texto aceptan `contains` parcial de manera segura.
4. Los rangos numéricos y de fecha soportan `gte`/`lte` sin obligar a completar ambos valores.
5. `sort` funciona por cualquier campo del recurso.
6. Se devuelve `400` para campos/operadores inválidos.
7. Se usan consultas parametrizadas y no concatenación de strings.
8. La respuesta usa `camelCase` y mantiene la relevancia de los campos del SQL.

## Sensibilidad de columnas

Las columnas sensibles no deben exponerse en reportes ni ser filtrables. En este esquema, `AccessToken` y `RefreshToken` de `CuentasML` son técnicamente sensibles y deben quedar fuera del recurso público.

## Impacto en Frontend

La UI en `pricing-ui/src/components/ReportsPanel.jsx` consulta estas rutas con:

- `page`
- `pageSize`
- `sort`
- `filter[campo][operador]=valor`

El backend debe responder con el envelope paginado para que la navegación y los conteos sean correctos.
