# Configuración por Cliente - Pricing Engine

**Última actualización**: 2026-08-18  
**Enfoque**: Configuración multi-tenant sin recompilación

---

## 1. Filosofía de Configuración

El Pricing Engine está diseñado para servir múltiples clientes (tenants) desde el mismo binario compilado.

**Principio**: 
- **Cambios de código** → Recompilar
- **Cambios de infraestructura, credenciales, o cliente** → Variables de entorno

---

## 2. Configuración Base (appsettings.json)

### Ubicación
```
c:\PricingEngine\src\PricingApi\appsettings.json
```

### Contenido por defecto
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
  "AllowedHosts": "*",
  "Cors": {
    "AllowedOrigins": [
      "http://localhost:3000",
      "http://localhost:4200",
      "http://localhost:5173"
    ]
  }
}
```

---

## 3. Configuración por Variables de Entorno

### 3.1 Connection String

El patrón de ASP.NET Core permite reemplazar configuración usando variables de entorno.

**Formato de variable**:
```
ConnectionStrings__PricingDb (doble guión bajo)
```

Se mapea a:
```json
{
  "ConnectionStrings": {
    "PricingDb": "..."
  }
}
```

### 3.2 Configurar en PowerShell

```powershell
# Variable de entorno para esta sesión
$env:ConnectionStrings__PricingDb="Server=SQL-CLIENTE-A;Database=PRECIOS_DB;Integrated Security=True;TrustServerCertificate=True;"

# O de forma permanente (Windows)
[Environment]::SetEnvironmentVariable("ConnectionStrings__PricingDb", "Server=...", [EnvironmentVariableTarget]::User)
```

---

## 4. Ejemplos por Cliente

### Cliente A (SQL Server en red)

```powershell
# Iniciar sesión PowerShell
$env:ConnectionStrings__PricingDb="Server=sql-cliente-a.empresa.com;Database=PRICES_DB;User Id=pricing_user;Password=SecurePass123!;Encrypt=true;TrustServerCertificate=False;"

cd C:\PricingEngine\src\PricingApi
dotnet run
```

### Cliente B (SQL Express local)

```powershell
$env:ConnectionStrings__PricingDb="Server=.\SQLEXPRESS;Database=PRECIOS_CLIENTE_B;Integrated Security=True;TrustServerCertificate=True;"

cd C:\PricingEngine\src\PricingApi
dotnet run
```

### Desarrollo Local

```powershell
$env:ConnectionStrings__PricingDb="Server=localhost\SQLEXPRESS;Database=PRICES_DB;Integrated Security=True;TrustServerCertificate=True;"

cd C:\PricingEngine\src\PricingApi
dotnet run
```

### Producción en Azure SQL

```powershell
$env:ConnectionStrings__PricingDb="Server=tcp:pricing-server.database.windows.net,1433;Initial Catalog=PRICES_DB;Persist Security Info=False;User ID=sqladmin;Password=SecurePass123!;Encrypt=True;Connection Timeout=30;"

cd C:\PricingEngine\src\PricingApi
dotnet run
```

---

## 5. Otros Parámetros Configurables

### 5.1 Logging Level

```powershell
# Cambiar nivel de logs
$env:Logging__LogLevel__Default="Debug"

# O por namespace específico
$env:Logging__LogLevel__Microsoft__AspNetCore="Debug"
```

### 5.2 CORS Customizado

Para agregar orígenes adicionales, edita `appsettings.json` o agrega variables:

```powershell
$env:Cors__AllowedOrigins__0="http://localhost:3000"
$env:Cors__AllowedOrigins__1="http://localhost:4200"
$env:Cors__AllowedOrigins__2="https://app.cliente.com"
```

### 5.3 Puerto Personalizado

```powershell
# Ejecutar en puerto 5000 en lugar de 5060
dotnet run -- --urls "http://localhost:5000"
```

### 5.4 Environment (Development/Production)

```powershell
# Environment variable
$env:ASPNETCORE_ENVIRONMENT="Production"

# O al ejecutar
dotnet run --environment Production
```

---

## 6. appsettings por Ambiente (Alternativa)

Si prefieres archivos en lugar de variables de entorno:

### 6.1 Crear archivos

```
src/PricingApi/
├── appsettings.json                    (base)
├── appsettings.Development.json        (dev)
├── appsettings.Staging.json            (staging)
└── appsettings.Production.json         (prod)
```

### 6.2 appsettings.Development.json

```json
{
  "ConnectionStrings": {
    "PricingDb": "Server=localhost\\SQLEXPRESS;Database=PRICES_DB;Integrated Security=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Debug"
    }
  }
}
```

### 6.3 appsettings.Production.json

```json
{
  "ConnectionStrings": {
    "PricingDb": "Server=prod-sql-server;Database=PRICES_DB;User Id=pricing_prod;Password=...;Encrypt=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Warning"
    }
  }
}
```

### 6.4 Ejecutar con ambiente

```powershell
$env:ASPNETCORE_ENVIRONMENT="Production"
cd C:\PricingEngine\src\PricingApi
dotnet run
# Cargará appsettings.json + appsettings.Production.json
```

---

## 7. Precedencia de Configuración

En ASP.NET Core, el orden de precedencia es:

1. **Variables de entorno** (mayor prioridad)
2. appsettings.{Environment}.json
3. appsettings.json
4. Valores por defecto en código

**Ejemplo**:
```powershell
# Si defines esta variable
$env:ConnectionStrings__PricingDb="Server=OTRA"

