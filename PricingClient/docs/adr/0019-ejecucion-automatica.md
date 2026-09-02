# Ejecución automática del ciclo completo

Hasta ahora, todo el ciclo de precios dependía de que alguien apretara 3
botones del header a mano (Actualizar desde ERP, Procesar cola ML,
Sincronizar ML) — y ni siquiera eso alcanzaba, porque "evaluar precio" (el
paso que decide subir/bajar) solo existía producto por producto desde la
pantalla Pricing. No había forma de correr el ciclo completo sin intervención
humana.

## Decisión de alcance (confirmada con el usuario)

Se agregaron las **4 etapas** en un solo ciclo automático, no solo las 3 que
ya eran botones:

1. **Actualizar desde ERP** (ya existía)
2. **Evaluar todos los productos activos y persistir la decisión** — pieza
   nueva, antes solo existía como acción manual de a un producto
3. **Procesar cola ML** (ya existía)
4. **Sincronizar ML** (ya existía)

Configuración deliberadamente simple: on/off + cada cuántos minutos corre.
Sin horarios específicos ni cron — se evaluó y se descartó a favor de algo
más chico de mantener.

## Cómo funciona

- **`SqlPricingService.EvaluarTodosLosProductosAsync()`** (pieza nueva): la
  lista a evaluar es todo `(EmpresaID, ProductoID)` con una publicación ML
  no cerrada. Llama a `spCalcularDecision` en modo producción
  (`ModoSimulacion=0, Persistir=1, ContextSource='BASE'`) pasando solo
  `@EmpresaID`/`@ProductoID` — el mismo llamado mínimo que ya usa
  `Run-PruebasMotor.ps1`, confirmando que la rama `BASE` del SP ignora el
  resto de los parámetros y lee todo de las tablas reales. No hizo falta
  tocar el SP.
- **`ConfiguracionEjecucionAutomatica`** (tabla nueva, fila única): `Activo`,
  `IntervaloMinutos`, y el resultado de la última corrida (`UltimaEjecucion`,
  `UltimoResultadoOk`, `UltimoResultadoResumen`) — mismo patrón de
  configuración de una fila que `ConfiguracionEmail`/`ConfiguracionMercadoLibre`.
- **`EjecucionAutomaticaHostedService`**: un `BackgroundService` de .NET
  (sin Hangfire, sin Quartz — nada nuevo que agregar al proyecto) que se
  despierta cada un minuto y le pregunta a `EjecucionAutomaticaService` si
  ya toca correr según `Activo`/`IntervaloMinutos`/`UltimaEjecucion`. Prender/
  apagar o cambiar el intervalo desde la UI tiene efecto sin reiniciar la
  API.
- Cada una de las 4 etapas corre en su propio `try/catch`: si una falla, las
  demás igual se intentan en ese mismo ciclo, y el resumen guardado deja
  registrado qué etapa falló y con qué números (ej. "ERP: 0 producto(s), 2
  conexión(es) fallaron").
- Pantalla nueva "Ejecución automática": checkbox, minutos, el resultado de
  la última corrida, y un botón "Ejecutar ahora" para probar sin esperar al
  intervalo.

## Bug encontrado y corregido durante las pruebas

`UltimaEjecucion` se guardaba con `SYSDATETIME()` (hora **local** del
servidor SQL, no UTC), pero se comparaba contra `DateTime.UtcNow` en C#. En
un servidor con offset negativo (como Argentina, UTC-3), esto hacía que la
sesión guardada pareciera sistemáticamente "atrasada" respecto al reloj UTC
real, así que el chequeo "¿ya pasó el intervalo?" daba `true` casi siempre —
el ciclo se hubiera disparado en cada tick (cada un minuto) sin importar el
`IntervaloMinutos` configurado. Se corrigió cambiando `SYSDATETIME()` por
`SYSUTCDATETIME()` en las cuatro escrituras de la tabla.

## Validado

- `EvaluarTodosLosProductosAsync()` contra los fixtures de QA reseedeados a
  un estado "sucio": detectó y persistió 5 cambios de precio reales, que
  aparecieron correctamente en la cola de aprobación de MercadoLibre.
- Con el bug del huso horario corregido: con `IntervaloMinutos=10`, esperar
  ~2 minutos (más de un tick del scheduler) **no** disparó una corrida
  nueva — `UltimaEjecucion` quedó sin cambios. Con `IntervaloMinutos=1`,
  esperar ~90 segundos **sí** disparó una corrida automática sola, sin
  llamar a "Ejecutar ahora" — confirmado por el cambio de `UltimaEjecucion`.
- El resumen de cada etapa distingue error vs. éxito con números concretos
  (ej. "Sincronizar ML: 0 publicación(es), 0 con ventas, 9 error(es)" cuando
  la Cuenta ML no tiene token configurado).
- Probado en navegador real: pantalla "Ejecución automática" con checkbox,
  minutos, botón "Ejecutar ahora" y el resumen de la última corrida
  visibles y funcionando.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`), corrida varias
  veces durante las pruebas: 10/10 sin cambios en todos los casos.
