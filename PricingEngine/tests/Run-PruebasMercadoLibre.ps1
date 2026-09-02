<#
.SYNOPSIS
    Corre el banco de pruebas de la integración con MercadoLibre (ADR 0005-0011)
    contra una instancia real de PricingApi, y deja un Excel con lo esperado vs.
    lo obtenido.

.DESCRIPTION
    Cubre, de punta a punta, contra la API HTTP real (no solo SQL), usando un
    servidor que simula la API real de MercadoLibre (Mock-MercadoLibreServer.py):
      TC01  Configuración ML: guardarla y leerla de vuelta.
      TC02  OAuth iniciar: cuenta válida (302 al dominio de auth correcto) /
            cuenta inexistente (400).
      TC03  OAuth callback: sin code/state / con un state inventado (ambos
            terminan en la página de error, sin tocar la Cuenta ML).
      TC04  OAuth callback exitoso (actualiza AccessToken/RefreshToken/UserIDML)
            y que el mismo state no se pueda reusar una segunda vez.
      TC05  Procesar cola (1ra corrida): renueva un token vencido, procesa lo
            que no requiere aprobación, respeta el gate de aprobación (se
            salta lo pendiente) y maneja un error de ML sin frenar el resto -
            sin tocar ninguna fila PENDIENTE que ya existiera en la base.
      TC06  Aprobación de cola: listar lo pendiente, aprobar una fila,
            rechazar otra.
      TC07  Procesar cola (2da corrida): la fila aprobada se procesa; la
            rechazada nunca se reprocesa.
      TC08  Competidor vinculado manualmente: vincular dos con precio a mano,
            listar, actualizar el precio de uno, desvincular el otro, listar
            de nuevo.
      TC09  Sincronizar publicaciones: catálogo (precio/estado + competencia
            vía price_to_win); no catálogo NO toca el competidor vinculado a
            mano en TC08 (ya no hay refresco automático por API).
      TC10  Sincronizar ventas: agrega correctamente las unidades vendidas por
            ventana (7/15/30/60/90 días) desde /orders/search.

    Todo lo que este script crea (Empresa "Empresa QA ML", su Cuenta ML, sus
    productos/publicaciones `QA-ML-*` y su cola) se borra al final, haya
    fallado algo o no. La `ConfiguracionMercadoLibre` (fila ÚNICA y GLOBAL, no
    por empresa) se guarda tal cual estaba ANTES de tocarla y se restaura por
    SQL directo al final, porque la API nunca expone el ClientSecret real de
    vuelta (por diseño) y no hay otra forma de recuperarlo después de
    sobrescribirlo.

.EXAMPLE
    pwsh -File .\Run-PruebasMercadoLibre.ps1 -AdminUsuario ADMIN -AdminPassword "................"

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
    [int]$MockMlPort = 8091
)

# #psScriptRootEnParamMandatory: ver la misma nota en Run-PruebasLogin.ps1.
if ([string]::IsNullOrWhiteSpace($OutputExcel)) { $OutputExcel = "$PSScriptRoot\Resultados-MercadoLibre.xlsx" }

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
        return [PSCustomObject]@{ StatusCode = [int]$resp.StatusCode; Body = $parsed; Text = $resp.Content }
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
        return [PSCustomObject]@{ StatusCode = $statusCode; Body = $parsed; Text = $rawBody }
    }
}

# #redirectSinSeguirlo: Invoke-WebRequest -MaximumRedirection 0 es inestable en
# Windows PowerShell 5.1 frente a un 302 real (tira InvalidOperationException interno
# de "estado del objeto", no un WebException limpio) -- se usa HttpWebRequest crudo con
# AllowAutoRedirect=$false, que sí devuelve el 3xx como respuesta normal sin excepción.
function Invoke-ApiSinRedirigir {
    param([string]$Path)
    $request = [System.Net.HttpWebRequest]::Create("$ApiBaseUrl$Path")
    $request.Method = "GET"
    $request.AllowAutoRedirect = $false
    try {
        $response = $request.GetResponse()
        $statusCode = [int]$response.StatusCode
        $location = $response.Headers["Location"]
        $response.Close()
        return [PSCustomObject]@{ StatusCode = $statusCode; Location = $location }
    } catch {
        $statusCode = 0
        $location = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $location = $_.Exception.Response.Headers["Location"]
        }
        return [PSCustomObject]@{ StatusCode = $statusCode; Location = $location }
    }
}

