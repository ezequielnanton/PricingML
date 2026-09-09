# 📦 Creación de Instaladores EXE para PricingML

Esta carpeta contiene los scripts y configuración para generar instaladores Windows (.exe) para el Motor y Cliente de PricingML.

## Estructura

```
build-installers/
├── motor-installer.nsi        ← Script NSIS para instalador del Motor
├── cliente-installer.nsi      ← Script NSIS para instalador del Cliente
├── build-motor.ps1            ← Script PowerShell para compilar Motor
├── build-cliente.ps1          ← Script PowerShell para compilar Cliente
├── build-all.ps1              ← Script para compilar ambos
└── README.md                  ← Este archivo
```

## Requisitos Previos

### Para Compilar

1. **Visual Studio 2022 o .NET SDK 10.0**
   - Descargar: https://dotnet.microsoft.com/download/dotnet/10.0
   - Verificar: `dotnet --version`

2. **Node.js 18+**
   - Descargar: https://nodejs.org/
   - Verificar: `node --version && npm --version`

3. **NSIS 3.0+** (Nullsoft Scriptable Install System)
   - Descargar: https://nsis.sourceforge.io/
   - Instalar en ruta por defecto: `C:\Program Files\NSIS\`

4. **PowerShell 5.0+**
   - Incluido en Windows 10/11

### En la PC Destino (para Instalar)

**Motor requiere:**
- Windows 10/11
- .NET 10.0 Runtime (se puede descargar automáticamente)
- SQL Server 2022+ o SQL Server LocalDB
- Puerto 5000 disponible

**Cliente requiere:**
- Windows 10/11
- Navegador web moderno (Chrome, Edge, Firefox, etc)
- Puerto 3000 disponible
- Conectividad al Motor (puerto 5000)

## Compilación

### Opción 1: Compilar Todo (Recomendado)

```powershell
cd build-installers
.\build-all.ps1
```

Esto:
1. ✅ Compila el Motor (.NET Release)
2. ✅ Compila el Cliente (React Build)
3. ✅ Crea PricingML-Motor-Setup.exe
4. ✅ Crea PricingML-Cliente-Setup.exe
5. ✅ Guarda ambos en `dist/`

**Tiempo estimado:** 5-10 minutos

### Opción 2: Compilar Solo Motor

```powershell
cd build-installers
.\build-motor.ps1
```

**Tiempo estimado:** 3-5 minutos

### Opción 3: Compilar Solo Cliente

```powershell
cd build-installers
.\build-cliente.ps1
```

**Tiempo estimado:** 2-3 minutos

## Instalación en PC Destino

### 1. Instalar Motor

```
Ejecutar: PricingML-Motor-Setup.exe

Pasos:
1. Aceptar licencia
2. Seleccionar carpeta (default: C:\Program Files\PricingML\Motor)
3. [Opcional] Instalar SQL Server LocalDB
4. Completar instalación
```

**Resultado:**
- ✅ Motor instalado en `C:\Program Files\PricingML\Motor\`
- ✅ Atajos creados en Menú Inicio
- ✅ Archivo `appsettings.json` configurado
- ✅ Accesible en `http://localhost:5000/swagger`

### 2. Instalar Cliente

```
Ejecutar: PricingML-Cliente-Setup.exe

Pasos:
1. Aceptar licencia
2. Seleccionar carpeta (default: C:\Program Files\PricingML\Cliente)
3. Ingresar URL del Motor (default: http://localhost:5000)
4. [Opcional] Crear atajo en Escritorio
5. Completar instalación
```

**Resultado:**
- ✅ Cliente instalado en `C:\Program Files\PricingML\Cliente\`
- ✅ Atajos creados en Menú Inicio
- ✅ Archivo `config.json` configurado
- ✅ Accesible en `http://localhost:3000`

### 3. Verificar Instalación

**Motor:**
```powershell
# Abrir navegador:
http://localhost:5000/swagger

# Deberías ver Swagger UI con endpoints disponibles
```

**Cliente:**
```powershell
# Abrir navegador:
http://localhost:3000

# Deberías ver la aplicación PricingML
```

## Estructura de Instalación

### Motor
```
C:\Program Files\PricingML\Motor\
├── PricingApi.exe              (Ejecutable principal)
├── PricingApi.dll
├── appsettings.json            (Configuración)
├── bin/                        (Binarios .NET)
└── logs/                       (Logs de ejecución)
```

### Cliente
```
C:\Program Files\PricingML\Cliente\
├── index.html                  (HTML principal)
├── config.json                 (Configuración)
├── start-server.bat            (Script para iniciar servidor)
├── start-server.ps1            (Script PowerShell alternativo)
└── assets/                     (CSS, JS, imágenes)
```

## Iniciar Servicios

### Motor (Automático)

El Motor se instala para iniciar automáticamente. Pero puedes:

```powershell
# Iniciar manual
C:\Program Files\PricingML\Motor\PricingApi.exe

# O desde menú: Inicio > PricingML > Motor - Iniciar
```

