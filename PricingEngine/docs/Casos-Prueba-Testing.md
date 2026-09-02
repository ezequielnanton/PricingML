# Testing y Casos de Prueba - Pricing Engine

**Última actualización**: 2026-08-18  
**Framework**: XUnit 2.9.3  
**Proyecto**: PricingApi.Tests

---

## 1. Estrategia de Testing

### Niveles de testing implementados

| Nivel | Status | Coverage | Notas |
|-------|--------|----------|-------|
| Unit | ✅ Implementado | AdminReportsService | 6 test cases |
| Integration | ⚠️ Planeado | - | Requiere BD de pruebas |
| E2E | ⚠️ Planeado | - | APIs completas |

### Ubicación de tests
```
PricingApi.Tests/
├── AdminReportsServiceTests.cs    (6 tests)
├── bin/
└── obj/
```

---

## 2. Unit Tests Implementados

### AdminReportsServiceTests

#### Test 1: Paginación por defecto y límites
**Nombre**: `Usa_paginacion_por_defecto_y_admite_limite`

**Objetivo**: Validar que paginación funciona con defaults (page=1, pageSize=50) y respeta máximo 100.

**Casos validados**:
- Default: page=1, pageSize=50
- Custom: pageSize=75 ✅
- Exceeding max: pageSize=150 → limitado a 100 ✅
- Invalid: pageSize=0 → error 400 ✅

**Entrada**:
```csharp
var query = Query(("page", "1"), ("pageSize", "50"));
```

**Validación**:
```csharp
Assert.Equal(1, result.Page);
Assert.Equal(50, result.PageSize);
```

---

#### Test 2: Filtros type-aware
**Nombre**: `Acepta_filtros_tipados`

**Objetivo**: Validar que filtros respetan operadores type-safe (contains, eq, gte, lt).

**Operadores soportados**:
- `contains`: búsqueda textual (strings)
- `eq`: igualdad exacta
- `gte`: mayor o igual (números)
- `lt`: menor que (números)

**Ejemplo de entrada**:
```json
{
  "page": 1,
  "pageSize": 50,
  "filters": {
    "nombreCampo": "valor",
    "numeroField:gte": "100",
    "textField:contains": "busqueda"
  }
}
```

**Validación**:
```csharp
Assert.NotEmpty(result.Data);
Assert.All(result.Data, row => Assert.NotNull(row.GetValue("nombreCampo")));
```

---

#### Test 3: Ordenamiento multi-columna
**Nombre**: `Acepta_ordenamiento_por_campos_expuestos`

**Objetivo**: Validar sorting por múltiples columnas en ASC/DESC.

**Sintaxis**:
```
sort=campo1:asc,campo2:desc,campo3
```

**Validación**:
```csharp
var sorted = result.Data.OrderByDescending(x => x.FechaDecision)
                        .ThenBy(x => x.MargenPorc);
Assert.Equal(sorted, result.Data);
```

---

#### Test 4: Validación de parámetros
**Nombre**: `Rechaza_parametros_invalidos`

**Objetivo**: Rechazar valores inválidos en page, pageSize, filtros, operadores.

**Casos**:
- page ≤ 0 → 400 Bad Request
- pageSize > 100 → ajusta a 100
- Filtro con campo no expuesto → 400
- Operador inválido (`:xyz`) → 400
- Sort por campo no expuesto → 400

**Validación**:
```csharp
Assert.Throws<ArgumentException>(() => service.GetReports(invalidQuery));
```

---

#### Test 5: SQL Injection Protection
**Nombre**: `Trata_payload_sql_como_valor_de_filtro_textual`

**Objetivo**: Validar que SQL injection se trata como valor literal.

**Payload de ataque**:
```json
{
  "filters": {
    "motivo:contains": "'; DROP TABLE Decisiones; --"
  }
}
```

**Comportamiento esperado**:
- La cadena se trata como un `CONTAINS` literal
- No se ejecuta SQL malicioso
- Retorna registros con esa cadena exacta (si existen)

