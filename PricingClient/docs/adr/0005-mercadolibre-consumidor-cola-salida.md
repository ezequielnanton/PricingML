# MercadoLibre: consumidor de ColaEjecucionML (sentido de salida)

`spCalcularDecision` ya insertaba en `ColaEjecucionML` (`PENDIENTE`) cuando persistía
un cambio de precio en modo producción, pero nada la leía: el motor "decidía" un
nuevo precio y quedaba solo en la cola, sin llegar nunca a MercadoLibre. `PrecioActual`
de `PublicacionesML` tampoco se actualizaba en ese momento — solo se tocaba
`FechaUltimoCambioPrecio` (para el anti-oscilación). Esta pieza cierra ese circuito.

## Qué se agregó

`MercadoLibreSyncService.ProcesarColaAsync`, disparado por el botón "Procesar cola
ML" del header (mismo patrón que "Actualizar desde ERP"):

1. Lee las filas `PENDIENTE` de `ColaEjecucionML`, resolviendo la `CuentaMLID` de cada
   una vía `PublicacionesML`.
2. Si el `AccessToken` de esa Cuenta ML está vencido (o vence en menos de 5 minutos),
   lo renueva contra `POST /oauth/token` de ML (`grant_type=refresh_token`) antes de
   usarlo, y guarda el token/refresh/vencimiento nuevos en `CuentasML`.
3. Llama `PUT /items/{MeliItemID}` con `{"price": PrecioNuevo}` — la forma real de la
   API de MercadoLibre para actualizar el precio de una publicación.
4. Si ML confirma el cambio: marca la fila `PROCESADO` y recién ahí actualiza
   `PublicacionesML.PrecioActual` — porque hasta ese momento el precio nuevo era solo
   una intención, no un hecho confirmado en la plataforma.
5. Si ML rechaza el cambio (o falla la llamada): marca la fila `ERROR` con el mensaje
   real devuelto por ML en `MensajeError`, sin frenar el resto del lote.

Los tokens de `CuentasML` reutilizan las columnas que ya existían
(`AccessToken`/`RefreshToken`/`FechaVencimientoToken`, agregadas en una pieza
anterior de esta misma sesión) — no hizo falta ningún cambio de schema.

## Probado con mock, no con la API real

No hay credenciales reales de una app de MercadoLibre todavía (`client_id`/`client_secret`
en `appsettings.json` quedan vacíos). Se implementó contra la forma real y documentada
de la API (`/oauth/token`, `PUT /items/{id}`), pero se validó de punta a punta contra
un servidor mock que imita esos dos endpoints — incluyendo el camino de éxito, el de
error (ML rechaza el precio) y el de renovación de token. Cuando haya una app real de
ML, conectar es solo completar `MercadoLibre:ClientId`/`ClientSecret` y cargar el
primer `AccessToken`/`RefreshToken` real en la Cuenta ML correspondiente — el código
no cambia.

## Client ID/Secret configurables desde la UI

`ClientId`/`ClientSecret` de la app de ML no quedaron fijos solo en
`appsettings.json`: se agregó `ConfiguracionMercadoLibre` (fila única, una app por
instalación) y la pantalla "Integración MercadoLibre" para cargarlos sin editar
archivos de configuración a mano. `appsettings.json` queda como default de arranque;
si hay una fila guardada en la base, esa tiene prioridad. El secreto nunca se
devuelve por la API una vez guardado (`GET` solo informa `clientSecretConfigurado:
true/false`) — dejar el campo vacío al guardar conserva el que ya está, igual que la
`ApiKeySaliente` de `ErpConexiones`. Se guarda en texto plano, consistente con cómo
ya se guardan `AccessToken`/`RefreshToken` de `CuentasML` y `ApiKeySaliente` de
`ErpConexiones` en este mismo proyecto — no se introdujo cifrado en reposo para este
campo sin tenerlo para los demás.

## Disparo manual, no automático

Igual que con el ERP, el procesamiento de la cola es manual (botón), no un
`BackgroundService` con temporizador. El método `ProcesarColaAsync` está aislado y no
depende de nada del pipeline HTTP, así que envolverlo en un worker programado más
adelante es un cambio chico y contenido — se posterga hasta que haga falta correr
esto sin intervención humana.
