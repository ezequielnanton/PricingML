# Guía Rápida: Levantar API y Probar con Postman

**Última actualización**: 2026-08-18  
**Tiempo estimado**: 15 minutos  
**Requisitos**: .NET 10.0 SDK, SQL Server, Postman

---

## Paso 1: Preparar la Base de Datos

### 1.1 Crear la BD PRICES_DB

```powershell
# Abre PowerShell como Admin
sqlcmd -S localhost\SQLEXPRESS -Q "CREATE DATABASE PRICES_DB"
```

### 1.2 Aplicar esquema SQL

```powershell
# Ejecuta el archivo de estructura
sqlcmd -S localhost\SQLEXPRESS -d PRICES_DB -i "C:\PricingEngine\SQL\Estructura.sql"
```

**Verificación**:
```powershell
sqlcmd -S localhost\SQLEXPRESS -d PRICES_DB -Q "SELECT COUNT(*) FROM sys.tables"
# Debería retornar: 17+ tablas
```

---

## Paso 2: Levantar la API

### 2.1 Abrir terminal PowerShell

```powershell
# Navegar al proyecto
cd C:\PricingEngine\src\PricingApi
```

### 2.2 Restaurar dependencias

```powershell
dotnet restore
```

### 2.3 Compilar

```powershell
dotnet build
```

### 2.4 Ejecutar

```powershell
dotnet run
```

**Output esperado**:
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5060
      
Application started. Press Ctrl+C to exit.
```

**Si el puerto está en uso**:
```powershell
# Matar proceso anterior
Get-Process | Where-Object { $_.Name -like "*dotnet*" } | Stop-Process -Force

# Ejecutar en puerto diferente
dotnet run -- --urls "http://localhost:5001"
```

---

## Paso 3: Verificar que la API funciona

### 3.1 Health Check (en otra terminal)

```powershell
# Terminal nueva
Invoke-WebRequest -Uri "http://localhost:5060/health" -Method GET | ConvertTo-Json
```

**Response esperada**:
```json
{
  "StatusCode": 200,
  "Content": "{\"status\":\"ok\"}"
}
```

### 3.2 O acceder a Swagger (UI interactiva)

Abre en navegador:
```
http://localhost:5060/swagger
```

---

## Paso 4: Importar Collection en Postman

### 4.1 Descargar Postman

Si no lo tienes: https://www.postman.com/downloads/

### 4.2 Crear collection manual

En Postman:
1. New → Collection → Nombre: "Pricing Engine"
2. Crear carpeta: "Pricing"
3. Crear folder: "Admin"

### 4.3 Guardar URL Base como variable

1. Click en collection → Variables
2. Agregar variable `baseUrl` con valor `http://localhost:5060`

---

## Paso 5: Pruebas Rápidas

### Test 1: Health Check

**Endpoint**: GET /health

```
GET {{baseUrl}}/health
```

**Headers**:
```
Content-Type: application/json
```

**Body**: (vacío)

**Response esperada** (200):
```json
{
  "status": "ok"
}
```

---

### Test 2: Evaluar Producto (Simulación)

**Endpoint**: POST /pricing/evaluate

```
POST {{baseUrl}}/pricing/evaluate
```

**Headers**:
```
Content-Type: application/json
```

