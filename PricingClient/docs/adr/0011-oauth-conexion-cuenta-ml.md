# Flujo OAuth real para conectar una Cuenta ML

Hasta ahora, conectar una Cuenta ML significaba pegar `AccessToken`/`RefreshToken`
a mano por SQL o por el formulario ABM — nadie pasaba realmente por el login de
MercadoLibre. Esto se reemplaza por el flujo real de OAuth 2.0 (Authorization
Code) que ML expone.

## Cómo funciona

1. Desde el formulario "Cuenta ML" (con un registro ya guardado), el usuario
   hace clic en **Conectar con MercadoLibre**, un link simple (no un fetch) a
   `GET /api/marketplace/ml/oauth/iniciar?cuentaMlId={id}`.
2. El backend arma la URL de autorización de ML (`https://auth.mercadolibre.
   {dominio-del-site}/authorization?...`) usando el `SiteId` y `RedirectUri`
   configurados en "Integración MercadoLibre", genera un `state` de un solo uso
   asociado a esa `CuentaMLID` (guardado en memoria, mismo patrón que
   `RepositorAuthService`) y redirige al navegador ahí.
3. El usuario se loguea y autoriza en el sitio real de ML.
4. ML redirige a nuestro `RedirectUri` con `?code=...&state=...`.
   `GET /api/marketplace/ml/oauth/callback` valida el `state` (y lo consume,
   evitando reintentos), cambia el `code` por tokens reales vía
   `POST {ApiBaseUrl}/oauth/token` (`grant_type=authorization_code`, endpoint
   global — no el de auth por site) y guarda `AccessToken`, `RefreshToken`,
   `FechaVencimientoToken` y `UserIDML` en la `CuentaML` correspondiente.
5. La pantalla de callback es una página HTML mínima de éxito/error — el
   usuario simplemente cierra la pestaña y vuelve a la app.

## Por qué el dominio de auth es configurable y no fijo a Argentina

El dominio de login de ML varía por site y, en el caso de Brasil, ni siquiera
sigue el mismo patrón de nombre (`mercadolivre`, no `mercadolibre`). Se agregó
`SiteId` a "Integración MercadoLibre" (dropdown, valores fijos MLA/MLB/MLM/
MLC/MCO/MLU/MPE/MLV/MEC) y un mapa explícito site→dominio en el backend, en vez
de derivarlo de una regla o dejarlo hardcodeado a un país.

## Qué se agregó

- `ConfiguracionMercadoLibre.SiteId`, `RedirectUri` (columnas nuevas,
  migración `Migrar-OAuthMercadoLibre.sql`), editables desde "Integración
  MercadoLibre".
- `MercadoLibreSyncService.ConstruirUrlAutorizacionAsync` /
  `ProcesarCallbackAutorizacionAsync`.
- `GET /api/marketplace/ml/oauth/iniciar`, `GET /api/marketplace/ml/oauth/
  callback`.
- Link "Conectar con MercadoLibre" en el formulario "Cuenta ML" (solo visible
  para un registro ya guardado).

## Validado con mock

- Mock de `/oauth/token` extendido para responder también a
  `grant_type=authorization_code` (incluye `user_id`).
- `iniciar` redirige con la URL de `auth.mercadolibre.com.ar` correcta,
  `client_id`, `redirect_uri` codificada y `state` nuevo.
- `callback` con `code`/`state` válidos actualiza `AccessToken`,
  `RefreshToken`, `FechaVencimientoToken` y `UserIDML` en `CuentasML`.
- Reusar el mismo `state` una segunda vez se rechaza (protección contra
  reintento/replay).
- `iniciar` con una `CuentaMLID` inexistente devuelve 400 con mensaje claro.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios.
