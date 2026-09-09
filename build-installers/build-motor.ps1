# Script para compilar el Motor y crear instalador
# Uso: .\build-motor.ps1

Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🔨 Compilando Motor PricingML" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan

# Variables
$sourceDir = "..\PricingEngine\src\PricingApi"
$publishDir = "$sourceDir\bin\Release\net10.0\publish"
$distDir = "..\dist"
$nsisScript = "motor-installer.nsi"

# Crear directorio de salida
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
    Write-Host "✅ Directorio $distDir creado" -ForegroundColor Green
}

# Paso 1: Compilar Motor en Release
Write-Host "`n📦 Compilando Motor en Release..." -ForegroundColor Yellow
Push-Location $sourceDir
dotnet publish -c Release -o "bin\Release\net10.0\publish" --no-self-contained
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al compilar Motor" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "✅ Motor compilado exitosamente" -ForegroundColor Green

# Paso 2: Verificar que NSIS está instalado
Write-Host "`n🔍 Verificando NSIS..." -ForegroundColor Yellow
$nsisPath = "C:\Program Files\NSIS\makensis.exe"
if (-not (Test-Path $nsisPath)) {
    $nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
}
if (-not (Test-Path $nsisPath)) {
    Write-Host "❌ NSIS no está instalado" -ForegroundColor Red
    Write-Host "   Descargar desde: https://nsis.sourceforge.io/" -ForegroundColor Gray
    exit 1
}
Write-Host "✅ NSIS encontrado: $nsisPath" -ForegroundColor Green

# Paso 3: Crear instalador
Write-Host "`n📦 Creando instalador con NSIS..." -ForegroundColor Yellow
& $nsisPath $nsisScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al crear instalador" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Instalador creado exitosamente" -ForegroundColor Green

# Resultado final
Write-Host "`n════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ ¡Compilación completada!" -ForegroundColor Green
Write-Host "`n📦 Instalador disponible en:" -ForegroundColor Cyan
Write-Host "   $distDir\PricingML-Motor-Setup.exe" -ForegroundColor Yellow
Write-Host "`n📋 Requisitos para instalar:" -ForegroundColor Yellow
Write-Host "   - Windows 10/11" -ForegroundColor Gray
Write-Host "   - .NET 10.0 Runtime" -ForegroundColor Gray
Write-Host "   - SQL Server 2022+ o LocalDB" -ForegroundColor Gray
Write-Host "   - Puerto 5000 disponible" -ForegroundColor Gray
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
