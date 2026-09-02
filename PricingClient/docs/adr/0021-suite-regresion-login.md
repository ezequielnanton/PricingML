# Suite de regresión de Login

El usuario pidió empezar la suite de regresión de todo el sistema (ERP,
Repositor, Login, ML, Email) "por Login, profundo" — un solo script,
mismo estilo que `Run-PruebasMotor.ps1`, cubriendo el flujo completo de
punta a punta contra la API real, dejando ERP/ML/Repositor/Email como
suites separadas para más adelante, una a la vez.

## Qué cubre

`C:\PricingEngine\tests\Run-PruebasLogin.ps1`, contra una instancia real
de PricingApi (nunca la arranca ni la reinicia — falla rápido con un
mensaje claro si `/health` no responde):

- **TC01** — El guard de bootstrap rechaza un segundo "primer admin" sin
  tocar el ADMIN real de la instalación (recibido por parámetro, solo
  para loguearse).
- **TC02** — Alta de usuario + login correcto (200, con token) / incorrecto
  (401).
- **TC03** — Un usuario LECTURA puede leer (200) pero no mutar (403); un
  ADMIN sí llega a nivel de Rol (404 = no encontrado, no 403 — confirma
  que el gate es de Rol, no de existencia del dato).
- **TC04** — Las Secciones que devuelve el login son exactamente las que
  se le asignaron al usuario.
- **TC05** — Cambiar la propia contraseña: actual incorrecta (400) /
  correcta (204); la vieja deja de servir, la nueva funciona.
- **TC06** — Recuperar contraseña por email real, contra un servidor SMTP
  simulado (`Mock-SmtpServer.py`, nuevo fixture permanente) que el script
  levanta y apaga solo: token corto rechazado (400), reset válido (204),
  login con vieja/nueva contraseña, el token no se puede reusar (400) ni
  inventar (400).
- **TC07** — Eliminar usuario: sin historial (204); con historial
  simulado en `ColaEjecucionML` (409) — se saltea con una descripción
  explícita si no hay ninguna fila para simular ese caso, en vez de
  fallar; la propia cuenta logueada no se puede autoeliminar (400).
- **TC08** — La sesión queda persistida en `UsuarioSesiones` (no solo en
  memoria) tras el login, y desaparece al hacer logout.

Todos los usuarios/tokens/config de email que crea el script llevan el
prefijo `qa_login_` y se borran al final, haya fallado algo o no. Nunca
toca el usuario ADMIN real salvo para loguearse con él, y la
`ConfiguracionEmail` original se restaura tal cual estaba después de TC06.

## Defectos encontrados y corregidos durante esta QA

Como en ADR 0017 y 0019, construir la suite encontró bugs reales, no solo
en el script sino en cómo se estaba interpretando su resultado:

1. **El conteo final de fallos mentía cuando había exactamente un FAIL.**
   `($rows | Where-Object { $_.Resultado -eq 'FAIL' }).Count` — si el
   filtro matchea un solo elemento, PowerShell no lo envuelve en un array,
   así que `.Count` se evalúa sobre un `PSCustomObject` suelto, que no
   tiene esa propiedad y devuelve `$null` en vez de un error. Como
   `$null` se trata como `0` en aritmética, `$total - $failCount` daba
   igual "8 / 8 casos OK" aunque hubiera un caso realmente fallado. Esto
   ocultó el bug de TC06 (ver siguiente punto) durante varias corridas
   seguidas — el script decía que todo pasaba mientras el Excel exportado
   mostraba un FAIL real. Corregido envolviendo con `@(...)` para forzar
   contexto de array: `@($rows | Where-Object {...}).Count`.
2. **TC06 fallaba siempre (no de forma intermitente) porque el cuerpo del
   email llega en base64.** `System.Net.Mail.SmtpClient`, con el
   `BodyEncoding = UTF8` que usa `EmailService`, codifica el cuerpo HTML
   como `Content-Transfer-Encoding: base64` aunque el contenido sea ASCII
   puro (el link de reseteo nunca aparece en texto plano dentro del log
   crudo del mock). El regex que buscaba `reset-password?token=...`
   directamente en el log jamás matcheaba, así que `TC06` fallaba en
   cada corrida real — enmascarado por el bug del punto 1. Corregido
   agregando, como fallback dentro del mismo loop de espera, la
   extracción y decodificación del bloque base64 del cuerpo del mensaje
   antes de buscar el token adentro del texto ya decodificado.
