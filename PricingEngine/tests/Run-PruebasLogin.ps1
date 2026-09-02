<#
.SYNOPSIS
    Corre el banco de pruebas del login general de Usuarios (ADR 0012-0018) contra
    una instancia real de PricingApi, y deja un Excel con lo esperado vs. lo obtenido.

.DESCRIPTION
    Cubre, de punta a punta, contra la API HTTP real (no solo SQL):
      TC01  El guard de bootstrap rechaza un segundo "primer admin" (no destructivo:
            nunca borra el ADMIN real de la instalación).
      TC02  Alta de usuario + login correcto/incorrecto.
      TC03  Un usuario LECTURA puede leer (200) pero no mutar (403); un ADMIN sí.
      TC04  Las Secciones que devuelve el login son las que se le asignaron.
      TC05  Cambiar la propia contraseña (actual incorrecta/correcta).
      TC06  Recuperar contraseña por email real, contra un servidor SMTP simulado
            (Mock-SmtpServer.py) que este script levanta y apaga solo.
      TC07  Eliminar usuario: sin historial (204), con historial simulado (409),
            la propia cuenta logueada (400).
      TC08  La sesión queda persistida en UsuarioSesiones (no en memoria) y
            desaparece al hacer logout.

    Todos los usuarios/tokens/config de email que crea este script son de prueba
    (prefijo qa_login_) y se borran al final, haya fallado algo o no. Nunca toca el
    usuario ADMIN real que se le pasa por parámetro, salvo para loguearse con él.

.EXAMPLE
    pwsh -File .\Run-PruebasLogin.ps1 -AdminUsuario ADMIN -AdminPassword "................"

.NOTES
    -AdminUsuario/-AdminPassword son las credenciales reales de un ADMIN ya existente
    en la instalación de destino. Nunca hardcodear una contraseña real acá ni pasarla
    en un script versionado - se piden como parámetro en cada corrida.
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

# #psScriptRootEnParamMandatory: con parámetros [Parameter(Mandatory=$true)] en el
# mismo param() block, $PSScriptRoot puede llegar vacío todavía al evaluar el default
# de un parámetro ANTERIOR (acá, $OutputExcel) — a diferencia de un param() sin
# obligatorios (como Run-PruebasMotor.ps1), donde sí llega poblado a tiempo. Por eso
# el default de $OutputExcel se resuelve acá, en el cuerpo del script, no en el
# param() — para cuando el cuerpo arranca, $PSScriptRoot ya está seteado siempre.
if ([string]::IsNullOrWhiteSpace($OutputExcel)) { $OutputExcel = "$PSScriptRoot\Resultados-Login.xlsx" }

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
        # #invokeWebRequestBodyNoEsUtf8: pasarle a -Body un string con acentos/ñ no
        # garantiza bytes UTF-8 en Windows PowerShell 5.1 — según la codepage del
        # sistema, puede mandar mal el multi-byte y el JSON le llega corrupto a la
        # API (400 en vez del código real que se está probando). Conviertiendo a
        # bytes UTF-8 nosotros mismos, queda bien sin importar la codepage.
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
Write-Host "== 1. Limpiando usuarios de prueba de una corrida anterior ==" -ForegroundColor Cyan
function Remove-UsuarioQaPorNombre($usuario) {
    $u = Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = '$usuario'"
    if ($u) {
        Invoke-Sql "DELETE FROM UsuarioSesiones WHERE UsuarioID = $($u.UsuarioID)"
        Invoke-Sql "DELETE FROM PasswordResetTokens WHERE UsuarioID = $($u.UsuarioID)"
        Invoke-Sql "DELETE FROM UsuarioSecciones WHERE UsuarioID = $($u.UsuarioID)"
        Invoke-Sql "UPDATE ColaEjecucionML SET UsuarioAprobacionID = NULL WHERE UsuarioAprobacionID = $($u.UsuarioID)"
        Invoke-Sql "UPDATE PublicacionCompetidoresManual SET UsuarioVinculoID = NULL WHERE UsuarioVinculoID = $($u.UsuarioID)"
        Invoke-Sql "DELETE FROM Usuarios WHERE UsuarioID = $($u.UsuarioID)"
    }
}
$qaUsuarios = @("qa_login_admin", "qa_login_lectura", "qa_login_delete1", "qa_login_delete2")
foreach ($u in $qaUsuarios) { Remove-UsuarioQaPorNombre $u }

