# Script para compilar Motor y Cliente, crear ambos instaladores
# Uso: .\build-all.ps1

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Compilando Motor y Cliente - PricingML" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

$ErrorCount = 0

# Compilar Motor
Write-Host "" -ForegroundColor Cyan
Write-Host "PASO 1: MOTOR" -ForegroundColor Cyan
.\build-motor.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error compilando Motor" -ForegroundColor Red
    $ErrorCount++
} else {
    Write-Host "[OK] Motor compilado exitosamente" -ForegroundColor Green
}

# Compilar Cliente
Write-Host "" -ForegroundColor Cyan
Write-Host "PASO 2: CLIENTE" -ForegroundColor Cyan
.\build-cliente.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error compilando Cliente" -ForegroundColor Red
    $ErrorCount++
} else {
    Write-Host "[OK] Cliente compilado exitosamente" -ForegroundColor Green
}

# Resultado final
Write-Host "" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
if ($ErrorCount -eq 0) {
    Write-Host "[OK] BUILD COMPLETADO!" -ForegroundColor Green
    Write-Host "" -ForegroundColor Cyan
    Write-Host "Instaladores listos en: ..\dist\" -ForegroundColor Cyan
    Write-Host "   - PricingML-Motor-Setup.exe" -ForegroundColor Yellow
    Write-Host "   - PricingML-Cliente-Setup.exe" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Cyan
    Write-Host "Proximos pasos:" -ForegroundColor Yellow
    Write-Host "   1. Ejecutar PricingML-Motor-Setup.exe en la PC destino" -ForegroundColor Gray
    Write-Host "   2. Ejecutar PricingML-Cliente-Setup.exe en la PC destino" -ForegroundColor Gray
    Write-Host "   3. Acceder a http://localhost:3000" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] BUILD FALLO - $ErrorCount error(s)" -ForegroundColor Red
    exit 1
}
Write-Host "======================================" -ForegroundColor Cyan
