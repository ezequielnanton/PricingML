# API Admin Endpoints (CRUD for core tables)

> Especificación vigente de reportes: [Reportes-API-Pendientes.md](./Reportes-API-Pendientes.md). Define los `GET` para todas las tablas, rutas canónicas, paginación, filtros dinámicos, ordenamiento y la convención para la UI actual.

Nota: Estos endpoints exponen operaciones de creación/lectura/actualización/borrado para las tablas definidas en `SQL/Estructura.sql`. Por decisión del proyecto, las tablas de historial/auditoría no permiten `DELETE` físico.

Base URL: `/api/admin`

## Contexto de navegación actual de la UI

La sección principal de la frontend quedó organizada así:

- Pricing
- Formularios (submenú con cada tipo de entidad)
- Reportes (submenú con cada recurso)
- Documentación (submenú: Funcional, Apartado especial, Manual práctico, API docs)
- API Check

La UI ya no usa un bloque independiente de Admin ni una vista de Health con ese nombre. La comprobación de disponibilidad aparece como `API Check` en el árbol lateral y consulta `GET /health` automáticamente al entrar; no hay un botón adicional en la barra ni dentro de la pantalla.

## Reportes públicos (lectura con filtros)

La UI de Reportes ya usa un motor genérico para cada recurso y no dispara la carga automáticamente al cambiar de reporte. La consulta comienza cuando el usuario completa los filtros y presiona Ejecutar.

### Endpoints GET requeridos

- Empresas: `GET /api/admin/empresas`
- Monedas: `GET /api/admin/monedas`
- Cotizaciones: `GET /api/admin/cotizaciones`
- Parámetros generales: `GET /api/admin/parametros-generales`
- Cuentas ML: `GET /api/admin/cuentas-ml`
- Productos: `GET /api/admin/productos`
- Costos producto: `GET /api/admin/costos-producto`
- Publicaciones ML: `GET /api/admin/publicaciones-ml`
- Stock estado: `GET /api/admin/stock-estado`
- Métricas ventas: `GET /api/admin/metricas-ventas-hist`
- Competencia snapshot: `GET /api/admin/competencia-snapshot`
- Estrategias: `GET /api/admin/estrategias`
- Reglas: `GET /api/admin/reglas`
- Estrategia-Reglas: `GET /api/admin/estrategia-reglas`
- Configuración parámetros: `GET /api/admin/configuracion-parametros`
- Decisiones: `GET /api/admin/decisiones`
- Detalle auditoría: `GET /api/admin/decisiones-detalle-auditoria`
- Cola ejecución ML: `GET /api/admin/cola-ejecucion-ml`

### Contrato de respuesta

```json
{
  "items": [{ "campo": "valor" }],
  "page": 1,
  "pageSize": 50,
  "totalCount": 123
}
```

**Regla de nombres**: la respuesta debe usar `camelCase` exactamente como lo usan los filtros del frontend, por ejemplo `empresaID`, `razonSocial`, `activo`, `fechaCreacion`.

### Filtros y orden

La UI envía filtros en la forma:

```http
GET /api/admin/empresas?filter[empresaID][eq]=1&filter[activo][eq]=true
GET /api/admin/productos?filter[sku][contains]=ABC&filter[precioActual][gte]=1500
GET /api/admin/decisiones?sort=fechaDecision:desc,decisionID:desc
```

Operadores admitidos:

- `eq`, `contains`, `startsWith`, `endsWith`, `gt`, `gte`, `lt`, `lte`, `in`, `isNull`

Requisitos para backend:

- aceptar varios filtros a la vez;
- combinar filtros con `AND`;
- no concatenar strings en SQL;
- validar nombre de campo y operador antes de ejecutar;
- devolver `400` si el valor o el operador no es válido.

## Escritura y mantenimiento (POST/PUT/DELETE)