$loginAdminReal = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = $AdminUsuario; Password = $AdminPassword }
if ($loginAdminReal.StatusCode -ne 200) {
    throw "No se pudo loguear con -AdminUsuario/-AdminPassword (HTTP $($loginAdminReal.StatusCode)). Verificá las credenciales."
}
$adminRealToken = $loginAdminReal.Body.token

# Config de email original, para restaurarla al final tal cual estaba.
$configEmailOriginal = Invoke-Api -Method Get -Path "/api/admin/email-configuracion" -Token $adminRealToken

Write-Host "== 2. Corriendo casos de prueba ==" -ForegroundColor Cyan

# --- TC01: guard de bootstrap (no destructivo) --------------------------------
$existe = Invoke-Api -Method Get -Path "/api/auth/existe-usuario"
$bootstrapRechazado = Invoke-Api -Method Post -Path "/api/auth/setup-primer-admin" -Body @{ Usuario = "qa_login_nunca_se_crea"; Password = "NoDeberiaCrearse1" }
$pass = ($existe.Body.existeUsuario -eq $true) -and ($bootstrapRechazado.StatusCode -eq 409)
Add-Resultado -Id "TC01" -Descripcion "Bootstrap rechaza un segundo 'primer admin' sin tocar el ADMIN real" `
    -Esperado "existeUsuario=true, setup-primer-admin=409" `
    -Obtenido "existeUsuario=$($existe.Body.existeUsuario), setup-primer-admin=$($bootstrapRechazado.StatusCode)" -Pass $pass

# --- TC02: alta de usuario + login correcto/incorrecto -------------------------
$altaAdmin = Invoke-Api -Method Post -Path "/api/admin/usuarios" -Token $adminRealToken -Body @{
    NombreCompleto = "QA Login Admin"; Usuario = "qa_login_admin"; Password = "QaLogin1Pass!"
    Rol = "ADMIN"; Secciones = @("pricing")
}
$loginOk = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = "QaLogin1Pass!" }
$loginMal = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = "PasswordIncorrecta1" }
$pass = ($altaAdmin.StatusCode -eq 201) -and ($loginOk.StatusCode -eq 200) -and (-not [string]::IsNullOrEmpty($loginOk.Body.token)) -and ($loginMal.StatusCode -eq 401)
Add-Resultado -Id "TC02" -Descripcion "Alta de usuario + login correcto (200, con token) / incorrecto (401)" `
    -Esperado "alta=201, login OK=200 con token, login incorrecto=401" `
    -Obtenido "alta=$($altaAdmin.StatusCode), login OK=$($loginOk.StatusCode) token=$(if($loginOk.Body.token){'sí'}else{'no'}), login incorrecto=$($loginMal.StatusCode)" -Pass $pass
$qaAdminToken = $loginOk.Body.token
$qaAdminPasswordActual = "QaLogin1Pass!"

# --- TC03: LECTURA no puede mutar, ADMIN sí ------------------------------------
$altaLectura = Invoke-Api -Method Post -Path "/api/admin/usuarios" -Token $adminRealToken -Body @{
    NombreCompleto = "QA Login Lectura"; Usuario = "qa_login_lectura"; Password = "QaLoginLectura1!"
    Rol = "LECTURA"; Secciones = @("pricing")
}
$loginLectura = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_lectura"; Password = "QaLoginLectura1!" }
$qaLecturaToken = $loginLectura.Body.token
$lecturaGet = Invoke-Api -Method Get -Path "/api/admin/usuarios" -Token $qaLecturaToken
$lecturaPost = Invoke-Api -Method Post -Path "/api/marketplace/ml/cola-aprobacion/999999999/aprobar" -Token $qaLecturaToken
$adminPost = Invoke-Api -Method Post -Path "/api/marketplace/ml/cola-aprobacion/999999999/aprobar" -Token $qaAdminToken
$pass = ($lecturaGet.StatusCode -eq 200) -and ($lecturaPost.StatusCode -eq 403) -and ($adminPost.StatusCode -eq 404)
Add-Resultado -Id "TC03" -Descripcion "LECTURA: GET permitido (200), POST bloqueado (403) · ADMIN: POST permitido a nivel Rol (404 = no encontrado, no 403)" `
    -Esperado "lectura GET=200, lectura POST=403, admin POST=404" `
    -Obtenido "lectura GET=$($lecturaGet.StatusCode), lectura POST=$($lecturaPost.StatusCode), admin POST=$($adminPost.StatusCode)" -Pass $pass

