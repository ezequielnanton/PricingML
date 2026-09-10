# Script para compilar el Cliente y crear instalador MSI
# Uso: .\build-cliente-msi.ps1

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Compilando Cliente PricingML (MSI)" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Variables
$sourceDir = "..\PricingClient\pricing-ui"
$distDir = "..\dist"
$wxsScript = "PricingML-Cliente.wxs"
$productName = "PricingML-Cliente"

# Crear directorio de salida
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
    Write-Host "[OK] Directorio $distDir creado" -ForegroundColor Green
}

# Paso 1: Verificar Node.js
Write-Host "" -ForegroundColor Yellow
Write-Host "Verificando Node.js..." -ForegroundColor Yellow
$node = node --version 2>$null
if (-not $node) {
    Write-Host "[ERROR] Node.js no esta instalado" -ForegroundColor Red
    Write-Host "   Descargar desde: https://nodejs.org/" -ForegroundColor Gray
    exit 1
}
Write-Host "[OK] Node.js encontrado: $node" -ForegroundColor Green

# Paso 2: Compilar Cliente
Write-Host "" -ForegroundColor Yellow
Write-Host "Compilando Cliente (React + Vite)..." -ForegroundColor Yellow
Push-Location $sourceDir
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al compilar Cliente" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "[OK] Cliente compilado exitosamente" -ForegroundColor Green

# Paso 3: Crear archivo .env.local en dist
Write-Host "" -ForegroundColor Yellow
Write-Host "Preparando configuracion..." -ForegroundColor Yellow

$envFile = Join-Path $sourceDir "dist" ".env.local"
if (-not (Test-Path $envFile)) {
    Set-Content -Path $envFile -Value "VITE_API_BASE_URL=http://localhost:5000"
    Write-Host "[OK] Archivo .env.local creado" -ForegroundColor Green
}

# Paso 4: Verificar que WiX Toolset esta instalado
Write-Host "" -ForegroundColor Yellow
Write-Host "Verificando WiX Toolset..." -ForegroundColor Yellow

# Intentar encontrar candle.exe (WiX tool)
$candlePath = $null
$possiblePaths = @(
    "C:\Program Files (x86)\WiX Toolset v3\bin\candle.exe",
    "C:\Program Files\WiX Toolset v3\bin\candle.exe",
    "${env:ProgramFiles(x86)}\WiX Toolset v3\bin\candle.exe",
    "$env:ProgramFiles\WiX Toolset v3\bin\candle.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $candlePath = $path
        break
    }
}

if (-not $candlePath) {
    Write-Host "[ERROR] WiX Toolset no esta instalado" -ForegroundColor Red
    Write-Host "   Descargar desde: https://wixtoolset.org/releases/" -ForegroundColor Gray
    Write-Host "   O usar: dotnet tool install -g WiX" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] WiX Toolset encontrado" -ForegroundColor Green

# Paso 5: Compilar WiX con Candle
Write-Host "" -ForegroundColor Yellow
Write-Host "Compilando WiX script con Candle..." -ForegroundColor Yellow

$toolsetDir = Split-Path -Parent $candlePath
$candle = $candlePath
$light = Join-Path $toolsetDir "light.exe"

& $candle -o "PricingML-Cliente.wixobj" $wxsScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al compilar WiX script" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] WiX script compilado" -ForegroundColor Green

# Paso 6: Enlazar con Light (generar MSI)
Write-Host "" -ForegroundColor Yellow
Write-Host "Generando MSI con Light..." -ForegroundColor Yellow

$msiOutput = Join-Path $distDir "$productName.msi"
& $light -o $msiOutput "PricingML-Cliente.wixobj"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al generar MSI" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] MSI generado exitosamente" -ForegroundColor Green

# Limpiar archivos temporales
Remove-Item "PricingML-Cliente.wixobj" -Force -ErrorAction SilentlyContinue
Remove-Item "PricingML-Cliente.wixpdb" -Force -ErrorAction SilentlyContinue

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
Write-Host "   - Node.js 18+ instalado" -ForegroundColor Gray
Write-Host "   - Motor PricingML corriendo (http://localhost:5000)" -ForegroundColor Gray
Write-Host "   - Puerto 3000 disponible" -ForegroundColor Gray
Write-Host "======================================" -ForegroundColor Cyan
