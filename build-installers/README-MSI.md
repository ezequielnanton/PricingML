# Instaladores MSI - PricingML Motor y Cliente

## Descripción General

Este directorio contiene los scripts y definiciones de instaladores Windows (MSI) para compilar y distribuir PricingML Motor y Cliente como aplicaciones instalables en Windows.

## Componentes

### Archivos WiX (XML Installer definitions)
- **PricingML-Motor.wxs**: Definición del instalador MSI para el Motor (.NET API)
  - Instala Motor como Windows Service
  - Configura conexión SQL Server
  - Abre acceso directo a Swagger UI
  
- **PricingML-Cliente.wxs**: Definición del instalador MSI para el Cliente (React)
  - Instala archivos compilados de React
  - Configura URL del Motor API
  - Crea acceso directo a la interfaz web

### Scripts PowerShell
- **build-motor-msi.ps1**: Compila Motor y genera Motor.msi
  - Ejecuta `dotnet publish -c Release`
  - Compila WiX script con Candle
  - Genera MSI con Light
  
- **build-cliente-msi.ps1**: Compila Cliente y genera Cliente.msi
  - Ejecuta `npm run build`
  - Compila WiX script con Candle
  - Genera MSI con Light
  
- **build-all-msi.ps1**: Orquesta la compilación de ambos MSI
  - Ejecuta build-motor-msi.ps1 y build-cliente-msi.ps1
  - Reporta éxito/error consolidado

## Prerequisitos

### Sistema
- Windows 10/11 (64-bit)
- PowerShell 5.0+

### Herramientas Requeridas

1. **.NET 10.0 SDK** (para compilar Motor)
   ```powershell
   dotnet --version
   ```

2. **Node.js 18+** (para compilar Cliente)
   ```powershell
   node --version
   npm --version
   ```

3. **WiX Toolset v3** (para compilar MSI)
   - Descargar: https://wixtoolset.org/releases/
   - O instalar con: `dotnet tool install -g WiX`
   - Verifica: Busca `candle.exe` y `light.exe` en `Program Files`

4. **SQL Server 2022+ o LocalDB** (requerido en PC destino)

## Compilación

### Compilar ambos instaladores
```powershell
cd build-installers
.\build-all-msi.ps1
```

### Compilar solo Motor MSI
```powershell
cd build-installers
.\build-motor-msi.ps1
```

### Compilar solo Cliente MSI
```powershell
cd build-installers
.\build-cliente-msi.ps1
```

### Resultado
Los archivos MSI se generan en `dist/`:
- `dist/PricingML-Motor.msi`
- `dist/PricingML-Cliente.msi`

## Instalación en PC Destino

### Motor MSI
1. Ejecutar `PricingML-Motor.msi`
2. Responder preguntas de configuración:
   - **Carpeta de instalación** (default: `C:\Program Files\PricingML\Motor`)
   - **Puerto Motor** (default: 5000)
   - **SQL Server Hostname** (default: localhost)
   - **SQL Server Usuario** (default: sa)
   - **SQL Server Contraseña** (requerida)
   - **SQL Server Puerto** (default: 1433)
3. Completar instalación
4. El servicio `PricingMLMotor` se registra automáticamente (requiere inicio manual)
5. Iniciar servicio desde `Services.msc` o:
   ```powershell
   Start-Service -Name "PricingMLMotor"
   ```
6. Acceder a Swagger: http://localhost:{puerto}/swagger

### Cliente MSI
1. Ejecutar `PricingML-Cliente.msi`
2. Responder preguntas de configuración:
   - **Carpeta de instalación** (default: `C:\Program Files\PricingML\Cliente`)
   - **URL del Motor** (default: http://localhost:5000)
3. Completar instalación
4. Verificar que Motor está corriendo
5. Acceder a: http://localhost:3000
   - Usuario debe tener Node.js 18+ instalado
   - O ejecutar servidor: `npm run dev` en carpeta instalación

## Desinstalación

### Windows Control Panel
1. Ir a: Settings → Apps → Installed Apps
2. Buscar "PricingML Motor" o "PricingML Cliente"
3. Hacer click en "Uninstall"

### PowerShell
```powershell
msiexec /x "{GUID del Motor}"
msiexec /x "{GUID del Cliente}"
```

## Configuración Avanzada

### Motor - appsettings.json
Ubicación: `C:\Program Files\PricingML\Motor\appsettings.json`

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;User Id=sa;Password=...;Encrypt=True;TrustServerCertificate=True;"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": { "Url": "http://0.0.0.0:5000" }
    }
  }
}
```

### Cliente - .env.local
Ubicación: `C:\Program Files\PricingML\Cliente\.env.local`

```env
VITE_API_BASE_URL=http://localhost:5000
```

## Troubleshooting

### Motor no inicia
1. Verificar que SQL Server está corriendo
2. Verificar credenciales SQL en `appsettings.json`
3. Ver logs: `C:\Program Files\PricingML\Motor\logs\`
4. Reintentar: `Restart-Service -Name "PricingMLMotor"`

### Cliente no conecta a Motor
1. Verificar Motor está corriendo: http://localhost:5000/swagger
2. Verificar URL en `%APPDATA%\.env.local`
3. Verificar firewall permite puerto 5000

### WiX no compila
1. Instalar WiX Toolset: https://wixtoolset.org/releases/
2. Agregar `C:\Program Files (x86)\WiX Toolset v3\bin` al PATH

## CI/CD Integration

Ver `.github/workflows/build-msi-installers.yml` para automatización con GitHub Actions.

Workflow ejecuta:
1. `build-all-msi.ps1` en cada push
2. Genera MSI en `dist/`
3. Publica en GitHub Releases

## Notas Técnicas

- **Plataforma**: Windows x64 únicamente
- **Idioma**: Español (instaladores)
- **Licencia**: MSI - instalación por usuario o por máquina
- **Update Strategy**: Actualmente requiere desinstalación manual
- **Rollback**: Soporte nativo Windows Installer

## Comparativa: NSIS vs WiX MSI

| Aspecto | NSIS (.EXE) | WiX (.MSI) |
|---------|------------|-----------|
| UI Nativa | No | Sí |
| Configuración | Scripts | XML |
| Complejidad | Media | Media-Alta |
| Desinstalación | Manual | Control Panel |
| Actualizaciones | No soportadas | Soportadas |
| Tamaño Final | ~150MB | ~120MB |
| Curva Aprendizaje | Baja | Media |
