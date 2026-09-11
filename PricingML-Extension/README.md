# PricingML Chrome Extension

Captura competidores de MercadoLibre desde el navegador y los vincula a tus publicaciones en
PricingML. La guía de usuario completa está en [`../COMPETIDORES-EXTENSION.md`](../COMPETIDORES-EXTENSION.md).

## Instalación para desarrollo

1. `bash GENERATE_ICONS.sh` (requiere ImageMagick)
2. `chrome://extensions/` → **Modo de desarrollador** → **Cargar extensión sin empaquetar**
3. Elegir esta carpeta
4. Tener PricingML abierto y logueado con un usuario ADMIN: la sesión se toma de ahí

## Archivos

| Archivo | Qué hace |
|---------|----------|
| `manifest.json` | Manifest V3. Declara los hosts de ML y del Motor (`localhost`, `127.0.0.1`) |
| `src/popup.html` | Formulario de captura y panel de configuración |
| `src/popup.js` | Lee la pestaña, carga tus publicaciones, postea al Motor |
| `src/background.js` | Service worker: deja la URL por defecto al instalar |

## Decisiones de diseño

**No hay content script.** El popup lee la pestaña con `chrome.scripting.executeScript` al
abrirse. Un content script que dejara los datos en `chrome.storage.session` no funciona: ese
storage no es escribible desde un content script sin bajarle el nivel de acceso, y el dato
guardado queda viejo si el usuario cambia de artículo.

**El usuario elige la publicación.** No se adivina por parecido de título: un match equivocado
vincularía el competidor al producto errado en silencio, y ese precio alimenta el cálculo del
precio de venta.

**Se reusa el endpoint del panel web.** `POST /api/marketplace/ml/publicaciones/{id}/competidores`
es el mismo que usa la app. Es idempotente: reenviar un competidor ya vinculado actualiza su
precio en vez de fallar contra el UNIQUE `(PublicacionID, CompetidorItemID)`. Devuelve
`esNuevo` y `precioAnterior` para que el popup diga si dio de alta o actualizó.

**La sesión se reusa, no se pide.** El popup lee `localStorage['pricingUiToken']` de una pestaña
local con PricingML abierto (ver `CLAVE_TOKEN_APP` y el comentario en
`PricingClient/pricing-ui/src/utils/auth.js`). Las sesiones duran 12 horas: ante un 401 se
relee el token y se reintenta una vez, así que el vencimiento es transparente. Pedirle al
usuario que copiara un token de la consola, o usuario y contraseña una vez por día, eran las
alternativas descartadas. El token va en `chrome.storage.local` —no `sync`, que lo replicaría a
la cuenta de Google— y viaja solo al Motor en el header `Authorization`. Nunca se manda a ML.

## Limitaciones

- Solo Chrome/Edge (Manifest V3).
- El Motor tiene que estar corriendo y el host declarado en `host_permissions`.
- La captura es siempre manual: ML devuelve 403 al leer publicaciones ajenas por API, así que
  no hay refresco automático posible (ver ADR 0010).
