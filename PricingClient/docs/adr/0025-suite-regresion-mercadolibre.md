# Suite de regresión de MercadoLibre

Tercera de las cuatro suites pendientes de este pedido (ver ADR 0021, 0023,
0024): **MercadoLibre** (ver ADR 0005-0011) — la integración más grande del
sistema: OAuth, procesamiento de cola, sincronización de publicaciones y
ventas, aprobación humana y competidores vinculados a mano.

## Qué cubre

`C:\PricingEngine\tests\Run-PruebasMercadoLibre.ps1`, contra una API real ya
levantada y un servidor que simula lo justo de la API real de ML
(`Mock-MercadoLibreServer.py`, nuevo fixture permanente: OAuth, items,
price_to_win, orders/search y sites/search — no imita el resto de la API
real, solo lo que `MercadoLibreSyncService.cs` llama):

- **TC01** — Configuración ML: guardarla y leerla de vuelta.
- **TC02** — OAuth iniciar: cuenta válida (302 al dominio de auth correcto
  según `SiteId`) / cuenta inexistente (400).
- **TC03** — OAuth callback: sin `code`/`state`, o con un `state` inventado
  — ambos terminan en la página de error, sin tocar la Cuenta ML.
- **TC04** — OAuth callback exitoso (actualiza `AccessToken`/`RefreshToken`/
  `UserIDML`) y que el mismo `state` no se pueda reusar una segunda vez.
- **TC05** — Procesar cola (1ra corrida): renueva un token vencido contra
  el mock, procesa lo que no requiere aprobación, respeta el gate de
  aprobación (se salta lo pendiente), y maneja un error real de ML (precio
  rechazado) sin frenar el resto de la cola — verificando además que
  **ninguna fila `PENDIENTE` que ya existiera en la base antes de la
  suite se haya tocado** (ver nota de diseño abajo).
- **TC06** — Aprobación de cola: listar lo pendiente, aprobar una fila,
  rechazar otra.
- **TC07** — Procesar cola (2da corrida): la fila aprobada se procesa; la
  rechazada nunca se reprocesa (queda `PENDIENTE` para siempre, que es el
  comportamiento correcto de un rechazo).
- **TC08** — Competidor vinculado manualmente: buscar candidatos, vincular
  dos, listar, desvincular uno, listar de nuevo.
- **TC09** — Sincronizar publicaciones: catálogo (precio/estado +
  competencia vía `price_to_win`) y no catálogo (refresca el competidor
  que quedó vinculado a mano en TC08).
- **TC10** — Sincronizar ventas: agrega correctamente las unidades
  vendidas por ventana (7/15/30/60/90 días) desde `/orders/search`, con
  una distribución de órdenes fija y verificable a mano.

Fixture: **"Empresa QA ML"** (CUIT `30-00000005-1`), una Cuenta ML, cinco
publicaciones (`QA-ML-CATALOGO`, `QA-ML-NOCAT`, dos de aprobación y una
que el mock rechaza) y su cola — todo se crea y borra en cada corrida.

## Nota de diseño: la cola de ejecución no tiene alcance por empresa

`ProcesarColaAsync` y `GetColaPendienteAprobacionAsync` no filtran por
empresa: toman/listan TODAS las filas `PENDIENTE` (o pendientes de
aprobación) del sistema, sin importar a qué empresa pertenecen. Esto ya
existía antes de esta suite y no se tocó, pero significa que correr
"Procesar cola" durante la prueba podía, en principio, afectar filas
reales de otras empresas si las hubiera. La suite se protege de esto
explícitamente: al arrancar, guarda qué `ColaID` ya estaban `PENDIENTE`
antes de tocar nada, y después de cada corrida de "Procesar cola" verifica
que sigan exactamente igual. En la práctica había 5 filas así — leftovers
de `Run-PruebasMotor.ps1` con `RequiereAprobacion=1, Aprobado=NULL`, que
por eso mismo nunca las toma `ObtenerPendientesAsync` — y la suite
confirmó que siguieron intactas en las cinco corridas de validación.

## Defecto encontrado y corregido durante esta QA

**El callback de OAuth devuelve HTML con acentos corruptos para cualquier
cliente que no sea un navegador.** `Results.Content(TituloYMensaje(...), "text/html")`
en `Program.cs` nunca declaraba `charset=utf-8` en el header
`Content-Type` — solo el `<meta charset="utf-8">` dentro del HTML lo decía,
y los navegadores reales sí "sniffean" esa etiqueta y renderizan bien (por
eso nunca se notó a simple vista), pero cualquier cliente HTTP que decida
la codificación por el header en vez de mirar el body (como
`Invoke-WebRequest` de PowerShell, o cualquier integración futura) decodifica
mal los bytes UTF-8 de los acentos: `"Estado OAuth inválido o expirado"`
llegaba como `"Estado OAuth invǭlido o expirado"`. Se corrigió agregando
`; charset=utf-8` a las tres respuestas `Results.Content(...)` del
callback (éxito, código/estado faltante, y cualquier error de
`ProcesarCallbackAutorizacionAsync`).

## Validado

- Antes de la corrección: TC04 reproducido fallando específicamente en la
  verificación del mensaje de "state reusado" — confirmado leyendo el HTML
  crudo devuelto (`invǭlido` en vez de `inválido`), no solo por el
  resultado PASS/FAIL.
- Después de la corrección: 3 corridas limpias y consecutivas, consola y
  Excel exportado coinciden ("10 / 10 casos OK", `exit 0`) las tres veces.
- Limpieza confirmada tras la corrida final: sin "Empresa QA ML" ni sus
  publicaciones/cola remanentes, `ConfiguracionMercadoLibre` restaurada a
  su estado original (la tabla estaba vacía antes de esta suite — sigue
  vacía después), sin proceso `python.exe` del mock corriendo, y las 5
  filas `PENDIENTE` preexistentes de `Run-PruebasMotor.ps1` siguen
  exactamente igual que antes.

## Nota sobre `ConfiguracionMercadoLibre`: fila única y global, sin secreto legible

A diferencia de `ConfiguracionEmail` (que la suite de Login ya sabía
guardar/restaurar), acá había una dificultad extra: la API nunca devuelve
el `ClientSecret` real (solo un booleano `clientSecretConfigurado`), así
que "restaurar por API" después de sobrescribirlo hubiera perdido el
secreto real para siempre. La suite lo resuelve leyendo el valor real por
SQL directo ANTES de tocar nada, y restaurándolo también por SQL directo
al final — nunca a través de la API.

## Pendiente

Email queda como la última de esta misma tanda.
