<#
.SYNOPSIS
    Corre el banco de pruebas de la Integración Email (ADR 0017), más allá del
    camino de recuperación de contraseña que ya cubre TC06 de
    Run-PruebasLogin.ps1: la Configuración de Email en sí y el botón "Probar
    conexión". Deja un Excel con lo esperado vs. lo obtenido.

.DESCRIPTION
    Cubre, de punta a punta, contra la API HTTP real (no solo SQL), usando el
    mismo mock SMTP que ya usa Run-PruebasLogin.ps1 (Mock-SmtpServer.py):
      TC01  Guardar la Configuración de Email completa y leerla de vuelta.
      TC02  El SmtpPassword se preserva si un PUT posterior no manda uno
            nuevo (mismo patrón que ClientSecret de MercadoLibre).
      TC03  Probar conexión con el destinatario vacío (400).
      TC04  Probar conexión sin servidor SMTP configurado (400, mensaje
            específico).
      TC05  Probar conexión exitosa contra el mock SMTP (200, y el mock
            recibe el email real).
      TC06  Probar conexión con un SMTP mal configurado - host/puerto que
            nadie escucha (400 con el error real, a diferencia de "olvidé mi
            contraseña" que lo traga a propósito para no revelar cuentas).

    La `ConfiguracionEmail` (fila ÚNICA y GLOBAL, no por empresa) se guarda
    tal cual estaba ANTES de tocarla y se restaura por SQL directo al final,
    porque la API nunca expone el SmtpPassword real de vuelta (por diseño) y
    no hay otra forma de recuperarlo después de sobrescribirlo.

.EXAMPLE
    pwsh -File .\Run-PruebasEmail.ps1 -AdminUsuario ADMIN -AdminPassword "................"

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
    [int]$MockSmtpPort = 1025
)

# #psScriptRootEnParamMandatory: ver la misma nota en Run-PruebasLogin.ps1.
if ([string]::IsNullOrWhiteSpace($OutputExcel)) { $OutputExcel = "$PSScriptRoot\Resultados-Email.xlsx" }

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
# 1. Snapshot real de ConfiguracionEmail (para restaurar por SQL al final) +
#    login como el ADMIN real
# ----------------------------------------------------------------------------
Write-Host "== 1. Guardando la Configuración de Email real (para restaurarla al final) ==" -ForegroundColor Cyan
# #configEmailEsGlobalYSinSecretoLegible: ver la misma nota en
# Run-PruebasMercadoLibre.ps1 para ConfiguracionMercadoLibre -- misma fila única y
# global, mismo problema (la API nunca devuelve el SmtpPassword real).
$configEmailOriginal = Invoke-Sql "SELECT TOP 1 ConfiguracionEmailID, SmtpHost, SmtpPort, SmtpUsuario, SmtpPassword, UsarSsl, EmailDesde, NombreDesde, FrontendBaseUrl FROM ConfiguracionEmail ORDER BY ConfiguracionEmailID DESC"

$loginAdminReal = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = $AdminUsuario; Password = $AdminPassword }
if ($loginAdminReal.StatusCode -ne 200) {
    throw "No se pudo loguear con -AdminUsuario/-AdminPassword (HTTP $($loginAdminReal.StatusCode)). Verificá las credenciales."
}
$adminRealToken = $loginAdminReal.Body.token

# ----------------------------------------------------------------------------
# 2. Mock SMTP (mismo fixture que usa Run-PruebasLogin.ps1)
# ----------------------------------------------------------------------------
Write-Host "== 2. Levantando el mock SMTP ==" -ForegroundColor Cyan
$mockLog = "$PSScriptRoot\mock-smtp-email.log"
if (Test-Path $mockLog) { Remove-Item $mockLog -Force }
$mockProcess = Start-Process -FilePath "python" -ArgumentList "`"$PSScriptRoot\Mock-SmtpServer.py`" $MockSmtpPort" `
    -RedirectStandardOutput $mockLog -WindowStyle Hidden -PassThru

# #esperarMockListoNoSleepFijo: ver la misma nota en Run-PruebasLogin.ps1.
$mockListo = $false
for ($intento = 0; $intento -lt 20; $intento++) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("localhost", $MockSmtpPort)
        $tcp.Close()
        $mockListo = $true
        break
    } catch {
        Start-Sleep -Milliseconds 250
    }
}
if (-not $mockListo) { throw "El mock SMTP no llegó a escuchar en el puerto $MockSmtpPort a tiempo." }

$configCompleta = @{
    SmtpHost = "localhost"; SmtpPort = $MockSmtpPort; SmtpUsuario = ""; SmtpPassword = "qa-smtp-password-1"
    UsarSsl = $false; EmailDesde = "qa-email-suite@example.com"; NombreDesde = "QA Email Suite"
    FrontendBaseUrl = "http://localhost:9999"
}

