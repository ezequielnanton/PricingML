# MercadoLibre: sincronización de entrada (precio/estado + competencia de catálogo)

Sentido de entrada de la integración con MercadoLibre: traer de ML lo que este
sistema no controla directamente, para que el motor decida con datos reales.

## Qué se agregó

`MercadoLibreSyncService.SincronizarPublicacionesAsync`, disparado por el botón
"Sincronizar ML" del header:

1. Para cada `PublicacionesML` no cerrada, `GET /items/{id}` (forma real de la API
   de ML) trae el precio y estado vigentes en la plataforma, y actualiza
   `PublicacionesML.PrecioActual`/`Estado` — por si algo cambió fuera de este
   sistema (ej. el vendedor lo tocó a mano en ML, o ML pausó la publicación).
2. Para publicaciones de catálogo (`EsCatalogo = 1`), `GET /items/{id}/price_to_win?version=v2`
   trae la competencia real del buy box. Si no estamos ganando, inserta una fila
   nueva en `CompetenciaSnapshot` (competidor + precio); si ya estamos ganando, no
   inserta nada — no hay un "competidor" distinto que registrar.

Reutiliza el mismo manejo de token (renovación automática) y la misma configuración
de credenciales (`ConfiguracionMercadoLibre` / `appsettings.json`) que ya existían
para el sentido de salida.

## Por qué no se sincronizan ventas (`MetricasVentasHist`) todavía

ML no tiene un endpoint simple de "ventas de los últimos N días" por publicación.
Esa información sale de la API de Órdenes (`/orders/search`), agregando histórico de
órdenes por item en ventanas de tiempo (7/15/30/60/90 días) — es un trabajo
sustancialmente distinto (batch/histórico) al de este pull puntual por publicación,
y se decidió dejarlo como una pieza aparte en vez de forzarlo en esta misma tanda.

## Por qué no hay competencia para publicaciones que no son de catálogo

`price_to_win` es específico de publicaciones de catálogo (donde ML arbitra un único
"buy box" entre vendedores del mismo producto). Para una publicación normal (no
catálogo) ML no expone un endpoint directo de "quién es mi competencia" — a lo sumo
se podría buscar por texto/categoría en `/sites/{site_id}/search` y tratar de
identificar competidores por heurística, lo cual es ambiguo y específico de cada
categoría de producto. Se dejó fuera de esta pieza en vez de construir una
heurística que no reflejaría de verdad cómo funciona ML.

## Bug real encontrado y corregido durante la prueba con mock

`competenciaActualizada` en la respuesta del endpoint decía `true` incluso cuando
`InsertarCompetenciaSnapshotAsync` no llegaba a insertar nada (caso "ya estamos
ganando el buy box"). El dato en la base quedaba correcto, pero el resumen que ve el
usuario mentía. Se corrigió haciendo que `InsertarCompetenciaSnapshotAsync` devuelva
si realmente insertó, y usando ese valor (no una bandera fija en `true`) para armar
el resumen.

## Probado con mock, no con la API real

Igual que el sentido de salida (ADR 0005): sin credenciales reales de ML todavía, se
implementó contra la forma real y documentada de `/items/{id}` y
`/items/{id}/price_to_win`, pero se validó de punta a punta contra un mock —
incluyendo el caso "estamos ganando" (no inserta competencia), "no estamos ganando"
(inserta competencia real) y la sincronización de precio/estado. El shape exacto de
`price_to_win` se leyó de forma defensiva (todos los campos opcionales) porque no
hay forma de confirmarlo en vivo sin una app real — al conectar una app real, vale
la pena revisar la respuesta real una vez y ajustar si algún nombre de campo difiere.
