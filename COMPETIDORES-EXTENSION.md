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

## Cómo funciona

Para entender paso a paso qué hace la extensión, desde que clickeas el icono hasta que el Motor
guarda los datos, consultá la guía visual interactiva:

**[📖 Cómo funciona PricingML Extension](https://claude.ai/code/artifact/6f854c89-113d-402c-bf75-88369ecf9f64)**

Ese documento tiene:
- El flujo completo en 10 pasos (desde que abres MercadoLibre hasta que se guardan datos)
- Ejemplos reales de datos (IDs, precios, respuestas del Motor)
- Cómo distingue "primera captura" de "recaptura con actualización"
- Flujos de error (token vencido, Motor apagado, sin permisos)
- Por qué es seguro (no automatiza ML, valida en el Motor, sesión de 12h)

---

## Instalación

### 1. Cargar en Chrome

No hay nada que compilar ni generar: la carpeta ya viene lista.

1. Ir a `chrome://extensions/` (en Edge, `edge://extensions/`)
2. **Activar "Modo de desarrollador"** (toggle arriba a la derecha). Si lo apagas, Chrome esconde
   las extensiones sin empaquetar. Es crítico que quede **prendido**.
3. Clic en **"Cargar extensión sin empaquetar"**
4. **Elegir la carpeta que contiene `manifest.json` directamente adentro:**
   ```
   C:\Proyectos\PricingML\PricingML-Extension
   ```
   **No es la raíz del repo** (`C:\Proyectos\PricingML`), **ni tampoco `src\`**. Tiene que ser
   la carpeta donde ves estos archivos: `manifest.json`, `src/`, `icons/`, etc.

5. La extensión aparecerá en la lista. **En Edge**, la ruta es `edge://extensions/` en lugar de
   `chrome://extensions/`, pero el resto es igual.

### 2. Fijarla en la barra (obligatorio)

Chrome no muestra sola el icono en la barra de herramientas. Tenés que fijarlo:

1. Clic en el **🧩** (puzzle) a la derecha de la barra de direcciones
2. Buscar **"PricingML Competitor Capture"**
3. Clic en el **📌 alfiler** al lado
4. El icono azul de PricingML debe quedar visible al lado de la barra de búsqueda

### 2. Sesión: no hay nada que configurar

El endpoint que usa la extensión está detrás del login y exige rol **ADMIN**, igual que
cualquier otra escritura de la app. Pero **no tenés que copiar ningún token**: la extensión
toma la sesión que ya tenés abierta en PricingML.

El único requisito es tener **PricingML abierto en alguna pestaña y logueado**. La extensión
busca entre las pestañas locales, lee el token de sesión del cliente web y lo reusa. Las
sesiones duran 12 horas; cuando una vence, la extensión vuelve a leer la nueva sola, así que en
la práctica nunca te pide nada.

Si no encuentra sesión, el popup te avisa y te ofrece un botón para abrir PricingML.

El token queda en `chrome.storage.local` — o sea en esta máquina y nada más, a propósito no se
usa `sync`, que lo replicaría a tu cuenta de Google. Nunca se manda a MercadoLibre: únicamente
viaja al Motor, en el header `Authorization`.

Lo único configurable es la **URL del Motor** (por defecto `http://localhost:5000`), en
**Configuración** dentro del popup.

> Si el Motor corre en algo que no sea `localhost` ni `127.0.0.1`, hay que agregar ese host a
> `host_permissions` en `manifest.json` y recargar la extensión. Chrome no deja que una
> extensión lea ni postee a un host que no declaró.

---

## Uso diario

1. Abrí en MercadoLibre la publicación del competidor.
2. Clic en el icono de la extensión.
3. El popup se completa solo: **ID**, **título** y **precio** leídos de la página. Si la
   publicación está con descuento, toma el precio **vigente**, no el tachado.
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
│   ├── icon.svg           # Diseño de referencia
│   └── icon-{16,48,128}.png
├── generar-iconos.py      # Solo si se cambia el diseño del icono
├── tests/                 # Pruebas automáticas (ver tests/README.md)
└── README.md
```

Los PNG del icono están versionados: `generar-iconos.py` los rehace con Python pelado (sin
ImageMagick ni librerías) y solo hace falta correrlo si se toca el diseño.

No hay content script: el popup lee la pestaña con `chrome.scripting` en el momento en que lo
abrís. Así el dato nunca queda viejo si cambiás de artículo.

---

## Flujo técnico

```
Popup abierto
  └─ chrome.scripting lee la pestaña de ML → ID, título, precio
  └─ chrome.scripting lee localStorage de la pestaña de PricingML → token de sesión
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
| **No aparece en `chrome://extensions/`** | Modo de desarrollador apagado, o se eligió otra carpeta | Prender el toggle (arriba a la derecha) y elegir la carpeta que tiene `manifest.json` adentro: `...\PricingML\PricingML-Extension` |
| **Aparece en la lista pero no hay icono en la barra** | Chrome no fija automáticamente las extensiones nuevas | Clic en 🧩 (puzzle) → buscar "PricingML" → clic en 📌 (alfiler) al lado |
| **"Could not load icon" al cargar la extensión** | Falta el `git pull` con los PNG del icono | `git pull` para traer `icons/icon-{16,48,128}.png`, luego **Recargar** la extensión en `chrome://extensions/` |
| "No encontré una sesión de PricingML abierta" | La app no está abierta o no hay login | Abrir PricingML y loguearse |
| "Tu sesión de PricingML venció" (401) | Pasaron las 12 horas | Volver a iniciar sesión en la app |
| "Tu usuario es de solo lectura" (403) | El usuario no es ADMIN | Iniciar sesión con un usuario ADMIN |
| "No se pudo conectar con el Motor" | Motor apagado, o host no declarado | Verificar `http://localhost:5000/swagger` y `host_permissions` en `manifest.json` |
| "No tenés publicaciones activas" | No hay publicaciones en la base | Sincronizar publicaciones desde la app primero |
| "Esa publicación no tiene Moneda Principal" | Falta configurarla | Cargar la Moneda Principal de la empresa |
| El popup no completa los datos | No es una página de artículo | Abrir una URL `articulo.mercadolibre.com...` |
| El precio que completa no es el que veo | El PDP de ML cambió de markup | Corregirlo a mano y avisar: hay que actualizar `extraerDatosDelArticulo` |

---

## Seguridad

- **Datos públicos**: solo se lee lo que ya está en pantalla (título, precio).
- **Sin credenciales de ML**: la extensión nunca pide ni usa tu login de MercadoLibre.
- **Detrás del login**: el endpoint exige token de sesión y rol ADMIN, como el resto de la app.
- **Nada sale a internet**: los datos van únicamente al Motor, en tu red.
- El token viaja por **HTTP** en desarrollo. En producción, poner el Motor detrás de HTTPS.
