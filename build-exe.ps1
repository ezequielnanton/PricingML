# Compila PricingML en dos ejecutables autocontenidos para Windows x64.
#
#   PricingMotor.exe   -> API REST (.NET) + Swagger
#   PricingCliente.exe -> interfaz web React embebida dentro del propio .exe
#
# La PC de destino NO necesita .NET ni Node.js instalados, solo SQL Server.
# Uso: .\build-exe.ps1

$ErrorActionPreference = "Stop"

$raiz        = $PSScriptRoot
$proyectoUi  = Join-Path $raiz "PricingClient\pricing-ui"
$proyectoWeb = Join-Path $raiz "PricingClient\PricingClientHost"
$proyectoApi = Join-Path $raiz "PricingEngine\src\PricingApi\PricingApi.csproj"
$salida      = Join-Path $raiz "dist\PricingML"

function Escribir-Paso($texto) {
    Write-Host ""
    Write-Host "=== $texto ===" -ForegroundColor Cyan
}

function Verificar-Comando($comando, $descarga) {
    if (-not (Get-Command $comando -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] Falta $comando. Instalalo desde: $descarga" -ForegroundColor Red
        exit 1
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  PricingML - Generacion de ejecutables" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

Escribir-Paso "Verificando herramientas"
Verificar-Comando "dotnet" "https://dotnet.microsoft.com/download/dotnet/10.0"
Verificar-Comando "npm" "https://nodejs.org/"
Write-Host "[OK] dotnet $(dotnet --version)"
Write-Host "[OK] node $(node --version)"

Escribir-Paso "Compilando la interfaz React"
Push-Location $proyectoUi
try {
    if (Test-Path "package-lock.json") { npm ci } else { npm install }
    if ($LASTEXITCODE -ne 0) { throw "Fallo la instalacion de dependencias de npm" }

    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Fallo el build de React" }
}
finally { Pop-Location }
Write-Host "[OK] React compilado"

Escribir-Paso "Empaquetando la interfaz dentro del host"
$destinoWww = Join-Path $proyectoWeb "wwwroot"
if (Test-Path $destinoWww) { Remove-Item $destinoWww -Recurse -Force }
New-Item -ItemType Directory -Path $destinoWww -Force | Out-Null
Copy-Item -Path (Join-Path $proyectoUi "dist\*") -Destination $destinoWww -Recurse -Force
Write-Host "[OK] Archivos embebidos preparados"

# Un unico .exe sin dependencias externas. IncludeNativeLibrariesForSelfExtract es necesario
# porque Microsoft.Data.SqlClient trae librerias nativas que no entran en el bundle plano.
$opcionesPublish = @(
    "-c", "Release",
    "-r", "win-x64",
    "--self-contained", "true",
    "-p:PublishSingleFile=true",
    "-p:IncludeNativeLibrariesForSelfExtract=true",
    "-p:EnableCompressionInSingleFile=true",
    "-p:DebugType=none",
    "--nologo"
)

if (Test-Path $salida) { Remove-Item $salida -Recurse -Force }
New-Item -ItemType Directory -Path $salida -Force | Out-Null

Escribir-Paso "Generando PricingCliente.exe"
dotnet publish (Join-Path $proyectoWeb "PricingClientHost.csproj") @opcionesPublish -o (Join-Path $salida "_cliente")
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Fallo la compilacion del Cliente" -ForegroundColor Red; exit 1 }

Escribir-Paso "Generando PricingMotor.exe"
dotnet publish $proyectoApi @opcionesPublish -o (Join-Path $salida "_motor")
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Fallo la compilacion del Motor" -ForegroundColor Red; exit 1 }

Escribir-Paso "Armando la carpeta final"
Move-Item (Join-Path $salida "_cliente\PricingCliente.exe") (Join-Path $salida "PricingCliente.exe")
Move-Item (Join-Path $salida "_motor\PricingApi.exe")       (Join-Path $salida "PricingMotor.exe")
Remove-Item (Join-Path $salida "_cliente") -Recurse -Force
Remove-Item (Join-Path $salida "_motor")   -Recurse -Force

# El Motor arranca solo en http: el https del entorno de desarrollo depende del certificado
# de dotnet dev-certs, que no existe en la PC de destino. La cadena de conexion se deja
# vacia a proposito para que el asistente del primer arranque la pida.
$configMotor = @{
    ConnectionStrings = @{ PricingDb = "" }
    Urls              = "http://0.0.0.0:5000"
    Logging           = @{ LogLevel = @{ Default = "Information"; "Microsoft.AspNetCore" = "Warning" } }
    AllowedHosts      = "*"
    MercadoLibre      = @{ ApiBaseUrl = "https://api.mercadolibre.com"; ClientId = ""; ClientSecret = "" }
}
$configMotor | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $salida "appsettings.json") -Encoding UTF8

@"
PricingML
=========

Esta carpeta contiene los dos programas. No hace falta instalar nada mas
que SQL Server: ni .NET ni Node.js.

PASO 1 - Motor
  Doble clic en PricingMotor.exe
  La primera vez pregunta los datos de SQL Server (servidor, base, usuario)
  y los guarda en appsettings.json. Dejalo abierto: es el servidor.
  Para verificar que anda: http://localhost:5000/swagger

PASO 2 - Cliente
  Doble clic en PricingCliente.exe
  La primera vez pregunta el puerto y donde esta el Motor.
  Si el Motor corre en esta misma PC, dejalo vacio y presiona Enter.
  Abre el navegador solo en http://localhost:3000

NOTAS
  - Los dos programas tienen que quedar abiertos mientras uses el sistema.
  - Si el Motor esta en otra PC, poné su direccion cuando el Cliente lo pida
    (por ejemplo http://192.168.1.50:5000) y habilita el puerto 5000 en el
    firewall de la PC donde corre el Motor.
  - Para cambiar la configuracion mas adelante, edita appsettings.json (Motor)
    o PricingCliente.config.json (Cliente), o borralos para que vuelvan a
    preguntar en el proximo arranque.
"@ | Set-Content (Join-Path $salida "LEEME.txt") -Encoding UTF8

Escribir-Paso "Comprimiendo"
$zip = Join-Path $raiz "dist\PricingML-windows-x64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $salida "*") -DestinationPath $zip

$tamMotor   = [Math]::Round((Get-Item (Join-Path $salida "PricingMotor.exe")).Length / 1MB, 1)
$tamCliente = [Math]::Round((Get-Item (Join-Path $salida "PricingCliente.exe")).Length / 1MB, 1)
$tamZip     = [Math]::Round((Get-Item $zip).Length / 1MB, 1)

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  LISTO" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Carpeta : $salida"
Write-Host "  ZIP     : $zip ($tamZip MB)"
Write-Host ""
Write-Host "  PricingMotor.exe   $tamMotor MB"
Write-Host "  PricingCliente.exe $tamCliente MB"
Write-Host ""
Write-Host "  Copia la carpeta (o el ZIP) a la otra PC y segui LEEME.txt"
Write-Host ""
