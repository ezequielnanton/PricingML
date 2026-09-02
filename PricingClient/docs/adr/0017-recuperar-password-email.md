# Recuperar contraseña olvidada por email real

El usuario eligió explícitamente el flujo por email real (no que un ADMIN
resetee la cuenta a mano), aunque el proyecto no tenía ninguna
infraestructura de email — ni SMTP, ni ninguna librería de envío.

## Cómo funciona

- **`ConfiguracionEmail`** (tabla nueva, fila única): host/puerto/usuario/
  contraseña SMTP, SSL, email y nombre remitente, y la URL base del
  frontend (para armar el link de reseteo) — mismo patrón que
  `ConfiguracionMercadoLibre` (ADR 0006) e "Integración MercadoLibre".
  Pantalla nueva "Integración Email", con un botón "Enviar email de
  prueba" para validar la configuración sin tener que disparar todo el
  flujo de "olvidé mi contraseña".
- **`EmailService`** usa `System.Net.Mail.SmtpClient` directamente (sin
  sumar una librería nueva como MailKit) — alcanza para un envío simple de
  HTML por SMTP con o sin SSL.
- **`Usuarios.Email`** (columna nueva, nullable): sin email cargado, "olvidé
  mi contraseña" no manda nada — pero la respuesta es igual de todas
  formas (ver abajo). El alta de un Usuario nuevo pide el email; para los
  ya existentes (como el ADMIN del bootstrap, que no tiene) hay un botón
  "Editar" en la pantalla Usuarios.
- **`PasswordResetTokens`**: token de un solo uso (32 bytes random,
  URL-safe base64), válido 1 hora, ligado a un Usuario. `POST /api/auth/
  resetear-password` lo consume exactamente una vez — reutilizarlo, uno
  vencido, o uno inexistente dan mensajes de error distintos y claros
  (usado / expirado / inválido).
- **Sin enumeración de usuarios**: `POST /api/auth/olvide-password` devuelve
  siempre el mismo mensaje genérico ("si existe y tiene email, te
  mandamos instrucciones"), sea el usuario inexistente, inactivo, sin
  email cargado, o el envío de SMTP falle — nunca revela por la respuesta
  cuál de esos casos ocurrió.
- El link (`{FrontendBaseUrl}/reset-password?token=...`) abre una pantalla
  nueva del lado del frontend (`ResetPasswordCard`, dentro de `LoginGate.
  jsx`) que funciona **sin sesión y sin importar si existe algún Usuario o
  no** — se resuelve antes que cualquier otro estado del gate (bootstrap/
  login/autenticado).
- Desde el login normal, un link "¿Olvidaste tu contraseña?" abre un
  formulario chico (solo pide el Usuario) que llama al mismo endpoint.

## Bug encontrado y corregido durante las pruebas

`ResetPasswordViaTokenAsync` llamaba a `tx.RollbackAsync()` mientras el
`SqlDataReader` de la consulta del token todavía estaba abierto en la misma
conexión — `SqlClient` lo rechaza con `InvalidOperationException` ("Ya hay
un DataReader abierto..."), lo que producía un 500 en vez del 400 esperado
al reusar un token ya gastado. Se corrigió cerrando el reader (saliendo de
su bloque `await using`) antes de decidir si hace falta el rollback.

## Validado con un servidor SMTP simulado

Se armó un servidor SMTP mínimo en Python (protocolo real: EHLO/MAIL FROM/
RCPT TO/DATA, sin auth ni TLS) para probar el envío real por socket, no
solo el código en aislamiento:

- Bootstrap sin cambios: el ADMIN del bootstrap no tiene email por
  default (no aplica acá).
- Usuario con email → "olvidé mi contraseña" → el mock SMTP recibe un
  email real con el link correcto (decodificado y verificado).
- Reset con el token del link → 204, contraseña vieja deja de andar,
  la nueva funciona de inmediato.
- Reusar el mismo token → 400 "ya fue usado" (antes: 500, ver bug arriba).
- Token inventado → 400 "no es válido".
- "Olvidé mi contraseña" para un usuario inexistente y para uno sin email
  cargado → mismo mensaje genérico en ambos casos, sin enviar nada.
- Botón "Enviar email de prueba" → el mock SMTP recibe el email de prueba.
- Probado en navegador real: link "¿Olvidaste tu contraseña?" → formulario
  → mensaje de confirmación → abrir el link del email real (extraído del
  mock) → pantalla "Elegir contraseña nueva" → "Contraseña actualizada" →
  login funciona con la contraseña nueva.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios.

## Nota

`email-integracion` se agregó a `UsuarioAuthService.TodasLasSecciones`
(las secciones que recibe automáticamente el primer ADMIN del bootstrap),
pero un ADMIN creado *antes* de este cambio no la tiene hasta que alguien
se la tilde a mano desde "Editar permisos" — o vuelva a loguearse después
de que se la agreguen, ya que las `Secciones` de una sesión quedan fijas
en el momento del login (mismo diseño que el Rol, ver ADR 0012/0013).