**Body**:
```json
{
  "empresaId": 1,
  "sku": "TEST-PROD-001",
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

**Response esperada** (200):
```json
{
  "empresaId": 1,
  "sku": "TEST-PROD-001",
  "precioActual": 1000.0,
  "precioSugerido": 1000.0,
  "accion": "MANTENER",
  "motivo": "Margen dentro de límites",
  "margenActualPorc": 19.14,
  "scoreConfianza": 87.3,
  "modoSimulacion": true,
  "fuenteOrigen": "UI"
}
```

---

### Test 3: Ingerir desde UI (con persistencia)

**Endpoint**: POST /api/input/ui/product

```
POST {{baseUrl}}/api/input/ui/product
```

**Headers**:
```
Content-Type: application/json
```

**Body** (mismo que Test 2 pero con `persistir: true`):
```json
{
  "empresaId": 1,
  "sku": "PERSIST-001",
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

**Response esperada** (201):
```json
{
  "productoId": 1,
  "sku": "PERSIST-001",
  "empresaId": 1,
  "decision": {
    "empresaId": 1,
    "sku": "PERSIST-001",
    "precioActual": 5000.0,
    "precioSugerido": 5000.0,
    "accion": "MANTENER",
    "motivo": "Margen dentro de límites",
    "margenActualPorc": 21.0,
    "scoreConfianza": 87.3,
    "modoSimulacion": false,
    "fuenteOrigen": "UI"
  }
}
```

---

### Test 4: Crear Empresa (Admin CRUD)

**Endpoint**: POST /api/admin/empresas

```
POST {{baseUrl}}/api/admin/empresas
```

**Headers**:
```
Content-Type: application/json
```

**Body**:
```json
{
  "razonSocial": "Mi Empresa LTDA",
  "cuit": "30123456789"
}
```

**Response esperada** (201):
```json
{
  "id": 1,
  "razonSocial": "Mi Empresa LTDA",
  "cuit": "30123456789",
  "activo": true,
  "fechaCreacion": "2026-08-18T14:30:00Z"
}
```

---

### Test 5: Validación (SKU vacío = 400)

**Endpoint**: POST /pricing/evaluate

**Body** (con SKU vacío):
```json
{
  "empresaId": 1,
  "sku": "",
  "titulo": "Test",
  "precioPropuesto": 1000.0,
  ...resto de campos...
}
```

**Response esperada** (400):
```json
{
  "errors": {
    "sku": ["SKU cannot be empty"]
  }
}
```

---

## Paso 6: Checklist de Verificación

- [ ] API levantada en http://localhost:5060
- [ ] GET /health retorna 200 OK
- [ ] POST /pricing/evaluate retorna 200 OK
- [ ] POST /api/input/ui/product retorna 201 Created
- [ ] POST /api/admin/empresas retorna 201 Created
- [ ] Validaciones funcionan (400 Bad Request)
- [ ] Base de datos PRICES_DB creada
- [ ] Tablas creadas correctamente

---

## Paso 7: Conectar Frontend

### Configuración de CORS

El archivo `Program.cs` ya tiene CORS habilitado para:
- `http://localhost:3000` (React)
- `http://localhost:4200` (Angular)
- `http://localhost:5173` (Vite)

Si tu frontend está en otro puerto, edita `Program.cs`:

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins("http://localhost:TU_PUERTO")
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});
```

Luego recompila y ejecuta:
```powershell
dotnet build
dotnet run
```

---

## Paso 8: Troubleshooting

### Error: "Cannot connect to database"

```powershell
# Verificar SQL Server está corriendo
Get-Service -Name MSSQLSERVER | Select Status

# Verificar BD existe
sqlcmd -S localhost\SQLEXPRESS -Q "SELECT name FROM sys.databases WHERE name='PRICES_DB'"

# Si no existe, crear:
sqlcmd -S localhost\SQLEXPRESS -Q "CREATE DATABASE PRICES_DB"
sqlcmd -S localhost\SQLEXPRESS -d PRICES_DB -i "C:\PricingEngine\SQL\Estructura.sql"
```

### Error: "Port already in use"

```powershell
# Ver proceso en puerto 5060
netstat -ano | findstr :5060

# Matar proceso
taskkill /PID <PID> /F

# O ejecutar en puerto diferente
dotnet run -- --urls "http://localhost:5001"
```

### Error: ".NET SDK not found"

```powershell
# Verificar SDK
dotnet --info

# Instalar .NET 10.0
# https://dotnet.microsoft.com/download/dotnet/10.0
```

---

## Paso 9: Colección Postman Lista

Descarga o importa esta colección:

**Archivo**: `docs/Postman-Collection.json` (por crear)

Para crear manualmente en Postman, usa los ejemplos de **Paso 5**.

---

## Paso 10: Próximos Pasos

1. ✅ Configurar frontend para llamar a `{{baseUrl}}/api/input/ui/product`
2. ✅ Implementar adaptador ML cuando sea necesario
3. ✅ Agregar autenticación (JWT) en Fase 2
4. ✅ Activar endpoints de reportes

---

## Comandos Rápidos

```powershell
# Todo de una vez
cd C:\PricingEngine\src\PricingApi; dotnet restore; dotnet build; dotnet run

# En puerto custom
dotnet run -- --urls "http://localhost:5001"

# Con variables de entorno
$env:ConnectionStrings__PricingDb="Server=MI_SERVIDOR\SQLEXPRESS;Database=PRICES_DB;Integrated Security=True;"
dotnet run
```

---

**Estado**: ✅ Listo para producción MVP  
**Última revisión**: 2026-08-18  
**Soporte**: Contactar equipo DevOps

URL de ejemplo:

```http
http://localhost:5060/health
```

En Postman:
- Method: GET
- URL: `http://localhost:5060/health`
- Send

Respuesta esperada:

```json
{
  "status": "ok"
}
```

Si esto funciona, la API está levantada correctamente.

---

## 3) Probar el endpoint principal

### Endpoint

```http
POST /pricing/evaluate
```

Ejemplo completo:

```http
http://localhost:5060/pricing/evaluate
```

