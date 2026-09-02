<#
.SYNOPSIS
    Corre el banco de pruebas de la pantalla de Repositor (ADR 0003) contra una
    instancia real de PricingApi, y deja un Excel con lo esperado vs. lo obtenido.

.DESCRIPTION
    Cubre, de punta a punta, contra la API HTTP real (no solo SQL):
      TC01  Alta de una cuenta de Repositor (provisión por ADMIN).
      TC02  Alta con Usuario o Pin vacío (400).
      TC03  Un Usuario duplicado no crea una segunda fila (UNIQUE global).
      TC04  Login: correcto (200 con token) / PIN incorrecto (401) / usuario
            inexistente (401).
      TC05  Lookup de stock sin sesión (401) / con un token inventado (401).
      TC06  Lookup de stock de un SKU de la propia empresa del Repositor.
      TC07  Aislamiento multi-empresa: un Repositor no puede ver ni cargar
            stock de un SKU que pertenece a OTRA empresa (404, no 403 - el
            SKU "no existe" desde su perspectiva).
      TC08  Recuento absoluto de stock: actualiza StockEstado.StockActual y
            deja rastro inmutable en StockCargas.
      TC09  Recuento absoluto con StockNuevo negativo (400).
      TC10  Recuento absoluto de un SKU inexistente (404).

    Todo lo que este script crea (dos Empresas QA, sus productos `QA-REPO-*` y
    la cuenta `qa_repositor_uno`) se borra al final, haya fallado algo o no.

.EXAMPLE
    pwsh -File .\Run-PruebasRepositor.ps1 -AdminUsuario ADMIN -AdminPassword "................"

.NOTES
    -AdminUsuario/-AdminPassword son las credenciales reales de un ADMIN ya
    existente en la instalación de destino. Nunca hardcodear una contraseña
    real acá ni pasarla en un script versionado - se piden como parámetro en
    cada corrida.
#>

param(
    [string]$ApiBaseUrl = "http://localhost:5000",
    [string]$ServerInstance = "localhost\SQLEXPRESS",
    [string]$Database = "PRICES_DB",
    [string]$OutputExcel = "",
    [Parameter(Mandatory = $true)][string]$AdminUsuario,
    [Parameter(Mandatory = $true)][string]$AdminPassword
)

# #psScriptRootEnParamMandatory: ver la misma nota en Run-PruebasLogin.ps1.
if ([string]::IsNullOrWhiteSpace($OutputExcel)) { $OutputExcel = "$PSScriptRoot\Resultados-Repositor.xlsx" }

$ErrorActionPreference = "Stop"
if (-not (Get-Module -ListAvailable ImportExcel)) {
    throw "Falta el módulo ImportExcel. Instalarlo con: Install-Module ImportExcel -Scope CurrentUser"
}
Import-Module ImportExcel

function Invoke-Sql($query) {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query
}

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Token = $null,
        $Body = $null
    )
    $headers = @{}
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    $params = @{ Method = $Method; Uri = "$ApiBaseUrl$Path"; Headers = $headers; ErrorAction = 'Stop'; UseBasicParsing = $true }
    if ($null -ne $Body) {
        # #invokeWebRequestBodyNoEsUtf8: ver la misma nota en Run-PruebasLogin.ps1.
        $json = $Body | ConvertTo-Json -Depth 6
        $params["Body"] = [System.Text.Encoding]::UTF8.GetBytes($json)
        $params["ContentType"] = "application/json; charset=utf-8"
    }
    try {
        $resp = Invoke-WebRequest @params
        $parsed = $null
        if ($resp.Content) { try { $parsed = $resp.Content | ConvertFrom-Json } catch {} }
        return [PSCustomObject]@{ StatusCode = [int]$resp.StatusCode; Body = $parsed }
    } catch {
        $statusCode = 0
        $rawBody = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $rawBody = $reader.ReadToEnd()
            } catch {}
        }
        $parsed = $null
        if ($rawBody) { try { $parsed = $rawBody | ConvertFrom-Json } catch {} }
        return [PSCustomObject]@{ StatusCode = $statusCode; Body = $parsed }
    }
}