**Validación**:
```csharp
var results = service.GetReports(query);
Assert.DoesNotThrow(() => results);
// Verifica que tabla sigue intacta
Assert.True(dbRowCount > 0);
```

---

#### Test 6: Conversión camelCase
**Nombre**: `Convierte_columnas_a_camelCase_compatibles_con_front`

**Objetivo**: Validar que columnas BD (snake_case) se convierten a camelCase.

**Conversión**:
```
FechaDecision → fechaDecision
MargenActualPorc → margenActualPorc
ScoreConfianza → scoreConfianza
DecisionID → decisionId
```

**Validación**:
```csharp
Assert.Contains("fechaDecision", result.Data.First().Keys);
Assert.DoesNotContain("fecha_decision", result.Data.First().Keys);
```

---

## 3. Casos de Prueba Manual (Postman/Insomnia)

### Configuración previa

**Endpoint base**:
```
http://localhost:5000
```

**Headers**:
```
Content-Type: application/json
Accept: application/json
```

**CORS**: Verificar que frontend está en localhost:3000, 4200 o 5173

---

### 3.1 Pruebas de Evaluación

#### CT-EVAL-001: Evaluación simple (simulación)

**Endpoint**: `POST /pricing/evaluate`

**Request**:
```json
{
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
  "costoEnvioPromedio": 0.0,
  "costoLogisticoFijo": 0.0,
  "costoFinancieroPorc": 0.0,
  "costoPublicidadPorc": 0.0,
  "estadoPublicacion": "active",
  "origen": "UI",
  "modoSimulacion": true,
  "persistir": false
}
```

**Validaciones esperadas**:
- ✅ HTTP 200 OK
- ✅ `precioSugerido` presente
- ✅ `accion` en [MANTENER, AUMENTAR, DISMINUIR]
- ✅ `margenActualPorc` > 0
- ✅ `scoreConfianza` entre 0 y 100

---

#### CT-EVAL-002: Evaluación con persistencia

**Endpoint**: `POST /pricing/evaluate`

**Request** (mismo que CT-EVAL-001 pero con `persistir: true`):
```json
{
  ...mismos campos...,
  "persistir": true
}
```

**Validaciones esperadas**:
- ✅ HTTP 200 OK
- ✅ Producto creado en `Productos` tabla
- ✅ Costos persistidos en `CostosProducto`
- ✅ Stock persistido en `StockEstado`

**Verificación en SQL**:
```sql
SELECT * FROM Productos WHERE SKU='TEST-001' AND EmpresaID=1;
SELECT * FROM CostosProducto WHERE ProductoID=(SELECT ID FROM Productos WHERE SKU='TEST-001');
```

---

#### CT-EVAL-003: Validación de entrada (SKU vacío)

**Endpoint**: `POST /pricing/evaluate`

**Request**:
```json
{
  ...mismos campos...,
  "sku": ""
}
```

**Validaciones esperadas**:
- ✅ HTTP 400 Bad Request
- ✅ Mensaje: "SKU cannot be empty"

---

#### CT-EVAL-004: Empresa inexistente (con persistencia)

**Endpoint**: `POST /pricing/evaluate`

**Request**:
```json
{
  "empresaId": 99999,
  ...otros campos...,
  "persistir": true
}
```

**Validaciones esperadas**:
- ✅ HTTP 404 Not Found
- ✅ Mensaje: "Enterprise not found"
- ✅ No se crea producto

---

### 3.2 Pruebas de Ingestión

#### CT-INPUT-001: Ingestión desde UI (con evaluación)

**Endpoint**: `POST /api/input/ui/product`

**Request**:
```json
{
  "empresaId": 1,
  "sku": "INPUT-001",
  "titulo": "Producto Ingesta",
  "precioPropuesto": 5000.0,
  "precioMinimoPermitido": 4000.0,
  "precioMaximoPermitido": 6000.0,
  "stockDisponible": 20,
  "stockMinimo": 10,
  "stockMaximo": 100,
  "costoBase": 3000.0,
  "iva": 21.0,
  "comisionMLPorc": 9.0,
  "costoEnvioPromedio": 500.0,
  "costoLogisticoFijo": 1000.0,
  "costoFinancieroPorc": 2.5,
  "costoPublicidadPorc": 1.0,
  "estadoPublicacion": "active",
  "origen": "UI",
  "modoSimulacion": false,
  "persistir": true
}
```

