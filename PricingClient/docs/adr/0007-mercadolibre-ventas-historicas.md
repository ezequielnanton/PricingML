# MercadoLibre: ventas históricas vía API de Órdenes (MetricasVentasHist)

Completa el sentido de entrada de MercadoLibre con lo que había quedado afuera en
el ADR 0006: `MetricasVentasHist` (`VentasHoy`/`7D`/`15D`/`30D`/`60D`/`90D`,
`VelocidadVentaDiaria`, `TendenciaPorc`), que `spCalcularDecision` usa para
`REGLA_OPORTUNIDAD` (velocidad de venta alta) y como contexto de decisión.

## Qué se agregó

`MercadoLibreSyncService.SincronizarVentasAsync`, disparado por el mismo botón
"Sincronizar ML" del header (junto con la sincronización de precio/competencia del
ADR 0006, en un solo click vía `Promise.all`):

1. Por cada Cuenta ML, trae sus órdenes pagas de los últimos 90 días vía
   `GET /orders/search?seller={UserIDML}&order.status=paid&order.date_created.from=...&order.date_created.to=...`
   (forma real de la API de Órdenes de ML), paginando hasta agotar los resultados.
2. Agrupa las cantidades vendidas por `MeliItemID` y por día.
3. Calcula las ventanas (`VentasHoy` = hoy; `Ventas7D`/`15D`/`30D`/`60D`/`90D` = suma
   de los últimos N días incluyendo hoy) y `VelocidadVentaDiaria` = `Ventas30D / 30`.
4. `TendenciaPorc` compara `Ventas15D` contra los 15 días previos a esos (días 16 a
   30): `(Ventas15D - Previos15D) / Previos15D * 100`, con guarda para división por
   cero.
5. Hace `MERGE` (upsert) en `MetricasVentasHist` por `PublicacionID` — la tabla tiene
   una fila por publicación (`UQ_MetricasVentas_Publicacion`), no un historial de
   filas; el nombre "Hist" se refiere a que guarda ventanas históricas de venta, no a
   que sea una tabla de auditoría append-only.

## Por qué no se hizo antes (y por qué ahora sí se justificaba)

En el ADR 0006 se separó esto explícitamente porque requiere agregación temporal
sobre un endpoint distinto (Órdenes, no Items), con paginación y ventanas de tiempo
— más superficie que un GET puntual. No cambió nada de esa evaluación; se hizo ahora
porque el usuario priorizó completar el tema en esta sesión.

## Probado con mock, no con la API real

Igual que el resto de la integración ML: se armó un dataset de órdenes con
cantidades conocidas en distintos rangos de antigüedad (hoy, 3, 10, 20, 50 y 85
días) para verificar cada ventana a mano. Todos los cálculos coincidieron
exactamente con lo esperado, incluida la tendencia (15D vs 15D previos). No hay
credenciales reales de MercadoLibre para probar contra `/orders/search` en vivo.