$rows = @()
function Add-Resultado {
    param([string]$Id, [string]$Descripcion, [bool]$Pass, [string]$Esperado, [string]$Obtenido, [string]$Detalle = "")
    $script:rows += [PSCustomObject]@{
        Caso              = $Id
        Descripcion       = $Descripcion
        ResultadoEsperado = $Esperado
        ResultadoObtenido = $Obtenido
        Resultado         = if ($Pass) { "PASS" } else { "FAIL" }
        Detalle           = $Detalle
    }
}

# ----------------------------------------------------------------------------
# 0. Pre-flight
# ----------------------------------------------------------------------------
Write-Host "== 0. Verificando que la API esté arriba ==" -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri "$ApiBaseUrl/health" -Method Get -UseBasicParsing | Out-Null
} catch {
    throw "No se pudo conectar a $ApiBaseUrl/health. Iniciá PricingApi antes de correr esta suite."
}

# ----------------------------------------------------------------------------
# 1. Limpieza de una corrida anterior (idempotente) + login como el ADMIN real
# ----------------------------------------------------------------------------
Write-Host "== 1. Limpiando datos de una corrida anterior ==" -ForegroundColor Cyan
function Remove-DatosQaRepositor {
    Invoke-Sql "DELETE sc FROM StockCargas sc JOIN Productos p ON p.ProductoID = sc.ProductoID WHERE p.SKU LIKE 'QA-REPO-%'"
    Invoke-Sql "DELETE FROM Repositores WHERE Usuario LIKE 'qa_repositor_%'"
    foreach ($nombreEmpresa in @('Empresa QA Repositor A', 'Empresa QA Repositor B')) {
        $emp = Invoke-Sql "SELECT EmpresaID FROM Empresas WHERE RazonSocial = '$nombreEmpresa'"
        if ($emp) {
            $id = $emp.EmpresaID
            $prods = Invoke-Sql "SELECT ProductoID FROM Productos WHERE EmpresaID = $id AND SKU LIKE 'QA-REPO-%'"
            foreach ($p in @($prods)) {
                Invoke-Sql "DELETE FROM StockEstado WHERE ProductoID = $($p.ProductoID)"
                Invoke-Sql "DELETE FROM Productos WHERE ProductoID = $($p.ProductoID)"
            }
            Invoke-Sql "DELETE FROM Empresas WHERE EmpresaID = $id"
        }
    }
}
Remove-DatosQaRepositor

$loginAdminReal = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = $AdminUsuario; Password = $AdminPassword }
if ($loginAdminReal.StatusCode -ne 200) {
    throw "No se pudo loguear con -AdminUsuario/-AdminPassword (HTTP $($loginAdminReal.StatusCode)). Verificá las credenciales."
}
$adminRealToken = $loginAdminReal.Body.token

$empresaA = Invoke-Api -Method Post -Path "/api/admin/empresas" -Token $adminRealToken -Body @{ RazonSocial = "Empresa QA Repositor A"; CUIT = "30-00000003-1"; Activo = $true }
$empresaB = Invoke-Api -Method Post -Path "/api/admin/empresas" -Token $adminRealToken -Body @{ RazonSocial = "Empresa QA Repositor B"; CUIT = "30-00000004-1"; Activo = $true }
$empresaAId = $empresaA.Body.empresaID
$empresaBId = $empresaB.Body.empresaID

$productoA = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaAId; SKU = "QA-REPO-A"; Titulo = "Producto QA Repositor A"; Activo = $true }
$productoB = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaBId; SKU = "QA-REPO-B"; Titulo = "Producto QA Repositor B"; Activo = $true }
$productoAId = $productoA.Body.productoID
$productoBId = $productoB.Body.productoID

Invoke-Api -Method Post -Path "/api/admin/stock-estado" -Token $adminRealToken -Body @{ ProductoID = $productoAId; StockActual = 50; StockReservado = 0; StockMinimo = 5; StockMaximo = 200; StockObjetivo = 100 } | Out-Null
Invoke-Api -Method Post -Path "/api/admin/stock-estado" -Token $adminRealToken -Body @{ ProductoID = $productoBId; StockActual = 99; StockReservado = 0; StockMinimo = 5; StockMaximo = 200; StockObjetivo = 100 } | Out-Null

