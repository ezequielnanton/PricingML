# 📦 Instaladores .EXE para PricingML

Se han creado **dos instaladores independientes** para Windows que permiten instalar el Motor y Cliente sin dependencias de Docker.

## 🎯 Instaladores Disponibles

### 1️⃣ PricingML-Motor-Setup.exe
**Instalador del Motor API (.NET 10.0)**

Incluye:
- ✅ Descarga automática de .NET 10.0 Runtime (si no existe)
- ✅ Verificación de SQL Server / LocalDB
- ✅ Instalación en `C:\Program Files\PricingML\Motor\`
- ✅ Atajos en Menú Inicio
- ✅ Configuración automática de `appsettings.json`
- ✅ Acceso en `http://localhost:5000/swagger`

### 2️⃣ PricingML-Cliente-Setup.exe
**Instalador del Cliente React**

Incluye:
- ✅ Instalación en `C:\Program Files\PricingML\Cliente\`
- ✅ Configuración de URL del Motor (interactive setup)
- ✅ Scripts para iniciar servidor HTTP
- ✅ Atajos en Menú Inicio y Escritorio
- ✅ Acceso en `http://localhost:3000`

---

## 🚀 Cómo Obtener los Instaladores

### Opción 1: Descargar desde GitHub Releases
Una vez creado el PR y mergeado a `main`, estarán en:
```
https://github.com/tu-usuario/PricingML/releases
```

### Opción 2: Compilar Localmente

