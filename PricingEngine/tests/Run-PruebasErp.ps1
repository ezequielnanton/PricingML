<#
.SYNOPSIS
    Corre el banco de pruebas de la Integración ERP (ADR 0004, 0022) contra una
    instancia real de PricingApi, y deja un Excel con lo esperado vs. lo obtenido.

.DESCRIPTION
    Cubre, de punta a punta, contra la API HTTP real (no solo SQL):
      TC01  Crear una Conexión ERP para una empresa y leerla de vuelta.
      TC02  El UNIQUE constraint (una conexión por empresa) se respeta.
      TC03  Actualizar UrlSalida/ApiKeySaliente de una conexión existente.
      TC04  Actualizar la conexión de una empresa que no tiene una creada (400).
      TC05  Descubrir campos: URL válida (200, con los campos reales del ERP) /
            URL rota (400).
      TC06  Guardar un mapeo de campos válido y leerlo de vuelta.
      TC07  Guardar un mapeo con un campo canónico inválido (400) / sin los
            campos obligatorios (400).
      TC08  Entrante (POST /api/erp/sync): crea un producto nuevo con su costo y
            stock.
      TC09  Entrante: el mismo SKU actualiza (no duplica) y nunca toca los
            costos operativos que no le pertenecen al ERP (envío, logística,
            financiero, publicidad).
      TC10  Entrante: sin ApiKey (401) / ApiKey inventada (401) / item sin SKU
            (no es error HTTP, es un ítem con error en el resultado).
      TC11  Saliente (POST /api/erp/pull): aplica el mapeo configurado contra
            un ERP simulado y deja rastro en ErpSincronizaciones.
      TC12  Saliente con ApiKeySaliente incorrecta: la empresa queda con
            Ok=false en el resumen, sin tirar abajo el resto de la corrida.

    Todo lo que este script crea (Empresa "Empresa QA ERP", su Conexión, su
    Mapeo, sus productos SKU `QA-ERP-*`) se borra al final, haya fallado algo o
    no. Nunca toca datos fuera de esa Empresa.

.EXAMPLE
    pwsh -File .\Run-PruebasErp.ps1 -AdminUsuario ADMIN -AdminPassword "................"

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
    [Parameter(Mandatory = $true)][string]$AdminPassword,
    [int]$MockErpPort = 8090
)

# #psScriptRootEnParamMandatory: ver la misma nota en Run-PruebasLogin.ps1 -- con
# parámetros Mandatory en el param() block, $PSScriptRoot puede llegar vacío todavía al
# evaluar el default de un parámetro anterior. Se resuelve en el cuerpo del script.
if ([string]::IsNullOrWhiteSpace($OutputExcel)) { $OutputExcel = "$PSScriptRoot\Resultados-Erp.xlsx" }

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
        [string]$ApiKeyHeader = $null,
        $Body = $null
    )
    $headers = @{}
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    if ($ApiKeyHeader) { $headers["X-Api-Key"] = $ApiKeyHeader }
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
# 0. Pre-flight: la API tiene que estar arriba. Este script nunca la arranca ni
#    la reinicia (podría estar sirviendo a un usuario real en este momento).
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
function Remove-EmpresaQaErp {
    $emp = Invoke-Sql "SELECT EmpresaID FROM Empresas WHERE RazonSocial = 'Empresa QA ERP'"
    if ($emp) {
        $id = $emp.EmpresaID
        Invoke-Sql "DELETE FROM ErpCampoMapeos WHERE EmpresaID = $id"
        Invoke-Sql "DELETE FROM ErpSincronizaciones WHERE EmpresaID = $id"
        Invoke-Sql "DELETE FROM ErpConexiones WHERE EmpresaID = $id"
        $prods = Invoke-Sql "SELECT ProductoID FROM Productos WHERE EmpresaID = $id AND SKU LIKE 'QA-ERP-%'"
        foreach ($p in @($prods)) {
            Invoke-Sql "DELETE FROM CostosProducto WHERE ProductoID = $($p.ProductoID)"
            Invoke-Sql "DELETE FROM StockEstado WHERE ProductoID = $($p.ProductoID)"
            Invoke-Sql "DELETE FROM Productos WHERE ProductoID = $($p.ProductoID)"
        }
        Invoke-Sql "DELETE FROM Empresas WHERE EmpresaID = $id"
    }
}
Remove-EmpresaQaErp

