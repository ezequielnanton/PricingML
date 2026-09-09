# Script para compilar el Cliente y crear instalador
# Uso: .\build-cliente.ps1

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Compilando Cliente PricingML" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Variables
$sourceDir = "..\PricingClient\pricing-ui"
$distDir = "..\dist"
$nsisScript = "cliente-installer.nsi"

# Crear directorio de salida
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
    Write-Host "✅ Directorio $distDir creado" -ForegroundColor Green
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

# Paso 3: Verificar que NSIS está instalado
Write-Host "" -ForegroundColor Yellow
Write-Host "Verificando NSIS..." -ForegroundColor Yellow
$nsisPath = "C:\Program Files\NSIS\makensis.exe"
if (-not (Test-Path $nsisPath)) {
    $nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
}
if (-not (Test-Path $nsisPath)) {
    Write-Host "[ERROR] NSIS no esta instalado" -ForegroundColor Red
    Write-Host "   Descargar desde: https://nsis.sourceforge.io/" -ForegroundColor Gray
    exit 1
}
Write-Host "[OK] NSIS encontrado: $nsisPath" -ForegroundColor Green

# Paso 4: Crear instalador
Write-Host "" -ForegroundColor Yellow
Write-Host "Creando instalador con NSIS..." -ForegroundColor Yellow
& $nsisPath $nsisScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al crear instalador" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Instalador creado exitosamente" -ForegroundColor Green

# Resultado final
Write-Host "" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "[OK] Compilacion completada!" -ForegroundColor Green
Write-Host "" -ForegroundColor Cyan
Write-Host "Instalador disponible en:" -ForegroundColor Cyan
Write-Host "   $distDir\PricingML-Cliente-Setup.exe" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow
Write-Host "Requisitos para instalar:" -ForegroundColor Yellow
Write-Host "   - Windows 10/11" -ForegroundColor Gray
Write-Host "   - Navegador web moderno" -ForegroundColor Gray
Write-Host "   - Motor PricingML corriendo (http://localhost:5000)" -ForegroundColor Gray
Write-Host "   - Puerto 3000 disponible" -ForegroundColor Gray
Write-Host "======================================" -ForegroundColor Cyan