3. **La tabla de consola descartaba silenciosamente la columna
   "Resultado".** `Format-Table -AutoSize` calcula el ancho disponible en
   base a la consola real — al redirigir la salida a un archivo (sin
   consola real detrás) ese ancho cae a un valor angosto por defecto, y
   `Format-Table` directamente omite columnas enteras que no entran, sin
   avisar. Esto fue lo que hizo pasar desapercibido el defecto del punto 1
   durante la depuración: la tabla impresa solo mostraba Caso y
   Descripción, nunca Resultado. Corregido forzando un ancho fijo con
   `Out-String -Width 200` antes de imprimir.

Los tres defectos se descubrieron encadenados: sin el punto 3 (columna
oculta) costó notar que el punto 1 (conteo mentiroso) enmascaraba el
punto 2 (bug real y permanente en TC06) durante varias corridas seguidas
que parecían "8/8" en consola.

## Gotchas de PowerShell/Windows documentados en el script (comentarios
`#anclaDeNombre` inline, mismo estilo que Run-PruebasMotor.ps1)

- Un `.ps1` sin BOM UTF-8 puede corromper silenciosamente literales de
  string con tildes/rayas — ya documentado para `Run-PruebasMotor.ps1` en
  `docs/QA-Motor-Pricing.md`; el archivo de esta suite lleva BOM.
- `Invoke-WebRequest`/`Invoke-RestMethod` necesitan `-UseBasicParsing` en
  sesiones no interactivas.
- `Invoke-Sqlcmd` devuelve `NULL` de SQL como `[DBNull]::Value` (objeto
  "truthy" en PowerShell, no `$null`) — hay que chequear `-is [DBNull]`
  explícitamente antes de usar el valor en una query armada a mano.
- `$PSScriptRoot` puede llegar vacío al evaluar el default de un
  parámetro que aparece ANTES de un `[Parameter(Mandatory=$true)]` en el
  mismo `param()` block — se resuelve en el cuerpo del script en vez de
  en el default del parámetro.
- `Invoke-WebRequest -Body <string>` no garantiza bytes UTF-8 correctos
  en Windows PowerShell 5.1 con contenido no-ASCII — hay que convertir
  explícitamente con `[System.Text.Encoding]::UTF8.GetBytes(...)`.
- Esperar a un proceso externo asincrónico (el mock SMTP, el envío de un
  email) con `Start-Sleep` de duración fija es una carrera — se reemplazó
  por polling activo (conexión TCP real al puerto del mock, y lectura
  del log del mock por regex) con reintentos acotados.

## Validado

- 3 corridas limpias y consecutivas después de las correcciones: consola
  y Excel exportado coinciden exactamente, "8 / 8 casos OK" en las tres,
  `exit 0` en las tres.
- Verificado que antes de las correcciones el mismo Excel mostraba
  `TC06 = FAIL` con `token=NO EXTRAÍDO` mientras la consola de esa misma
  corrida decía "8 / 8 casos OK" — reproducido y confirmado como el bug
  real antes de corregirlo.
- Limpieza confirmada tras la corrida final: sin usuarios `qa_login_*`
  remanentes en `Usuarios`, sin `mock-smtp-login.log` remanente, sin
  proceso `python.exe` del mock corriendo, puerto 1025 libre.
- No se tocó el motor de pricing ni ninguna tabla fuera del alcance de
  Login/Usuarios — `Run-PruebasMotor.ps1` no se volvió a correr en esta
  tarea porque no se tocó ningún objeto que le concierna.

## Pendiente (explícitamente fuera de alcance, a pedido del usuario)

Suites de regresión separadas para ERP, Repositor, ML y Email (más allá
del camino de recuperación de contraseña que ya cubre TC06 acá) — se
abordan una a la vez, después de esta.
