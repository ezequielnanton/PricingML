# Guía de Compilación y Ejecución - Pricing Engine

**Última actualización**: 2026-08-18  
**Framework**: .NET 10.0  
**OS**: Windows 10/11, Linux, macOS

---

## 1. Requisitos Previos

### Software requerido
- ✅ .NET 10.0 SDK (descargar de https://dotnet.microsoft.com/download)
- ✅ SQL Server 2019+ (SQL Express o superior)
- ✅ PowerShell 5.1+ o Terminal (Windows)
- ✅ Git (opcional, para clonar)

### Verificar instalación

```powershell
# Verificar .NET
dotnet --version
# Output: 10.0.400 (o superior)

# Verificar SQL Server
sqlcmd -S localhost\SQLEXPRESS -Q "SELECT @@VERSION"
```

### Base de datos

```powershell
# Crear BD PRICES_DB
sqlcmd -S localhost\SQLEXPRESS -Q "CREATE DATABASE PRICES_DB"

# Aplicar esquema
sqlcmd -S localhost\SQLEXPRESS -d PRICES_DB -i "c:\PricingEngine\SQL\Estructura.sql"
```

---

## 2. Preparar el ambiente

### 2.1 Clonar/descargar proyecto

```powershell
# Si tienes Git
git clone <repo-url> c:\PricingEngine

# O descargar ZIP y extraer a c:\PricingEngine
```

### 2.2 Navigar a la carpeta del proyecto

```powershell
cd c:\PricingEngine
```

---

## 3. Restaurar dependencias

### Opción A: Restaurar toda la solución

```powershell
cd c:\PricingEngine
dotnet restore
```

### Opción B: Restaurar solo PricingApi (recomendado para desarrollo)

```powershell
cd c:\PricingEngine\src\PricingApi
dotnet restore
```

**Output esperado**:
```
Restore completed in X.XXs for c:\PricingEngine\src\PricingApi\PricingApi.csproj
```

---

## 4. Compilación

### 4.1 Compilar solución completa

```powershell
cd c:\PricingEngine
dotnet build
```

**Output esperado**:
```
Build succeeded. (X.XXXs)
Total errors: 0, Total warnings: 0
```

### 4.2 Compilar solo PricingApi (recomendado)

```powershell
cd c:\PricingEngine\src\PricingApi
dotnet build
```

### 4.3 Compilar con configuración Release

```powershell
dotnet build --configuration Release
```

---

## 5. Ejecutar Tests (Opcional)

### Ejecutar todos los tests

```powershell
cd c:\PricingEngine
dotnet test
```

### Ejecutar tests específicos

```powershell
cd c:\PricingEngine\src\PricingApi.Tests
dotnet test
```

**Output esperado**:
```
Test Run Successful.
Total tests: 6, Passed: 6, Failed: 0
```

---

## 6. Ejecutar la API

### 6.1 En modo Debug (Desarrollo)

```powershell
cd c:\PricingEngine\src\PricingApi
dotnet run
```

**Output esperado**:
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5060

Application started. Press Ctrl+C to exit.
```

**URL de la API**: `http://localhost:5060`

### 6.2 En modo Release (Producción)

```powershell
cd c:\PricingEngine\src\PricingApi
dotnet run --configuration Release
```

### 6.3 Especificar puerto custom

```powershell
dotnet run -- --urls "http://localhost:5000"
```

---

## 7. Acceder a la API

### 7.1 Health Check

```bash
curl http://localhost:5060/health
```

**Response esperado**:
```json
{
  "status": "ok"
}
```

### 7.2 Swagger (Documentación interactiva)

En desarrollo, accede a:
```
http://localhost:5060/swagger
```

---

## 8. Solución de Problemas

### Error: "Cannot connect to database"

**Solución**:
1. Verificar que SQL Server está corriendo
2. Verificar connection string en `appsettings.json`
3. Crear BD: `sqlcmd -S localhost\SQLEXPRESS -Q "CREATE DATABASE PRICES_DB"`

### Error: "Port XXXX already in use"

**Solución**:
```powershell
# Encontrar proceso usando puerto 5060
Get-Process | Where-Object { $_.ProcessName -like "*dotnet*" } | Stop-Process -Force

# O especificar puerto diferente
dotnet run -- --urls "http://localhost:5001"
```

### Error: ".NET SDK not found"

**Solución**:
```powershell
# Verificar versión instalada
dotnet --info

# Descargar e instalar .NET 10.0
# https://dotnet.microsoft.com/download/dotnet/10.0
```

### Error: "Project dependencies not restored"

**Solución**:
```powershell
dotnet clean
dotnet restore
dotnet build
```

---

## 9. Flujo Completo (Un comando)

```powershell
cd c:\PricingEngine; `
dotnet restore; `
dotnet build; `
dotnet test --no-build; `
cd src\PricingApi; `
dotnet run
```

O en una línea:
```powershell
cd c:\PricingEngine; dotnet restore; dotnet build; dotnet test --no-build; cd src\PricingApi; dotnet run
```

---

## 10. Proyectos en la Solución

| Proyecto | Ubicación | Tipo | Responsabilidad |
|----------|-----------|------|-----------------|
| PricingApi | src/PricingApi | Web API | API REST + Servicios de negocio |
| PricingAdapter | src/PricingAdapter | Library | Adaptadores de normalización |
| PricingApi.Tests | src/PricingApi.Tests | Test | Unit tests con XUnit |
| SqlProbe | src/SqlProbe | Console | Validación de conexión DB |

---

## 11. Configuración (appsettings.json)

### Ubicación
```
c:\PricingEngine\src\PricingApi\appsettings.json
```

### Contenido
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

### Customizar

Para cambiar puerto:
1. Crear `appsettings.Development.json`:
```json
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://localhost:5000"
      }
    }
  }
}
```

2. O ejecutar con: `dotnet run -- --urls "http://localhost:5000"`

---

## 12. Publicación (Deployment)

### Crear build Release auto-contenido

```powershell
dotnet publish -c Release -o c:\PricingEngine\publish
```

### Publicar en IIS

```powershell
dotnet publish -c Release -o "C:\inetpub\wwwroot\PricingApi"
```

---

## 13. Checklist Pre-Deployment

- [ ] .NET 10.0 SDK instalado y verificado
- [ ] SQL Server corriendo y PRICES_DB creada
- [ ] SQL/Estructura.sql aplicada
- [ ] appsettings.json configurado
- [ ] `dotnet restore` completado sin errores
- [ ] `dotnet build` completado sin errores
- [ ] `dotnet test` todos los tests pasando
- [ ] `dotnet run` inicia sin errores
- [ ] Health check responde en /health
- [ ] Swagger accesible en /swagger (dev)
- [ ] Frontend puede acceder (CORS configurado)

---

## 14. Comandos Rápidos Útiles

```powershell
# Información del ambiente
dotnet --info

# Limpiar compilaciones previas
dotnet clean

# Compilar sin ejecutar
dotnet build

# Ejecutar sin compilar (más rápido)
dotnet run --no-build

# Compilar para producción
dotnet build -c Release

# Ejecutar con información de debug
dotnet run -- --environment Development --loglevel Debug

# Monitorear cambios y recompilar (Watch mode)
dotnet watch run

# Ver versión de dependencias
dotnet list package

# Actualizar dependencias
dotnet add package <NombrePaquete>
```

---

**Última verificación**: 2026-08-18  
**Estado**: ✅ Compilación correcta  
**Responsable**: Equipo DevOps
  "status": "ok"
}
```

entonces la API quedó levantada correctamente.