# Y además tienes appsettings.Production.json con otra conexión
# La variable de entorno GANA
```

---

## 8. Flujo de Deployment

### Fase 1: Compilación (Una sola vez)

```powershell
cd C:\PricingEngine
dotnet build --configuration Release
dotnet test

# Resultado: binarios listos en bin/Release/
```

### Fase 2: Deployment (Por cliente)

**Copiar binarios**:
```powershell
Copy-Item -Recurse "C:\PricingEngine\src\PricingApi\bin\Release\net10.0\*" -Destination "C:\Clientes\ClienteA\PricingApi"
```

**Crear script de inicio por cliente**:

`C:\Clientes\ClienteA\start-api.ps1`:
```powershell
# Configuración de Cliente A
$env:ConnectionStrings__PricingDb="Server=SQL-CLIENTE-A;Database=PRICES_DB;Integrated Security=True;"
$env:ASPNETCORE_ENVIRONMENT="Production"
$env:ASPNETCORE_URLS="http://localhost:5000"

# Ejecutar
C:\Clientes\ClienteA\PricingApi\PricingApi.exe
```

**Crear Windows Service** (opcional):

```powershell
# Usando NSSM (Non-Sucking Service Manager)
nssm install PricingAPI_ClienteA `
  "C:\Clientes\ClienteA\start-api.ps1" `
  -ExecutionPolicy ByPass

nssm start PricingAPI_ClienteA
```

---

## 9. Verificación de Configuración

### Confirmar que la conexión es correcta

```powershell
# Ejecutar API en modo verbose
$env:Logging__LogLevel__Default="Debug"
dotnet run

# Observar logs. Si arranca sin errores de BD:
# ✅ Conexión correcta
```

### Test de conectividad SQL

```powershell
# Desde PowerShell
sqlcmd -S "sql-cliente-a.empresa.com" -d PRICES_DB -Q "SELECT @@VERSION"

# Si responde con versión de SQL Server: ✅ Conectividad OK
```

### Health check post-deployment

```bash
curl http://localhost:5000/health
# Response: {"status":"ok"}
```

---

## 10. Troubleshooting

### "Connection timeout"
**Solución**:
```powershell
# Verificar servidor SQL
ping sql-cliente-a.empresa.com

# Verificar puerto SQL
Test-NetConnection -ComputerName sql-cliente-a.empresa.com -Port 1433

# Verificar credenciales en variable
$env:ConnectionStrings__PricingDb
```

### "Login failed"
**Solución**:
```powershell
# Verificar usuario y contraseña
sqlcmd -S "servidor" -U "usuario" -P "password"

# Si usa Integrated Security, verificar permisos
sqlcmd -S "servidor" -E -Q "SELECT USER"
```

### "Database not found"
**Solución**:
```powershell
# Crear BD en cliente
sqlcmd -S "servidor" -Q "CREATE DATABASE PRICES_DB"
sqlcmd -S "servidor" -d PRICES_DB -i "SQL\Estructura.sql"
```

---

## 11. Checklist de Deployment

- [ ] Compilación Release completada
- [ ] Binarios copiados a carpeta del cliente
- [ ] appsettings.json actualizado o variable de entorno definida
- [ ] Conexión SQL probada (sqlcmd)
- [ ] BD PRICES_DB creada y esquema aplicado
- [ ] Health check responde 200
- [ ] Firewall permite tráfico (cliente puede acceder a API)
- [ ] Logs disponibles para debugging

---

## 12. Seguridad: Credenciales en Variables

### ❌ NO HACER
```powershell
# Guardar password en claro en archivos
# appsettings.json: "Password=MyPassword123"
```

### ✅ SI HACER
```powershell
# Usar Windows Credential Manager o Azure Key Vault
$creds = Get-Credential
$env:ConnectionStrings__PricingDb="Server=...;Password=$($creds.GetNetworkCredential().Password)"
```

### ✅ MEJOR AÚN
```powershell
# Para producción, usar Azure Key Vault
# La app buscará secretos en Azure durante el startup
```

---

## 13. Plantilla de Configuración por Cliente

**Archivo**: `deployment/config-template.ps1`

```powershell
# ============================================
# Configuración: Cliente [NOMBRE]
# Fecha: $(Get-Date)
# ============================================

# Base de datos
$env:ConnectionStrings__PricingDb="Server=<SERVER>;Database=<DB>;User Id=<USER>;Password=<PASS>;"

# Ambiente
$env:ASPNETCORE_ENVIRONMENT="Production"

# Puerto
$env:ASPNETCORE_URLS="http://localhost:<PUERTO>"

# Logging
$env:Logging__LogLevel__Default="Information"

# Iniciar API
Write-Host "Iniciando API para Cliente [NOMBRE]..."
cd "C:\Clientes\<NOMBRE>\PricingApi"
.\PricingApi.exe
```

---

**Última revisión**: 2026-08-18  
**Responsable**: Equipo DevOps  
**Estado**: ✅ Listo para producción multi-tenant