### Configuración en Postman

1. Abrir Postman
2. Crear una nueva request
3. Elegir `POST`
4. Poner la URL:
   ```http
   http://localhost:5060/pricing/evaluate
   ```
5. En la pestaña `Headers` agregar:
   ```http
   Content-Type: application/json
   ```
6. En la pestaña `Body` seleccionar `raw`
7. Elegir `JSON`
8. Pegar este payload:

```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "titulo": "Celular X",
  "precioPropuesto": 250000,
  "precioMinimoPermitido": 230000,
  "precioMaximoPermitido": 290000,
  "stockDisponible": 15,
  "stockMinimo": 10,
  "stockMaximo": 30,
  "costoBase": 190000,
  "iva": 21,
  "comisionMLPorc": 9,
  "costoEnvioPromedio": 2500,
  "costoLogisticoFijo": 1200,
  "costoFinancieroPorc": 1.5,
  "costoPublicidadPorc": 3,
  "estadoPublicacion": "active",
  "origen": "UI"
}
```

9. Click en `Send`

### Formato de números decimales

El contrato HTTP usa JSON estándar: los números se envían sin comillas y el
separador decimal es siempre el punto (`.`), independientemente de la
configuración regional de Windows o Postman.

```json
{
  "iva": 21.00,
  "comisionMLPorc": 11.5,
  "costoFinancieroPorc": 3.0,
  "costoPublicidadPorc": 2.0
}
```

La API los interpreta con cultura invariante. Por lo tanto, `21.00` significa
veintiuno y nunca `2100`. No enviar valores decimales como texto, por ejemplo
`"21,00"`.

---

## 4) Respuesta esperada

La API transforma el payload con el adapter y luego llama al motor SQL. En un escenario correcto, la respuesta será algo similar a:

```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "precioActual": 250000,
  "precioSugerido": 250000,
  "accion": "MANTENER_PRECIO",
  "motivo": "Escenario simulado",
  "margenActualPorc": -8.34,
  "scoreConfianza": 0.80,
  "modoSimulacion": true,
  "fuenteOrigen": "UI"
}
```

La respuesta REST expone el resumen de la decisión. Los campos adicionales del
procedimiento —por ejemplo `MargenProyectadoPorc`, `ClasificacionStock` y
`CompMinPrecio`— se consultan al ejecutar `spCalcularDecision` directamente;
no forman parte todavía del contrato de la API.

---

## 5) Si falla la llamada a SQL

Si desde Postman aparece un error relacionado con SQL Server o base de datos, revisar esto:

### Verificaciones rápidas

1. La instancia `localhost\SQLEXPRESS` está levantada
2. La base `PRICES_DB` existe
3. El procedimiento `dbo.spCalcularDecision` existe en esa base
4. El usuario de Windows tiene permisos para conectarse a SQL Server
5. La cadena de conexión en `appsettings.json` es válida

### Diagnóstico típico

Error de conexión:
- SQL Server no está arrancado
- el puerto 1433 o la instancia no está disponible
- la base no existe

Error de procedimiento:
- `dbo.spCalcularDecision` no está creado
- la base está vacía o la estructura no fue aplicada

---

### Error: parámetro `2100,00` fuera del intervalo

**Causa:** una versión anterior de la API interpretó `21.00` con la cultura
local y lo convirtió en `2100.00`, valor inválido para `@IVA DECIMAL(5,2)`.

**Solución:** detener la API, recompilar y volver a ejecutar `dotnet run`.
Conservar los decimales del payload con punto, por ejemplo `21.00`.

---

## 6) ¿Por qué Postman es una buena opción acá?

Postman es un cliente HTTP ideal para esta etapa porque:

- permite probar la API sin frontend
- permite enviar JSON mock rápido
- ayuda a validar contratos de entrada y salida
- reduce el tiempo de integración con SQL y negocio

En otras palabras, Postman hace el papel de una interfaz temporal del sistema mientras el motor se valida.

---

## 7) Siguiente paso recomendado

Luego de ver que la API responde y el motor ejecuta decisiones reales, el siguiente paso es:

- armar un frontend simple
- o integrar un ERP u otro sistema origen
- o crear adaptadores específicos para cada fuente (UI, ERP, ML, etc.)

## 8) Resumen rápido

### Comandos para levantar la API

```powershell
cd "c:\PricingEngine\src\PricingApi"
dotnet restore
dotnet build
dotnet run
```

### URL a probar

```http
http://localhost:5060/health
http://localhost:5060/pricing/evaluate
```

### Método HTTP

```http
POST /pricing/evaluate
Content-Type: application/json
```

Con este documento ya podés levantar la API y probarla desde Postman de forma local y repetible.