**Validaciones esperadas**:
- ✅ HTTP 201 Created
- ✅ Response incluye `productoId`
- ✅ Response incluye `decision` con precio sugerido
- ✅ Producto persistido en BD

---

#### CT-INPUT-002: Upsert (producto duplicado)

**Pasos**:
1. POST /api/input/ui/product con sku="UPSERT-001" (crea)
2. POST /api/input/ui/product con sku="UPSERT-001" (actualiza precio)

**Validaciones esperadas**:
- ✅ Primer: HTTP 201, nuevo ProductoId
- ✅ Segundo: HTTP 201, **mismo ProductoId**
- ✅ Precio actualizado en BD

---

### 3.3 Pruebas Admin CRUD

#### CT-ADMIN-001: Crear empresa

**Endpoint**: `POST /api/admin/empresas`

**Request**:
```json
{
  "razonSocial": "Test Corp S.A.",
  "cuit": "30987654321"
}
```

**Validaciones esperadas**:
- ✅ HTTP 201 Created
- ✅ Response incluye `id`, `razonSocial`, `cuit`, `activo: true`, `fechaCreacion`

---

#### CT-ADMIN-002: Obtener empresa

**Endpoint**: `GET /api/admin/empresas/{id}`

**Validaciones esperadas**:
- ✅ HTTP 200 OK si existe
- ✅ HTTP 404 Not Found si no existe

---

#### CT-ADMIN-003: Crear moneda

**Endpoint**: `POST /api/admin/monedas`

**Request**:
```json
{
  "codigoISO": "USD",
  "nombre": "Dólar Estadounidense",
  "simbolo": "$"
}
```

**Validaciones esperadas**:
- ✅ HTTP 201 Created
- ✅ Moneda creada con CodigoISO único

---

### 3.4 Pruebas de Reportes (Futuro)

#### CT-REPORT-001: Listar decisiones con paginación

**Endpoint**: `GET /api/reports/decisiones?page=1&pageSize=50`

**Validaciones esperadas** (cuando se implemente):
- ✅ HTTP 200 OK
- ✅ Array de decisiones paginadas
- ✅ Campos en camelCase

---

## 4. Checklist de Testing Pre-Deploy

- [ ] Unit tests: Todos pasan (`dotnet test`)
- [ ] Health check: GET /health → 200 OK
- [ ] Evaluación simple: POST /pricing/evaluate → 200 OK
- [ ] Ingestión: POST /api/input/ui/product → 201 Created
- [ ] Admin CRUD: POST /api/admin/empresas → 201 Created
- [ ] Validación: SKU vacío → 400 Bad Request
- [ ] Empresa inexistente → 404 Not Found
- [ ] SQL injection: Payload tratado como string → seguro
- [ ] CORS: Frontend accede sin errores
- [ ] BD: Productos, Costos, Stock persistidos correctamente

---

## 5. Ejecución de tests

### Unit Tests (XUnit)

```bash
# En directorio raíz del proyecto
cd PricingApi.Tests
dotnet test

# Con cobertura (requiere herramienta)
dotnet test /p:CollectCoverage=true
```

**Output esperado**:
```
Build succeeded.
6 test(s), 6 passed
Test Run Successful.
```

---

## 6. Próximos pasos (Roadmap Testing)

### Fase 2
1. ✅ Integration tests para InputPersistenceService
2. ✅ Integration tests para SqlPricingService
3. ✅ Tests E2E con Postman/Newman
4. ✅ BD de pruebas (PRICES_DB_TEST)

### Fase 3
1. 📊 Load tests (100 req/sec)
2. 🔒 Security tests (OWASP Top 10)
3. 🔄 Contract tests (Frontend-Backend)

