# Competencia para publicaciones que no son de catálogo: vínculo manual asistido por búsqueda

MercadoLibre no define automáticamente quién es la competencia de una publicación
que no es de catálogo (a diferencia de catálogo, que tiene `price_to_win`). La única
fuente disponible es el buscador de ML (`GET /sites/{site_id}/search?q=...`), que
devuelve resultados de texto libre — no una relación de competencia curada por ML.

## Qué se agregó

- **`PublicacionCompetidoresManual`** (tabla nueva): vínculo explícito
  `PublicacionID` ↔ `CompetidorItemID`, creado únicamente cuando el usuario lo
  confirma — igual que la aprobación de precios (ADR 0009), ningún dato se acepta
  como válido sin decisión humana.
- **Buscador dentro de "Publicación ML"**: al abrir una publicación que no es de
  catálogo, una sección nueva permite buscar en ML por título y vincular candidatos
  de los resultados. El `site_id` de la búsqueda se infiere del propio prefijo del
  `MeliItemID` de la publicación (MLA/MLB/MLM/...), no hace falta que el usuario lo
  indique.
- **`SincronizarPublicacionesAsync`** ("Sincronizar ML"): para publicaciones que no
  son de catálogo, en vez de `price_to_win` (que no aplica ahí), refresca el precio
  de cada competidor vinculado a mano vía `GET /items/{id}` e inserta un snapshot
  nuevo en `CompetenciaSnapshot` — mismo destino que alimenta al motor, la única
  diferencia es la fuente del vínculo (manual vs `price_to_win`).

## Validado con mock

- Búsqueda: `GET /sites/MLA/search?q=...` devuelve candidatos con título, precio e
  item_id.
- Vincular / listar / desvincular: probado end-to-end por API.
- Sincronización: un competidor vinculado a una publicación no-catálogo se refresca
  correctamente en `CompetenciaSnapshot` al correr "Sincronizar ML".
- UI: sección visible dentro de "Publicación ML" solo para publicaciones no-catálogo
  con un registro abierto; error manejado con claridad cuando la Cuenta ML no tiene
  token configurado.

## Defecto pre-existente encontrado y corregido

El buscador del listado maestro-detalle de "Publicación ML" (`AbmRecordList`, campo
`MeliItemID`) devolvía `400 — El operador de filtro no es compatible` al buscar por
texto. Causa: `AdminReportsService.Kind()` clasifica el tipo de una columna por
heurística de nombre, y cualquier columna terminada en "ID" cae en `ColumnKind.Int`
— pero `MeliItemID`, `CategoriaID`, `CompetidorItemID` y `CompetidorVendedorID` son
`VARCHAR` con códigos de un sistema externo (ML, categorías), no un ID numérico
interno. Se agregó una lista explícita de excepciones (`IdsDeTexto`) para que esas
cuatro columnas se traten como texto.

Al corregirlo apareció un segundo bug, introducido por el fix: el `HashSet` estático
de excepciones se declaró *después*, en el código fuente, del campo `Definitions`
que lo usa indirectamente (vía `Kind()`) dentro de su propio inicializador estático
— los inicializadores de campos estáticos en C# corren en orden de declaración
textual, así que `Definitions` se inicializaba con `IdsDeTexto` todavía en `null`,
tirando abajo la API entera al arrancar (`NullReferenceException` en el constructor
estático). Se corrigió moviendo la declaración de `IdsDeTexto` antes de `Definitions`.

## Actualización: MercadoLibre bloquea toda forma de leer una publicación ajena por API — se reemplazó por carga manual

Esta ADR se escribió asumiendo que `GET /sites/{site}/search?q=...` seguía
funcionando como en años anteriores. Dejó de ser así: hoy devuelve
`403 {"message":"forbidden"}` para aplicaciones de terceros, con token válido o sin
él (confirmado contra la API real, y coincide con reportes de otros desarrolladores
en 2025). Se intentó un reemplazo — pegar el ID o link de la publicación competidora
y resolverlo vía `GET /items/{id}` (que en un primer test funcionó) — pero una
segunda ronda de pruebas contra un ítem que **no era de nuestra propia cuenta**
reveló que ese endpoint también está bloqueado para publicaciones ajenas:

```
GET /items/{id_propio}   → 200 OK, detalle completo
GET /items/{id_ajeno}    → 403 {"message":"...forbidden","error":"access_denied"}
```

