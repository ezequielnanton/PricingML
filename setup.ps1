# Script de Instalación para Windows - PricingML
# Uso: .\setup.ps1

Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🚀 PricingML - Setup Installation Script" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan

# Verificar si Docker está instalado
Write-Host "`n📋 Verificando requisitos..." -ForegroundColor Yellow
$dockerInstalled = docker --version 2>$null

if (-not $dockerInstalled) {
    Write-Host "❌ Docker no está instalado o no está en el PATH" -ForegroundColor Red
    Write-Host "   Descargar desde: https://www.docker.com/products/docker-desktop" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Docker encontrado: $dockerInstalled" -ForegroundColor Green

# Verificar Docker daemon
Write-Host "`n🔍 Verificando Docker daemon..." -ForegroundColor Yellow
docker info >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker daemon no está corriendo" -ForegroundColor Red
    Write-Host "   Inicia Docker Desktop e intenta de nuevo" -ForegroundColor Gray
    exit 1
}
Write-Host "✅ Docker daemon está activo" -ForegroundColor Green

# Copiar .env si no existe
if (-not (Test-Path ".env")) {
    Write-Host "`n📝 Creando archivo .env..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "✅ Archivo .env creado" -ForegroundColor Green
    Write-Host "   ⚠️  Edita .env con tus credenciales de SQL Server antes de continuar" -ForegroundColor Yellow
    Write-Host "   Ejecuta de nuevo este script una vez configurado" -ForegroundColor Gray
    exit 0
}

Write-Host "✅ Archivo .env encontrado" -ForegroundColor Green

# Construcción de imágenes
Write-Host "`n🔨 Construyendo imágenes Docker (esto puede tomar 5-10 minutos)..." -ForegroundColor Yellow
docker-compose build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al construir imágenes Docker" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Imágenes construidas exitosamente" -ForegroundColor Green

# Iniciar servicios
Write-Host "`n🚀 Iniciando servicios..." -ForegroundColor Yellow
docker-compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al iniciar servicios" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Servicios iniciados" -ForegroundColor Green

# Esperar a que se inicialicen
Write-Host "`n⏳ Esperando a que los servicios se inicialicen (30 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Verificar estado
Write-Host "`n📊 Estado de los servicios:" -ForegroundColor Yellow
docker-compose ps

# Verificar endpoints
Write-Host "`n🔗 Verificando conectividad..." -ForegroundColor Yellow

$motorHealth = $false
$clientHealth = $false

$maxAttempts = 5
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $attempt++

    try {
        $motorResponse = curl.exe -s -o /dev/null -w "%{http_code}" "http://localhost:5000/health" 2>$null
        if ($motorResponse -eq "200") {
            Write-Host "✅ Motor (API) está respondiendo en http://localhost:5000" -ForegroundColor Green
            $motorHealth = $true
        }
    } catch {
        # Continuar intentando
    }

    try {
        $clientResponse = curl.exe -s -o /dev/null -w "%{http_code}" "http://localhost:3000" 2>$null
        if ($clientResponse -eq "200") {
            Write-Host "✅ Cliente está respondiendo en http://localhost:3000" -ForegroundColor Green
            $clientHealth = $true
        }
    } catch {
        # Continuar intentando
    }

    if ($motorHealth -and $clientHealth) {
        break
    }

    if ($attempt -lt $maxAttempts) {
        Write-Host "   Reintentando en 10 segundos..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

# Resultado final
Write-Host "`n════════════════════════════════════════════════" -ForegroundColor Cyan
if ($motorHealth -and $clientHealth) {
    Write-Host "✅ ¡Setup completado exitosamente!" -ForegroundColor Green
    Write-Host "`n🎉 PricingML está listo para usar:" -ForegroundColor Green
    Write-Host "   🌐 Cliente: http://localhost:3000" -ForegroundColor Cyan
    Write-Host "   🔌 API: http://localhost:5000/swagger" -ForegroundColor Cyan
    Write-Host "   🗄️  SQL: localhost,1433 (Usuario: sa)" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Setup completado, pero verificar los servicios:" -ForegroundColor Yellow
    docker-compose logs --tail=20
    Write-Host "`n   Ejecuta 'docker-compose logs -f' para más detalles" -ForegroundColor Gray
}
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n💡 Comandos útiles:" -ForegroundColor Yellow
Write-Host "   docker-compose ps          - Ver estado de servicios" -ForegroundColor Gray
Write-Host "   docker-compose logs -f     - Ver logs en tiempo real" -ForegroundColor Gray
Write-Host "   docker-compose down        - Detener servicios" -ForegroundColor Gray
Write-Host "   docker-compose restart     - Reiniciar servicios" -ForegroundColor Gray