**Rutas canónicas de la API actual**:
- Empresas: `POST /api/admin/empresas`, `PUT /api/admin/empresas/{id}`, `DELETE /api/admin/empresas/{id}`
- Monedas: `POST /api/admin/monedas`, `PUT /api/admin/monedas/{id}`, `DELETE /api/admin/monedas/{id}`
- Cotizaciones: `POST /api/admin/cotizaciones`, `PUT /api/admin/cotizaciones/{id}`, `DELETE /api/admin/cotizaciones/{id}`
- Parámetros generales: `POST`, `PUT /api/admin/parametros-generales/{id}`, `DELETE /api/admin/parametros-generales/{id}` (alias: `/api/admin/parametrosgenerales`)
- Cuentas ML: `POST`, `PUT /api/admin/cuentas-ml/{id}`, `DELETE /api/admin/cuentas-ml/{id}` (alias: `/api/admin/cuentasml`)
- Productos: `POST`, `PUT /api/admin/productos/{id}`, `DELETE /api/admin/productos/{id}`
- Costos producto: `POST`, `PUT /api/admin/costos-producto/{id}`, `DELETE /api/admin/costos-producto/{id}` (alias: `/api/admin/costos`)
- Publicaciones ML: `POST`, `PUT /api/admin/publicaciones-ml/{id}`, `DELETE /api/admin/publicaciones-ml/{id}` (alias: `/api/admin/publicacionesml`)
- Stock estado: `POST`, `PUT /api/admin/stock-estado/{id}`, `DELETE /api/admin/stock-estado/{id}` (alias: `/api/admin/stock`)
- Métricas ventas: `POST /api/admin/metricas-ventas-hist` (alias: `/api/admin/metricas`)
- Competencia snapshot: `POST /api/admin/competencia-snapshot` (alias: `/api/admin/competencia`)
- Estrategias: `POST`, `PUT /api/admin/estrategias/{id}`, `DELETE /api/admin/estrategias/{id}`
- Reglas negocio: `POST`, `PUT /api/admin/reglas/{id}`, `DELETE /api/admin/reglas/{id}`
- Estrategia reglas: `POST /api/admin/estrategia/{estrategiaId}/reglas`, `PUT` y `DELETE` sobre `/api/admin/estrategia/{estrategiaId}/reglas/{id}`
- Configuración parámetros: `POST`, `PUT /api/admin/configuracion-parametros/{id}`, `DELETE /api/admin/configuracion-parametros/{id}` (alias: `/api/admin/configuracion`)
- Decisiones: `POST` y `PUT /api/admin/decisiones/{id}`; **no se expone DELETE**
- Auditoría de decisiones: `POST /api/admin/decisiones/{decisionId}/auditoria` y `POST /api/admin/decisiones-detalle-auditoria`
- Cola ejecución ML: `POST /api/admin/cola-ejecucion-ml` (alias: `/api/admin/colaejecucion`)

Cada endpoint espera un DTO JSON correspondiente. La API soporta ambos nombres canónicos y aliases para compatibilidad con el frontend y con rutas legacy.

## Ejemplo de request con filtros y orden

```http
GET /api/admin/empresas?page=1&pageSize=50&filter[activo][eq]=true&filter[fechaCreacion][gte]=2026-01-01&sort=empresaID:asc
```

## Observaciones importantes para integración

- La UI no ejecuta automáticamente la consulta al cambiar la pestaña; la acción explícita es `Ejecutar`.
- Los filtros son por columna y el valor puede ser simple o rango (`gte`/`lte`).
- Los booleanos se representan con `true`/`false`.
- Los textos usan coincidencia parcial mediante `contains`.
- Fechas y datetime deben manejarse en UTC/ISO y el extremo final del día debe incluir el día completo.
- No debe exponerse `AccessToken` ni `RefreshToken` dentro de `GET /api/admin/cuentas-ml`.

## Contrato de los formularios administrativos

Cada formulario define una **Clave de formulario** y el nombre de su ID técnico de respuesta. Al salir del último campo de la clave, la UI consulta el recurso con filtros `eq`. Solo una respuesta permite cargar el registro y conservar internamente su ID.

Con un registro recuperado, `Aceptar` ejecuta `PUT /api/admin/{recurso}/{id}`. Sin coincidencia, `Aceptar` ejecuta `POST /api/admin/{recurso}`. `Eliminar` requiere confirmación y solo se habilita para un registro recuperado; Decisiones no muestra esa acción.

| Formulario | Clave de formulario | ID técnico |
| --- | --- | --- |
| Empresa | `CUIT` | `empresaID` |
| Moneda | `CodigoMoneda` | `monedaID` |
| Cotización | `MonedaOrigenID`, `MonedaDestinoID`, `FechaVigencia` | `cotizacionID` |
| Parámetro general | `NombreParametro` | `parametroID` |
| Cuenta ML | `EmpresaID`, `NombreCuenta` | `cuentaMLID` |
| Producto | `EmpresaID`, `SKU` | `productoID` |
| Costo producto | `ProductoID`, `TipoCosto`, `FechaVigencia` | `costoID` |
| Publicación ML | `PublicacionMLID` | `publicacionID` |
| Stock estado | `ProductoID` | `stockID` |
| Estrategia | `EmpresaID`, `NombreEstrategia` | `estrategiaID` |
| Regla | `CodigoRegla` | `reglaID` |
| Estrategia-Regla | `EstrategiaID`, `ReglaID` | `estrategiaReglaID` |
| Configuración parámetros | `EmpresaID`, `EstrategiaID`, `NombreConfiguracion` | `configuracionID` |
| Decisión | `ProductoID`, `FechaDecision` | `decisionID` |
| Cola ejecución ML | `ProductoID`, `TipoTarea`, `FechaCreacion` | `tareaID` |