**Requisitos previos:**
- Windows 10/11
- Visual Studio 2022 o .NET SDK 10.0
- Node.js 18+
- NSIS 3.0+ (descargar de https://nsis.sourceforge.io/)

**Compilar:**
```powershell
cd build-installers
.\build-all.ps1
```

Los instaladores se crearán en: `dist/`

---

## 📥 Instalación en PC Destino

### Paso 1: Instalar Motor

```
1. Ejecutar: PricingML-Motor-Setup.exe
2. Aceptar licencia
3. Seleccionar carpeta (default: C:\Program Files\PricingML\Motor)
4. [Opcional] Instalar SQL Server LocalDB
5. Completar instalación
```

✅ Motor accesible en: `http://localhost:5000/swagger`

### Paso 2: Instalar Cliente

```
1. Ejecutar: PricingML-Cliente-Setup.exe
2. Aceptar licencia
3. Seleccionar carpeta (default: C:\Program Files\PricingML\Cliente)
4. Ingresar URL del Motor (default: http://localhost:5000)
5. Completar instalación
```

✅ Cliente accesible en: `http://localhost:3000`

### Paso 3: Usar la Aplicación

1. Abrir navegador: `http://localhost:3000`
2. Comenzar a usar PricingML

---

## 📋 Requisitos en PC Destino

**Motor:**
- Windows 10/11 64-bit
- .NET 10.0 Runtime (descargado automáticamente si no existe)
- SQL Server 2022+ o LocalDB
- Puerto 5000 disponible
- 256 MB RAM mínimo

**Cliente:**
- Windows 10/11 64-bit
- Navegador web moderno (Chrome, Edge, Firefox)
- Puerto 3000 disponible
- Motor corriendo (conectividad a puerto 5000)
- 128 MB RAM mínimo

**Base de Datos:**
- SQL Server 2022+
- O LocalDB (incluido con .NET)
- O servidor SQL Server remoto

---

## 🔧 Configuración Avanzada

### Motor: Cambiar Puerto (5000)

Editar después de instalar:
```
C:\Program Files\PricingML\Motor\appsettings.json
```

Cambiar línea:
```json
"Urls": "http://0.0.0.0:5001"  // cambiar 5000 por otro puerto
```

Reiniciar Motor.

### Motor: Usar SQL Server Remoto

Editar `appsettings.json`:
```json
"ConnectionStrings": {
  "PricingDb": "Server=192.168.1.50;Database=PRICES_DB;User Id=sa;Password=TuPassword;"
}
```

Reiniciar Motor.

### Cliente: Cambiar Puerto (3000)

Editar después de instalar:
```
C:\Program Files\PricingML\Cliente\start-server.bat
```

Cambiar:
```batch
python -m http.server 3000  →  python -m http.server 8080
```

### Cliente: Cambiar URL del Motor

Editar después de instalar:
```
C:\Program Files\PricingML\Cliente\config.json
```

---

## 📁 Estructura de Carpetas

### Motor
```
C:\Program Files\PricingML\Motor\
├── PricingApi.exe              (Ejecutable)
├── PricingApi.dll
├── appsettings.json            (Configuración)
├── appsettings.Production.json (Prod config)
├── bin/                        (Binarios .NET)
├── logs/                       (Logs automáticos)
└── uninstall.exe               (Desinstalador)
```

### Cliente
```
C:\Program Files\PricingML\Cliente\
├── index.html                  (Página principal)
├── config.json                 (Configuración)
├── start-server.bat            (Inicia servidor HTTP)
├── start-server.ps1            (PowerShell version)
├── assets/                     (CSS, JS, imágenes)
├── favicon.ico
└── uninstall.exe               (Desinstalador)
```

---

## 🚀 Iniciar Servicios

### Motor (Automático)
El Motor se auto-inicia. Si necesitas:

**Iniciar manualmente:**
```powershell
"C:\Program Files\PricingML\Motor\PricingApi.exe"
```

**O desde Menú Inicio:**
```
Inicio > Todos los programas > PricingML > Motor - Iniciar
```

**Ver en logs:**
```
C:\Program Files\PricingML\Motor\logs\
```

### Cliente (Manual)

**Opción 1: Script Batch**
```powershell
"C:\Program Files\PricingML\Cliente\start-server.bat"
```

**Opción 2: PowerShell**
```powershell
cd "C:\Program Files\PricingML\Cliente"
python -m http.server 3000
```

**Opción 3: Navegador**
```
http://localhost:3000
```

---

## 🛠️ Desinstalación

### Vía Configuración

1. Abrir: `Configuración > Apps > Aplicaciones instaladas`
2. Buscar: "PricingML Motor" o "PricingML Cliente"
3. Hacer clic en "⋮" > "Desinstalar"
4. Confirmar

### Vía Panel de Control

1. Abrir: `Panel de Control > Programas > Programas y características`
2. Buscar y seleccionar
3. Hacer clic en "Desinstalar"

### Línea de Comandos

```powershell
# Motor
"C:\Program Files\PricingML\Motor\uninstall.exe"

# Cliente
"C:\Program Files\PricingML\Cliente\uninstall.exe"
```

---

## ⚠️ Troubleshooting

### Motor no inicia (.NET Runtime)

**Problema:** "No se encontró .NET 10.0"

**Solución:**
1. Descargar: https://dotnet.microsoft.com/download/dotnet/10.0
2. Instalar
3. Reiniciar PC
4. Reintentar instalador

### Motor no conecta a SQL Server

**Problema:** "Cannot connect to database"

**Solución:**
1. Verificar SQL Server está corriendo: `services.msc`
2. Verificar nombre/IP de servidor en `appsettings.json`
3. Verificar credenciales (usuario/password)
4. Probar conexión con SQL Server Management Studio

### Puerto 5000 en uso

**Problema:** Motor no inicia, "Address already in use"

**Solución:**
1. Ver qué usa puerto: `netstat -ano | findstr :5000`
2. Cambiar puerto en `appsettings.json`
3. Reiniciar Motor

### Cliente no carga

**Problema:** "Cannot connect to server"

**Solución:**
1. Verificar Motor está corriendo: `http://localhost:5000/swagger`
2. Verificar URL en `config.json` es correcta
3. Reiniciar script `start-server.bat`
4. Abrir F12 (Developer Tools) para ver errores

### Firewall bloquea puertos

**Solución:**
1. Abrir Windows Defender Firewall
2. Permitir aplicaciones:
   - `PricingApi.exe` (puerto 5000)
   - `python.exe` (puerto 3000)
3. O agregar excepciones:
   - Inbound: puerto 5000 TCP
   - Inbound: puerto 3000 TCP

---

## 🔄 Actualizar

### Actualizar Motor

1. Desinstalar versión antigua
2. Compilar nueva versión: `cd build-installers && .\build-motor.ps1`
3. Ejecutar nuevo instalador

### Actualizar Cliente

1. Desinstalar versión antigua
2. Compilar nueva versión: `cd build-installers && .\build-cliente.ps1`
3. Ejecutar nuevo instalador

---

## 📊 Comparativa: Docker vs .EXE

| Aspecto | Docker | .EXE |
|---------|--------|------|
| Instalación | 1 comando | 2 asistentes |
| Complejidad | Baja | Media |
| Tamaño | 350 MB (inicial) | 200 MB (.NET) + 50 MB (Cliente) |
| Aislamiento | Excelente | Bueno |
| Reproducibilidad | Perfecta | Buena |
| Windows nativo | No | Sí |
| Curva aprendizaje | Media | Baja |
| Escalabilidad | Alta | Media |

---

## 🎁 Archivos Creados

```
build-installers/
├── motor-installer.nsi         ← Script NSIS Motor
├── cliente-installer.nsi       ← Script NSIS Cliente
├── build-motor.ps1            ← Compilar Motor
├── build-cliente.ps1          ← Compilar Cliente
├── build-all.ps1              ← Compilar ambos
├── README.md                  ← Documentación técnica
└── (generados en dist/)
    ├── PricingML-Motor-Setup.exe
    └── PricingML-Cliente-Setup.exe

.github/workflows/
└── build-installers.yml        ← GitHub Actions CI/CD
```

---

## 💡 Tips

- **Desarrollo**: Usa Docker Compose (más rápido iterar)
- **Producción**: Usa .EXE (más estable en Windows)
- **Equipo remoto**: Envía ambos .EXE por email/USB/FTP
- **Actualizaciones**: Crea tag de release en GitHub para automatiazr

---

## 📞 Soporte

- 📖 Documentación técnica: `build-installers/README.md`
- 🐛 Issues: GitHub Issues
- 💬 Preguntas: GitHub Discussions

---

¡Listo! Motor y Cliente instalables con dos simples .EXE 🚀