Write-Host "== 2. Corriendo casos de prueba ==" -ForegroundColor Cyan

# --- TC01: alta de repositor --------------------------------------------------
$altaRepositor = Invoke-Api -Method Post -Path "/api/admin/repositores" -Token $adminRealToken -Body @{
    EmpresaID = $empresaAId; NombreCompleto = "QA Repositor Uno"; Usuario = "qa_repositor_uno"; Pin = "123456"
}
$pass = ($altaRepositor.StatusCode -eq 201) -and ($altaRepositor.Body.repositorID -gt 0)
Add-Resultado -Id "TC01" -Descripcion "Alta de una cuenta de Repositor" `
    -Esperado "201 con RepositorID" -Obtenido "$($altaRepositor.StatusCode) RepositorID=$($altaRepositor.Body.repositorID)" -Pass $pass

# --- TC02: alta con Usuario/Pin vacío ------------------------------------------
$altaVacia = Invoke-Api -Method Post -Path "/api/admin/repositores" -Token $adminRealToken -Body @{
    EmpresaID = $empresaAId; NombreCompleto = "QA Repositor Vacío"; Usuario = ""; Pin = ""
}
$pass = ($altaVacia.StatusCode -eq 400)
Add-Resultado -Id "TC02" -Descripcion "Alta de Repositor con Usuario o Pin vacío" `
    -Esperado "400" -Obtenido "$($altaVacia.StatusCode)" -Pass $pass