## Seguridad

- En esta etapa no se ha incorporado autenticación.
- En producción, proteger con JWT o API key.
- Habilitar CORS para `http://localhost:5173` y `http://localhost:5174` si la UI corre localmente.

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowLocalhost", builder =>
    {
        builder.WithOrigins("http://localhost:5173", "http://localhost:5174")
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

app.UseCors("AllowLocalhost");
```

## Endpoints GET (Lectura/Dropdowns)

1) Listar todas las Empresas
GET /api/admin/empresas
Response: 200 OK
```json
{
  "items": [
    {
      "empresaID": 1,
      "razonSocial": "ACME S.A.",
      "cuit": "30-12345678-9",
      "activo": true,
      "fechaCreacion": "2026-01-15T10:30:00.000Z"
    }
  ],
  "page": 1,
  "pageSize": 50,
  "totalCount": 1
}
```

2) Listar todas las Estrategias
GET /api/admin/estrategias
Response: 200 OK
```json
{
  "items": [
    {
      "estrategiaID": 1,
      "empresaID": 1,
      "nombreEstrategia": "Estrategia Premium",
      "descripcion": "Margen premium para productos de alto valor",
      "activa": true
    }
  ],
  "page": 1,
  "pageSize": 50,
  "totalCount": 1
}
```

3) Listar todas las Reglas
GET /api/admin/reglas
Response: 200 OK
```json
{
  "items": [
    {
      "reglaID": 5,
      "codigoRegla": "MARGEN_MIN_15",
      "nombre": "Margen mínimo 15%",
      "tipoRegla": "MARGEN",
      "activa": true
    }
  ],
  "page": 1,
  "pageSize": 50,
  "totalCount": 1
}
```

## Endpoints CRUD (POST/PUT/DELETE)

### 1. EMPRESAS

**POST** - Crear empresa
```http
POST /api/admin/empresas
Content-Type: application/json

{
  "razonSocial": "ACME S.A.",
  "cuit": "30-12345678-9",
  "activo": true,
  "fechaCreacion": "2026-08-17T00:00:00Z"
}
```
Response: 201 Created
```json
{ "empresaID": 123 }
```

**PUT** - Actualizar empresa
```http
PUT /api/admin/empresas/{empresaID}
Content-Type: application/json

{
  "razonSocial": "ACME S.A. Actualizada",
  "cuit": "30-12345678-9",
  "activo": true
}
```
Response: 200 OK

**DELETE** - Eliminar empresa
```http
DELETE /api/admin/empresas/{empresaID}
```
Response: 200 OK

---

### 2. MONEDAS

**POST** - Crear moneda
```http
POST /api/admin/monedas
Content-Type: application/json

{
  "codigoMoneda": "ARS",
  "nombreMoneda": "Peso Argentino",
  "simbolo": "$",
  "activa": true
}
```
Response: 201 Created
```json
{ "monedaID": 1 }
```

**PUT** - Actualizar moneda
```http
PUT /api/admin/monedas/{monedaID}
Content-Type: application/json

{
  "nombreMoneda": "Peso Argentino",
  "simbolo": "$",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar moneda
```http
DELETE /api/admin/monedas/{monedaID}
```
Response: 200 OK

---

### 3. COTIZACIONES

**POST** - Crear cotización
```http
POST /api/admin/cotizaciones
Content-Type: application/json

{
  "monedaOrigenID": 2,
  "monedaDestinoID": 1,
  "tasaCambio": 42.50,
  "fechaVigencia": "2026-08-17T00:00:00Z",
  "activa": true
}
```
Response: 201 Created
```json
{ "cotizacionID": 1 }
```

**PUT** - Actualizar cotización
```http
PUT /api/admin/cotizaciones/{cotizacionID}
Content-Type: application/json

{
  "tasaCambio": 43.00,
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar cotización
```http
DELETE /api/admin/cotizaciones/{cotizacionID}
```
Response: 200 OK

---

### 4. PARÁMETROS GENERALES

**POST** - Crear parámetro general
```http
POST /api/admin/parametros-generales
Content-Type: application/json

{
  "nombreParametro": "MARGEN_GLOBAL",
  "valor": "15",
  "descripcion": "Margen mínimo global para todos los productos",
  "tipoParametro": "DECIMAL",
  "activo": true
}
```
Response: 201 Created
```json
{ "parametroID": 1 }
```

**PUT** - Actualizar parámetro general
```http
PUT /api/admin/parametros-generales/{parametroID}
Content-Type: application/json

{
  "valor": "20",
  "descripcion": "Margen mínimo actualizado",
  "activo": true
}
```
Response: 200 OK

**DELETE** - Eliminar parámetro general
```http
DELETE /api/admin/parametros-generales/{parametroID}
```
Response: 200 OK

---

### 5. CUENTAS ML

**POST** - Crear cuenta ML
```http
POST /api/admin/cuentas-ml
Content-Type: application/json

{
  "empresaID": 1,
  "nombreCuenta": "Cuenta Premium ML",
  "usuarioML": "usuario@mercadolibre.com",
  "accessToken": "XXXXXXXXXXXXXX",
  "refreshToken": "YYYYYYYYYYYYYY",
  "fechaVencimientoToken": "2026-09-17T00:00:00Z",
  "activa": true
}
```
Response: 201 Created
```json
{ "cuentaMLID": 1 }
```

**PUT** - Actualizar cuenta ML
```http
PUT /api/admin/cuentas-ml/{cuentaMLID}
Content-Type: application/json

{
  "nombreCuenta": "Cuenta Premium ML Actualizada",
  "accessToken": "XXXXXXXXXXXXXX",
  "refreshToken": "YYYYYYYYYYYYYY",
  "fechaVencimientoToken": "2026-10-17T00:00:00Z",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar cuenta ML
```http
DELETE /api/admin/cuentas-ml/{cuentaMLID}
```
Response: 200 OK

---

### 6. PRODUCTOS

**POST** - Crear producto
```http
POST /api/admin/productos
Content-Type: application/json

{
  "empresaID": 1,
  "sku": "SKU-001",
  "titulo": "Auriculares Bluetooth Premium",
  "descripcion": "Auriculares inalámbricos de alta calidad",
  "categoriaMLID": "MLA123456",
  "precioActual": 50000,
  "costoBase": 30000,
  "monedaID": 1,
  "activo": true
}
```
Response: 201 Created
```json
{ "productoID": 1 }
```

**PUT** - Actualizar producto
```http
PUT /api/admin/productos/{productoID}
Content-Type: application/json

{
  "titulo": "Auriculares Bluetooth Premium v2",
  "precioActual": 52000,
  "costoBase": 31000,
  "activo": true
}
```
Response: 200 OK

**DELETE** - Eliminar producto
```http
DELETE /api/admin/productos/{productoID}
```
Response: 200 OK

---

### 7. COSTOS PRODUCTO

**POST** - Crear costo producto
```http
POST /api/admin/costos-producto
Content-Type: application/json

{
  "productoID": 1,
  "tipoCosto": "ENVIO",
  "monto": 500,
  "monedaID": 1,
  "fechaVigencia": "2026-08-17T00:00:00Z",
  "activo": true
}
```
Response: 201 Created
```json
{ "costoID": 1 }
```

**PUT** - Actualizar costo producto
```http
PUT /api/admin/costos-producto/{costoID}
Content-Type: application/json

{
  "monto": 550,
  "activo": true
}
```
Response: 200 OK

**DELETE** - Eliminar costo producto
```http
DELETE /api/admin/costos-producto/{costoID}
```
Response: 200 OK

---

### 8. PUBLICACIONES ML

**POST** - Crear publicación ML
```http
POST /api/admin/publicaciones-ml
Content-Type: application/json

{
  "cuentaMLID": 1,
  "productoID": 1,
  "publicacionMLID": "MLA987654321",
  "titulo": "Auriculares Bluetooth - Publicación ML",
  "precioML": 50000,
  "stockPublicado": 10,
  "estadoPublicacion": "active",
  "fechaPublicacion": "2026-08-17T00:00:00Z",
  "activa": true
}
```
Response: 201 Created
```json
{ "publicacionID": 1 }
```

**PUT** - Actualizar publicación ML
```http
PUT /api/admin/publicaciones-ml/{publicacionID}
Content-Type: application/json

{
  "precioML": 52000,
  "stockPublicado": 8,
  "estadoPublicacion": "paused",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar publicación ML
```http
DELETE /api/admin/publicaciones-ml/{publicacionID}
```
Response: 200 OK

---

### 9. STOCK ESTADO

**POST** - Crear registro stock estado
```http
POST /api/admin/stock-estado
Content-Type: application/json

{
  "productoID": 1,
  "stockDisponible": 25,
  "stockMinimo": 5,
  "stockMaximo": 100,
  "stockReservado": 3,
  "fechaActualizacion": "2026-08-17T00:00:00Z",
  "activo": true
}
```
Response: 201 Created
```json
{ "stockID": 1 }
```

**PUT** - Actualizar stock estado
```http
PUT /api/admin/stock-estado/{stockID}
Content-Type: application/json

{
  "stockDisponible": 22,
  "stockReservado": 6,
  "fechaActualizacion": "2026-08-17T12:00:00Z",
  "activo": true
}
```
Response: 200 OK

**DELETE** - Eliminar registro stock estado
```http
DELETE /api/admin/stock-estado/{stockID}
```
Response: 200 OK

---

### 10. ESTRATEGIAS

**POST** - Crear estrategia
```http
POST /api/admin/estrategias
Content-Type: application/json

{
  "empresaID": 1,
  "nombreEstrategia": "Estrategia Premium",
  "descripcion": "Estrategia de pricing para productos premium",
  "activa": true
}
```
Response: 201 Created
```json
{ "estrategiaID": 1 }
```

**PUT** - Actualizar estrategia
```http
PUT /api/admin/estrategias/{estrategiaID}
Content-Type: application/json

{
  "nombreEstrategia": "Estrategia Premium v2",
  "descripcion": "Estrategia mejorada para productos premium",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar estrategia
```http
DELETE /api/admin/estrategias/{estrategiaID}
```
Response: 200 OK

---

### 11. REGLAS

**POST** - Crear regla
```http
POST /api/admin/reglas
Content-Type: application/json

{
  "codigoRegla": "MARGEN_MIN_15",
  "nombre": "Margen mínimo 15%",
  "descripcion": "Valida que el margen sea al menos 15%",
  "tipoRegla": "MARGEN",
  "condicionJSON": "{\"minMargen\": 0.15}",
  "activa": true
}
```
Response: 201 Created
```json
{ "reglaID": 1 }
```

**PUT** - Actualizar regla
```http
PUT /api/admin/reglas/{reglaID}
Content-Type: application/json

{
  "nombre": "Margen mínimo 20%",
  "descripcion": "Valida que el margen sea al menos 20%",
  "condicionJSON": "{\"minMargen\": 0.20}",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar regla
```http
DELETE /api/admin/reglas/{reglaID}
```
Response: 200 OK

---

### 12. ESTRATEGIA-REGLAS

**POST** - Asignar regla a estrategia
```http
POST /api/admin/estrategia/{estrategiaID}/reglas
Content-Type: application/json

{
  "reglaID": 5,
  "prioridad": 1,
  "parametrosJSON": "{\"margenMinimo\": 15}",
  "activa": true
}
```
Response: 201 Created
```json
{ "estrategiaReglaID": 1 }
```

**PUT** - Actualizar asignación de regla a estrategia
```http
PUT /api/admin/estrategia/{estrategiaID}/reglas/{estrategiaReglaID}
Content-Type: application/json

{
  "prioridad": 2,
  "parametrosJSON": "{\"margenMinimo\": 20}",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Remover regla de estrategia
```http
DELETE /api/admin/estrategia/{estrategiaID}/reglas/{estrategiaReglaID}
```
Response: 200 OK

---

### 13. CONFIGURACIÓN PARÁMETROS

**POST** - Crear configuración parámetros
```http
POST /api/admin/configuracion-parametros
Content-Type: application/json

{
  "empresaID": 1,
  "estrategiaID": 1,
  "nombreConfiguracion": "Config Premium Q3",
  "parametrosJSON": "{\"margenGlobal\": 20, \"descuentoMaximo\": 10}",
  "fechaVigencia": "2026-08-17T00:00:00Z",
  "activa": true
}
```
Response: 201 Created
```json
{ "configuracionID": 1 }
```

**PUT** - Actualizar configuración parámetros
```http
PUT /api/admin/configuracion-parametros/{configuracionID}
Content-Type: application/json

{
  "parametrosJSON": "{\"margenGlobal\": 25, \"descuentoMaximo\": 15}",
  "activa": true
}
```
Response: 200 OK

**DELETE** - Eliminar configuración parámetros
```http
DELETE /api/admin/configuracion-parametros/{configuracionID}
```
Response: 200 OK

---

### 14. DECISIONES

**POST** - Crear decisión
```http
POST /api/admin/decisiones
Content-Type: application/json

{
  "productoID": 1,
  "precioPropuesto": 50000,
  "precioDecidido": 48500,
  "razonDecision": "Aplicada regla de margen mínimo 20%",
  "estadoDecision": "APROBADA",
  "fechaDecision": "2026-08-17T12:00:00Z",
  "usuarioDecision": "admin@empresa.com"
}
```
Response: 201 Created
```json
{ "decisionID": 1 }
```

**PUT** - Actualizar decisión
```http
PUT /api/admin/decisiones/{decisionID}
Content-Type: application/json

{
  "precioDecidido": 49000,
  "razonDecision": "Revisión manual - margen ajustado",
  "estadoDecision": "REVISADA"
}
```
Response: 200 OK

Las decisiones no admiten `DELETE`; se conservan para auditoría. La UI tampoco muestra la acción `Eliminar` para este formulario.

---

### 15. MÉTRICAS VENTAS (Historial - Solo lectura, registros automáticos)

**POST** - Crear métrica venta (típicamente automático desde engine)
```http
POST /api/admin/metricas-ventas-hist
Content-Type: application/json

{
  "productoID": 1,
  "fechaMetrica": "2026-08-17T00:00:00Z",
  "cantidadVendida": 5,
  "montoVentas": 250000,
  "margenReal": 0.18,
  "monedaID": 1
}
```
Response: 201 Created
```json
{ "metricaID": 1 }
```

**⚠️ Nota**: Tabla de historial. No se recomienda DELETE físico en producción. Las métricas son registros históricos.

---

### 16. COMPETENCIA SNAPSHOT (Snapshot - Solo lectura, registros automáticos)

**POST** - Crear snapshot de competencia
```http
POST /api/admin/competencia-snapshot
Content-Type: application/json

{
  "productoID": 1,
  "competidorSKU": "COMP-SKU-001",
  "precioCompetidor": 45000,
  "fechaSnapshot": "2026-08-17T10:00:00Z",
  "fuente": "scrap_mercadolibre"
}
```
Response: 201 Created
```json
{ "snapshotID": 1 }
```

**⚠️ Nota**: Tabla de auditoría. No se recomienda DELETE físico en producción. Los snapshots son datos históricos de inteligencia competitiva.

---

### 17. COLA EJECUCIÓN ML

**POST** - Crear tarea en cola de ejecución
```http
POST /api/admin/cola-ejecucion-ml
Content-Type: application/json

{
  "productoID": 1,
  "tipoTarea": "UPDATE_PRICE",
  "estadoTarea": "PENDING",
  "parametrosJSON": "{\"nuevoPrecios\": 48500, \"razon\": \"Pricing automático\"}",
  "intentos": 0,
  "fechaCreacion": "2026-08-17T12:00:00Z"
}
```
Response: 201 Created
```json
{ "tareaID": 1 }
```

**PUT** - Actualizar tarea en cola
```http
PUT /api/admin/cola-ejecucion-ml/{tareaID}
Content-Type: application/json

{
  "estadoTarea": "COMPLETED",
  "resultadoJSON": "{\"success\": true, \"publishingID\": \"MLA987654321\"}",
  "intentos": 1,
  "fechaCompletacion": "2026-08-17T12:15:00Z"
}
```
Response: 200 OK

**DELETE** - Eliminar tarea de cola (cuidado con transacciones activas)
```http
DELETE /api/admin/cola-ejecucion-ml/{tareaID}
```
Response: 200 OK

---

### 18. DECISIONES HISTORIAL (Auditoría - Solo lectura)

**⚠️ Nota**: Tabla de auditoría. **No exponer POST/PUT/DELETE** para esta tabla. Solo lectura (GET).

---

### 19. DECISIONES DETALLE AUDITORÍA (Auditoría - Solo lectura)

**POST** - Crear registro de auditoría (típicamente automático desde el sistema)
```http
POST /api/admin/decisiones-detalle-auditoria
Content-Type: application/json

{
  "decisionID": 1,
  "campoModificado": "precioDecidido",
  "valorAnterior": "50000",
  "valorNuevo": "48500",
  "fechaModificacion": "2026-08-17T12:00:00Z",
  "usuarioModificacion": "admin@empresa.com",
  "razonModificacion": "Ajuste manual por revisión"
}
```
Response: 201 Created
```json
{ "detalleAuditoriaID": 1 }
```

**⚠️ Nota**: Tabla de auditoría. No se recomienda DELETE en producción. La auditoría es un registro inmutable de cambios.

---

## Códigos de Respuesta HTTP (aplicable a todos los endpoints)

| Código | Descripción | Ejemplo |
|--------|-------------|---------|
| **200 OK** | Operación GET, PUT o DELETE exitosa | `GET /api/admin/empresas` devuelve listado |
| **201 Created** | Recurso creado exitosamente | `POST /api/admin/empresas` devuelve ID del recurso |
| **400 Bad Request** | Error de validación o parámetros inválidos | Campo requerido faltante, valor fuera de rango |
| **404 Not Found** | Recurso no existe | `PUT /api/admin/empresas/999` (ID no existe) |
| **409 Conflict** | Conflicto de constraint (FK, unique) | Crear empresa con CUIT duplicado |
| **422 Unprocessable Entity** | Datos inválidos según reglas de negocio | Estrategia sin empresa asignada |
| **500 Internal Server Error** | Error en el servidor | Error en BD, excepción no capturada |

---

## Validaciones y Reglas por Tabla

### Validaciones Globales (aplican a POST y PUT)

1. **Campos requeridos**: Todos los DTOs deben validar que campos obligatorios no sean nulos o vacíos.
2. **Tipos de dato**: Validar que los valores coincidan con el tipo esperado (int, decimal, date, boolean, string).
3. **Restricciones de longitud**: Strings no deben exceder longitud máxima de la BD.
4. **Ranges**: Valores numéricos deben estar dentro de rangos válidos.
5. **Unicidad**: CUIT (Empresas), código (Reglas, Parámetros), SKU (Productos) deben ser únicos.
6. **Referencial Integrity**: Foreign keys deben apuntar a recursos existentes.

### Validaciones Específicas por Tabla

#### Empresas
- `razonSocial`: requerido, string, longitud máx 255
- `cuit`: requerido, único, formato "XX-XXXXXXXX-X"
- `activo`: boolean, default true

#### Monedas
- `codigoMoneda`: requerido, único, string ISO 4217 (ARS, USD, BRL, etc.)
- `nombreMoneda`: requerido, string, longitud máx 100
- Restricción: No permitir DELETE si hay Cotizaciones activas usando esta moneda

#### Cotizaciones
- `monedaOrigenID`, `monedaDestinoID`: requerido, deben existir (FK)
- `monedas origen != destino`: No se permite cambio de moneda a moneda igual
- `tasaCambio`: requerido, decimal, > 0
- Restricción: No permitir DELETE si hay conversiones pendientes

#### Parámetros Generales
- `nombreParametro`: requerido, único, string, longitud máx 100
- `valor`: requerido, se parsea según `tipoParametro`
- `tipoParametro`: enum [DECIMAL, INTEGER, TEXT, BOOLEAN]
- Restricción: No permitir cambiar tipo si hay configuraciones vigentes

#### Cuentas ML
- `empresaID`: requerido, debe existir (FK)
- `nombreCuenta`: requerido, string, longitud máx 100
- `usuarioML`: requerido, email válido
- `accessToken`, `refreshToken`: no deben exponerse en GET (retornar valores hasheados)
- Restricción: Al actualizar tokens, validar formato y fecha de vencimiento

#### Productos
- `empresaID`: requerido, debe existir (FK)
- `sku`: requerido, único, string, longitud máx 50
- `titulo`: requerido, string, longitud máx 255
- `precioActual`, `costoBase`: decimal, > 0
- `monedaID`: requerido, debe existir (FK)
- Restricción: costoBase no puede ser > precioActual (validar margen mínimo)

#### Costos Producto
- `productoID`: requerido, debe existir (FK)
- `tipoCosto`: enum [ENVIO, LOGISTICA, PUBLICIDAD, FINANCIERO]
- `monto`: requerido, decimal, >= 0
- `monedaID`: requerido, debe existir (FK)
- Restricción: No permitir costos negativos o montos irracionales (> 1M)

#### Publicaciones ML
- `cuentaMLID`: requerido, debe existir (FK)
- `productoID`: requerido, debe existir (FK)
- `publicacionMLID`: unique, string, formato MLA + dígitos
- `precioML`, `stockPublicado`: decimal/int, > 0
- `estadoPublicacion`: enum [active, paused, closed]
- Restricción: Un producto solo puede tener una publicación activa por cuenta ML

#### Stock Estado
- `productoID`: requerido, debe existir (FK), único
- `stockDisponible`: int, >= 0
- `stockMinimo`, `stockMaximo`: int, > 0
- Restricción: stockMinimo <= stockMaximo <= stockDisponible + stockReservado

#### Estrategias
- `empresaID`: requerido, debe existir (FK)
- `nombreEstrategia`: requerido, string, longitud máx 100
- Restricción: Una empresa puede tener múltiples estrategias pero solo una activa por producto

#### Reglas
- `codigoRegla`: requerido, único, string, longitud máx 50
- `tipoRegla`: enum [MARGEN, DESCUENTO, COSTO, PRECIO_MINIMO, PRECIO_MAXIMO]
- `condicionJSON`: requerido, JSON válido con estructura específica por tipoRegla
- Restricción: No permitir DELETE si hay estrategias usando esta regla

#### Estrategia-Reglas
- `estrategiaID`: requerido, debe existir (FK)
- `reglaID`: requerido, debe existir (FK)
- `prioridad`: int, > 0, único por estrategia
- `parametrosJSON`: JSON válido, debe ser compatible con condición de la Regla
- Restricción: No se permite la misma regla dos veces en una estrategia

#### Configuración Parámetros
- `empresaID`, `estrategiaID`: requerido, deben existir (FK)
- `nombreConfiguracion`: requerido, string, longitud máx 100
- `parametrosJSON`: requerido, JSON válido
- `fechaVigencia`: requerido, date
- Restricción: Solo una configuración activa por (empresa, estrategia)

#### Decisiones
- `productoID`: requerido, debe existir (FK)
- `precioPropuesto`, `precioDecidido`: decimal, > 0
- `estadoDecision`: enum [APROBADA, RECHAZADA, REVISADA, CANCELADA]
- `usuarioDecision`: string, email o ID de usuario
- Restricción: precioDecidido >= precioPropu esto (NO puede ser menor)

#### Métricas Ventas
- `productoID`: requerido, debe existir (FK)
- `cantidadVendida`: int, >= 0
- `montoVentas`: decimal, >= 0
- `margenReal`: decimal, 0 <= x <= 1
- `monedaID`: requerido, debe existir (FK)
- Restricción: registros históricos, no modificar (solo lectura después de crear)

#### Competencia Snapshot
- `productoID`: requerido, debe existir (FK)
- `precioCompetidor`: decimal, > 0
- `fuente`: enum [scrap_mercadolibre, manual_admin, integracion_api]
- Restricción: registros históricos, no modificar (solo lectura después de crear)

#### Cola Ejecución ML
- `productoID`: requerido, debe existir (FK)
- `tipoTarea`: enum [UPDATE_PRICE, UPDATE_STOCK, PUBLISH, UNPUBLISH, DELETE_LISTING]
- `estadoTarea`: enum [PENDING, PROCESSING, COMPLETED, FAILED, RETRY]
- `parametrosJSON`: JSON, estructura específica según tipoTarea
- `intentos`: int, 0 <= x <= 5 (máximo 5 reintentos)
- Restricción: No permitir crear dos PENDING para el mismo (producto, tipoTarea)

---

Notas de Validación General
- **Transaccionalidad**: Las operaciones deben ser ACID. Si hay múltiples inserts/updates, todo-o-nada.
- **Auditoría**: Registrar usuario y timestamp en cada operación (idealmente en base de datos con triggers).
- **Soft Delete**: Para tablas de historial (DecisionesHistorial, DecisionesDetalleAuditoria, MetricasVentasHist, CompetenciaSnapshot), implementar soft delete (columna `activo` = false) en lugar de DELETE físico.
- **Constraint Cascada**: Definir si DELETE en tabla padre debe cascadear a tabla hijo o rechazar (recomendación: RESTRICT).
- **JSON Schema**: Validar que campos JSON respeten un esquema definido (idealmente server-side con JSON Schema).



Seguridad
- En esta etapa no se implementó autenticación. Estos endpoints son poderosos y deben protegerse con autenticación/roles antes de exponerlos en entornos no confiables.
- CORS debe habilitarse en el backend para permitir requests desde la UI en `http://localhost:5173` (y opcionalmente `http://localhost:5174`).

Configuración CORS (ASP.NET Core)
Para que la UI pueda consumir estos endpoints, el backend debe habilitar CORS. En la API actual esto queda así:

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins(
                "http://localhost:3000",
                "http://localhost:4200",
                "http://localhost:5173",
                "http://127.0.0.1:3000",
                "http://127.0.0.1:4200",
                "http://127.0.0.1:5173")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

app.UseCors("AllowFrontend");
```

En producción, reemplazar los orígenes localhost con los dominios reales de la UI.

Documentación técnica
- Ver `src/PricingApi/Program.cs` para el mapeo real de endpoints.
- Ver `src/PricingApi/Services/AdminCrudService.cs` para la persistencia SQL de cada operación.
- Ver `SQL/Estructura.sql` para el esquema completo de tablas y constraints.
