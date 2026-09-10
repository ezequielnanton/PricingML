# Diagnostico: que endpoints de la API de MercadoLibre siguen disponibles para esta app.
#
# El ADR 0010 documenta que en 2025 ML bloqueo con 403 tanto la busqueda por texto
# (GET /sites/{site}/search) como la lectura de publicaciones ajenas (GET /items/{id}),
# lo que obligo a cargar los competidores a mano. Este script vuelve a probar eso contra
# la API real, con el token de la cuenta configurada, y agrega endpoints que el ADR no
# dejo registrados (/products/search, /products/{id}, /highlights) para ver si hay
# alguna via de descubrimiento automatico todavia abierta.
#
# Uso:  .\Verificar-ApiMercadoLibre.ps1
#       .\Verificar-ApiMercadoLibre.ps1 -Termino "zapatillas nike" -ItemAjeno MLA1234567890

param(
    [string]$Termino = "",
    [string]$ItemAjeno = "",
    [string]$AppSettings = ""
)

$ErrorActionPreference = "Stop"
$resultados = @()

function Escribir-Titulo($texto) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $texto" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Probar-Endpoint {
    param(
        [string]$Nombre,
        [string]$Url,
        [string]$Token,
        [string]$Nota = ""
    )

    $encabezados = @{ "Accept" = "application/json" }
    if ($Token) { $encabezados["Authorization"] = "Bearer $Token" }

    $codigo = 0
    $cuerpo = ""

    # Windows PowerShell 5.1 no tiene -SkipHttpErrorCheck y lanza excepcion en 4xx/5xx,
    # que es justamente el caso que interesa medir aca.
    $parametros = @{
        Uri             = $Url
        Headers         = $encabezados
        Method          = "Get"
        TimeoutSec      = 30
        UseBasicParsing = $true
    }
    if ($PSVersionTable.PSVersion.Major -ge 6) { $parametros["SkipHttpErrorCheck"] = $true }

    try {
        $respuesta = Invoke-WebRequest @parametros
        $codigo = [int]$respuesta.StatusCode
        $cuerpo = $respuesta.Content
    }
    catch {
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $cuerpo = $_.ErrorDetails.Message }
        else { $cuerpo = $_.Exception.Message }

        if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $_.Exception.Response) {
            try { $codigo = [int]$_.Exception.Response.StatusCode } catch { }
        }
    }

    $color = switch ($codigo) {
        200     { "Green" }
        0       { "Yellow" }
        default { "Red" }
    }

    $conToken = if ($Token) { "con token" } else { "sin token" }
    Write-Host ("  {0,-46} {1,-10} HTTP {2}" -f $Nombre, $conToken, $codigo) -ForegroundColor $color

    # Un fragmento del cuerpo alcanza para distinguir "forbidden" de "access_denied"
    # de un resultado real, sin volcar respuestas enormes en la consola.
    $extracto = ""
    if ($cuerpo) {
        $extracto = ($cuerpo -replace '\s+', ' ').Trim()
        if ($extracto.Length -gt 200) { $extracto = $extracto.Substring(0, 200) + "..." }
        if ($codigo -ne 200) { Write-Host "      $extracto" -ForegroundColor DarkGray }
    }

    $script:resultados += [PSCustomObject]@{
        Endpoint = $Nombre
        Token    = $conToken
        Codigo   = $codigo
        Nota     = $Nota
        Extracto = $extracto
    }

    return @{ Codigo = $codigo; Cuerpo = $cuerpo }
}

Escribir-Titulo "Diagnostico de la API de MercadoLibre"

# --- 1. Localizar appsettings.json y leer la cadena de conexion -----------------------
if (-not $AppSettings) {
    $candidatos = @(
        (Join-Path $PSScriptRoot "..\..\dist\PricingML\appsettings.json"),
        (Join-Path $PSScriptRoot "..\src\PricingApi\appsettings.json")
    )
    $AppSettings = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $AppSettings -or -not (Test-Path $AppSettings)) {
    Write-Host "[ERROR] No encontre appsettings.json. Pasalo con -AppSettings <ruta>" -ForegroundColor Red
    exit 1
}

Write-Host "  Configuracion: $AppSettings"
$config = Get-Content $AppSettings -Raw | ConvertFrom-Json
$cadena = $config.ConnectionStrings.PricingDb
if (-not $cadena) {
    Write-Host "[ERROR] appsettings.json no tiene ConnectionStrings.PricingDb" -ForegroundColor Red
    exit 1
}

# --- 2. Sacar de la base el token, un item propio y un item ajeno ---------------------
Add-Type -AssemblyName "System.Data"
$conexion = New-Object System.Data.SqlClient.SqlConnection $cadena