try {
    Write-Host "== 3. Corriendo casos de prueba ==" -ForegroundColor Cyan

    # --- TC01: guardar Configuración de Email completa + leerla -------------
    $putConfig = Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body $configCompleta
    $getConfig = Invoke-Api -Method Get -Path "/api/admin/email-configuracion" -Token $adminRealToken
    $pass = ($putConfig.StatusCode -eq 204) -and ($getConfig.StatusCode -eq 200) -and
            ($getConfig.Body.smtpHost -eq "localhost") -and ($getConfig.Body.smtpPort -eq $MockSmtpPort) -and
            ($getConfig.Body.smtpPasswordConfigurada -eq $true) -and ($getConfig.Body.usarSsl -eq $false) -and
            ($getConfig.Body.emailDesde -eq "qa-email-suite@example.com") -and ($getConfig.Body.frontendBaseUrl -eq "http://localhost:9999")
    Add-Resultado -Id "TC01" -Descripcion "Guardar la Configuración de Email completa y leerla de vuelta" `
        -Esperado "204, get refleja host/puerto/ssl/desde/frontendUrl, passwordConfigurada=true" `
        -Obtenido "$($putConfig.StatusCode), host=$($getConfig.Body.smtpHost) puerto=$($getConfig.Body.smtpPort) passwordConfigurada=$($getConfig.Body.smtpPasswordConfigurada)" -Pass $pass

    # --- TC02: el password se preserva si el PUT no manda uno nuevo ---------
    $putSinPassword = Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body @{
        SmtpHost = "localhost"; SmtpPort = $MockSmtpPort; SmtpUsuario = ""; UsarSsl = $false
        EmailDesde = "qa-email-suite@example.com"; NombreDesde = "QA Email Suite"; FrontendBaseUrl = "http://localhost:9999"
    }
    $getTrasSinPassword = Invoke-Api -Method Get -Path "/api/admin/email-configuracion" -Token $adminRealToken
    $passwordRealTrasSinPassword = (Invoke-Sql "SELECT SmtpPassword FROM ConfiguracionEmail ORDER BY ConfiguracionEmailID DESC").SmtpPassword
    $pass = ($putSinPassword.StatusCode -eq 204) -and ($getTrasSinPassword.Body.smtpPasswordConfigurada -eq $true) -and ($passwordRealTrasSinPassword -eq "qa-smtp-password-1")
    Add-Resultado -Id "TC02" -Descripcion "El SmtpPassword se preserva si un PUT posterior no manda uno nuevo" `
        -Esperado "204, passwordConfigurada sigue true, el valor real en la base no cambió" `
        -Obtenido "$($putSinPassword.StatusCode), passwordConfigurada=$($getTrasSinPassword.Body.smtpPasswordConfigurada), valorReal=$(if($passwordRealTrasSinPassword -eq 'qa-smtp-password-1'){'sin cambios'}else{'CAMBIÓ'})" -Pass $pass

    # --- TC03: probar conexión con destinatario vacío ------------------------
    $probarSinDestinatario = Invoke-Api -Method Post -Path "/api/admin/email-configuracion/probar" -Token $adminRealToken -Body @{ Destinatario = "" }
    $pass = ($probarSinDestinatario.StatusCode -eq 400) -and ($probarSinDestinatario.Body.message -match "destinatario")
    Add-Resultado -Id "TC03" -Descripcion "Probar conexión con el destinatario vacío" `
        -Esperado "400 con mensaje sobre el destinatario" -Obtenido "$($probarSinDestinatario.StatusCode) msg=$($probarSinDestinatario.Body.message)" -Pass $pass

    # --- TC04: probar conexión sin servidor SMTP configurado -----------------
    Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body @{
        SmtpHost = ""; SmtpPort = $MockSmtpPort; SmtpUsuario = ""; UsarSsl = $false
        EmailDesde = "qa-email-suite@example.com"; NombreDesde = "QA Email Suite"; FrontendBaseUrl = "http://localhost:9999"
    } | Out-Null
    $probarSinHost = Invoke-Api -Method Post -Path "/api/admin/email-configuracion/probar" -Token $adminRealToken -Body @{ Destinatario = "qa-destino@example.com" }
    $pass = ($probarSinHost.StatusCode -eq 400) -and ($probarSinHost.Body.message -match "Falta configurar el servidor SMTP")
    Add-Resultado -Id "TC04" -Descripcion "Probar conexión sin servidor SMTP configurado" `
        -Esperado "400 con 'Falta configurar el servidor SMTP'" -Obtenido "$($probarSinHost.StatusCode) msg=$($probarSinHost.Body.message)" -Pass $pass

    # --- TC05: probar conexión exitosa contra el mock -------------------------
    Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body $configCompleta | Out-Null
    $probarOk = Invoke-Api -Method Post -Path "/api/admin/email-configuracion/probar" -Token $adminRealToken -Body @{ Destinatario = "qa-destino@example.com" }

    # #esperarMockListoNoSleepFijo: idem -- el envío es asincrónico del lado de la API.
    $mensajeLlego = $false
    for ($intento = 0; $intento -lt 20; $intento++) {
        $logContenido = if (Test-Path $mockLog) { Get-Content $mockLog -Raw } else { "" }
        if ($logContenido -match "MENSAJE RECIBIDO") { $mensajeLlego = $true; break }
        Start-Sleep -Milliseconds 250
    }
    $pass = ($probarOk.StatusCode -eq 200) -and $mensajeLlego
    Add-Resultado -Id "TC05" -Descripcion "Probar conexión exitosa contra el mock SMTP" `
        -Esperado "200, el mock recibe el email real" -Obtenido "$($probarOk.StatusCode), mensajeLlegoAlMock=$mensajeLlego" -Pass $pass

    # --- TC06: probar conexión con un SMTP que nadie escucha ------------------
    Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body @{
        SmtpHost = "localhost"; SmtpPort = 19; SmtpUsuario = ""; UsarSsl = $false
        EmailDesde = "qa-email-suite@example.com"; NombreDesde = "QA Email Suite"; FrontendBaseUrl = "http://localhost:9999"
    } | Out-Null
    $probarPuertoMalo = Invoke-Api -Method Post -Path "/api/admin/email-configuracion/probar" -Token $adminRealToken -Body @{ Destinatario = "qa-destino@example.com" }
    $pass = ($probarPuertoMalo.StatusCode -eq 400) -and (-not [string]::IsNullOrWhiteSpace($probarPuertoMalo.Body.message)) -and ($probarPuertoMalo.Body.message -notmatch "Falta configurar")
    Add-Resultado -Id "TC06" -Descripcion "Probar conexión con un SMTP mal configurado (host/puerto que nadie escucha) devuelve el error real" `
        -Esperado "400 con el error real de conexión (no el mensaje genérico de 'falta configurar')" `
        -Obtenido "$($probarPuertoMalo.StatusCode) msg=$($probarPuertoMalo.Body.message)" -Pass $pass
} finally {
    if ($mockProcess -and -not $mockProcess.HasExited) { Stop-Process -Id $mockProcess.Id -Force }
    if (Test-Path $mockLog) { Remove-Item $mockLog -Force }

    # Restaura ConfiguracionEmail tal cual estaba (ver nota de TC01 arriba) -- por
    # SQL directo, nunca por API, porque el SmtpPassword real no se puede releer.
    if ($configEmailOriginal) {
        $hostSql = if ($configEmailOriginal.SmtpHost -is [DBNull]) { 'NULL' } else { "'$($configEmailOriginal.SmtpHost)'" }
        $portSql = if ($configEmailOriginal.SmtpPort -is [DBNull]) { 'NULL' } else { "$($configEmailOriginal.SmtpPort)" }
        $usuarioSql = if ($configEmailOriginal.SmtpUsuario -is [DBNull]) { 'NULL' } else { "'$($configEmailOriginal.SmtpUsuario)'" }
        $passwordSql = if ($configEmailOriginal.SmtpPassword -is [DBNull]) { 'NULL' } else { "'$($configEmailOriginal.SmtpPassword)'" }
        $sslSql = if ($configEmailOriginal.UsarSsl) { '1' } else { '0' }
        $desdeSql = if ($configEmailOriginal.EmailDesde -is [DBNull]) { 'NULL' } else { "'$($configEmailOriginal.EmailDesde)'" }
        $nombreSql = if ($configEmailOriginal.NombreDesde -is [DBNull]) { 'NULL' } else { "'$($configEmailOriginal.NombreDesde)'" }
        $frontendSql = if ($configEmailOriginal.FrontendBaseUrl -is [DBNull]) { 'NULL' } else { "'$($configEmailOriginal.FrontendBaseUrl)'" }
        Invoke-Sql "UPDATE ConfiguracionEmail SET SmtpHost = $hostSql, SmtpPort = $portSql, SmtpUsuario = $usuarioSql, SmtpPassword = $passwordSql, UsarSsl = $sslSql, EmailDesde = $desdeSql, NombreDesde = $nombreSql, FrontendBaseUrl = $frontendSql WHERE ConfiguracionEmailID = $($configEmailOriginal.ConfiguracionEmailID)" | Out-Null
        Invoke-Sql "DELETE FROM ConfiguracionEmail WHERE ConfiguracionEmailID <> $($configEmailOriginal.ConfiguracionEmailID)" | Out-Null
    } else {
        Invoke-Sql "DELETE FROM ConfiguracionEmail" | Out-Null
    }
}

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