$loginAdminReal = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = $AdminUsuario; Password = $AdminPassword }
if ($loginAdminReal.StatusCode -ne 200) {
    throw "No se pudo loguear con -AdminUsuario/-AdminPassword (HTTP $($loginAdminReal.StatusCode)). Verificá las credenciales."
}
$adminRealToken = $loginAdminReal.Body.token

$empresaCreada = Invoke-Api -Method Post -Path "/api/admin/empresas" -Token $adminRealToken -Body @{
    RazonSocial = "Empresa QA ERP"; CUIT = "30-00000002-1"; Activo = $true
}
if ($empresaCreada.StatusCode -ne 201) { throw "No se pudo crear la Empresa QA ERP (HTTP $($empresaCreada.StatusCode))." }
$empresaId = $empresaCreada.Body.empresaID

# ----------------------------------------------------------------------------
# 2. Mock del GET que expone un ERP de cliente (nombres de campo no canónicos a
#    propósito, para ejercitar el mapeo configurable de punta a punta).
# ----------------------------------------------------------------------------
Write-Host "== 2. Levantando el mock ERP ==" -ForegroundColor Cyan
$mockToken = "qa-erp-token-secreto"
$mockProcess = Start-Process -FilePath "python" -ArgumentList "`"$PSScriptRoot\Mock-ErpServer.py`" $MockErpPort $mockToken" `
    -WindowStyle Hidden -PassThru

# #esperarMockListoNoSleepFijo: ver la misma nota en Run-PruebasLogin.ps1 -- se espera
# una conexión TCP real en vez de adivinar cuánto tarda Python en arrancar.
$mockListo = $false
for ($intento = 0; $intento -lt 20; $intento++) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("localhost", $MockErpPort)
        $tcp.Close()
        $mockListo = $true
        break
    } catch {
        Start-Sleep -Milliseconds 250
    }
}
if (-not $mockListo) { throw "El mock ERP no llegó a escuchar en el puerto $MockErpPort a tiempo." }
$mockUrl = "http://localhost:$MockErpPort/"