---

**Responsable Testing**: Equipo QA  
**Última revisión**: 2026-08-18

---

### CT-SIM-002: Stock Crítico (Bajo Mínimo)

**Objetivo:** Validar que stock crítico activa REGLA 1 (subida 5%)

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-CRITICO-001",
  "titulo": "Stock Crítico",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 5,
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

**Salida Esperada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-CRITICO-001",
  "modoSimulacion": true,
  "precioActual": 100.00,
  "precioSugerido": 105.00,
  "accion": "AUMENTAR_PRECIO",
  "motivo": "Stock en nivel CRÍTICO. Se incrementa precio 5% para proteger quiebre.",
  "margenActualPorc": 20.64,
  "margenProyectadoPorc": 21.67,
  "clasificacionStock": "CRITICO",
  "stockDisponible": 5,
  "scoreConfianza": 0.85
}
```

**Validaciones:**
- ✅ Status Code = 200
- ✅ `clasificacionStock` = "CRITICO"
- ✅ `accion` = "AUMENTAR_PRECIO"
- ✅ `precioSugerido` = 105.00 (100 × 1.05)
- ✅ `margenProyectadoPorc` > `margenActualPorc`

---

### CT-SIM-003: Stock Bajo (Entre Mín y Mín×1.5)

**Objetivo:** Validar clasificación BAJO de stock (no activa regla, solo monitoreo)

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-BAJO-001",
  "titulo": "Stock Bajo",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 12,
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

**Salida Esperada:**
```json
{
  "accion": "MANTENER_PRECIO",
  "motivo": "Escenario simulado",
  "clasificacionStock": "BAJO",
  "precioSugerido": 100.00
}
```

**Validaciones:**
- ✅ `clasificacionStock` = "BAJO"
- ✅ `accion` = "MANTENER_PRECIO" (sin regla de BAJO)

---

### CT-SIM-004: Stock Alto (>80% del máximo)

**Objetivo:** Validar stock ALTO sin activar EXCESO

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-ALTO-001",
  "titulo": "Stock Alto",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 170,
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

**Salida Esperada:**
```json
{
  "accion": "MANTENER_PRECIO",
  "clasificacionStock": "ALTO",
  "precioSugerido": 100.00
}
```

**Validaciones:**
- ✅ `clasificacionStock` = "ALTO"
- ✅ Sin cambio de precio

---

### CT-SIM-005: Exceso de Stock (≥ StockMaximo)

**Objetivo:** Validar REGLA 3 activa, descuento 7%

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-EXCESO-001",
  "titulo": "Exceso Stock",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 250,
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

**Salida Esperada:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 93.00,
  "accion": "DISMINUIR_PRECIO",
  "motivo": "Exceso de stock detectado con baja rotación. Aplicando descuento de liquidación.",
  "clasificacionStock": "EXCESO",
  "margenActualPorc": 20.64,
  "margenProyectadoPorc": 19.17
}
```

**Validaciones:**
- ✅ `clasificacionStock` = "EXCESO"
- ✅ `accion` = "DISMINUIR_PRECIO"
- ✅ `precioSugerido` = 93.00 (100 × 0.93)
- ✅ `margenProyectadoPorc` < `margenActualPorc`

---

### CT-SIM-006: Margen Negativo (Costo > Precio)

**Objetivo:** Validar RESTRICCIÓN 1: Bloquea cambios si margen < 15%

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-NEGATIVO-001",
  "titulo": "Margen Negativo",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 50,
  "stockMinimo": 10,
  "stockMaximo": 200,
  "costoBase": 120.00,
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

**Salida Esperada:**
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

**Validaciones:**
- ✅ `margenActualPorc` < 0
- ✅ `accion` = "NO_MODIFICAR"
- ✅ `scoreConfianza` = 0.95 (máxima en seguridad)

---

### CT-SIM-007: Precio Bajo Límite Mínimo