try { $conexion.Open() }
catch {
    Write-Host "[ERROR] No se pudo conectar a SQL Server: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

function Consultar-Escalar($sql) {
    $cmd = $conexion.CreateCommand()
    $cmd.CommandText = $sql
    $valor = $cmd.ExecuteScalar()
    if ($null -eq $valor -or $valor -is [System.DBNull]) { return $null }
    return $valor.ToString()
}

$token = Consultar-Escalar @"
SELECT TOP 1 AccessToken FROM CuentasML
WHERE AccessToken IS NOT NULL AND LEN(AccessToken) > 0
ORDER BY FechaVencimientoToken DESC
"@

$vencimiento = Consultar-Escalar @"
SELECT TOP 1 CONVERT(VARCHAR(30), FechaVencimientoToken, 126) FROM CuentasML
WHERE AccessToken IS NOT NULL AND LEN(AccessToken) > 0
ORDER BY FechaVencimientoToken DESC
"@

$itemPropio = Consultar-Escalar "SELECT TOP 1 MeliItemID FROM PublicacionesML WHERE MeliItemID IS NOT NULL ORDER BY PublicacionID DESC"

if (-not $ItemAjeno) {
    $ItemAjeno = Consultar-Escalar "SELECT TOP 1 CompetidorItemID FROM PublicacionCompetidoresManual WHERE Activo = 1 ORDER BY VinculoID DESC"
}

if (-not $Termino) {
    $titulo = Consultar-Escalar "SELECT TOP 1 CompetidorTitulo FROM PublicacionCompetidoresManual WHERE CompetidorTitulo IS NOT NULL ORDER BY VinculoID DESC"
    $Termino = if ($titulo) { ($titulo -split '\s+' | Select-Object -First 3) -join ' ' } else { "zapatillas" }
}

$conexion.Close()

$sitio = if ($itemPropio -and $itemPropio.Length -ge 3) { $itemPropio.Substring(0, 3).ToUpper() } else { "MLA" }

Write-Host ""
Write-Host "  Sitio            : $sitio"
Write-Host "  Termino de busqueda: $Termino"
Write-Host "  Item propio      : $(if ($itemPropio) { $itemPropio } else { '(no hay publicaciones cargadas)' })"
Write-Host "  Item ajeno       : $(if ($ItemAjeno) { $ItemAjeno } else { '(no hay competidores cargados)' })"

if ($token) {
    $vencido = $false
    if ($vencimiento) {
        try { $vencido = ([datetime]$vencimiento) -lt (Get-Date) } catch { }
    }
    $estado = if ($vencido) { "VENCIDO - abri la app y usa 'Sincronizar ML' para refrescarlo, despues volve a correr esto" } else { "vigente" }
    $colorEstado = if ($vencido) { "Yellow" } else { "Green" }
    Write-Host "  Token            : ...$($token.Substring([Math]::Max(0, $token.Length - 6))) ($estado)" -ForegroundColor $colorEstado
}
else {
    Write-Host "  Token            : (no hay ninguno guardado; solo se prueban las llamadas anonimas)" -ForegroundColor Yellow
}

$api = "https://api.mercadolibre.com"
$terminoUrl = [System.Uri]::EscapeDataString($Termino)

# --- 3. Control: lo que segun el ADR SI funciona -------------------------------------
Escribir-Titulo "Control (deberia funcionar)"
if ($itemPropio -and $token) {
    Probar-Endpoint "GET /items/{propio}" "$api/items/$itemPropio" $token "control positivo" | Out-Null
    Probar-Endpoint "GET /items/{propio}/price_to_win" "$api/items/$itemPropio/price_to_win?version=v2" $token "solo catalogo" | Out-Null
}
else {
    Write-Host "  (omitido: falta item propio o token)" -ForegroundColor DarkGray
}

# --- 4. Lo que el ADR reporto bloqueado ----------------------------------------------
Escribir-Titulo "Bloqueado segun ADR 0010 (verificar si sigue igual)"
Probar-Endpoint "GET /sites/{sitio}/search" "$api/sites/$sitio/search?q=$terminoUrl&limit=1" "" "sin token" | Out-Null
if ($token) {
    Probar-Endpoint "GET /sites/{sitio}/search" "$api/sites/$sitio/search?q=$terminoUrl&limit=1" $token "con token" | Out-Null
}
if ($ItemAjeno -and $token) {
    Probar-Endpoint "GET /items/{ajeno}" "$api/items/$ItemAjeno" $token "publicacion de otro vendedor" | Out-Null
}

# --- 5. Vias que el ADR no dejo registradas ------------------------------------------
Escribir-Titulo "Vias no registradas en el ADR (lo que interesa averiguar)"

$productos = Probar-Endpoint "GET /products/search" "$api/products/search?site_id=$sitio&q=$terminoUrl&status=active" $token "catalogo de productos"
if ($productos.Codigo -eq 200) {
    try {
        $primerProducto = ($productos.Cuerpo | ConvertFrom-Json).results | Select-Object -First 1
        $idProducto = if ($primerProducto -is [string]) { $primerProducto } else { $primerProducto.id }
        if ($idProducto) {
            Write-Host "      -> producto encontrado: $idProducto" -ForegroundColor Green
            Probar-Endpoint "GET /products/{id}" "$api/products/$idProducto" $token "precio del buy box" | Out-Null
            Probar-Endpoint "GET /products/{id}/items" "$api/products/$idProducto/items" $token "publicaciones del producto" | Out-Null
        }
    }
    catch {
        Write-Host "      No pude interpretar la respuesta: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

Probar-Endpoint "GET /highlights/{sitio}/category/{cat}" "$api/highlights/$sitio/category/MLA1276" $token "mas vendidos" | Out-Null
Probar-Endpoint "GET /sites/{sitio}/search?seller_id" "$api/sites/$sitio/search?seller_id=0&limit=1" $token "busqueda acotada a vendedor" | Out-Null
Probar-Endpoint "GET /trends/{sitio}" "$api/trends/$sitio" $token "tendencias" | Out-Null

# --- 6. Resumen ----------------------------------------------------------------------
Escribir-Titulo "Resumen"
$resultados | Format-Table Endpoint, Token, Codigo, Nota -AutoSize

$abiertos = $resultados | Where-Object { $_.Codigo -eq 200 }
Write-Host ""
Write-Host "  Endpoints que respondieron 200: $($abiertos.Count) de $($resultados.Count)" -ForegroundColor $(if ($abiertos.Count -gt 0) { "Green" } else { "Red" })
Write-Host ""
Write-Host "  Copiá esta salida completa y pasamela para decidir el diseño." -ForegroundColor Yellow
Write-Host ""