try {
    Write-Host "== 3. Corriendo casos de prueba ==" -ForegroundColor Cyan

    # --- TC01: crear conexión + leerla ------------------------------------------
    $crearConexion = Invoke-Api -Method Post -Path "/api/admin/erp-conexiones" -Token $adminRealToken -Body @{ EmpresaID = $empresaId }
    $getConexion = Invoke-Api -Method Get -Path "/api/admin/erp-conexiones/$empresaId" -Token $adminRealToken
    $pass = ($crearConexion.StatusCode -eq 201) -and (-not [string]::IsNullOrEmpty($crearConexion.Body.apiKeyEntrante)) -and
            ($getConexion.StatusCode -eq 200) -and ($null -eq $getConexion.Body.urlSalida)
    Add-Resultado -Id "TC01" -Descripcion "Crear Conexión ERP para una empresa y leerla de vuelta" `
        -Esperado "crear=201 con apiKeyEntrante, get=200 con urlSalida=null" `
        -Obtenido "crear=$($crearConexion.StatusCode) apiKey=$(if($crearConexion.Body.apiKeyEntrante){'sí'}else{'no'}), get=$($getConexion.StatusCode) urlSalida=$($getConexion.Body.urlSalida)" -Pass $pass

    # --- TC02: UNIQUE constraint (una conexión por empresa) ----------------------
    $crearDuplicada = Invoke-Api -Method Post -Path "/api/admin/erp-conexiones" -Token $adminRealToken -Body @{ EmpresaID = $empresaId }
    $conteoConexiones = (Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM ErpConexiones WHERE EmpresaID = $empresaId").Cantidad
    $pass = ($crearDuplicada.StatusCode -ne 201) -and ($conteoConexiones -eq 1)
    Add-Resultado -Id "TC02" -Descripcion "Una segunda Conexión ERP para la misma empresa no crea una fila duplicada" `
        -Esperado "crear duplicada != 201, sigue habiendo 1 fila en ErpConexiones" `
        -Obtenido "crear duplicada=$($crearDuplicada.StatusCode), filas=$conteoConexiones" -Pass $pass

    # --- TC03: actualizar UrlSalida/ApiKeySaliente + leerla ----------------------
    $actualizarConexion = Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/$empresaId" -Token $adminRealToken -Body @{
        UrlSalida = $mockUrl; ApiKeySaliente = $mockToken
    }
    $getConexion2 = Invoke-Api -Method Get -Path "/api/admin/erp-conexiones/$empresaId" -Token $adminRealToken
    $pass = ($actualizarConexion.StatusCode -eq 204) -and ($getConexion2.Body.urlSalida -eq $mockUrl) -and ($getConexion2.Body.apiKeySaliente -eq $mockToken)
    Add-Resultado -Id "TC03" -Descripcion "Actualizar UrlSalida/ApiKeySaliente de una Conexión existente" `
        -Esperado "actualizar=204, get refleja urlSalida y apiKeySaliente nuevos" `
        -Obtenido "actualizar=$($actualizarConexion.StatusCode), urlSalida=$($getConexion2.Body.urlSalida), apiKeySaliente=$($getConexion2.Body.apiKeySaliente)" -Pass $pass

    # --- TC04: actualizar la conexión de una empresa sin conexión creada --------
    $actualizarSinConexion = Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/999999999" -Token $adminRealToken -Body @{
        UrlSalida = "http://no-existe"; ApiKeySaliente = "x"
    }
    $pass = ($actualizarSinConexion.StatusCode -eq 400)
    Add-Resultado -Id "TC04" -Descripcion "Actualizar la Conexión ERP de una empresa que no tiene una creada" `
        -Esperado "400" -Obtenido "$($actualizarSinConexion.StatusCode)" -Pass $pass

    # --- TC05: descubrir campos: URL válida / URL rota ---------------------------
    $descubrirOk = Invoke-Api -Method Post -Path "/api/admin/erp-conexiones/descubrir-campos" -Token $adminRealToken -Body @{
        Url = $mockUrl; ApiKey = $mockToken
    }
    $camposEsperados = @("codigo_sku", "nombre", "precio_compra", "iva_pct", "impuestos_int", "existencias", "stock_min", "stock_max")
    $camposObtenidos = @($descubrirOk.Body.camposDescubiertos)
    $todosPresentes = ($camposEsperados | Where-Object { $camposObtenidos -notcontains $_ }).Count -eq 0
    $descubrirRoto = Invoke-Api -Method Post -Path "/api/admin/erp-conexiones/descubrir-campos" -Token $adminRealToken -Body @{
        Url = "http://localhost:19" # puerto que nadie escucha
    }
    $pass = ($descubrirOk.StatusCode -eq 200) -and $todosPresentes -and ($descubrirRoto.StatusCode -eq 400)
    Add-Resultado -Id "TC05" -Descripcion "Descubrir campos: URL válida (200, con los campos reales) / URL rota (400)" `
        -Esperado "válida=200 con 8 campos, rota=400" `
        -Obtenido "válida=$($descubrirOk.StatusCode) campos=$($camposObtenidos -join ','), rota=$($descubrirRoto.StatusCode)" -Pass $pass

    # --- TC06: guardar mapeo válido + leerlo -------------------------------------
    $mapeoValido = @(
        @{ CampoCanonico = "SKU"; CampoOrigen = "codigo_sku" }
        @{ CampoCanonico = "Titulo"; CampoOrigen = "nombre" }
        @{ CampoCanonico = "CostoCompra"; CampoOrigen = "precio_compra" }
        @{ CampoCanonico = "PorcentajeIVA"; CampoOrigen = "iva_pct" }
        @{ CampoCanonico = "ImpuestosInternos"; CampoOrigen = "impuestos_int" }
        @{ CampoCanonico = "StockActual"; CampoOrigen = "existencias" }
        @{ CampoCanonico = "StockMinimo"; CampoOrigen = "stock_min" }
        @{ CampoCanonico = "StockMaximo"; CampoOrigen = "stock_max" }
    )
    $guardarMapeo = Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/$empresaId/mapeo" -Token $adminRealToken -Body @{ Mapeos = $mapeoValido }
    $getMapeo = Invoke-Api -Method Get -Path "/api/admin/erp-conexiones/$empresaId/mapeo" -Token $adminRealToken
    $pass = ($guardarMapeo.StatusCode -eq 204) -and (@($getMapeo.Body).Count -eq 8)
    Add-Resultado -Id "TC06" -Descripcion "Guardar un mapeo de campos válido y leerlo de vuelta" `
        -Esperado "guardar=204, get devuelve 8 mapeos" `
        -Obtenido "guardar=$($guardarMapeo.StatusCode), get=$(@($getMapeo.Body).Count) mapeos" -Pass $pass

    # --- TC07: mapeo inválido (campo canónico desconocido / faltan obligatorios) -
    $mapeoInvalido = Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/$empresaId/mapeo" -Token $adminRealToken -Body @{
        Mapeos = @(@{ CampoCanonico = "CampoInventado"; CampoOrigen = "x" })
    }
    $mapeoIncompleto = Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/$empresaId/mapeo" -Token $adminRealToken -Body @{
        Mapeos = @(@{ CampoCanonico = "Titulo"; CampoOrigen = "nombre" })
    }
    $pass = ($mapeoInvalido.StatusCode -eq 400) -and ($mapeoIncompleto.StatusCode -eq 400)
    Add-Resultado -Id "TC07" -Descripcion "Guardar mapeo con campo canónico inválido (400) / sin los campos obligatorios (400)" `
        -Esperado "400 / 400" -Obtenido "$($mapeoInvalido.StatusCode) / $($mapeoIncompleto.StatusCode)" -Pass $pass
    # Deja el mapeo válido guardado de nuevo para TC11 (saliente).
    Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/$empresaId/mapeo" -Token $adminRealToken -Body @{ Mapeos = $mapeoValido } | Out-Null

    # --- TC08: entrante crea un producto nuevo -----------------------------------
    $syncCrear = Invoke-Api -Method Post -Path "/api/erp/sync" -ApiKeyHeader $crearConexion.Body.apiKeyEntrante -Body @{
        Items = @(@{ SKU = "QA-ERP-SYNC"; Titulo = "Producto QA ERP (entrante)"; CostoCompra = 1000; PorcentajeIVA = 21; StockActual = 10 })
    }
    $productoSync = Invoke-Sql "SELECT ProductoID FROM Productos WHERE EmpresaID = $empresaId AND SKU = 'QA-ERP-SYNC'"
    $costoSync = Invoke-Sql "SELECT CostoCompra FROM CostosProducto WHERE ProductoID = $($productoSync.ProductoID)"
    $stockSync = Invoke-Sql "SELECT StockActual FROM StockEstado WHERE ProductoID = $($productoSync.ProductoID)"
    $pass = ($syncCrear.StatusCode -eq 200) -and ($syncCrear.Body.procesados -eq 1) -and ($null -ne $productoSync) -and
            ($costoSync.CostoCompra -eq 1000) -and ($stockSync.StockActual -eq 10)
    Add-Resultado -Id "TC08" -Descripcion "Entrante (POST /api/erp/sync) crea un producto nuevo con su costo y stock" `
        -Esperado "procesados=1, CostoCompra=1000, StockActual=10" `
        -Obtenido "procesados=$($syncCrear.Body.procesados), CostoCompra=$($costoSync.CostoCompra), StockActual=$($stockSync.StockActual)" -Pass $pass

    # --- TC09: entrante actualiza (no duplica) y protege costos operativos ------
    Invoke-Sql "UPDATE CostosProducto SET CostoEnvioPromedio = 999 WHERE ProductoID = $($productoSync.ProductoID)"
    $syncActualizar = Invoke-Api -Method Post -Path "/api/erp/sync" -ApiKeyHeader $crearConexion.Body.apiKeyEntrante -Body @{
        Items = @(@{ SKU = "QA-ERP-SYNC"; Titulo = "Producto QA ERP (entrante)"; CostoCompra = 1500; StockActual = 25 })
    }
    $conteoProductoSync = (Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM Productos WHERE EmpresaID = $empresaId AND SKU = 'QA-ERP-SYNC'").Cantidad
    $costoSync2 = Invoke-Sql "SELECT CostoCompra, CostoEnvioPromedio FROM CostosProducto WHERE ProductoID = $($productoSync.ProductoID)"
    $stockSync2 = Invoke-Sql "SELECT StockActual FROM StockEstado WHERE ProductoID = $($productoSync.ProductoID)"
    $pass = ($conteoProductoSync -eq 1) -and ($costoSync2.CostoCompra -eq 1500) -and ($stockSync2.StockActual -eq 25) -and ($costoSync2.CostoEnvioPromedio -eq 999)
    Add-Resultado -Id "TC09" -Descripcion "Entrante: el mismo SKU actualiza (no duplica) y nunca toca costos operativos ajenos al ERP" `
        -Esperado "1 producto, CostoCompra=1500, StockActual=25, CostoEnvioPromedio sigue en 999" `
        -Obtenido "$conteoProductoSync producto(s), CostoCompra=$($costoSync2.CostoCompra), StockActual=$($stockSync2.StockActual), CostoEnvioPromedio=$($costoSync2.CostoEnvioPromedio)" -Pass $pass

    # --- TC10: entrante sin ApiKey / ApiKey inventada / item sin SKU ------------
    $syncSinApiKey = Invoke-Api -Method Post -Path "/api/erp/sync" -Body @{ Items = @(@{ SKU = "QA-ERP-X"; CostoCompra = 1; StockActual = 1 }) }
    $syncApiKeyInventada = Invoke-Api -Method Post -Path "/api/erp/sync" -ApiKeyHeader "no-existe-esta-key" -Body @{ Items = @(@{ SKU = "QA-ERP-X"; CostoCompra = 1; StockActual = 1 }) }
    $syncSinSku = Invoke-Api -Method Post -Path "/api/erp/sync" -ApiKeyHeader $crearConexion.Body.apiKeyEntrante -Body @{ Items = @(@{ SKU = ""; CostoCompra = 1; StockActual = 1 }) }
    $pass = ($syncSinApiKey.StatusCode -eq 401) -and ($syncApiKeyInventada.StatusCode -eq 401) -and
            ($syncSinSku.StatusCode -eq 200) -and ($syncSinSku.Body.errores -eq 1) -and ($syncSinSku.Body.procesados -eq 0)
    Add-Resultado -Id "TC10" -Descripcion "Entrante: sin ApiKey (401) / ApiKey inventada (401) / item sin SKU (error en el resultado, no 400 HTTP)" `
        -Esperado "401 / 401 / 200 con errores=1 procesados=0" `
        -Obtenido "$($syncSinApiKey.StatusCode) / $($syncApiKeyInventada.StatusCode) / $($syncSinSku.StatusCode) errores=$($syncSinSku.Body.errores) procesados=$($syncSinSku.Body.procesados)" -Pass $pass

    # --- TC11: saliente aplica el mapeo configurado contra el mock ERP ----------
    $ultimaSyncAntes = (Invoke-Sql "SELECT UltimaSincronizacion FROM ErpConexiones WHERE EmpresaID = $empresaId").UltimaSincronizacion
    $pullOk = Invoke-Api -Method Post -Path "/api/erp/pull"
    $resumenQa = @($pullOk.Body) | Where-Object { $_.empresaID -eq $empresaId }
    $productoPull = Invoke-Sql "SELECT ProductoID FROM Productos WHERE EmpresaID = $empresaId AND SKU = 'QA-ERP-PULL'"
    $costoPull = if ($productoPull) { Invoke-Sql "SELECT CostoCompra FROM CostosProducto WHERE ProductoID = $($productoPull.ProductoID)" } else { $null }
    $stockPull = if ($productoPull) { Invoke-Sql "SELECT StockActual FROM StockEstado WHERE ProductoID = $($productoPull.ProductoID)" } else { $null }
    $filaSyncSaliente = (Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM ErpSincronizaciones WHERE EmpresaID = $empresaId AND Direccion = 'SALIENTE'").Cantidad
    $pass = ($pullOk.StatusCode -eq 200) -and ($resumenQa.ok -eq $true) -and ($null -ne $productoPull) -and
            ($costoPull.CostoCompra -eq 2500.75) -and ($stockPull.StockActual -eq 42) -and ($filaSyncSaliente -ge 1)
    Add-Resultado -Id "TC11" -Descripcion "Saliente (POST /api/erp/pull) aplica el mapeo configurado y deja rastro en ErpSincronizaciones" `
        -Esperado "pull=200, ok=true, CostoCompra=2500.75 (de precio_compra), StockActual=42 (de existencias), >=1 fila SALIENTE" `
        -Obtenido "pull=$($pullOk.StatusCode), ok=$($resumenQa.ok), CostoCompra=$($costoPull.CostoCompra), StockActual=$($stockPull.StockActual), filasSaliente=$filaSyncSaliente" -Pass $pass

    # --- TC12: saliente con ApiKeySaliente incorrecta ----------------------------
    Invoke-Api -Method Put -Path "/api/admin/erp-conexiones/$empresaId" -Token $adminRealToken -Body @{
        UrlSalida = $mockUrl; ApiKeySaliente = "clave-incorrecta"
    } | Out-Null
    $pullMal = Invoke-Api -Method Post -Path "/api/erp/pull"
    $resumenQaMal = @($pullMal.Body) | Where-Object { $_.empresaID -eq $empresaId }
    $pass = ($pullMal.StatusCode -eq 200) -and ($resumenQaMal.ok -eq $false)
    Add-Resultado -Id "TC12" -Descripcion "Saliente con ApiKeySaliente incorrecta: la empresa queda Ok=false sin tirar abajo la corrida" `
        -Esperado "pull=200 (HTTP), resumen de la empresa QA con ok=false" `
        -Obtenido "pull=$($pullMal.StatusCode), ok=$($resumenQaMal.ok), error=$($resumenQaMal.error)" -Pass $pass
} finally {
    if ($mockProcess -and -not $mockProcess.HasExited) { Stop-Process -Id $mockProcess.Id -Force }
}

# ----------------------------------------------------------------------------
# 4. Limpieza final - nunca deja la Empresa QA ni sus productos en la base.
# ----------------------------------------------------------------------------
Write-Host "== 4. Limpieza final ==" -ForegroundColor Cyan
Remove-EmpresaQaErp

Write-Host "== 5. Resultado ==" -ForegroundColor Cyan
# #outStringWidthConsolaAngosta: ver la misma nota en Run-PruebasLogin.ps1.
($rows | Format-Table Caso, Descripcion, Resultado -AutoSize -Wrap | Out-String -Width 200) | Write-Host

# #whereObjectColapsaAEscalar: ver la misma nota en Run-PruebasLogin.ps1.
$failCount = @($rows | Where-Object { $_.Resultado -eq 'FAIL' }).Count
$total = @($rows).Count
Write-Host "$($total - $failCount) / $total casos OK" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })

Write-Host "== 6. Exportando a Excel: $OutputExcel ==" -ForegroundColor Cyan
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
