# Cambiar la propia contraseña

El login general (ADR 0012) no tenía forma de que un Usuario cambiara su
propia contraseña — solo un ADMIN podía recrear cuentas por completo.

## Cómo funciona

- `POST /api/auth/cambiar-password` (nuevo): pide `PasswordActual` y
  `PasswordNueva`. Vive bajo `/api/auth/*`, así que el middleware de login
  general no lo intercepta (esa ruta está deliberadamente excluida, ver ADR
  0012) — el propio endpoint resuelve la sesión con
  `UsuarioAuthService.ResolveSession(request)`, el mismo patrón que ya usaban
  `/api/auth/me` y `/api/auth/logout`.
- Exige conocer la contraseña actual (comparada con hash fijo en tiempo,
  `CryptographicOperations.FixedTimeEquals`, igual que el login) antes de
  guardar la nueva con un salt nuevo. No invalida la sesión vigente — el
  token no depende del hash de password, así que seguís logueado después de
  cambiarla; solo afecta el próximo login.
- En el frontend, la barra superior de `LoginGate` (donde ya estaba "Cerrar
  sesión") suma un botón "Cambiar contraseña" que despliega un formulario
  chico con contraseña actual, nueva y confirmación.

## Validado

- Contraseña actual incorrecta → 400 "La contraseña actual no es correcta.",
  no cambia nada (confirmado reintentando login con la contraseña vieja).
- Contraseña actual correcta → 204, la vieja deja de funcionar y la nueva
  funciona de inmediato.
- Probado en navegador real contra la cuenta ADMIN real de la instalación
  (cambiada y devuelta a su valor original al terminar la prueba, para no
  dejar la credencial real distinta de la que se le comunicó al usuario).
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios.

## Nota de diagnóstico (no un defecto de la app)

Durante la verificación en navegador, los clics/tipeos simulados por la
herramienta de automatización a veces no disparaban el `onChange`/`onClick`
de React de forma confiable contra este formulario (posiblemente por timing
de montado/desmontado condicional del panel). Se confirmó separadamente que
la causa no era la app: setear los inputs vía el setter nativo de
`HTMLInputElement` + `dispatchEvent(new Event('input'))` y disparar `click()`
directo sobre los elementos reprodujo el flujo completo sin problemas. Vale
la pena recordarlo si un futuro test de UI contra este formulario "no hace
nada" — probablemente sea la herramienta de automatización, no el código.
