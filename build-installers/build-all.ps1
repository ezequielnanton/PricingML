# Script para compilar Motor y Cliente, crear ambos instaladores
# Uso: .\build-all.ps1

Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🚀 Compilando Motor y Cliente - PricingML" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan

$ErrorCount = 0

# Compilar Motor
Write-Host "`n" -ForegroundColor Cyan
Write-Host "═══ PASO 1: MOTOR ═══" -ForegroundColor Cyan
.\build-motor.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error compilando Motor" -ForegroundColor Red
    $ErrorCount++
} else {
    Write-Host "✅ Motor compilado exitosamente" -ForegroundColor Green
}

# Compilar Cliente
Write-Host "`n" -ForegroundColor Cyan
Write-Host "═══ PASO 2: CLIENTE ═══" -ForegroundColor Cyan
.\build-cliente.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error compilando Cliente" -ForegroundColor Red
    $ErrorCount++
} else {
    Write-Host "✅ Cliente compilado exitosamente" -ForegroundColor Green
}

# Resultado final
Write-Host "`n════════════════════════════════════════════════" -ForegroundColor Cyan
if ($ErrorCount -eq 0) {
    Write-Host "✅ ¡BUILD COMPLETADO!" -ForegroundColor Green
    Write-Host "`n📦 Instaladores listos en: ..\dist\" -ForegroundColor Cyan
    Write-Host "   - PricingML-Motor-Setup.exe" -ForegroundColor Yellow
    Write-Host "   - PricingML-Cliente-Setup.exe" -ForegroundColor Yellow
    Write-Host "`n📋 Próximos pasos:" -ForegroundColor Yellow
    Write-Host "   1. Ejecutar PricingML-Motor-Setup.exe en la PC destino" -ForegroundColor Gray
    Write-Host "   2. Ejecutar PricingML-Cliente-Setup.exe en la PC destino" -ForegroundColor Gray
    Write-Host "   3. Acceder a http://localhost:3000" -ForegroundColor Gray
} else {
    Write-Host "❌ BUILD FALLÓ ($ErrorCount error(s))" -ForegroundColor Red
    exit 1
}
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