# --- TC04: las Secciones que devuelve el login son las que se asignaron --------
$qaLecturaId = (Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = 'qa_login_lectura'").UsuarioID
Invoke-Api -Method Put -Path "/api/admin/usuarios/$qaLecturaId/secciones" -Token $adminRealToken -Body @{ Secciones = @("pricing", "reports") } | Out-Null
$loginLectura2 = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_lectura"; Password = "QaLoginLectura1!" }
$seccionesObtenidas = @($loginLectura2.Body.secciones) | Sort-Object
$seccionesEsperadas = @("pricing", "reports") | Sort-Object
$pass = ($seccionesObtenidas -join ',') -eq ($seccionesEsperadas -join ',')
Add-Resultado -Id "TC04" -Descripcion "Las Secciones que devuelve el login son exactamente las que se asignaron" `
    -Esperado ($seccionesEsperadas -join ', ') -Obtenido ($seccionesObtenidas -join ', ') -Pass $pass

# --- TC05: cambiar la propia contraseña ----------------------------------------
$cambioMal = Invoke-Api -Method Post -Path "/api/auth/cambiar-password" -Token $qaAdminToken -Body @{ PasswordActual = "NoEsLaActual1"; PasswordNueva = "QaLogin2Pass!" }
$cambioOk = Invoke-Api -Method Post -Path "/api/auth/cambiar-password" -Token $qaAdminToken -Body @{ PasswordActual = $qaAdminPasswordActual; PasswordNueva = "QaLogin2Pass!" }
$loginConVieja = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = $qaAdminPasswordActual }
$loginConNueva = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = "QaLogin2Pass!" }
$pass = ($cambioMal.StatusCode -eq 400) -and ($cambioOk.StatusCode -eq 204) -and ($loginConVieja.StatusCode -eq 401) -and ($loginConNueva.StatusCode -eq 200)
Add-Resultado -Id "TC05" -Descripcion "Cambiar contraseña: actual incorrecta (400) / correcta (204); vieja ya no sirve, nueva sí" `
    -Esperado "400 / 204 / login vieja=401 / login nueva=200" `
    -Obtenido "$($cambioMal.StatusCode) / $($cambioOk.StatusCode) / login vieja=$($loginConVieja.StatusCode) / login nueva=$($loginConNueva.StatusCode)" -Pass $pass
if ($pass) { $qaAdminPasswordActual = "QaLogin2Pass!" }

# --- TC06: recuperar contraseña por email real (mock SMTP) --------------------
Write-Host "== TC06: levantando el mock SMTP para probar el flujo de recuperación ==" -ForegroundColor Cyan
$mockLog = "$PSScriptRoot\mock-smtp-login.log"
if (Test-Path $mockLog) { Remove-Item $mockLog -Force }
$mockProcess = Start-Process -FilePath "python" -ArgumentList "`"$PSScriptRoot\Mock-SmtpServer.py`" $MockSmtpPort" `
    -RedirectStandardOutput $mockLog -WindowStyle Hidden -PassThru

# #esperarMockListoNoSleepFijo: un Start-Sleep fijo es una carrera — si el intérprete de
# Python tarda un poco más en arrancar (carga del sistema, primera vez que corre, etc.),
# la API intenta mandar el email de reseteo ANTES de que el mock esté escuchando, la
# conexión falla, /api/auth/olvide-password lo traga (devuelve igual el 200 genérico,
# ver ADR 0017) y el test queda con el token nunca extraído. Se espera de verdad a que
# el puerto acepte una conexión TCP real, con un timeout generoso en vez de adivinar.
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

try {
    Invoke-Api -Method Put -Path "/api/admin/usuarios/$((Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = 'qa_login_admin'").UsuarioID)/email" `
        -Token $adminRealToken -Body @{ Email = "qa-login@example.com" } | Out-Null
    Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body @{
        SmtpHost = "localhost"; SmtpPort = $MockSmtpPort; UsarSsl = $false
        EmailDesde = "qa-login-suite@example.com"; NombreDesde = "QA Login Suite"
        FrontendBaseUrl = "http://localhost:9999"
    } | Out-Null

    $olvide = Invoke-Api -Method Post -Path "/api/auth/olvide-password" -Body @{ Usuario = "qa_login_admin" }

    # Idem: esperar de verdad a que el link aparezca en el log en vez de un sleep fijo
    # (el envío del email es asincrónico del lado de la API).
    $tokenReset = $null
    for ($intento = 0; $intento -lt 20; $intento++) {
        $logContenido = if (Test-Path $mockLog) { Get-Content $mockLog -Raw } else { "" }
        $match = [regex]::Match($logContenido, 'reset-password\?token=([A-Za-z0-9\-_]+)')
        if ($match.Success) { $tokenReset = $match.Groups[1].Value; break }
        # #cuerpoEmailEsBase64: System.Net.Mail.SmtpClient codifica el cuerpo HTML en
        # base64 (Content-Transfer-Encoding: base64) aunque el contenido sea ASCII puro,
        # por el BodyEncoding=UTF8 del EmailService -- el link nunca aparece en texto
        # plano en el log crudo del mock. Sin este fallback, el regex de arriba jamás
        # matchea y el test falla siempre (no de forma intermitente): hay que decodificar
        # el bloque base64 del cuerpo y buscar el token adentro del texto decodificado.
        $b64Match = [regex]::Match($logContenido, 'Content-Transfer-Encoding:\s*base64\s*\r?\n\r?\n(?<b64>[A-Za-z0-9+/=\r\n]+?)\r?\n\r?\n')
        if ($b64Match.Success) {
            try {
                $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($b64Match.Groups['b64'].Value -replace '\s', '')))
                $decodedMatch = [regex]::Match($decoded, 'reset-password\?token=([A-Za-z0-9\-_]+)')
                if ($decodedMatch.Success) { $tokenReset = $decodedMatch.Groups[1].Value; break }
            } catch {}
        }
        Start-Sleep -Milliseconds 250
    }

    $resetCorto = if ($tokenReset) { Invoke-Api -Method Post -Path "/api/auth/resetear-password" -Body @{ Token = $tokenReset; PasswordNueva = "corta" } } else { $null }
    $resetOk = if ($tokenReset) { Invoke-Api -Method Post -Path "/api/auth/resetear-password" -Body @{ Token = $tokenReset; PasswordNueva = "QaLogin3Pass!" } } else { $null }
    $loginConVieja2 = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = $qaAdminPasswordActual }
    $loginConNueva2 = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = "QaLogin3Pass!" }
    $resetReusado = if ($tokenReset) { Invoke-Api -Method Post -Path "/api/auth/resetear-password" -Body @{ Token = $tokenReset; PasswordNueva = "OtraPass1234!" } } else { $null }
    $resetInventado = Invoke-Api -Method Post -Path "/api/auth/resetear-password" -Body @{ Token = "token-que-no-existe"; PasswordNueva = "OtraPass1234!" }

    $pass = ($olvide.StatusCode -eq 200) -and ($null -ne $tokenReset) -and ($resetCorto.StatusCode -eq 400) -and
            ($resetOk.StatusCode -eq 204) -and ($loginConVieja2.StatusCode -eq 401) -and ($loginConNueva2.StatusCode -eq 200) -and
            ($resetReusado.StatusCode -eq 400) -and ($resetInventado.StatusCode -eq 400)
    Add-Resultado -Id "TC06" -Descripcion "Recuperar contraseña: mock SMTP recibe el link, reset funciona, token no se puede reusar ni inventar" `
        -Esperado "olvide=200, token extraído, corta=400, reset=204, vieja=401, nueva=200, reusado=400, inventado=400" `
        -Obtenido "olvide=$($olvide.StatusCode), token=$(if($tokenReset){'extraído'}else{'NO EXTRAÍDO'}), corta=$($resetCorto.StatusCode), reset=$($resetOk.StatusCode), vieja=$($loginConVieja2.StatusCode), nueva=$($loginConNueva2.StatusCode), reusado=$($resetReusado.StatusCode), inventado=$($resetInventado.StatusCode)" -Pass $pass
    if ($pass) { $qaAdminPasswordActual = "QaLogin3Pass!" }
} finally {
    if ($mockProcess -and -not $mockProcess.HasExited) { Stop-Process -Id $mockProcess.Id -Force }
    # Config de email de vuelta a lo que había antes de esta corrida.
    Invoke-Api -Method Put -Path "/api/admin/email-configuracion" -Token $adminRealToken -Body @{
        SmtpHost = $configEmailOriginal.Body.smtpHost; SmtpPort = $configEmailOriginal.Body.smtpPort
        SmtpUsuario = $configEmailOriginal.Body.smtpUsuario; UsarSsl = $configEmailOriginal.Body.usarSsl
        EmailDesde = $configEmailOriginal.Body.emailDesde; NombreDesde = $configEmailOriginal.Body.nombreDesde
        FrontendBaseUrl = $configEmailOriginal.Body.frontendBaseUrl
    } | Out-Null
}

