# Resumen de ventas en la pantalla principal

El usuario pidió ver, al entrar al sistema (pantalla Pricing), la venta
bruta total, cuánto de esa venta corresponde al costo total, y la
rentabilidad.

## Limitación real de los datos (por qué es una aproximación)

El sistema no guarda un historial de órdenes/ventas (precio y costo al
momento exacto de cada venta) — `MetricasVentasHist` guarda solo
**cantidades** por ventana rodante (`Ventas7D`, `Ventas30D`, etc.), una fila
por publicación, sobreescrita en cada sincronización. No hay forma de saber
a qué precio se vendió cada unidad en el pasado.

Por eso el cálculo es: **unidades vendidas en la ventana × precio/costo
ACTUAL** de la publicación — no la venta real histórica. Es una
aproximación razonable (asume que el precio no cambió durante la ventana),
pero hay que dejarlo explícito en la pantalla para no generar una
expectativa de precisión contable que el dato no puede cumplir. Se eligió
una ventana fija de **30 días** (mismo default que ya usa el motor para la
velocidad de venta, ver ADR 0008) en vez de "todo el histórico", que no
existe como concepto real acá.

## Fórmula (mismos componentes de costo que ya usa el motor)

- **Venta Bruta Total** = Σ (unidades vendidas × Precio Actual) — literalmente
  lo que pagó el cliente, sin descontar nada.
- **Costo Total** = Σ (unidades vendidas × Costo Unitario), donde Costo
  Unitario usa los mismos componentes que `dbo.fn_CalcularMargenNetoPorc`
  (Costo de Compra + Comisión ML + Envío + Logística + Financiero +
  Publicidad) — **sin** tocar esa función ni `spCalcularDecision`, para no
  arriesgar el motor de precios por una pantalla de reporte.
- **Rentabilidad** = Venta Bruta Total − Costo Total (a propósito, no la
  fórmula con IVA neteado que usa el motor para decidir precios) — así los
  tres números que ve el usuario se pueden verificar a simple vista con una
  resta, que es lo que pidió.

Nota: `CostosProducto.OtrosCostosFijos` e `ImpuestosInternos` existen en la
tabla pero **no** están en `fn_CalcularMargenNetoPorc` ni se usan acá
tampoco — se mantuvo la misma definición de "costo" que ya usa el motor en
todo el resto de la app, para que este número sea consistente con
`MargenActualPorc` en vez de divergir con una definición de costo distinta.

## Validado

- El cálculo se verificó a mano contra un producto real de la base
  (`QA-TC01`: 10 unidades × $10.000 = $100.000 venta bruta; costo unitario
  $4.264 → $42.640 costo total; $57.360 / 57,36% de rentabilidad) — coincide
  exacto con lo que devuelve el endpoint.
- Probado en navegador real: la tarjeta "Resumen de ventas" aparece arriba
  del formulario de Pricing al entrar, con los tres números y el rótulo de
  la ventana de 30 días.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios
  — no se tocó ningún objeto del motor de pricing.