**Objetivo:** Validar RESTRICCIÓN 2: CLAMP a límite mínimo

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-MINLIMIT-001",
  "titulo": "Bajo Límite Min",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 90.00,
  "precioMaximoPermitido": 150.00,
  "stockDisponible": 250,
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

**Procesamiento:**
1. Stock = 250 → Exceso
2. Regla 3: `PrecioSugerido = 100 × 0.93 = 93.00`
3. Restricción 2: `93.00 < 90.00` es FALSO, no se clampea

**Salida Esperada:**
```json
{
  "precioSugerido": 93.00,
  "accion": "DISMINUIR_PRECIO"
}
```

**Validaciones:**
- ✅ NO se clampea (93 está dentro de 90-150)

---

### CT-SIM-008: Precio Sobre Límite Máximo

**Objetivo:** Validar RESTRICCIÓN 2: CLAMP a límite máximo

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-MAXLIMIT-001",
  "titulo": "Sobre Límite Max",
  "precioPropuesto": 100.00,
  "precioMinimoPermitido": 80.00,
  "precioMaximoPermitido": 102.00,
  "stockDisponible": 5,
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

**Procesamiento:**
1. Stock = 5 → Crítico
2. Regla 1: `PrecioSugerido = 100 × 1.05 = 105.00`
3. Restricción 2: `105.00 > 102.00` → CLAMPEA a 102.00

**Salida Esperada:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 102.00,
  "motivo": "Ajustado al Límite Máximo Permitido por Publicación",
  "accion": "AUMENTAR_PRECIO"
}
```

**Validaciones:**
- ✅ `precioSugerido` = 102.00 (clampeado)
- ✅ Motivo menciona límite máximo

---

### CT-SIM-009: Sin parámetros modoSimulacion/persistir (Defaults)

**Objetivo:** Validar que defaults funcionan (true/false)

**Entrada:** (misma que CT-SIM-001 pero SIN `modoSimulacion` ni `persistir`)
```json
{
  "empresaId": 1,
  "sku": "TEST-DEFAULTS-001",
  "titulo": "Con Defaults",
  "precioPropuesto": 100.00,
  "stockDisponible": 50,
  ...
  "costoBase": 40.00,
  "iva": 21.00,
  "comisionMLPorc": 11.5,
  "costoEnvioPromedio": 5.00,
  "costoLogisticoFijo": 2.00,
  "costoFinancieroPorc": 3.0,
  "costoPublicidadPorc": 2.0,
  "estadoPublicacion": "active"
}
```

**Salida Esperada:** (idéntica a CT-SIM-001)
```json
{
  "modoSimulacion": true,
  "accion": "MANTENER_PRECIO",
  "precioSugerido": 100.00
}
```

**Validaciones:**
- ✅ Usa defaults (modoSimulacion=true, persistir=false)
- ✅ No hay errores de deserialización

---

## Casos de Producción

### CT-PROD-001: Modo Producción con Persistencia

**Objetivo:** Validar que modo producción carga datos de BASE y persiste

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "PROD-REAL-001",
  "precioPropuesto": 100.00,
  "stockDisponible": 50,
  "costoBase": 40.00,
  "iva": 21.00,
  "comisionMLPorc": 11.5,
  "costoEnvioPromedio": 5.00,
  "costoLogisticoFijo": 2.00,
  "costoFinancieroPorc": 3.0,
  "costoPublicidadPorc": 2.0,
  "modoSimulacion": false,
  "persistir": true
}
```

**Comportamiento SQL:**
1. `@ContextSource = "BASE"`
2. Carga datos desde PublicacionesML + Productos + Stock
3. Si encuentra datos → Aplica reglas
4. Si no encuentra → Retorna conjunto vacío
5. `@Persistir = 1` → INSERT en DecisionesHistorial
6. `@ModoSimulacion = 0` → INSERT en ColaEjecucionML (si acción cambio)

**Validaciones:**
- ✅ Status Code = 200 (o 200 vacío si no hay datos)
- ✅ Si hay respuesta: `modoSimulacion = false`
- ✅ Ver BD: `SELECT TOP 1 * FROM DecisionesHistorial ORDER BY FechaDecision DESC`

