# Script para compilar PricingML y crear release ZIP
# Uso: .\build-release.ps1

Write-Host "================================" -ForegroundColor Cyan
Write-Host "  Compilando PricingML" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$ErrorCount = 0
$distDir = "dist"
$releaseDir = "$distDir/pricingml-release"

# Crear directorio
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
    Write-Host "[OK] Directorio $releaseDir creado" -ForegroundColor Green
}

# Paso 1: Compilar Motor
Write-Host "" -ForegroundColor Yellow
Write-Host "Compilando Motor..." -ForegroundColor Yellow
$motorSource = "PricingEngine\src\PricingApi"
$motorDest = "$releaseDir\Motor"

Push-Location $motorSource
dotnet publish -c Release -o "bin\Release\net10.0\publish" --no-self-contained 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al compilar Motor" -ForegroundColor Red
    $ErrorCount++
} else {
    Write-Host "[OK] Motor compilado" -ForegroundColor Green
    New-Item -ItemType Directory -Path $motorDest -Force | Out-Null
    Copy-Item -Path "bin\Release\net10.0\publish\*" -Destination $motorDest -Recurse -Force
    Write-Host "[OK] Motor copiado a release" -ForegroundColor Green
}
Pop-Location

# Paso 2: Compilar Cliente
Write-Host "" -ForegroundColor Yellow
Write-Host "Compilando Cliente..." -ForegroundColor Yellow
$clientSource = "PricingClient\pricing-ui"
$clientDest = "$releaseDir\Cliente"

Push-Location $clientSource
npm install 2>&1 | Out-Null
npm run build 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error al compilar Cliente" -ForegroundColor Red
    $ErrorCount++
} else {
    Write-Host "[OK] Cliente compilado" -ForegroundColor Green
    New-Item -ItemType Directory -Path $clientDest -Force | Out-Null
    Copy-Item -Path "dist\*" -Destination $clientDest -Recurse -Force
    Write-Host "[OK] Cliente copiado a release" -ForegroundColor Green
}
Pop-Location

# Paso 3: Copiar archivos de configuracion
Write-Host "" -ForegroundColor Yellow
Write-Host "Agregando archivos de configuracion..." -ForegroundColor Yellow

# Copiar appsettings.json.example
if (Test-Path "PricingEngine\src\PricingApi\appsettings.json") {
    Copy-Item "PricingEngine\src\PricingApi\appsettings.json" "$releaseDir\appsettings.json.example"
    Write-Host "[OK] Archivo de ejemplo copiado" -ForegroundColor Green
}

# Crear README
$readmeContent = @"
# PricingML - Release v1.0.0

## Contenido
- `Motor/` - API REST (.NET 10.0)
- `Cliente/` - Interfaz Web (React)

## Requisitos
- .NET 10.0 Runtime
- Node.js 18+
- SQL Server 2022+ o LocalDB

## Instalacion

### 1. Configurar Motor
Edita `appsettings.json` con tus datos SQL:
``json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;User Id=sa;Password=tu_password;..."
  }
}
```

### 2. Ejecutar Motor
```bash
cd Motor
dotnet PricingApi.dll
```
Motor estara en: http://localhost:5000

### 3. Ejecutar Cliente
```bash
cd Cliente
npm install
npm run dev
```
Cliente estara en: http://localhost:3000

## Documentacion
- Motor Swagger: http://localhost:5000/swagger
- Cliente: http://localhost:3000

"@

Set-Content -Path "$releaseDir\README.md" -Value $readmeContent
Write-Host "[OK] README.md creado" -ForegroundColor Green

# Paso 4: Crear ZIP
Write-Host "" -ForegroundColor Yellow
Write-Host "Creando archivo ZIP..." -ForegroundColor Yellow

$zipPath = "$distDir\PricingML-v1.0.0.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Compress-Archive -Path $releaseDir -DestinationPath $zipPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] ZIP creado: $zipPath" -ForegroundColor Green
    $zipSize = (Get-Item $zipPath).Length / 1MB
    Write-Host "     Tamanio: $([Math]::Round($zipSize, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] Error al crear ZIP" -ForegroundColor Red
    $ErrorCount++
}

# Resultado
Write-Host "" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
if ($ErrorCount -eq 0) {
    Write-Host "[OK] BUILD EXITOSO!" -ForegroundColor Green
    Write-Host "" -ForegroundColor Cyan
    Write-Host "Release ZIP disponible:" -ForegroundColor Cyan
    Write-Host "   $zipPath" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Proximos pasos:" -ForegroundColor Yellow
    Write-Host "   1. Subir a GitHub Releases" -ForegroundColor Gray
    Write-Host "   2. Descargar en otra PC" -ForegroundColor Gray
    Write-Host "   3. Extraer y ejecutar" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] BUILD FALLO - $ErrorCount error(s)" -ForegroundColor Red
    exit 1
}
Write-Host "================================" -ForegroundColor Cyan