### Cliente (Manual)

El Cliente necesita iniciarse manualmente:

**Opción 1: Script Batch**
```powershell
C:\Program Files\PricingML\Cliente\start-server.bat
```

**Opción 2: Python**
```powershell
cd "C:\Program Files\PricingML\Cliente"
python -m http.server 3000 --directory .
```

**Opción 3: Navegador directo**
```
Abrir: http://localhost:3000
```

## Desinstalación

### Vía Panel de Control
1. Panel de Control > Programas > Programas y características
2. Buscar "PricingML Motor" o "PricingML Cliente"
3. Hacer clic en "Desinstalar"
4. Confirmar

### Vía Línea de Comandos
```powershell
# Motor
"C:\Program Files\PricingML\Motor\uninstall.exe"

# Cliente
"C:\Program Files\PricingML\Cliente\uninstall.exe"
```

## Troubleshooting

### "No se encontró .NET 10.0"
- Descargar e instalar: https://dotnet.microsoft.com/download/dotnet/10.0
- Reiniciar después de instalar
- Reintentar instalador del Motor

### "No se encontró SQL Server"
- Opción 1: Instalar SQL Server LocalDB (parte del instalador)
- Opción 2: Usar SQL Server existente (cambiar ConnectionString en appsettings.json)
- Opción 3: Usar servidor remoto (cambiar IP/hostname en appsettings.json)

### "Puerto 5000 ya está en uso"
- Ver qué proceso ocupa puerto: `netstat -ano | findstr :5000`
- Cambiar puerto en `appsettings.json` (en carpeta de instalación)
- Reiniciar Motor

### "Puerto 3000 ya está en uso"
- Ver qué proceso ocupa puerto: `netstat -ano | findstr :3000`
- Cambiar puerto en `start-server.bat`
- Reiniciar servidor

### "Motor no responde en http://localhost:5000"
- Verificar que Motor está corriendo: `tasklist | findstr PricingApi`
- Ver logs: `C:\Program Files\PricingML\Motor\logs\`
- Reiniciar: Inicio > Programas > PricingML > Motor - Iniciar
- Verificar firewall: agregar excepción para puerto 5000

### "Cliente no carga"
- Verificar Motor está corriendo: `http://localhost:5000/swagger`
- Ver logs: Abrir Developer Console (F12)
- Verificar config.json: debe tener URL correcta del Motor
- Reiniciar servidor: `start-server.bat`

## Actualización

### Actualizar Motor
1. Desinstalar: Panel de Control > Desinstalar "PricingML Motor"
2. Compilar nueva versión: `.\build-motor.ps1`
3. Ejecutar nuevo instalador: `dist\PricingML-Motor-Setup.exe`

### Actualizar Cliente
1. Desinstalar: Panel de Control > Desinstalar "PricingML Cliente"
2. Compilar nueva versión: `.\build-cliente.ps1`
3. Ejecutar nuevo instalador: `dist\PricingML-Cliente-Setup.exe`

## Customización

### Cambiar Logo/Icono
1. Editar `motor-installer.nsi` o `cliente-installer.nsi`
2. Cambiar rutas de `Icon` y `MiscButtonText`
3. Recompilar con NSIS

### Cambiar Puertos
- Motor: Editar `appsettings.json` en carpeta de instalación
- Cliente: Editar `start-server.bat`

### Cambiar URL del Motor (en Cliente)
1. Durante instalación: Ingresar URL en "Configuración del Cliente"
2. Después: Editar `config.json` en carpeta de instalación

## CI/CD (GitHub Actions)

Para automatizar la compilación, ver `../.github/workflows/build-installers.yml`

```yaml
name: Build Installers
on: [push, pull_request]
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: microsoft/setup-msbuild@v1
      - uses: actions/setup-node@v3
      - run: choco install nsis -y
      - run: cd build-installers && .\build-all.ps1
      - uses: actions/upload-artifact@v3
```

## Preguntas Frecuentes

**P: ¿Qué pasa con mis datos si desinstalo?**
R: La base de datos SQL Server persiste independientemente. Los archivos de instalación se eliminan, pero la BD se mantiene.

**P: ¿Puedo instalar en múltiples máquinas?**
R: Sí. Cada instalador es independiente. Repite los pasos en cada PC.

**P: ¿Necesito internet?**
R: Sí, durante la primera instalación para descargar .NET Runtime (si no existe). Luego puede funcionar sin internet.

**P: ¿Se puede usar con SQL Server en otra máquina?**
R: Sí. Edita `appsettings.json` con la IP/hostname del servidor remoto.

**P: ¿Cómo hago backup de datos?**
R: Respaldar base de datos SQL Server según tu proveedor de BD.

## Soporte

- 📖 Documentación: Ver `../INSTALACION.md`
- 🐛 Issues: GitHub Issues
- 💬 Preguntas: GitHub Discussions