# --- TC03: Usuario duplicado no crea una segunda fila -------------------------
$altaDuplicada = Invoke-Api -Method Post -Path "/api/admin/repositores" -Token $adminRealToken -Body @{
    EmpresaID = $empresaBId; NombreCompleto = "QA Repositor Uno (duplicado)"; Usuario = "qa_repositor_uno"; Pin = "999999"
}
$conteoRepositores = (Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM Repositores WHERE Usuario = 'qa_repositor_uno'").Cantidad
$pass = ($altaDuplicada.StatusCode -ne 201) -and ($conteoRepositores -eq 1)
Add-Resultado -Id "TC03" -Descripcion "Un Usuario de Repositor duplicado no crea una segunda fila (UNIQUE global)" `
    -Esperado "alta duplicada != 201, sigue habiendo 1 fila con ese Usuario" `
    -Obtenido "alta duplicada=$($altaDuplicada.StatusCode), filas=$conteoRepositores" -Pass $pass

# --- TC04: login correcto / PIN incorrecto / usuario inexistente --------------
$loginOk = Invoke-Api -Method Post -Path "/api/input/repositor/login" -Body @{ Usuario = "qa_repositor_uno"; Pin = "123456" }
$loginPinMal = Invoke-Api -Method Post -Path "/api/input/repositor/login" -Body @{ Usuario = "qa_repositor_uno"; Pin = "000000" }
$loginUsuarioInexistente = Invoke-Api -Method Post -Path "/api/input/repositor/login" -Body @{ Usuario = "qa_repositor_no_existe"; Pin = "123456" }
$pass = ($loginOk.StatusCode -eq 200) -and (-not [string]::IsNullOrEmpty($loginOk.Body.token)) -and ($loginOk.Body.nombreCompleto -eq "QA Repositor Uno") -and
        ($loginPinMal.StatusCode -eq 401) -and ($loginUsuarioInexistente.StatusCode -eq 401)
Add-Resultado -Id "TC04" -Descripcion "Login: correcto (200 con token) / PIN incorrecto (401) / usuario inexistente (401)" `
    -Esperado "200 con token y nombre correcto / 401 / 401" `
    -Obtenido "$($loginOk.StatusCode) token=$(if($loginOk.Body.token){'sí'}else{'no'}) nombre=$($loginOk.Body.nombreCompleto) / $($loginPinMal.StatusCode) / $($loginUsuarioInexistente.StatusCode)" -Pass $pass
$tokenRepositor = $loginOk.Body.token

# --- TC05: lookup sin sesión / con token inventado -----------------------------
$lookupSinSesion = Invoke-Api -Method Get -Path "/api/input/stock/lookup?sku=QA-REPO-A"
$lookupTokenInventado = Invoke-Api -Method Get -Path "/api/input/stock/lookup?sku=QA-REPO-A" -Token "token-que-no-existe"
$pass = ($lookupSinSesion.StatusCode -eq 401) -and ($lookupTokenInventado.StatusCode -eq 401)
Add-Resultado -Id "TC05" -Descripcion "Lookup de stock sin sesión (401) / con un token inventado (401)" `
    -Esperado "401 / 401" -Obtenido "$($lookupSinSesion.StatusCode) / $($lookupTokenInventado.StatusCode)" -Pass $pass

# --- TC06: lookup de un SKU de la propia empresa -------------------------------
$lookupPropio = Invoke-Api -Method Get -Path "/api/input/stock/lookup?sku=QA-REPO-A" -Token $tokenRepositor
$pass = ($lookupPropio.StatusCode -eq 200) -and ($lookupPropio.Body.stockActual -eq 50) -and ($lookupPropio.Body.sku -eq "QA-REPO-A")
Add-Resultado -Id "TC06" -Descripcion "Lookup de stock de un SKU de la propia empresa del Repositor" `
    -Esperado "200, stockActual=50" -Obtenido "$($lookupPropio.StatusCode), stockActual=$($lookupPropio.Body.stockActual)" -Pass $pass

# --- TC07: aislamiento multi-empresa (SKU de OTRA empresa) --------------------
$lookupOtraEmpresa = Invoke-Api -Method Get -Path "/api/input/stock/lookup?sku=QA-REPO-B" -Token $tokenRepositor
$cargaOtraEmpresa = Invoke-Api -Method Post -Path "/api/input/stock" -Token $tokenRepositor -Body @{ SKU = "QA-REPO-B"; StockNuevo = 1 }
$stockBIntacto = (Invoke-Sql "SELECT StockActual FROM StockEstado WHERE ProductoID = $productoBId").StockActual
$pass = ($lookupOtraEmpresa.StatusCode -eq 404) -and ($cargaOtraEmpresa.StatusCode -eq 404) -and ($stockBIntacto -eq 99)
Add-Resultado -Id "TC07" -Descripcion "Aislamiento multi-empresa: no puede ver ni cargar stock de un SKU de OTRA empresa" `
    -Esperado "lookup=404, carga=404, StockActual de la otra empresa sigue en 99" `
    -Obtenido "lookup=$($lookupOtraEmpresa.StatusCode), carga=$($cargaOtraEmpresa.StatusCode), stockB=$stockBIntacto" -Pass $pass

# --- TC08: recuento absoluto de stock -------------------------------------------
$cargaOk = Invoke-Api -Method Post -Path "/api/input/stock" -Token $tokenRepositor -Body @{ SKU = "QA-REPO-A"; StockNuevo = 75 }
$stockADespues = (Invoke-Sql "SELECT StockActual FROM StockEstado WHERE ProductoID = $productoAId").StockActual
$filaStockCarga = Invoke-Sql "SELECT TOP 1 StockAnterior, StockNuevo, RepositorID FROM StockCargas WHERE ProductoID = $productoAId ORDER BY StockCargaID DESC"
$pass = ($cargaOk.StatusCode -eq 200) -and ($cargaOk.Body.stockAnterior -eq 50) -and ($cargaOk.Body.stockNuevo -eq 75) -and
        ($stockADespues -eq 75) -and ($filaStockCarga.StockAnterior -eq 50) -and ($filaStockCarga.StockNuevo -eq 75) -and ($filaStockCarga.RepositorID -eq $altaRepositor.Body.repositorID)
Add-Resultado -Id "TC08" -Descripcion "Recuento absoluto de stock actualiza StockEstado y deja rastro en StockCargas" `
    -Esperado "200 (anterior=50, nuevo=75), StockActual=75, fila en StockCargas con esos valores" `
    -Obtenido "$($cargaOk.StatusCode) (anterior=$($cargaOk.Body.stockAnterior), nuevo=$($cargaOk.Body.stockNuevo)), StockActual=$stockADespues, fila anterior=$($filaStockCarga.StockAnterior) nuevo=$($filaStockCarga.StockNuevo)" -Pass $pass

# --- TC09: recuento con StockNuevo negativo -------------------------------------
$cargaNegativa = Invoke-Api -Method Post -Path "/api/input/stock" -Token $tokenRepositor -Body @{ SKU = "QA-REPO-A"; StockNuevo = -5 }
$pass = ($cargaNegativa.StatusCode -eq 400)
Add-Resultado -Id "TC09" -Descripcion "Recuento absoluto con StockNuevo negativo" `
    -Esperado "400" -Obtenido "$($cargaNegativa.StatusCode)" -Pass $pass

# --- TC10: recuento de un SKU inexistente ---------------------------------------
$cargaInexistente = Invoke-Api -Method Post -Path "/api/input/stock" -Token $tokenRepositor -Body @{ SKU = "QA-REPO-NO-EXISTE"; StockNuevo = 10 }
$pass = ($cargaInexistente.StatusCode -eq 404)
Add-Resultado -Id "TC10" -Descripcion "Recuento absoluto de un SKU inexistente" `
    -Esperado "404" -Obtenido "$($cargaInexistente.StatusCode)" -Pass $pass

# ----------------------------------------------------------------------------
# 3. Limpieza final
# ----------------------------------------------------------------------------
Write-Host "== 3. Limpieza final ==" -ForegroundColor Cyan
Remove-DatosQaRepositor

Write-Host "== 4. Resultado ==" -ForegroundColor Cyan
# #outStringWidthConsolaAngosta: ver la misma nota en Run-PruebasLogin.ps1.
($rows | Format-Table Caso, Descripcion, Resultado -AutoSize -Wrap | Out-String -Width 200) | Write-Host

# #whereObjectColapsaAEscalar: ver la misma nota en Run-PruebasLogin.ps1.
$failCount = @($rows | Where-Object { $_.Resultado -eq 'FAIL' }).Count
$total = @($rows).Count
Write-Host "$($total - $failCount) / $total casos OK" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })

