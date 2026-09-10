# Script para compilar el Motor y crear instalador MSI
# Uso: .\build-motor-msi.ps1

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Compilando Motor PricingML (MSI)" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Variables
$sourceDir = "..\PricingEngine\src\PricingApi"
$publishDir = "$sourceDir\bin\Release\net10.0\publish"
$distDir = "..\dist"
$wxsScript = "PricingML-Motor.wxs"
$productName = "PricingML-Motor"

# Crear directorio de salida
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
    Write-Host "[OK] Directorio $distDir creado" -ForegroundColor Green
}

# Paso 1: Compilar Motor en Release
Write-Host "" -ForegroundColor Yellow
Write-Host "Compilando Motor en Release..." -ForegroundColor Yellow
Push-Location $sourceDir
dotnet publish -c Release -o "bin\Release\net10.0\publish" --no-self-contained
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al compilar Motor" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "[OK] Motor compilado exitosamente" -ForegroundColor Green

# Paso 2: Verificar que WiX Toolset esta instalado
Write-Host "" -ForegroundColor Yellow
Write-Host "Verificando WiX Toolset..." -ForegroundColor Yellow

# Intentar encontrar heat.exe (WiX tool)
$heatPath = $null
$possiblePaths = @(
    "C:\Program Files (x86)\WiX Toolset v3\bin\heat.exe",
    "C:\Program Files\WiX Toolset v3\bin\heat.exe",
    "${env:ProgramFiles(x86)}\WiX Toolset v3\bin\heat.exe",
    "$env:ProgramFiles\WiX Toolset v3\bin\heat.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $heatPath = $path
        break
    }
}

if (-not $heatPath) {
    Write-Host "[ERROR] WiX Toolset no esta instalado" -ForegroundColor Red
    Write-Host "   Descargar desde: https://wixtoolset.org/releases/" -ForegroundColor Gray
    Write-Host "   O usar: dotnet tool install -g WiX" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] WiX Toolset encontrado" -ForegroundColor Green

# Paso 3: Generar archivo Harvester (archivos del Motor)
Write-Host "" -ForegroundColor Yellow
Write-Host "Generando lista de archivos (Heat)..." -ForegroundColor Yellow

$toolsetDir = Split-Path -Parent $heatPath
$candle = Join-Path $toolsetDir "candle.exe"
$light = Join-Path $toolsetDir "light.exe"

if (-not (Test-Path $candle) -or -not (Test-Path $light)) {
    Write-Host "[ERROR] Herramientas de WiX no encontradas" -ForegroundColor Red
    exit 1
}

# Paso 4: Compilar WiX con Candle
Write-Host "" -ForegroundColor Yellow
Write-Host "Compilando WiX script con Candle..." -ForegroundColor Yellow

& $candle -o "PricingML-Motor.wixobj" $wxsScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al compilar WiX script" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] WiX script compilado" -ForegroundColor Green

# Paso 5: Enlazar con Light (generar MSI)
Write-Host "" -ForegroundColor Yellow
Write-Host "Generando MSI con Light..." -ForegroundColor Yellow

$msiOutput = Join-Path $distDir "$productName.msi"
& $light -o $msiOutput "PricingML-Motor.wixobj"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al generar MSI" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] MSI generado exitosamente" -ForegroundColor Green

# Limpiar archivos temporales
Remove-Item "PricingML-Motor.wixobj" -Force -ErrorAction SilentlyContinue
Remove-Item "PricingML-Motor.wixpdb" -Force -ErrorAction SilentlyContinue

# Resultado final
Write-Host "" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "[OK] Compilacion completada!" -ForegroundColor Green
Write-Host "" -ForegroundColor Cyan
Write-Host "Instalador disponible en:" -ForegroundColor Cyan
Write-Host "   $msiOutput" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow
Write-Host "Requisitos para instalar:" -ForegroundColor Yellow
Write-Host "   - Windows 10/11 64-bit" -ForegroundColor Gray
Write-Host "   - .NET 10.0 Runtime" -ForegroundColor Gray
Write-Host "   - SQL Server 2022+ o LocalDB" -ForegroundColor Gray
Write-Host "   - Puerto 5000 disponible" -ForegroundColor Gray
Write-Host "======================================" -ForegroundColor Cyan