function Get-EstadoOauthReal($cuentaId) {
    $resp = Invoke-ApiSinRedirigir -Path "/api/marketplace/ml/oauth/iniciar?cuentaMlId=$cuentaId"
    $match = [regex]::Match([string]$resp.Location, 'state=([a-f0-9]+)')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
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
# 1. Limpieza de una corrida anterior + fixture + snapshot de lo preexistente
# ----------------------------------------------------------------------------
Write-Host "== 1. Limpiando datos de una corrida anterior ==" -ForegroundColor Cyan
function Remove-DatosQaMl {
    $emp = Invoke-Sql "SELECT EmpresaID FROM Empresas WHERE RazonSocial = 'Empresa QA ML'"
    if ($emp) {
        $id = $emp.EmpresaID
        $pubs = Invoke-Sql "SELECT PublicacionID FROM PublicacionesML pub JOIN Productos p ON p.ProductoID = pub.ProductoID WHERE p.EmpresaID = $id"
        foreach ($pub in @($pubs)) {
            Invoke-Sql "DELETE FROM ColaEjecucionML WHERE PublicacionID = $($pub.PublicacionID)"
            Invoke-Sql "DELETE FROM CompetenciaSnapshot WHERE PublicacionID = $($pub.PublicacionID)"
            Invoke-Sql "DELETE FROM PublicacionCompetidoresManual WHERE PublicacionID = $($pub.PublicacionID)"
            Invoke-Sql "DELETE FROM MetricasVentasHist WHERE PublicacionID = $($pub.PublicacionID)"
        }
        Invoke-Sql "DELETE FROM PublicacionesML WHERE PublicacionID IN (SELECT PublicacionID FROM PublicacionesML pub JOIN Productos p ON p.ProductoID = pub.ProductoID WHERE p.EmpresaID = $id)"
        Invoke-Sql "DELETE FROM Productos WHERE EmpresaID = $id"
        Invoke-Sql "DELETE FROM CuentasML WHERE EmpresaID = $id"
        Invoke-Sql "DELETE FROM Empresas WHERE EmpresaID = $id"
    }
}
Remove-DatosQaMl

# #configMlEsGlobalYSinSecretoLegible: ConfiguracionMercadoLibre es una única fila
# (no por empresa) y la API nunca devuelve el ClientSecret real (solo un booleano
# "configurado"), así que restaurarlo después de la prueba SOLO es posible leyendo el
# valor real ahora, por SQL directo, y volviendo a escribirlo por SQL directo al final
# -- pasar por la API para "restaurar" perdería el secreto real para siempre.
$configMlOriginal = Invoke-Sql "SELECT TOP 1 ConfiguracionMercadoLibreID, ClientId, ClientSecret, ApiBaseUrl, SiteId, RedirectUri FROM ConfiguracionMercadoLibre ORDER BY ConfiguracionMercadoLibreID DESC"

# #colaGlobalSinScopePorEmpresa: ProcesarColaAsync y GetColaPendienteAprobacionAsync no
# filtran por empresa -- toman TODAS las filas PENDIENTE/pendientes-de-aprobación del
# sistema. Se guarda qué filas ya estaban así ANTES de esta suite para poder confirmar
# después que ninguna de ellas se tocó (podrían ser de otra suite o de uso real).
$colaPreexistentesPendientes = @(Invoke-Sql "SELECT ColaID FROM ColaEjecucionML WHERE EstadoEjecucion = 'PENDIENTE'" | Select-Object -ExpandProperty ColaID)
function Test-ColaPreexistentesIntactas {
    if ($colaPreexistentesPendientes.Count -eq 0) { return $true }
    $idsStr = $colaPreexistentesPendientes -join ','
    $cantidad = (Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM ColaEjecucionML WHERE ColaID IN ($idsStr) AND EstadoEjecucion = 'PENDIENTE'").Cantidad
    return $cantidad -eq $colaPreexistentesPendientes.Count
}

$loginAdminReal = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = $AdminUsuario; Password = $AdminPassword }
if ($loginAdminReal.StatusCode -ne 200) {
    throw "No se pudo loguear con -AdminUsuario/-AdminPassword (HTTP $($loginAdminReal.StatusCode)). Verificá las credenciales."
}
$adminRealToken = $loginAdminReal.Body.token
$adminUsuarioId = (Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = '$AdminUsuario'").UsuarioID

$empresaMl = Invoke-Api -Method Post -Path "/api/admin/empresas" -Token $adminRealToken -Body @{ RazonSocial = "Empresa QA ML"; CUIT = "30-00000005-1"; Activo = $true }
$empresaMlId = $empresaMl.Body.empresaID

$cuentaMl = Invoke-Api -Method Post -Path "/api/admin/cuentas-ml" -Token $adminRealToken -Body @{
    EmpresaID = $empresaMlId; UserIDML = ""; NicknameML = "QA ML Cuenta"; AccessToken = ""; RefreshToken = ""; Activo = $true
}
$cuentaMlId = $cuentaMl.Body.cuentaMLID

# ----------------------------------------------------------------------------
# 2. Mock de la API real de MercadoLibre
# ----------------------------------------------------------------------------
Write-Host "== 2. Levantando el mock de MercadoLibre ==" -ForegroundColor Cyan
$mockProcess = Start-Process -FilePath "python" -ArgumentList "`"$PSScriptRoot\Mock-MercadoLibreServer.py`" $MockMlPort" `
    -WindowStyle Hidden -PassThru

# #esperarMockListoNoSleepFijo: ver la misma nota en Run-PruebasLogin.ps1.
$mockListo = $false
for ($intento = 0; $intento -lt 20; $intento++) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("localhost", $MockMlPort)
        $tcp.Close()
        $mockListo = $true
        break
    } catch {
        Start-Sleep -Milliseconds 250
    }
}
if (-not $mockListo) { throw "El mock de MercadoLibre no llegó a escuchar en el puerto $MockMlPort a tiempo." }
$mockUrl = "http://localhost:$MockMlPort"