---

### CT-PROD-002: Modo Producción SIN Persistencia

**Objetivo:** Validar que `@Persistir = 0` no guarda en BD

**Entrada:** (misma que CT-PROD-001 pero `"persistir": false`)

**Comportamiento:**
1. Carga desde BASE
2. Aplica reglas
3. `@Persistir = 0` → NO INSERT en DecisionesHistorial
4. NO encola en ColaEjecucionML

**Validaciones:**
- ✅ Retorna resultado
- ✅ BD: `SELECT COUNT(*) FROM DecisionesHistorial` NO incrementa

---

## Casos de Error y Edge

### CT-ERR-001: EmpresaId Inválida

**Entrada:**
```json
{
  "empresaId": 999,
  "sku": "TEST-001",
  "precioPropuesto": 100.00,
  ...
  "modoSimulacion": true,
  "persistir": false
}
```

**Salida Esperada:**
```
Status Code: 500
Error: "No existe una estrategia activa configurada para la empresa."
```

**Validaciones:**
- ✅ Error claro y preciso

---

### CT-ERR-002: precioPropuesto = 0

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-001",
  "precioPropuesto": 0.00,
  ...
  "costoBase": 40.00
}
```

**Salida Esperada:**
```
Status Code: 400
Error: "El campo precioPropuesto debe ser mayor a cero."
```

**Validaciones:**
- ✅ Validación en UiAdapter
- ✅ No llega a SQL

---

### CT-ERR-003: costoBase Negativo

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-001",
  "precioPropuesto": 100.00,
  ...
  "costoBase": -10.00
}
```

**Salida Esperada:**
```
Status Code: 400
Error: "El campo costoBase debe ser mayor a cero."
```

**Validaciones:**
- ✅ Validación en UiAdapter

---

