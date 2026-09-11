# Captura de Competidores con la Extensión de Chrome

**Problema**: MercadoLibre bloquea leer una publicación ajena por API. Tanto la búsqueda por
texto (`GET /sites/{site}/search`) como la lectura de un ítem de otro vendedor
(`GET /items/{id}`) devuelven **403**, con token válido o sin él (ver
`PricingClient/docs/adr/0010-competidores-manuales-no-catalogo.md`). No hay forma de traer el
precio de un competidor por API.

**Solución**: una extensión de Chrome que lee los datos públicos que **vos ya estás viendo** en
la pantalla y los manda a PricingML. Vos elegís a qué publicación tuya le compite, y el Motor
lo vincula y guarda un snapshot de precio.

## Qué NO hace

Conviene ser claro para no esperar algo que no pasa:

- **No sincroniza sola.** Cada captura es un clic tuyo. No hay ningún proceso que salga a
  revisar precios de competidores, porque ML lo impide.
- **El botón "Sincronizar ML" no sirve para esto.** Ese botón trae tus *propias* publicaciones
  y ventas, donde estás autenticado como dueño. Los competidores quedan afuera por el 403.
- **El precio se actualiza cuando vos volvés a capturar.** Recapturar el mismo competidor
  refresca su precio y agrega un snapshot nuevo; no duplica el vínculo.

---

## Instalación

### 1. Generar los iconos

```bash
cd PricingML-Extension/
bash GENERATE_ICONS.sh      # requiere ImageMagick
```

### 2. Cargar en Chrome

1. Ir a `chrome://extensions/`
2. Activar **"Modo de desarrollador"** (arriba a la derecha)
3. **"Cargar extensión sin empaquetar"**
4. Elegir la carpeta `PricingML-Extension/`

### 3. Configurar el Motor y el token

El endpoint que usa la extensión está detrás del login y exige rol **ADMIN**, igual que
cualquier otra escritura de la app. Así que la primera vez hay que configurarlo:

1. Clic en el icono de la extensión → **"Configuración"**
2. **URL del Motor**: `http://localhost:5000` (o donde corra)
3. **Token de sesión**: el de tu sesión en PricingML. Entrá a la app web ya logueado, abrí la
   consola (F12) y copiá el token guardado por el cliente.
4. **"Guardar configuración"**

El token queda en `chrome.storage.local`, o sea en esta máquina y nada más — a propósito no se
usa `sync`, que lo replicaría a tu cuenta de Google. Nunca se manda a MercadoLibre: únicamente
viaja al Motor, en el header `Authorization`.

> Si el Motor no corre en `localhost` ni `127.0.0.1`, hay que agregar ese host a
> `host_permissions` en `manifest.json` y recargar la extensión. Chrome no deja que una
> extensión postee a un host que no declaró.

---

## Uso diario

1. Abrí en MercadoLibre la publicación del competidor.
2. Clic en el icono de la extensión.
3. El popup se completa solo: **ID**, **título** y **precio** leídos de la página.
4. Elegí **tu publicación** en el desplegable — a cuál de tus productos le compite.
5. Revisá el precio y clic en **"Guardar a PricingML"**.

El popup confirma qué pasó:

- **Alta**: `Competidor vinculado a "<tu producto>".`
- **Actualización**: `Precio actualizado en "<tu producto>": antes 15999, ahora 14500.`

### Por qué elegís la publicación a mano

Antes esto intentaba adivinar el producto por parecido de título. Se sacó a propósito: un
match equivocado vincula un competidor al producto errado **en silencio**, y ese precio entra
derecho al cálculo de tu precio de venta. Es un error carísimo de detectar después. Elegir del
desplegable son dos segundos y no tiene ese riesgo.

### Moneda

Se usa la **Moneda Principal** de la empresa dueña de esa publicación, la misma que sugiere el
panel de competidores de la app. Si la publicación no la tiene configurada, el popup te avisa
y no guarda nada.

---

## Dónde ver lo capturado

En la app: **Publicación → "Competidores vinculados"**. Ahí aparecen el link al competidor, su
título, la moneda y el último precio, con el mismo botón **"Actualizar precio"** de siempre si
lo querés corregir a mano.

Cada captura además inserta una fila en `CompetenciaSnapshot`, que es lo que lee
`spCalcularDecision` para que el competidor pese en la recomendación de precio.

---

## Estructura

```
PricingML-Extension/
├── manifest.json          # Manifest V3: permisos y hosts declarados
├── src/
│   ├── popup.html         # Formulario y panel de configuración
│   ├── popup.js           # Lee la pestaña, carga tus publicaciones, postea al Motor
│   └── background.js      # Service worker: solo la URL por defecto al instalar
├── icons/
│   ├── icon.svg
│   └── icon-{16,48,128}.png
├── GENERATE_ICONS.sh
└── README.md
```

No hay content script: el popup lee la pestaña con `chrome.scripting` en el momento en que lo
abrís. Así el dato nunca queda viejo si cambiás de artículo.

---

## Flujo técnico

```
Popup abierto
  └─ chrome.scripting lee la pestaña de ML → ID, título, precio
  └─ GET  /api/marketplace/ml/publicaciones          → puebla el desplegable
         ↓ (elegís publicación, clic en Guardar)
  └─ POST /api/marketplace/ml/publicaciones/{id}/competidores
         Authorization: Bearer <token>
         { competidorItemID, competidorTitulo, monedaID, precio }
              ↓
         MercadoLibreSyncService.VincularCompetidorAsync
           ├─ ¿ya existe el vínculo? → UPDATE del precio
           └─ si no                  → INSERT del vínculo
           └─ en los dos casos: INSERT en CompetenciaSnapshot
              ↓
         { vinculoID, esNuevo, precioAnterior }
```

Es el **mismo** endpoint que usa el panel de competidores de la app web: capturar desde el
navegador y cargar a mano son la misma operación, así que hay un solo camino en el Motor.

---

## Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| "Configurá la URL del Motor y tu token" | Falta el token | Configuración → pegar el token |
| "Token inválido o vencido" (401) | La sesión expiró | Volver a copiar el token desde la app |
| "Tu usuario es de solo lectura" (403) | El usuario no es ADMIN | Usar un token de un usuario ADMIN |
| "No se pudo conectar con el Motor" | Motor apagado, o host no declarado | Verificar `http://localhost:5000/swagger` y `host_permissions` |
| "No tenés publicaciones activas" | No hay publicaciones en la base | Sincronizar publicaciones desde la app primero |
| "Esa publicación no tiene Moneda Principal" | Falta configurarla | Cargar la Moneda Principal de la empresa |
| El popup no completa los datos | No es una página de artículo | Abrir una URL `articulo.mercadolibre.com...` |

---

## Seguridad

- **Datos públicos**: solo se lee lo que ya está en pantalla (título, precio).
- **Sin credenciales de ML**: la extensión nunca pide ni usa tu login de MercadoLibre.
- **Detrás del login**: el endpoint exige token de sesión y rol ADMIN, como el resto de la app.
- **Nada sale a internet**: los datos van únicamente al Motor, en tu red.
- El token viaja por **HTTP** en desarrollo. En producción, poner el Motor detrás de HTTPS.