try {
    # --- TC01: Configuración ML ---------------------------------------------
    $putConfig = Invoke-Api -Method Put -Path "/api/admin/ml-configuracion" -Token $adminRealToken -Body @{
        ClientId = "qa-client-id-ml"; ClientSecret = "qa-client-secret-ml"; ApiBaseUrl = $mockUrl; SiteId = "MLA"; RedirectUri = "http://localhost:9999/oauth/callback"
    }
    $getConfig = Invoke-Api -Method Get -Path "/api/admin/ml-configuracion" -Token $adminRealToken
    $pass = ($putConfig.StatusCode -eq 204) -and ($getConfig.StatusCode -eq 200) -and ($getConfig.Body.clientId -eq "qa-client-id-ml") -and
            ($getConfig.Body.clientSecretConfigurado -eq $true) -and ($getConfig.Body.apiBaseUrl -eq $mockUrl) -and
            ($getConfig.Body.siteId -eq "MLA") -and ($getConfig.Body.redirectUri -eq "http://localhost:9999/oauth/callback")
    Add-Resultado -Id "TC01" -Descripcion "Guardar la Configuración ML y leerla de vuelta" `
        -Esperado "204, get refleja clientId/apiBaseUrl/siteId/redirectUri, secretConfigurado=true" `
        -Obtenido "$($putConfig.StatusCode), clientId=$($getConfig.Body.clientId), secretoConfigurado=$($getConfig.Body.clientSecretConfigurado)" -Pass $pass

    Write-Host "== 3. Corriendo casos de prueba ==" -ForegroundColor Cyan

    # --- TC02: OAuth iniciar: válido / cuenta inexistente -------------------
    $iniciarOk = Invoke-ApiSinRedirigir -Path "/api/marketplace/ml/oauth/iniciar?cuentaMlId=$cuentaMlId"
    $iniciarInexistente = Invoke-Api -Method Get -Path "/api/marketplace/ml/oauth/iniciar?cuentaMlId=999999999"
    $pass = ($iniciarOk.StatusCode -eq 302) -and ($iniciarOk.Location -match "^https://auth\.mercadolibre\.com\.ar/") -and ($iniciarInexistente.StatusCode -eq 400)
    Add-Resultado -Id "TC02" -Descripcion "OAuth iniciar: cuenta válida (302 al dominio de auth correcto) / cuenta inexistente (400)" `
        -Esperado "302 a https://auth.mercadolibre.com.ar/... / 400" `
        -Obtenido "$($iniciarOk.StatusCode) location=$($iniciarOk.Location) / $($iniciarInexistente.StatusCode)" -Pass $pass

    # --- TC03: OAuth callback: sin code/state / state inventado -------------
    $callbackSinDatos = Invoke-Api -Method Get -Path "/api/marketplace/ml/oauth/callback"
    $callbackStateInventado = Invoke-Api -Method Get -Path "/api/marketplace/ml/oauth/callback?code=cualquiera&state=state-que-no-existe"
    $cuentaAntes = Invoke-Sql "SELECT AccessToken FROM CuentasML WHERE CuentaMLID = $cuentaMlId"
    $accessTokenAntes = if ($cuentaAntes.AccessToken -is [DBNull]) { "" } else { $cuentaAntes.AccessToken }
    $pass = ($callbackSinDatos.StatusCode -eq 200) -and ($callbackSinDatos.Text -match "No se pudo conectar") -and
            ($callbackStateInventado.StatusCode -eq 200) -and ($callbackStateInventado.Text -match "No se pudo conectar") -and
            [string]::IsNullOrEmpty($accessTokenAntes)
    Add-Resultado -Id "TC03" -Descripcion "OAuth callback: sin code/state / con un state inventado (ambos terminan en error, sin tocar la Cuenta ML)" `
        -Esperado "200 con 'No se pudo conectar' en ambos, AccessToken sigue vacío" `
        -Obtenido "sinDatos=$($callbackSinDatos.StatusCode) stateInventado=$($callbackStateInventado.StatusCode), accessTokenAntes='$accessTokenAntes'" -Pass $pass

    # --- TC04: OAuth callback exitoso + reuso del mismo state ---------------
    $stateValido = Get-EstadoOauthReal $cuentaMlId
    $callbackOk = Invoke-Api -Method Get -Path "/api/marketplace/ml/oauth/callback?code=cualquier-codigo&state=$stateValido"
    $cuentaDespues = Invoke-Sql "SELECT AccessToken, RefreshToken, UserIDML FROM CuentasML WHERE CuentaMLID = $cuentaMlId"
    $callbackReusado = Invoke-Api -Method Get -Path "/api/marketplace/ml/oauth/callback?code=otro-codigo&state=$stateValido"
    $pass = ($null -ne $stateValido) -and ($callbackOk.StatusCode -eq 200) -and ($callbackOk.Text -match "quedó vinculada correctamente") -and
            ($cuentaDespues.AccessToken -eq "MOCK-ACCESS-OAUTH") -and ($cuentaDespues.RefreshToken -eq "MOCK-REFRESH-OAUTH") -and ("$($cuentaDespues.UserIDML)" -eq "999888777") -and
            ($callbackReusado.StatusCode -eq 200) -and ($callbackReusado.Text -match "inválido o expirado")
    Add-Resultado -Id "TC04" -Descripcion "OAuth callback exitoso actualiza la Cuenta ML; el mismo state no se puede reusar" `
        -Esperado "éxito con AccessToken/RefreshToken/UserIDML del mock; reuso da 'inválido o expirado'" `
        -Obtenido "ok=$($callbackOk.StatusCode) accessToken=$($cuentaDespues.AccessToken) userIdMl=$($cuentaDespues.UserIDML), reusado=$($callbackReusado.StatusCode)" -Pass $pass

    # --- Fixture de productos/publicaciones/cola (después del OAuth, para no interferir con TC02-04) ---
    $prodCatalogo = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaMlId; SKU = "QA-ML-CATALOGO"; Titulo = "Producto QA ML Catálogo"; Activo = $true }
    $prodNoCat = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaMlId; SKU = "QA-ML-NOCAT"; Titulo = "Producto QA ML No Catálogo"; Activo = $true }
    $prodAprob1 = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaMlId; SKU = "QA-ML-APROB1"; Titulo = "Producto QA ML Aprobación 1"; Activo = $true }
    $prodAprob2 = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaMlId; SKU = "QA-ML-APROB2"; Titulo = "Producto QA ML Aprobación 2"; Activo = $true }
    $prodRechaza = Invoke-Api -Method Post -Path "/api/admin/productos" -Token $adminRealToken -Body @{ EmpresaID = $empresaMlId; SKU = "QA-ML-RECHAZA"; Titulo = "Producto QA ML Rechaza"; Activo = $true }

    function New-PublicacionQa($productoId, $meliItemId, $esCatalogo, $precioActual) {
        $resp = Invoke-Api -Method Post -Path "/api/admin/publicaciones-ml" -Token $adminRealToken -Body @{
            ProductoID = $productoId; CuentaMLID = $cuentaMlId; MeliItemID = $meliItemId; TipoPublicacion = "gold_special"
            ComisionMLPorc = 10; Estado = "active"; EsCatalogo = $esCatalogo; PrecioActual = $precioActual
            PrecioMinimoPermitido = 1; PrecioMaximoPermitido = 999999
        }
        return $resp.Body.publicacionID
    }
    $pubCatalogoId = New-PublicacionQa $prodCatalogo.Body.productoID "MLA-QA-ML-CATALOGO" $true 10000
    $pubNoCatId = New-PublicacionQa $prodNoCat.Body.productoID "MLA-QA-ML-NOCAT" $false 5000
    $pubAprob1Id = New-PublicacionQa $prodAprob1.Body.productoID "MLA-QA-ML-APROBACION-1" $false 2000
    $pubAprob2Id = New-PublicacionQa $prodAprob2.Body.productoID "MLA-QA-ML-APROBACION-2" $false 3000
    $pubRechazaId = New-PublicacionQa $prodRechaza.Body.productoID "MLA-QA-ML-RECHAZA" $false 999

    $colaNoAprobId = (Invoke-Sql "INSERT INTO ColaEjecucionML (PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida, RequiereAprobacion) VALUES ($pubCatalogoId, 'MLA-QA-ML-CATALOGO', 10500, 'AUMENTAR_PRECIO', 0); SELECT SCOPE_IDENTITY() AS ColaID").ColaID
    $colaAprob1Id = (Invoke-Sql "INSERT INTO ColaEjecucionML (PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida, RequiereAprobacion) VALUES ($pubAprob1Id, 'MLA-QA-ML-APROBACION-1', 2100, 'AUMENTAR_PRECIO', 1); SELECT SCOPE_IDENTITY() AS ColaID").ColaID
    $colaAprob2Id = (Invoke-Sql "INSERT INTO ColaEjecucionML (PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida, RequiereAprobacion) VALUES ($pubAprob2Id, 'MLA-QA-ML-APROBACION-2', 3100, 'AUMENTAR_PRECIO', 1); SELECT SCOPE_IDENTITY() AS ColaID").ColaID
    $colaRechazaId = (Invoke-Sql "INSERT INTO ColaEjecucionML (PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida, RequiereAprobacion) VALUES ($pubRechazaId, 'MLA-QA-ML-RECHAZA', 1050, 'AUMENTAR_PRECIO', 0); SELECT SCOPE_IDENTITY() AS ColaID").ColaID

    # --- TC05: Procesar cola (1ra corrida) -----------------------------------
    Invoke-Sql "UPDATE CuentasML SET FechaVencimientoToken = DATEADD(HOUR, -1, SYSDATETIME()) WHERE CuentaMLID = $cuentaMlId" | Out-Null
    $procesarCola1 = Invoke-Api -Method Post -Path "/api/marketplace/ml/procesar-cola" -Token $adminRealToken
    $cuentaTrasRefresh = Invoke-Sql "SELECT AccessToken, FechaVencimientoToken FROM CuentasML WHERE CuentaMLID = $cuentaMlId"
    $colaNoAprobTras = (Invoke-Sql "SELECT EstadoEjecucion FROM ColaEjecucionML WHERE ColaID = $colaNoAprobId").EstadoEjecucion
    $colaAprob1Tras = (Invoke-Sql "SELECT EstadoEjecucion FROM ColaEjecucionML WHERE ColaID = $colaAprob1Id").EstadoEjecucion
    $colaAprob2Tras = (Invoke-Sql "SELECT EstadoEjecucion FROM ColaEjecucionML WHERE ColaID = $colaAprob2Id").EstadoEjecucion
    $colaRechazaTras = Invoke-Sql "SELECT EstadoEjecucion, MensajeError FROM ColaEjecucionML WHERE ColaID = $colaRechazaId"
    $pubCatalogoTrasCola = (Invoke-Sql "SELECT PrecioActual FROM PublicacionesML WHERE PublicacionID = $pubCatalogoId").PrecioActual
    $preexistentesOk1 = Test-ColaPreexistentesIntactas
    $pass = ($procesarCola1.StatusCode -eq 200) -and ($cuentaTrasRefresh.AccessToken -eq "MOCK-ACCESS-REFRESHED") -and ($cuentaTrasRefresh.FechaVencimientoToken -gt (Get-Date)) -and
            ($colaNoAprobTras -eq "PROCESADO") -and ($pubCatalogoTrasCola -eq 10500) -and
            ($colaAprob1Tras -eq "PENDIENTE") -and ($colaAprob2Tras -eq "PENDIENTE") -and
            ($colaRechazaTras.EstadoEjecucion -eq "ERROR") -and ($colaRechazaTras.MensajeError -match "400") -and $preexistentesOk1
    Add-Resultado -Id "TC05" -Descripcion "Procesar cola (1ra corrida): renueva el token vencido, procesa lo que no requiere aprobación, se salta lo pendiente de aprobación, y un error de ML no frena el resto" `
        -Esperado "token renovado; fila sin aprobación=PROCESADO (precio 10500); filas con aprobación=PENDIENTE; fila que ML rechaza=ERROR; filas preexistentes intactas" `
        -Obtenido "accessToken=$($cuentaTrasRefresh.AccessToken), noAprob=$colaNoAprobTras (precio=$pubCatalogoTrasCola), aprob1=$colaAprob1Tras, aprob2=$colaAprob2Tras, rechaza=$($colaRechazaTras.EstadoEjecucion), preexistentesIntactas=$preexistentesOk1" -Pass $pass

    # --- TC06: Aprobación de cola --------------------------------------------
    $pendientesAprobacion = Invoke-Api -Method Get -Path "/api/marketplace/ml/cola-aprobacion" -Token $adminRealToken
    $misPendientes = @($pendientesAprobacion.Body) | Where-Object { $_.colaID -eq $colaAprob1Id -or $_.colaID -eq $colaAprob2Id }
    $aprobar = Invoke-Api -Method Post -Path "/api/marketplace/ml/cola-aprobacion/$colaAprob1Id/aprobar" -Token $adminRealToken
    $rechazar = Invoke-Api -Method Post -Path "/api/marketplace/ml/cola-aprobacion/$colaAprob2Id/rechazar" -Token $adminRealToken
    $filaAprob1 = Invoke-Sql "SELECT Aprobado, UsuarioAprobacionID FROM ColaEjecucionML WHERE ColaID = $colaAprob1Id"
    $filaAprob2 = Invoke-Sql "SELECT Aprobado FROM ColaEjecucionML WHERE ColaID = $colaAprob2Id"
    $pass = ($pendientesAprobacion.StatusCode -eq 200) -and (@($misPendientes).Count -eq 2) -and
            ($aprobar.StatusCode -eq 204) -and ($rechazar.StatusCode -eq 204) -and
            ($filaAprob1.Aprobado -eq $true) -and ($filaAprob1.UsuarioAprobacionID -eq $adminUsuarioId) -and ($filaAprob2.Aprobado -eq $false)
    Add-Resultado -Id "TC06" -Descripcion "Aprobación de cola: listar lo pendiente, aprobar una fila, rechazar otra" `
        -Esperado "2 filas propias en la lista, aprobar=204 (Aprobado=1, UsuarioAprobacionID correcto), rechazar=204 (Aprobado=0)" `
        -Obtenido "propias=$(@($misPendientes).Count), aprobar=$($aprobar.StatusCode) Aprobado=$($filaAprob1.Aprobado), rechazar=$($rechazar.StatusCode) Aprobado=$($filaAprob2.Aprobado)" -Pass $pass

    # --- TC07: Procesar cola (2da corrida) ------------------------------------
    $procesarCola2 = Invoke-Api -Method Post -Path "/api/marketplace/ml/procesar-cola" -Token $adminRealToken
    $colaAprob1TrasProcesar = (Invoke-Sql "SELECT EstadoEjecucion FROM ColaEjecucionML WHERE ColaID = $colaAprob1Id").EstadoEjecucion
    $colaAprob2TrasProcesar = (Invoke-Sql "SELECT EstadoEjecucion FROM ColaEjecucionML WHERE ColaID = $colaAprob2Id").EstadoEjecucion
    $pubAprob1TrasCola = (Invoke-Sql "SELECT PrecioActual FROM PublicacionesML WHERE PublicacionID = $pubAprob1Id").PrecioActual
    $preexistentesOk2 = Test-ColaPreexistentesIntactas
    $pass = ($procesarCola2.StatusCode -eq 200) -and ($colaAprob1TrasProcesar -eq "PROCESADO") -and ($pubAprob1TrasCola -eq 2100) -and
            ($colaAprob2TrasProcesar -eq "PENDIENTE") -and $preexistentesOk2
    Add-Resultado -Id "TC07" -Descripcion "Procesar cola (2da corrida): la fila aprobada se procesa; la rechazada nunca se reprocesa" `
        -Esperado "aprobada=PROCESADO (precio 2100), rechazada sigue PENDIENTE para siempre, filas preexistentes intactas" `
        -Obtenido "aprob1=$colaAprob1TrasProcesar (precio=$pubAprob1TrasCola), aprob2=$colaAprob2TrasProcesar, preexistentesIntactas=$preexistentesOk2" -Pass $pass

    # --- TC08: Competidor vinculado manualmente -------------------------------
    # MercadoLibre bloquea tanto la búsqueda pública por texto (GET /sites/{site}/search)
    # como leer una publicación ajena por ID (GET /items/{id}) -- 403 para apps de
    # terceros en ambos casos, con o sin token. No hay forma de traer el precio del
    # competidor por API en ningún momento: se carga a mano al vincular (con moneda,
    # FK a Monedas) y se puede reescribir después con "Actualizar precio" (ver
    # VincularCompetidorAsync / ActualizarPrecioCompetidorAsync en
    # MercadoLibreSyncService.cs). Se usa una Moneda ya existente en la base --esta
    # suite no crea monedas propias, es una tabla de referencia compartida-- y si no
    # hay ninguna cargada el test no puede vincular nada, así que se corta acá con un
    # mensaje claro en vez de fallar más abajo con un error de FK poco entendible.
    $monedaQaId = (Invoke-Sql "SELECT TOP 1 MonedaID FROM Monedas WHERE Activa = 1 ORDER BY MonedaID").MonedaID
    if (-not $monedaQaId) { throw "No hay ninguna Moneda activa en la base -- TC08 necesita al menos una para vincular un competidor." }
    $vincular1 = Invoke-Api -Method Post -Path "/api/marketplace/ml/publicaciones/$pubNoCatId/competidores" -Token $adminRealToken -Body @{ CompetidorItemID = "MLA-QA-ML-COMPETIDOR-MANUAL"; CompetidorTitulo = "Competidor Manual QA"; MonedaID = $monedaQaId; Precio = 4800 }
    $vincular2 = Invoke-Api -Method Post -Path "/api/marketplace/ml/publicaciones/$pubNoCatId/competidores" -Token $adminRealToken -Body @{ CompetidorItemID = "MLA-QA-ML-COMPETIDOR-DESVINCULAR"; CompetidorTitulo = "Se va a desvincular"; MonedaID = $monedaQaId; Precio = 100 }
    $listar1 = Invoke-Api -Method Get -Path "/api/marketplace/ml/publicaciones/$pubNoCatId/competidores" -Token $adminRealToken
    $vinculo1Listado = @($listar1.Body) | Where-Object { $_.competidorItemID -eq "MLA-QA-ML-COMPETIDOR-MANUAL" }
    $actualizarPrecio = Invoke-Api -Method Put -Path "/api/marketplace/ml/publicaciones/$pubNoCatId/competidores/$($vincular1.Body.vinculoID)/precio" -Token $adminRealToken -Body @{ Precio = 4750 }
    $desvincular = Invoke-Api -Method Delete -Path "/api/marketplace/ml/publicaciones/$pubNoCatId/competidores/$($vincular2.Body.vinculoID)" -Token $adminRealToken
    $listar2 = Invoke-Api -Method Get -Path "/api/marketplace/ml/publicaciones/$pubNoCatId/competidores" -Token $adminRealToken
    $vinculo1Final = @($listar2.Body) | Where-Object { $_.competidorItemID -eq "MLA-QA-ML-COMPETIDOR-MANUAL" }
    $pass = ($vincular1.StatusCode -eq 201) -and ($vincular2.StatusCode -eq 201) -and
            ($listar1.StatusCode -eq 200) -and (@($listar1.Body).Count -eq 2) -and ($vinculo1Listado.ultimoPrecio -eq 4800) -and
            ($actualizarPrecio.StatusCode -eq 204) -and
            ($desvincular.StatusCode -eq 204) -and
            ($listar2.StatusCode -eq 200) -and (@($listar2.Body).Count -eq 1) -and ($vinculo1Final.ultimoPrecio -eq 4750)
    Add-Resultado -Id "TC08" -Descripcion "Competidor vinculado manualmente: vincular dos con precio, listar, actualizar precio, desvincular uno, listar de nuevo" `
        -Esperado "vincular x2=201 (precio inicial 4800); listar=2; actualizar precio=204; desvincular=204; listar=1 con precio 4750" `
        -Obtenido "precioInicial=$($vinculo1Listado.ultimoPrecio), actualizarPrecio=$($actualizarPrecio.StatusCode), listar1=$(@($listar1.Body).Count), desvincular=$($desvincular.StatusCode), listar2=$(@($listar2.Body).Count), precioFinal=$($vinculo1Final.ultimoPrecio)" -Pass $pass

    # --- TC09: Sincronizar publicaciones ---------------------------------------
    # No catálogo ya no intenta refrescar el competidor vinculado a mano (ver TC08):
    # MercadoLibre bloquea leer una publicación ajena por ID, así que el intento
    # anterior fallaba en silencio para cualquier competidor real. El snapshot de
    # no-catálogo que queda es el que TC08 dejó a mano (precio 4750), sin tocar.
    $sincronizarPub = Invoke-Api -Method Post -Path "/api/marketplace/ml/sincronizar-publicaciones" -Token $adminRealToken
    $pubCatalogoFinal = (Invoke-Sql "SELECT PrecioActual FROM PublicacionesML WHERE PublicacionID = $pubCatalogoId").PrecioActual
    $snapshotCatalogo = Invoke-Sql "SELECT TOP 1 CompetidorItemID, PrecioCompetidor FROM CompetenciaSnapshot WHERE PublicacionID = $pubCatalogoId ORDER BY SnapshotID DESC"
    $pubNoCatFinal = (Invoke-Sql "SELECT PrecioActual FROM PublicacionesML WHERE PublicacionID = $pubNoCatId").PrecioActual
    $snapshotNoCat = Invoke-Sql "SELECT TOP 1 CompetidorItemID, PrecioCompetidor FROM CompetenciaSnapshot WHERE PublicacionID = $pubNoCatId ORDER BY SnapshotID DESC"
    $pass = ($sincronizarPub.StatusCode -eq 200) -and ($sincronizarPub.Body.procesados -ge 2) -and
            ($pubCatalogoFinal -eq 10500) -and ($snapshotCatalogo.CompetidorItemID -eq "MLA-QA-ML-COMPETIDOR-CATALOGO") -and ($snapshotCatalogo.PrecioCompetidor -eq 9800) -and
            ($pubNoCatFinal -eq 5200) -and ($snapshotNoCat.CompetidorItemID -eq "MLA-QA-ML-COMPETIDOR-MANUAL") -and ($snapshotNoCat.PrecioCompetidor -eq 4750)
    Add-Resultado -Id "TC09" -Descripcion "Sincronizar publicaciones: catálogo (precio/estado + competencia por price_to_win); no catálogo NO toca el competidor vinculado a mano" `
        -Esperado "catálogo: precio=10500, competidor=MLA-QA-ML-COMPETIDOR-CATALOGO a 9800; no catálogo: precio=5200, snapshot sin cambios (4750, el de TC08)" `
        -Obtenido "catálogo: precio=$pubCatalogoFinal, competidor=$($snapshotCatalogo.CompetidorItemID) a $($snapshotCatalogo.PrecioCompetidor); no catálogo: precio=$pubNoCatFinal, competidor=$($snapshotNoCat.CompetidorItemID) a $($snapshotNoCat.PrecioCompetidor)" -Pass $pass

    # --- TC10: Sincronizar ventas -----------------------------------------------
    $sincronizarVentas = Invoke-Api -Method Post -Path "/api/marketplace/ml/sincronizar-ventas" -Token $adminRealToken
    $metricas = Invoke-Sql "SELECT VentasHoy, Ventas7D, Ventas15D, Ventas30D, Ventas60D, Ventas90D FROM MetricasVentasHist WHERE PublicacionID = $pubCatalogoId"
    $pass = ($sincronizarVentas.StatusCode -eq 200) -and ($sincronizarVentas.Body.publicacionesActualizadas -ge 1) -and
            ($metricas.VentasHoy -eq 2) -and ($metricas.Ventas7D -eq 5) -and ($metricas.Ventas15D -eq 10) -and
            ($metricas.Ventas30D -eq 12) -and ($metricas.Ventas60D -eq 16) -and ($metricas.Ventas90D -eq 22)
    Add-Resultado -Id "TC10" -Descripcion "Sincronizar ventas agrega correctamente las unidades vendidas por ventana desde /orders/search" `
        -Esperado "hoy=2, 7D=5, 15D=10, 30D=12, 60D=16, 90D=22" `
        -Obtenido "hoy=$($metricas.VentasHoy), 7D=$($metricas.Ventas7D), 15D=$($metricas.Ventas15D), 30D=$($metricas.Ventas30D), 60D=$($metricas.Ventas60D), 90D=$($metricas.Ventas90D)" -Pass $pass
} finally {
    if ($mockProcess -and -not $mockProcess.HasExited) { Stop-Process -Id $mockProcess.Id -Force }

    # Restaura ConfiguracionMercadoLibre tal cual estaba (ver nota arriba de TC01).
    if ($configMlOriginal) {
        Invoke-Sql "UPDATE ConfiguracionMercadoLibre SET ClientId = $(if ($configMlOriginal.ClientId -is [DBNull]) { 'NULL' } else { "'$($configMlOriginal.ClientId)'" }), ClientSecret = $(if ($configMlOriginal.ClientSecret -is [DBNull]) { 'NULL' } else { "'$($configMlOriginal.ClientSecret)'" }), ApiBaseUrl = $(if ($configMlOriginal.ApiBaseUrl -is [DBNull]) { 'NULL' } else { "'$($configMlOriginal.ApiBaseUrl)'" }), SiteId = $(if ($configMlOriginal.SiteId -is [DBNull]) { 'NULL' } else { "'$($configMlOriginal.SiteId)'" }), RedirectUri = $(if ($configMlOriginal.RedirectUri -is [DBNull]) { 'NULL' } else { "'$($configMlOriginal.RedirectUri)'" }) WHERE ConfiguracionMercadoLibreID = $($configMlOriginal.ConfiguracionMercadoLibreID)" | Out-Null
        Invoke-Sql "DELETE FROM ConfiguracionMercadoLibre WHERE ConfiguracionMercadoLibreID <> $($configMlOriginal.ConfiguracionMercadoLibreID)" | Out-Null
    } else {
        Invoke-Sql "DELETE FROM ConfiguracionMercadoLibre" | Out-Null
    }
}

# ----------------------------------------------------------------------------
# 4. Limpieza final
# ----------------------------------------------------------------------------
Write-Host "== 4. Limpieza final ==" -ForegroundColor Cyan
Remove-DatosQaMl

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