Write-Host "== 5. Exportando a Excel: $OutputExcel ==" -ForegroundColor Cyan
if (Test-Path $OutputExcel) { Remove-Item $OutputExcel -Force }

$excelParams = @{
    Path          = $OutputExcel
    WorksheetName = "Casos de prueba"
    AutoSize      = $true
    AutoFilter    = $true
    FreezeTopRow  = $true
    TableStyle    = 'Medium2'
    BoldTopRow    = $true
}
$rows | Select-Object Caso, Descripcion, ResultadoEsperado, ResultadoObtenido, Resultado, Detalle | Export-Excel @excelParams

$pkg = Open-ExcelPackage -Path $OutputExcel
$ws = $pkg.Workbook.Worksheets["Casos de prueba"]
$lastRow = $ws.Dimension.End.Row
$resultCol = ($ws.Cells["A1:Z1"] | Where-Object { $_.Text -eq 'Resultado' }).Start.Column
if ($resultCol) {
    $colLetter = [OfficeOpenXml.ExcelCellAddress]::new(1, $resultCol).Address -replace '\d', ''
    $range = "${colLetter}2:$colLetter$lastRow"
    Add-ConditionalFormatting -Worksheet $ws -Address $range -RuleType Equal -ConditionValue "PASS" -BackgroundColor LightGreen
    Add-ConditionalFormatting -Worksheet $ws -Address $range -RuleType Equal -ConditionValue "FAIL" -BackgroundColor LightPink
}
Close-ExcelPackage $pkg

Write-Host "Listo: $OutputExcel" -ForegroundColor Green

if ($failCount -gt 0) { exit 1 } else { exit 0 }
