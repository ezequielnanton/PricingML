# Guía de Instalación - PricingML Motor y Cliente (Windows MSI)

## Resumen Rápido

PricingML se distribuye como dos instaladores Windows independientes:
1. **PricingML-Motor.msi** - Servidor API REST (Backend)
2. **PricingML-Cliente.msi** - Interfaz Web (Frontend)

## Pre-requisitos del Sistema

Asegúrate que tu PC cumple con:

- ✅ **Windows 10 o Windows 11** (64-bit)
- ✅ **.NET 10.0 Runtime** 
  - Descargar: https://dotnet.microsoft.com/download/dotnet/10.0
- ✅ **Node.js 18 o superior** (para Cliente)
  - Descargar: https://nodejs.org/
- ✅ **SQL Server 2022+** o **SQL Server Express** o **SQL Server LocalDB**
  - Si no lo tienes: Descargar SQL Server Developer Edition (gratis)
- ✅ **Puertos disponibles**: 5000 (Motor) y 3000 (Cliente)

## Pasos de Instalación

### Paso 1: Instalar Motor

1. **Descargar**: Obtén `PricingML-Motor.msi`
2. **Ejecutar**: Doble-click en el archivo
3. **Seguir el asistente**:
   - Click "Siguiente" en bienvenida
   - **Carpeta de instalación** (deja default o personaliza)
   - **Puerto Motor**: Default 5000 (cambiar solo si hay conflicto)
   - **SQL Server Hostname**: Tu servidor SQL (ej: `localhost` o IP)
   - **SQL Usuario**: Usuario con permisos (ej: `sa`)
   - **SQL Contraseña**: Contraseña de usuario
   - **SQL Puerto**: Default 1433 (cambiar si tu SQL usa puerto diferente)
4. **Completar**: Click "Finalizar"

**Resultado**: El servicio "PricingML Motor API" se instala pero NO inicia automáticamente.

### Paso 2: Iniciar el Motor

Antes de instalar Cliente, inicia el Motor:

**Opción A: Desde Services (Recomendado)**
1. Presiona `Windows + R`
2. Escribe: `services.msc`
3. Busca: "PricingML Motor API"
4. Click derecho → "Iniciar"
5. Estado debe cambiar a "En ejecución"

**Opción B: PowerShell (Admin)**
```powershell
Start-Service -Name "PricingMLMotor"
```

**Verificar que funciona**:
- Abre navegador: http://localhost:5000/swagger
- Deberías ver documentación API (Swagger UI)

### Paso 3: Instalar Cliente

1. **Descargar**: Obtén `PricingML-Cliente.msi`
2. **Ejecutar**: Doble-click en el archivo
3. **Seguir el asistente**:
   - Click "Siguiente" en bienvenida
   - **Carpeta de instalación** (deja default o personaliza)
   - **URL del Motor**: Debe ser igual a dónde corre Motor
     - Si Motor en localhost: `http://localhost:5000`
     - Si Motor en otra PC: `http://{IP-DE-MOTOR}:5000`
     - Si usando dominio: `http://api.tudominio.com`
4. **Completar**: Click "Finalizar"

### Paso 4: Acceder a PricingML

Abre navegador y ve a:
```
http://localhost:3000
```

¡Deberías ver la interfaz de PricingML!

## Información Importante

### Motor Service (Servicio Windows)

El Motor se instala como servicio Windows que:
- ✅ Persiste entre reinicios
- ✅ Se puede detener/iniciar desde Services.msc
- ✅ Registra logs en: `C:\Program Files\PricingML\Motor\logs\`

**Gestionar Motor**:
```powershell
# Ver estado
Get-Service -Name "PricingMLMotor"

# Iniciar
Start-Service -Name "PricingMLMotor"

# Detener
Stop-Service -Name "PricingMLMotor"

# Reiniciar
Restart-Service -Name "PricingMLMotor"
```

### Cliente Web

El Cliente es una aplicación web React que:
- ✅ Se accede desde navegador en http://localhost:3000
- ✅ Se conecta a Motor mediante API REST
- ✅ Requiere Node.js instalado (verificar versión)

## Desinstalación

### Quitar Motor
1. Presiona `Windows + I` → Settings
2. Ir a: Apps → Installed Apps
3. Buscar: "PricingML Motor"
4. Click en 3 puntos (⋯) → "Uninstall"
5. Confirmar

### Quitar Cliente
1. Presiona `Windows + I` → Settings
2. Ir a: Apps → Installed Apps
3. Buscar: "PricingML Cliente"
4. Click en 3 puntos (⋯) → "Uninstall"
5. Confirmar

## Solución de Problemas

### Motor no inicia

**Síntoma**: Service no inicia o se detiene inmediatamente

**Soluciones**:
1. Verificar SQL Server está corriendo
2. Verificar credenciales SQL en:
   `C:\Program Files\PricingML\Motor\appsettings.json`
3. Ver logs: `C:\Program Files\PricingML\Motor\logs\`
4. Reintentar: `Restart-Service -Name "PricingMLMotor"`

### Cliente no conecta a Motor

**Síntoma**: "Error connecting to API" o página en blanco

**Soluciones**:
1. Verificar Motor está corriendo:
   - Abre: http://localhost:5000/swagger
   - Si funciona → OK
   - Si no → Ver "Motor no inicia" arriba
   
2. Verificar URL configurada:
   - Archivo: `C:\Program Files\PricingML\Cliente\.env.local`
   - Verificar: `VITE_API_BASE_URL` apunta a Motor correcto

3. Verificar firewall:
   - Abrir puerto 5000 en Firewall de Windows

### Puerto ya está en uso

**Si puerto 5000 o 3000 ya está en uso**:
1. Instalar con puerto diferente
2. O detener la aplicación que usa ese puerto

Ver qué usa un puerto:
```powershell
netstat -ano | findstr :5000
# o
Get-NetTCPConnection -LocalPort 5000
```

## Información de Contacto

Para soporte o reportar problemas:
- Email: support@pricingml.com
- Documentación: https://docs.pricingml.com
- Issues: https://github.com/pricingml/pricingml/issues

---

**Versión**: 1.0.0  
**Última actualización**: Septiembre 2026
