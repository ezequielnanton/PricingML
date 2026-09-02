# QA del Motor de Pricing (`spCalcularDecision`)

Este documento describe los casos de uso y los casos de prueba automatizados
que validan el motor de cálculo de precios (el stored procedure
`dbo.spCalcularDecision`). Sirve como referencia funcional y como checklist
de regresión: después de cualquier cambio en el motor, en las reglas de
negocio o en sus parámetros, hay que volver a correr la suite y confirmar
que los 10 casos siguen dando el mismo resultado.

## Cómo correr la suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PricingEngine\tests\Run-PruebasMotor.ps1
```

El script:

1. Re-siembra datos de prueba fijos (`SQL/Seed-PruebasMotor.sql`) — es
   idempotente, se puede correr las veces que haga falta y siempre deja los
   productos `QA-TC01`..`QA-TC08` en el mismo estado inicial. También limpia
   lo que haya quedado en `ColaEjecucionML` y `DecisionesHistorial` de
   corridas anteriores para esas publicaciones, así no se van acumulando
   filas de prueba corrida tras corrida.
2. Ejecuta `dbo.spCalcularDecision` para cada caso.
3. Compara acción, precio sugerido y motivo contra lo esperado.
4. Exporta todo a `tests/Resultados-Motor-Pricing.xlsx` (PASS en verde,
   FAIL en rosa) y termina con código de salida 1 si algo falló.

Si el script marca un FAIL, revisar la columna `Detalle` de esa fila en el
Excel: indica exactamente qué no coincidió (acción, precio o motivo).

## Datos de prueba (fixture)

Empresa **"Empresa QA Motor"** (CUIT `30-00000000-1`), cuenta ML
**"QA_MOTOR_ML"** y estrategia **"Estrategia QA Motor"**, con las 4 reglas de
negocio activas y priorizadas así (menor número = mayor prioridad):

| Prioridad | Regla                     | Efecto por defecto                                  |
|-----------|---------------------------|-------------------------------------------------------|
| 1         | `REGLA_STOCK_CRITICO`     | +5% si `StockDisponible <= StockMinimo`               |
| 2         | `REGLA_COMPETENCIA_ABAJO` | precio = competidor × (1 − 1%) si compite más barato   |
| 3         | `REGLA_OPORTUNIDAD`       | +3% si no hay competidores o hay buena velocidad       |
| 4         | `REGLA_EXCESO_STOCK`      | −7% si `ClasificacionStock = EXCESO`                   |

"Buena velocidad" en `REGLA_OPORTUNIDAD` significa `VelocidadVentaDiaria > 1.0`, que
por defecto sale de `Ventas30D / 30`. Se puede pedir que use otra ventana
(`Ventas7D`, `15D`, `60D` o `90D`) con el parámetro `VENTANA_VELOCIDAD_DIAS` de
`REGLA_OPORTUNIDAD` en "Parámetros de Regla" (valores válidos: 7/15/30/60/90;
cualquier otro valor cae en el default de 30). Ver ADR 0008.

Todos los productos de prueba (`QA-TC01`..`QA-TC08`) parten de
`PrecioActual = 10000` y `FechaUltimoCambioPrecio = NULL` (para que el
bloqueo anti-oscilación no interfiera salvo en el caso que lo prueba
específicamente).

## Casos de uso cubiertos

1. **Ajuste por stock crítico**: proteger contra quiebre de stock subiendo
   el precio cuando el disponible cae por debajo del mínimo.
2. **Ninguna regla aplica**: el motor no debe inventar cambios cuando no hay
   ninguna condición que los justifique.
3. **Reacción a competencia más barata**: bajar el precio para quedar por
   debajo del competidor relevante, sin regalar margen de más.
4. **Oportunidad de suba**: si no hay presión competitiva y el stock está
   sano, capturar margen adicional.
5. **Liquidación por exceso de stock**: bajar el precio para acelerar la
   rotación cuando sobra stock.
6. **Piso de seguridad por margen**: nunca bajar un precio si eso perfora el
   margen neto mínimo configurado, aunque la regla de competencia lo pida.
7. **Piso de seguridad por publicación**: si el precio calculado por
   competencia cae por debajo del `PrecioMinimoPermitido` de la publicación,
   se ajusta (clampa) a ese mínimo en lugar de rechazarlo.
8. **Anti-oscilación por variación mínima**: no mover el precio por cambios
   insignificantes (menores al umbral configurado), para evitar "flapping".
9. **Modo Simulación vs Producción**: el modo simulación (`/pricing/evaluate`,
   `ContextSource='TEMP'`) debe evaluar únicamente los datos que el usuario
   ingresa a mano, ignorando la competencia real que ese mismo producto
   pueda tener en la base — es una foto hipotética, no debe leer ni escribir
   nada de producción.
10. **Persistencia y trazabilidad**: cuando se persiste una decisión con
    cambio de precio, tiene que quedar registrada en `DecisionesHistorial`,
    encolada para ejecución en `ColaEjecucionML`, y debe actualizar
    `FechaUltimoCambioPrecio` (que es lo que alimenta el anti-oscilación de
    la próxima corrida).

## Casos de prueba

| Caso | Producto            | Qué prueba                                                        | Resultado esperado                                             |
|------|----------------------|--------------------------------------------------------------------|------------------------------------------------------------------|
| TC01 | QA-TC01 (stock 3/10/100, sin competencia) | `REGLA_STOCK_CRITICO`                        | `AUMENTAR_PRECIO` a $10500.00, motivo menciona "CRÍTICO"          |
| TC02 | QA-TC02 (stock bajo, competidor más caro) | Ninguna regla dispara                        | `MANTENER_PRECIO` en $10000.00                                    |
| TC03 | QA-TC03 (competidor relevante a $9000)    | `REGLA_COMPETENCIA_ABAJO`                    | `DISMINUIR_PRECIO` a $8910.00 (1% debajo del competidor)           |
| TC04 | QA-TC04 (sin competidores, stock normal)  | `REGLA_OPORTUNIDAD`                          | `AUMENTAR_PRECIO` a $10300.00                                      |
| TC05 | QA-TC05 (stock en exceso, competidor más caro) | `REGLA_EXCESO_STOCK`                    | `DISMINUIR_PRECIO` a $9300.00                                      |
| TC06 | QA-TC06 (competidor barato, costo alto)   | Bloqueo por margen mínimo                    | `NO_MODIFICAR`, motivo "BLOQUEO SEGURIDAD"                         |
| TC07 | QA-TC07 (competidor a $8000, mínimo publicación $8500) | Clamp al `PrecioMinimoPermitido`| `DISMINUIR_PRECIO` a $8500.00 (no a $7920), motivo "Límite Mínimo" |
| TC08 | QA-TC08 (competidor a $9970, variación < 1.5%) | Bloqueo anti-oscilación por variación mínima | `MANTENER_PRECIO`, motivo "COOLDOWN"                          |
| TC09 | QA-TC03 evaluado en modo TEMP             | Simulación ignora competencia real de la base | `AUMENTAR_PRECIO` a $10300.00 (gana `REGLA_OPORTUNIDAD`, no ve al competidor de TC03) |
| TC10 | QA-TC01 (efectos colaterales de persistir TC01) | Persistencia deja rastro             | Fila en `ColaEjecucionML` (PENDIENTE, $10500), `FechaUltimoCambioPrecio` seteada, fila en `DecisionesHistorial` |

## Defectos encontrados y corregidos durante esta QA

1. **Motivo NULL al no haber competidores** (`spCalcularDecision.sql`): el
   armado del texto de `Motivo` usaba `REPLACE(..., CAST(ISNULL(comp1, comp2)
   AS VARCHAR(20)), ...)`; en SQL Server, `REPLACE` devuelve `NULL` si
   cualquiera de sus argumentos es `NULL` — incluido el valor a insertar —
   aunque el placeholder `{COMPETIDOR_PRECIO}` ni siquiera esté presente en
   el texto. Con cero competidores, esto dejaba `Motivo = NULL`, y como la
   columna es `NOT NULL`, la persistencia fallaba con
   `Cannot insert the value NULL into column 'Motivo'`. Se corrigió
   envolviendo cada reemplazo con `ISNULL(..., 'N/D')`.
2. **Cooldown siempre bloqueaba el modo Simulación** (`spCalcularDecision.sql`):
   en la rama `@ContextSource = 'TEMP'`, `FechaUltimoCambio` se cargaba con
   `SYSDATETIME()` (el instante actual) en lugar de `NULL`. Como el
   anti-oscilación bloquea si
   `DATEDIFF(HOUR, FechaUltimoCambio, SYSDATETIME()) < CooldownHoras`, esto
   daba siempre `0 < 12` y bloqueaba **cualquier** simulación con
   `BLOQUEO COOLDOWN/HISTÉRESIS`, sin importar los datos ingresados. Esto
   inutilizaba de hecho el endpoint `/pricing/evaluate` y el modo simulación
   de `/api/input/ui/product`. Se corrigió cargando `NULL` (un producto
   simulado no tiene un "último cambio de precio" real).

Ambos defectos ya están corregidos en el `spCalcularDecision.sql` desplegado
y cubiertos por TC01/TC10 (defecto 1) y TC09 (defecto 2) — si alguno de los
dos reaparece, la suite lo va a volver a detectar.

## Nota sobre encoding

`Run-PruebasMotor.ps1` se guarda con BOM UTF-8. Windows PowerShell 5.1 lee
los `.ps1` sin BOM usando la codepage del sistema, no UTF-8; sin el BOM, los
literales con tildes (ej. `"CRÍTICO"`, `"Límite Mínimo"`) usados para
verificar el `Motivo` se leían mal y producían falsos FAIL aunque el motor
devolviera el texto correcto. Si se edita el script con otro editor, hay que
verificar que se conserve el BOM UTF-8.
