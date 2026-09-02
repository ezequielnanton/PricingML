Implementation Notes - Estado actual (2026-08-18)

## Resumen ejecutivo de implementación

Este documento describe el estado de la implementación del Pricing Engine MVP y documenta decisiones técnicas tomadas.

**Estado**: MVP Funcional en fase de validación
**Plataforma**: .NET 10.0 ASP.NET Core + SQL Server
**Adaptadores activos**: UiAdapter
**Punto de entrada**: POST /api/input/ui/product

---

## 1. Servicios implementados

### 1.1 SqlPricingService (Singleton)
**Responsabilidad**: Motor de decisiones
- Invoca `dbo.spCalcularDecision` stored procedure
- Retorna `PricingDecisionResult` con precio sugerido, acción (AUMENTAR/DISMINUIR/MANTENER), margen %, score de confianza
- Soporta modo simulación (no persiste) y modo producción (encola para ejecución)

### 1.2 InputPersistenceService (Transient)
**Responsabilidad**: Ingestión y normalización de datos
- Método: `PersistProductoInputAsync(ProductoInput)`
- Flujo transaccional:
  1. Valida que empresa existe (throws `KeyNotFoundException` if missing)
  2. Upsert en `Productos` (clave: EmpresaID + SKU)
  3. Upsert en `CostosProducto` con todos los componentes de costo
  4. Upsert en `StockEstado` con niveles de inventario
- Rollback automático en caso de error
- No crea `PublicacionesML` (requiere CuentaMLID y MeliItemID)

### 1.3 AdminCrudService (Singleton)
**Responsabilidad**: Gestión de datos maestros
- Operaciones CRUD para: Empresas, Estrategias, Reglas, Monedas, Cotizaciones, ParametrosGenerales, CuentasML
- Usa SQL directo (no ORM) para rendimiento
- Métodos: GetAsync, CreateAsync, UpdateAsync, DeleteAsync

### 1.4 AdminReportsService (Singleton)
**Responsabilidad**: Reportes seguros sin inyección SQL
- Whitelist de tablas y columnas accesibles
- Filtros type-aware (contains, eq, gte, lt)
- Paginación: default 50, máximo 100
- Sorting multi-columna
- Conversión camelCase para frontend
- Validación regex de parámetros

---

## 2. Arquitectura de adaptadores

### 2.1 Patrón implementado

```
[Origen de datos] 
    |
    v
[Adaptador específico: Normaliza a ProductoInput]
    |
    v
[InputPersistenceService: Upsert transaccional]
    |
    v
[Tablas core: Productos, CostosProducto, StockEstado]
    |
    v
[SqlPricingService: spCalcularDecision]
    |
    v
[Auditoría: DecisionesHistorial, DecisionesDetalleAuditoria]
```

### 2.2 UiAdapter (implementado)
- Transforma `UiPricingRequest` en `ProductoInput`
- Normalizaciones:
  - SKU: trim() + uppercase()
  - Defaults: IVA=21%, ComisionML=9%
  - Validaciones: SKU no vacío, precio > 0, costo > 0

### 2.3 Adaptadores futuros (no implementados)
- **MeliAdapter**: Ingesta desde API de Mercado Libre
- **ErpAAdapter**, **ErpBAdapter**: Sistemas externos
- Todos siguen el mismo patrón: normalizar → ProductoInput

---

## 3. Endpoints principales

### Evaluación
- `GET /health` - Health check
- `POST /pricing/evaluate` - Evaluación (legacy)
- `POST /api/input/ui/product` - Ingestión UI (recomendado)

### Admin CRUD (bajo `/api/admin/`)
- `/empresas/{id}` - GET, POST, PUT, DELETE
- `/productos/{id}` - GET, POST
- `/estrategias/{id}` - GET (read-only MVP)
- `/reglas/{id}` - GET (read-only MVP)
- `/monedas` - POST
- `/cotizaciones` - POST
- `/cuentas-ml` - POST
- `/parametros-generales` - POST

### Reportes (futuro)
- `GET /api/reports/*` - No activos aún

---

## 4. Base de datos

### Tablas principales
- **Empresas**: Tenant root
- **Productos**: SKU por empresa (clave: EmpresaID + SKU)
- **CostosProducto**: Desglose de costos
- **StockEstado**: Niveles de inventario
- **PublicacionesML**: Publicaciones en Mercado Libre (no se crea desde UI)
- **DecisionesHistorial**: Historial de decisiones
- **DecisionesDetalleAuditoria**: Auditoría por regla
- **ColaEjecucionML**: Ejecución pendiente

### Funciones SQL
- `fn_CalcularMargenNetoPorc`: Cálculo de margen neto %

### Stored Procedures
- `dbo.spCalcularDecision`: Motor de decisiones (NO modificar sin autorización)