### CT-ERR-004: SKU Vacío

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "",
  "precioPropuesto": 100.00,
  ...
}
```

**Salida Esperada:**
```
Status Code: 400
Error: "El campo sku es obligatorio."
```

**Validaciones:**
- ✅ Validación en UiAdapter

---

### CT-ERR-005: JSON Inválido (Syntax)

**Entrada:**
```
{
  "empresaId": 1,
  "sku": "TEST",
  "precioPropuesto": 100.00
  FALTA COMA
}
```

**Salida Esperada:**
```
Status Code: 400
Error: "One or more validation errors occurred."
```

**Validaciones:**
- ✅ Deserialización falla

---

### CT-EDGE-001: Precio = Costo (Margen = 0%)

**Entrada:**
```json
{
  "empresaId": 1,
  "sku": "TEST-EDGE-001",
  "precioPropuesto": 100.00,
  "costoBase": 100.00,
  "stockDisponible": 50,
  ...
}
```

**Salida Esperada:**
```json
{
  "margenActualPorc": 0.00,
  "accion": "NO_MODIFICAR",
  "motivo": "BLOQUEO SEGURIDAD: La baja sugerida viola el margen mínimo permitido (15%)."
}
```

**Validaciones:**
- ✅ Margen = 0% < 15% → BLOQUEA

---

### CT-EDGE-002: Stock Exactamente en Límites

**Entrada:**
```json
{
  "stockDisponible": 10,
  "stockMinimo": 10,
  "stockMaximo": 200
}
```

**Salida Esperada:**
```json
{
  "clasificacionStock": "CRITICO"
}
```

**Validaciones:**
- ✅ Stock ≤ Mínimo → CRITICO (frontera inclusive)

---

### CT-EDGE-003: Stock Exactamente en Máximo

**Entrada:**
```json
{
  "stockDisponible": 200,
  "stockMinimo": 10,
  "stockMaximo": 200
}
```

**Salida Esperada:**
```json
{
  "clasificacionStock": "EXCESO"
}
```

**Validaciones:**
- ✅ Stock ≥ Máximo → EXCESO (frontera inclusive)

---

### CT-EDGE-004: Decimales Muy Altos (Precisión)

**Entrada:**
```json
{
  "precioPropuesto": 99999.9999,
  "costoBase": 99999.9998,
  "iva": 21.5,
  ...
}
```

**Salida Esperada:**
```json
{
  "precioActual": 99999.9999,
  "precioSugerido": 99999.9999,
  "margenActualPorc": [pequeño positivo]
}
```

**Validaciones:**
- ✅ Sin overflow
- ✅ Precisión DECIMAL(18,4) respetada

---

## Casos de Flujo Combinado

### CT-COMBO-001: Stock Crítico + Margen Bajo

**Objetivo:** Validar que seguridad prevalece sobre regla de stock

**Entrada:**
```json
{
  "sku": "TEST-COMBO-001",
  "precioPropuesto": 100.00,
  "costoBase": 85.00,
  "stockDisponible": 5,
  "stockMinimo": 10,
  "stockMaximo": 200,
  ...
}
```

**Cálculo Margen:** (100 - 85) / 100 = 15.00% (exactamente el mínimo)

**Procesamiento:**
1. Stock = 5 → CRITICO
2. Regla 1: `PrecioSugerido = 100 × 1.05 = 105.00`
3. Restricción 1: Margen de 105 = (105 - 85) / 105 = 19.05% > 15% ✅

**Salida Esperada:**
```json
{
  "precioActual": 100.00,
  "precioSugerido": 105.00,
  "accion": "AUMENTAR_PRECIO",
  "margenProyectadoPorc": 19.05
}
```

**Validaciones:**
- ✅ Regla se aplica porque margen final sigue siendo > 15%

---

### CT-COMBO-002: Exceso Stock + Límite Máximo Muy Bajo

**Objetivo:** Validar que límite máximo clapea descuento agresivo

**Entrada:**
```json
{
  "sku": "TEST-COMBO-002",
  "precioPropuesto": 100.00,
  "precioMaximoPermitido": 95.00,
  "stockDisponible": 250,
  "stockMaximo": 200,
  "costoBase": 40.00,
  ...
}
```

**Procesamiento:**
1. Stock = 250 → EXCESO
2. Regla 3: `PrecioSugerido = 100 × 0.93 = 93.00`
3. Restricción 2: `93.00 < 95.00` → NO CLAMPEA

**Salida Esperada:**
```json
{
  "precioSugerido": 93.00,
  "accion": "DISMINUIR_PRECIO"
}
```

**Validaciones:**
- ✅ NO se clampea (93 < 95)

---

## Matriz de Validación Resumen

| Caso | Entrada Clave | Salida Esperada | Status |
|------|---------------|-----------------|--------|
| CT-SIM-001 | Normal | MANTENER | ✅ Documentado |
| CT-SIM-002 | Stock CRITICO | AUMENTAR 5% | ✅ Documentado |
| CT-SIM-005 | Stock EXCESO | DISMINUIR 7% | ✅ Documentado |
| CT-SIM-006 | Margen < 15% | NO_MODIFICAR | ✅ Documentado |
| CT-PROD-001 | Modo BASE + Persistir | Guarda BD | ✅ Documentado |
| CT-ERR-001 | Empresa inválida | Error 500 | ✅ Documentado |

---

## Ejecución en Batch

### Script PowerShell para ejecutar todos los casos

```powershell
$baseUrl = "http://localhost:5000/pricing/evaluate"

# CT-SIM-001
$json1 = @{
    empresaId = 1
    sku = "TEST-NORMAL-001"
    precioPropuesto = 100.00
    # ... resto de parámetros
    modoSimulacion = $true
    persistir = $false
} | ConvertTo-Json

$response1 = Invoke-RestMethod -Uri $baseUrl -Method Post -Body $json1 -ContentType "application/json"
Write-Host "CT-SIM-001: $($response1.accion)"

# ... más casos
```

---

**Versión:** 2.1  
**Última Actualización:** 15/08/2026  
**Total de Casos:** 19 + combinados