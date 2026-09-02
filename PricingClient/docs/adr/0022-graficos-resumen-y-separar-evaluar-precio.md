# Gráficos en el Resumen de ventas y pantalla principal solo con el resumen

El usuario pidió que la pantalla principal (Pricing) muestre solo el
**Resumen de ventas** (ver ADR 0020), con algún gráfico de ventas — de
tendencia y de torta — y que el formulario de **Evaluación de precio**
deje de estar ahí.

## Restricción real de datos (por qué no hay un gráfico de ventas "diarias")

El sistema no guarda ventas por día: `MetricasVentasHist` solo guarda
totales acumulados por ventana rodante (`Ventas7D`, `Ventas15D`,
`Ventas30D`, `Ventas60D`, `Ventas90D`), sobreescritos en cada
sincronización con MercadoLibre — no hay forma de reconstruir cuánto se
vendió un día puntual (ver también la limitación ya documentada en ADR
0020). Se lo planteó explícitamente al usuario, que eligió el gráfico de
barras por ventana en vez de arrancar a trackear un historial diario nuevo
desde cero (que hubiera dejado el gráfico vacío hasta acumular varios días
reales) o quedarse solo con la torta.

## Qué se agregó

- **`GET /api/admin/resumen-ventas`** ahora devuelve también
  `ventasPorVentana`: un array `[{ dias: 7, unidadesVendidas }, ...]` para
  7/15/30/60/90 días, sumando `MetricasVentasHist` con el mismo `WHERE`
  (publicación abierta, producto activo) que ya usaba el cálculo de Venta
  Bruta Total. No se tocó el cálculo de Venta Bruta Total/Costo
  Total/Rentabilidad (siguen fijos en la ventana de 30 días).
- **`ResumenVentasCard.jsx`** agrega dos gráficos, ambos SVG hechos a mano
  (sin sumar ninguna librería de gráficos al proyecto, consistente con el
  resto de la app):
  - **Barras**: unidades vendidas por ventana (7D/15D/30D/60D/90D).
  - **Torta (donut)**: Costo Total vs. Rentabilidad, las mismas dos
    porciones que ya suman la Venta Bruta Total en las tarjetas de arriba.
    Si la Rentabilidad es negativa o no hay Venta Bruta Total, el
    componente no dibuja nada en vez de mostrar una torta sin sentido
    (dos porciones que no suman un 100% coherente).
- La pantalla principal (`/`) ahora renderiza únicamente
  `<ResumenVentasCard />`. El formulario de **Evaluación de precio** (y su
  panel de Resultado) se movió a una ruta nueva, `/evaluar-precio`, con su
  propia entrada en el menú lateral ("Evaluar precio", justo debajo de
  "Pricing").

## Permisos: por qué "Evaluar precio" no es una Sección nueva

"Evaluar precio" es la misma pantalla de siempre partida en dos rutas, no
una funcionalidad nueva — así que se gatea con el mismo permiso
`pricing` que ya existía (ver **Sección permitida**, ADR 0013), en vez de
crear una Sección nueva que un ADMIN tendría que salir a tildar a mano
para cada Usuario que ya podía evaluar precios. El único cambio fue en el
filtro de visibilidad del menú (`Sidebar.jsx`): el ítem `evaluar-precio`
se resuelve contra `hasSeccion('pricing')` en vez de `hasSeccion('evaluar-precio')`.
`SectionGuard` de la ruta `/evaluar-precio` también usa `seccion="pricing"`.

## Validado

- `GET /api/admin/resumen-ventas` devuelve `ventasPorVentana` con los 5
  puntos esperados, verificado a mano contra la fixture QA-TC01..08
  (7D=3, 15D=6, 30D=10, 60D=15, 90D=17 unidades).
- Probado en navegador real: la pantalla principal (`/`) muestra el
  Resumen de ventas con las barras y la torta, sin el formulario de
  Evaluación de precio; "Evaluar precio" aparece en el menú y navega a
  `/evaluar-precio`, donde el formulario y el panel de Resultado funcionan
  igual que antes.
- Un Usuario con la Sección `pricing` ve ambas entradas de menú
  (Pricing y Evaluar precio) sin necesitar ningún permiso adicional.