### Connection String
```
Server=localhost\SQLEXPRESS;Database=PRICES_DB;Integrated Security=True;TrustServerCertificate=True;
```

---

## 5. Decisiones técnicas

### 5.1 Persistencia
✅ **Upsert transaccional** en vez de insert único
- Razón: Permite reingesta de datos sin duplicados
- Implementación: EmpresaID + SKU como clave única
- Garantía: Todo o nada (rollback en error)

### 5.2 Validaciones
⚠️ **Mínimas en adapter**, exhaustivas recomendadas
- Current: SKU no vacío, precio > 0, costo > 0
- Mejora sugerida: Rangos coherentes, stock ≥ 0, IVA válido, etc.

### 5.3 Publicaciones ML
❌ **No se crean desde UI**
- Razón: Requiere CuentaMLID y MeliItemID (no disponibles en UI)
- Solución: Crear endpoint explícito o adaptador ML

### 5.4 Stored Procedure
🔒 **Congelado** hasta autorización expresa
- Razón: Core del motor, cambios requieren validación domain expert
- Impacto: Modificaciones de lógica de pricing requieren cambio explícito

### 5.5 Adaptadores
🔄 **Patrón preparado para extensión**
- Diseño: Cada origen normaliza a ProductoInput
- Ventaja: Motor agnóstico del origen
- Prueba: UiAdapter funciona, fácil agregar más

---

## 6. Testing

### Unit Tests
- **AdminReportsServiceTests**: 6 tests de paginación, filtros, ordenamiento, validación
- **Framework**: XUnit 2.9.3
- **Coverage**: AdminReportsService, validación de seguridad SQL

### Integration Tests
❌ **No implementadas** (requieren BD de pruebas)

### Recomendaciones
1. Agregar tests para InputPersistenceService (transaccionalidad)
2. Agregar tests para SqlPricingService (invocación SP)
3. Tests E2E con BD de pruebas
4. Load tests para evaluar rendimiento

---

## 7. Configuración

### appsettings.json
```json
{
  "ConnectionStrings": {
    "PricingDb": "Server=localhost\\SQLEXPRESS;Database=PRICES_DB;Integrated Security=True;TrustServerCertificate=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

### CORS
- Orígenes permitidos: localhost:3000, localhost:4200, localhost:5173
- Métodos: GET, POST, PUT, DELETE
- Headers: *

### Swagger
- Activo en desarrollo
- Deshabilitar en producción

---

## 8. Próximos pasos recomendados (Roadmap)

### Fase 2 (Corto plazo)
1. ✅ Implementar validaciones exhaustivas (rangos, negativos, etc.)
2. ✅ Agregar structured logging (ILogger en servicios)
3. ✅ Crear adaptador ML e integración con Mercado Libre
4. ✅ Endpoints de creación de PublicacionesML
5. ✅ Tests de integración con BD de pruebas

### Fase 3 (Mediano plazo)
1. 🔐 Autenticación y autorización (JWT)
2. 📊 Endpoints de reportes activos
3. 💾 Snapshots históricos para backtesting completo
4. 💱 Integración de conversión de moneda en motor
5. 📈 Metricas y monitoreo

### Fase 4 (Largo plazo)
1. 🚀 Auto-envío de cambios a Mercado Libre
2. 🤖 ML/AI para optimización de reglas
3. 📱 Mobile app
4. 🌍 Multi-región y multi-moneda integral

---

## 9. Operación

### Pre-launch checklist
- [ ] BD PRICES_DB creada
- [ ] SQL/Estructura.sql aplicada
- [ ] Connection string configurada (appsettings.json o env vars)
- [ ] Empresa de prueba creada (POST /api/admin/empresas)
- [ ] Frontend en localhost:3000 (o puerto configurado)
- [ ] Swagger accesible en /swagger

### Troubleshooting
| Error | Causa | Solución |
|-------|-------|----------|
| 404 Empresa | EmpresaId no existe | Crear empresa primero |
| 400 SKU vacío | Validación fallida | Proporcionar SKU válido |
| 500 Connection timeout | PRICES_DB desconectada | Verificar SQL Server corriendo |
| 400 Bad request | CORS policy | Verificar origen frontend en appsettings |

---

## 10. Notas finales

- **Modelo canónico**: ProductoInput es la única representación interna que el motor recibe
- **Responsabilidad de adapter**: Cada origen mapea a ProductoInput
- **Transaccionalidad**: Garantizada en InputPersistenceService
- **Auditoría**: Completa en DecisionesHistorial + DecisionesDetalleAuditoria
- **Motor congelado**: spCalcularDecision no se modifica sin autorización

---

**Última actualización**: 2026-08-18
**Responsable**: Equipo Development