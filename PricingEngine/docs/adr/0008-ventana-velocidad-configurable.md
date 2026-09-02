# Ventana de velocidad de venta configurable (REGLA_OPORTUNIDAD)

`MetricasVentasHist` ya guardaba `Ventas7D`/`15D`/`30D`/`60D`/`90D`, pero
`spCalcularDecision` solo leía `VelocidadVentaDiaria` (siempre `Ventas30D / 30`,
fijo) para decidir si `REGLA_OPORTUNIDAD` dispara y para estimar días de stock. Las
demás ventanas quedaban guardadas pero sin ningún efecto en la decisión.

## Qué se agregó

Un nuevo parámetro `VENTANA_VELOCIDAD_DIAS` para `REGLA_OPORTUNIDAD`, cargado con el
mismo mecanismo que ya usan los demás parámetros de reglas
(`EstrategiaReglaParametros`, editable desde la pantalla "Parámetros de Regla" que
ya existía — no hizo falta ninguna UI nueva). Acepta `7`, `15`, `30`, `60` o `90`;
cualquier otro valor (o ausencia de configuración) cae en el default de `30`, que es
el comportamiento que tenía el motor antes de este cambio.

`spCalcularDecision` calcula la velocidad con un `CROSS APPLY` que elige la columna
correspondiente (`Ventas7D/7.0`, `Ventas15D/15.0`, etc.) según ese parámetro, en vez
de leer siempre `VelocidadVentaDiaria`. Esa velocidad calculada alimenta tanto la
condición de disparo de `REGLA_OPORTUNIDAD` (`CantCompetidores = 0 OR Velocidad >
1.0`) como la estimación de `DiasStock` y el bono de `ScoreConfianza`.

## Validado

- La suite de regresión (`Run-PruebasMotor.ps1`) sigue en 10/10 sin ningún parámetro
  configurado (comportamiento default = 30 días, igual que antes).
- Prueba manual sobre TC05 (exceso de stock, gana `REGLA_EXCESO_STOCK` por defecto):
  con `Ventas30D` bajo pero `Ventas7D` alto, configurar `VENTANA_VELOCIDAD_DIAS=7`
  hace que `REGLA_OPORTUNIDAD` (prioridad 3) pase a ganarle a `REGLA_EXCESO_STOCK`
  (prioridad 4) — la decisión cambia de `DISMINUIR_PRECIO` a `AUMENTAR_PRECIO` con el
  mismo stock y la misma competencia, solo cambiando la ventana.