# --- TC07: eliminar usuario -----------------------------------------------------
Invoke-Api -Method Post -Path "/api/admin/usuarios" -Token $adminRealToken -Body @{
    NombreCompleto = "QA Login Delete 1"; Usuario = "qa_login_delete1"; Password = "QaLoginDelete1!"
    Rol = "LECTURA"; Secciones = @()
} | Out-Null
$delete1Id = (Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = 'qa_login_delete1'").UsuarioID
$deleteSinHistorial = Invoke-Api -Method Delete -Path "/api/admin/usuarios/$delete1Id" -Token $adminRealToken

$colaFila = Invoke-Sql "SELECT TOP 1 ColaID, UsuarioAprobacionID FROM ColaEjecucionML ORDER BY ColaID DESC"
$deleteConHistorial = $null
if ($colaFila) {
    Invoke-Api -Method Post -Path "/api/admin/usuarios" -Token $adminRealToken -Body @{
        NombreCompleto = "QA Login Delete 2"; Usuario = "qa_login_delete2"; Password = "QaLoginDelete2!"
        Rol = "LECTURA"; Secciones = @()
    } | Out-Null
    $delete2Id = (Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = 'qa_login_delete2'").UsuarioID
    Invoke-Sql "UPDATE ColaEjecucionML SET UsuarioAprobacionID = $delete2Id WHERE ColaID = $($colaFila.ColaID)"
    $deleteConHistorial = Invoke-Api -Method Delete -Path "/api/admin/usuarios/$delete2Id" -Token $adminRealToken
    # #dbNullEsVerdadero: Invoke-Sqlcmd devuelve un NULL de SQL como [DBNull]::Value, que
    # es un objeto no-nulo y por lo tanto "truthy" en PowerShell — un `if` simple sobre el
    # valor lo toma como si tuviera dato, y su ToString() es cadena vacía (rompía el UPDATE
    # con "SET UsuarioAprobacionID =  WHERE ..."). Hay que chequear [DBNull] explícitamente.
    $valorOriginal = if ($null -eq $colaFila.UsuarioAprobacionID -or $colaFila.UsuarioAprobacionID -is [DBNull]) { "NULL" } else { $colaFila.UsuarioAprobacionID }
    Invoke-Sql "UPDATE ColaEjecucionML SET UsuarioAprobacionID = $valorOriginal WHERE ColaID = $($colaFila.ColaID)"
}

$deletePropiaCuenta = Invoke-Api -Method Delete -Path "/api/admin/usuarios/$((Invoke-Sql "SELECT UsuarioID FROM Usuarios WHERE Usuario = 'qa_login_admin'").UsuarioID)" -Token $qaAdminToken

if ($null -ne $deleteConHistorial) {
    $pass = ($deleteSinHistorial.StatusCode -eq 204) -and ($deleteConHistorial.StatusCode -eq 409) -and ($deletePropiaCuenta.StatusCode -eq 400)
    Add-Resultado -Id "TC07" -Descripcion "Eliminar usuario: sin historial (204), con historial simulado (409), la propia cuenta logueada (400)" `
        -Esperado "204 / 409 / 400" -Obtenido "$($deleteSinHistorial.StatusCode) / $($deleteConHistorial.StatusCode) / $($deletePropiaCuenta.StatusCode)" -Pass $pass
} else {
    $pass = ($deleteSinHistorial.StatusCode -eq 204) -and ($deletePropiaCuenta.StatusCode -eq 400)
    Add-Resultado -Id "TC07" -Descripcion "Eliminar usuario: sin historial (204), la propia cuenta logueada (400) - caso 'con historial' salteado (no hay filas en ColaEjecucionML para simularlo)" `
        -Esperado "204 / 400" -Obtenido "$($deleteSinHistorial.StatusCode) / $($deletePropiaCuenta.StatusCode)" -Pass $pass
}

# --- TC08: la sesión está persistida en la base, no solo en memoria ------------
$loginParaSesion = Invoke-Api -Method Post -Path "/api/auth/login" -Body @{ Usuario = "qa_login_admin"; Password = $qaAdminPasswordActual }
$tokenSesion = $loginParaSesion.Body.token
$filaAntes = Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM UsuarioSesiones WHERE Token = '$tokenSesion'"
Invoke-Api -Method Post -Path "/api/auth/logout" -Token $tokenSesion | Out-Null
$filaDespues = Invoke-Sql "SELECT COUNT(*) AS Cantidad FROM UsuarioSesiones WHERE Token = '$tokenSesion'"
$pass = ($filaAntes.Cantidad -eq 1) -and ($filaDespues.Cantidad -eq 0)
Add-Resultado -Id "TC08" -Descripcion "La sesión queda en UsuarioSesiones (no solo en memoria) tras el login, y desaparece al hacer logout" `
    -Esperado "fila tras login=1, fila tras logout=0" -Obtenido "fila tras login=$($filaAntes.Cantidad), fila tras logout=$($filaDespues.Cantidad)" -Pass $pass

# ----------------------------------------------------------------------------
# 3. Limpieza final - nunca deja usuarios de prueba en la base.
# ----------------------------------------------------------------------------
Write-Host "== 3. Limpieza final ==" -ForegroundColor Cyan
foreach ($u in $qaUsuarios) { Remove-UsuarioQaPorNombre $u }
if (Test-Path $mockLog) { Remove-Item $mockLog -Force }

Write-Host "== 4. Resultado ==" -ForegroundColor Cyan
# #outStringWidthConsolaAngosta: sin forzar un ancho, Format-Table -AutoSize descarta
# columnas enteras (acá, silenciosamente tiraba "Resultado") cuando el ancho de consola
# reportado es angosto -- que es EXACTAMENTE lo que pasa al redirigir la salida a un
# archivo (no hay consola real, el default cae a ~80). Con Out-String -Width forzamos
# un ancho fijo generoso sin depender de si hay una consola real detrás.
($rows | Format-Table Caso, Descripcion, Resultado -AutoSize -Wrap | Out-String -Width 200) | Write-Host

# #whereObjectColapsaAEscalar: cuando el filtro matchea exactamente UN elemento,
# "$rows | Where-Object {...}" devuelve ese objeto suelto (no un array de 1), y un
# PSCustomObject no tiene propiedad .Count -- en PowerShell 5.1 eso da $null en vez de
# error, y "$total - $null" se evalúa como "$total - 0", reportando "8 / 8 casos OK"
# aunque hubiera exactamente un FAIL real. Envolver con @() fuerza el contexto array.
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
