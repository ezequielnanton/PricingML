# Workflow de aprobación para la cola de MercadoLibre

Antes de esta pieza, "Procesar cola ML" subía a MercadoLibre cualquier cambio de
precio que el motor hubiera calculado, sin que nadie lo revisara primero. Eso es
razonable para publicaciones de catálogo (la competencia viene de `price_to_win`,
una fuente confiable y verificada por ML), pero no para publicaciones que no son de
catálogo, donde hoy no hay ninguna fuente automática de competencia — un cambio de
precio ahí podría estar basado en datos viejos, incompletos o mal cargados a mano.

## Qué se agregó

- **`ParametrosGenerales.SubidaAutomaticaCatalogoML`** (bit, por Empresa, editable
  desde "Parámetro General"): si está activo, las publicaciones de **catálogo** suben
  el precio a ML sin aprobación humana. Si está apagado (default), piden aprobación
  igual que las que no son de catálogo.
- **Las publicaciones que NO son de catálogo siempre piden aprobación**, sin
  excepción — este flag nunca las salta.
- `ColaEjecucionML` ahora es autocontenida para la revisión: se agregaron `Motivo`,
  `CompetidorItemIDRef`, `PrecioCompetidorRef`, `RequiereAprobacion`, `Aprobado`
  (`NULL` = esperando revisión, `1`/`0` = aprobado/rechazado) y `FechaAprobacion`.
  `spCalcularDecision` las llena al persistir, sin necesitar un join a
  `DecisionesHistorial` para mostrar el contexto completo en la pantalla de revisión.
- **`DecisionesHistorial.CompetidorItemIDRef`** (nueva columna): igual que
  `PrecioCompetenciaRef` pero para el item_id del competidor puntual contra el que se
  comparó — antes solo se guardaba el precio, no de quién.
- El motor identifica ese competidor puntual con un `OUTER APPLY` nuevo, aparte del
  cálculo existente de `CompMinPrecio`/`CompRelevantePrecio` (que no se tocó): prioriza
  el más barato entre los "relevantes" (`NivelRelevancia=1`); si no hay ninguno, el más
  barato en general. No cambia ningún precio calculado, solo agrega la referencia.
- **Pantalla "Cola ML (Aprobación)"**: lista lo pendiente de revisión con nuestro
  precio actual → sugerido, el motivo en lenguaje de negocio, y un **link real** a la
  publicación del competidor (`https://articulo.mercadolibre.com.ar/{item_id}`, con
  mapeo de dominio según el prefijo del item — MLA/MLB/MLM/MLC). Aprobar/Rechazar por
  fila.
- `MercadoLibreSyncService.ProcesarColaAsync` ("Procesar cola ML") ahora solo toma
  filas con `RequiereAprobacion = 0` o `Aprobado = 1` — nunca procesa una fila
  rechazada ni una que sigue esperando revisión.

## Validado

- Suite de regresión del motor: 10/10 sin cambios (el flag nuevo defaultea a `0`,
  comportamiento "pide aprobación siempre" — no afecta ningún cálculo de precio).
- Prueba manual: publicación no-catálogo → `RequiereAprobacion=1`, `Aprobado=NULL`.
  Misma publicación marcada catálogo + `SubidaAutomaticaCatalogoML=1` para la
  empresa → `RequiereAprobacion=0`, `Aprobado=1` (nace ya aprobada).
- Aprobar/Rechazar por API: saca la fila de la lista de pendientes; reintentar sobre
  una fila ya decidida devuelve 404 (no se puede aprobar/rechazar dos veces).
- Competidor puntual verificado contra los fixtures de QA: `TC03`→`MLA-COMP-TC03`
  ($9000), `TC05`→`MLA-COMP-TC05` ($10800), `TC07`→`MLA-COMP-TC07` ($8000); `TC04`
  (sin competidores) queda `NULL` correctamente.