Mismo resultado catálogo o no catálogo, con un token recién renovado (scope
completo `read write offline_access` + varios permisos de marketplace). Se revisó
además la documentación oficial vigente de MercadoLibre ("Items & Searches",
"Autenticación y Autorización", "Developer Partner Program"): confirman que la API
de items/búsquedas está scopeada explícitamente a *"within your seller account"*,
que los únicos scopes que existen son `read`/`write`/`offline_access` (no hay uno
más granular para leer catálogo ajeno), y que el Developer Partner Program certifica
apps que administran *muchas cuentas propias* (por volumen de GMV), no acceso a
datos de vendedores no relacionados. No hay ningún nivel de partner, scope, ni
endpoint alternativo (se probó `/marketplace/benchmarks/...` de "Pricing Reference"
también, exclusivo de ítems CBT y sin exponer el competidor puntual) que habilite
esto para una app estándar.

Se evaluó además leer la página pública del ítem por HTML en vez de por API
(`https://articulo.mercadolibre.com.ar/{id}`), pero un pedido HTTP de servidor
(sin navegador real detrás) es redirigido de inmediato a un desafío
anti-bot (`.../gz/account-verification`, "verificación de tráfico sospechoso") —
tanto para la búsqueda como para la página de un ítem puntual. No se construyó
nada para esquivar esa detección.

**Diseño final**: sin ninguna vía de MercadoLibre disponible para traer el precio
de un competidor —ni al vincularlo ni después—, el usuario carga todo a mano:

- **Vincular** (`POST /publicaciones/{id}/competidores`, `VincularCompetidorAsync`):
  el usuario escribe el ID o link de MercadoLibre (se normaliza con
  `ExtraerItemId` — sin llamar a ML, solo para guardar el ID en formato consistente:
  extrae el ID de un link real, o completa el prefijo de sitio si vino solo el
  número), el título, la moneda y el precio que ve en su propio navegador. Se
  guarda en `PublicacionCompetidoresManual` (con `MonedaID`,
  `UltimoPrecio`/`FechaUltimoPrecio`) y se inserta el primer snapshot en
  `CompetenciaSnapshot`.
- **Moneda por defecto** (`GET /publicaciones/{id}/moneda-principal`,
  `ObtenerMonedaPrincipalAsync`, nuevo): sugiere la Moneda Principal de la Empresa
  dueña de la publicación (`PublicacionesML → Productos → ParametrosGenerales
  .MonedaPrincipalID`) para no obligar a elegirla a mano cada vez; el usuario puede
  cambiarla igual.
- **Actualizar precio** (`PUT /publicaciones/{id}/competidores/{vinculoId}/precio`,
  `ActualizarPrecioCompetidorAsync`, nuevo): como el precio nunca se puede refrescar
  solo, el usuario lo puede reescribir cuando quiera — actualiza
  `UltimoPrecio`/`FechaUltimoPrecio` y agrega un snapshot nuevo a
  `CompetenciaSnapshot` (conserva el historial, no lo pisa). La moneda queda fija
  desde que se vincula.
- **`SincronizarPublicacionesAsync`** ("Sincronizar ML") **ya no intenta** refrescar
  estos vínculos — el intento anterior (`SincronizarCompetidoresManualesAsync`,
  vía `GET /items/{id}` del competidor) fallaba en silencio para cualquier
  competidor real por el mismo bloqueo, sin que nadie lo notara. Se quitó en vez de
  dejarlo fallando calladamente.
- **Frontend** (`CompetidoresManualPanel.jsx`): se rediseñó como una grilla
  (reutilizando `.data-table`/`.table-container`, el mismo estilo "tipo Excel" que
  ya usan los Reportes, sin introducir colores nuevos) con las columnas Publicación
  (el ID, como link que abre la publicación real de MercadoLibre en una pestaña
  nueva — se reconstruye a partir del ID guardado, `MLA1234` → `.../MLA-1234`),
  Título, Moneda (`FkAutocompleteInput` con `getFkLookup('MonedaID')`, mismo
  componente que ya usan los campos Moneda de otros formularios de este panel) y
  Precio. Una fila fija al final de la grilla es el alta de un competidor nuevo. Ya
  no hay ningún llamado a MercadoLibre en este panel.

Catálogo no se ve afectado por nada de esto: `price_to_win` siempre se llama con el
ID de la **propia** publicación (nunca con el ID de un competidor ajeno), así que
nunca pisa este bloqueo.
