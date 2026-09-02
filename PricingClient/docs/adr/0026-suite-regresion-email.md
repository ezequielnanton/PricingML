# Suite de regresión de Email

Última de las cuatro suites pendientes de este pedido (ver ADR 0021, 0023,
0024, 0025): **Email** (ver ADR 0017), acotada a lo que queda fuera del
camino de recuperación de contraseña — ese ya lo cubre a fondo TC06 de
`Run-PruebasLogin.ps1` (pedir el link, token de un solo uso, expiración,
reset). Al mapear todos los usos de `EmailService` en el backend, resultó
que el email solo se usa para dos cosas en todo el sistema: recuperación
de contraseña (ya cubierta) y el botón "Probar conexión" de la pantalla
Integración Email — así que esta suite es más chica que las otras tres a
propósito, no por falta de profundidad: es todo lo que hay para probar.

## Qué cubre

`C:\PricingEngine\tests\Run-PruebasEmail.ps1`, reusando el mismo mock SMTP
que ya usa Login (`Mock-SmtpServer.py`), contra una API real ya levantada:

- **TC01** — Guardar la Configuración de Email completa y leerla de vuelta.
- **TC02** — El `SmtpPassword` se preserva si un PUT posterior no manda
  uno nuevo — mismo patrón que `ClientSecret` de MercadoLibre (ADR 0025) —
  verificado leyendo el valor real por SQL, no solo el booleano que
  devuelve la API.
- **TC03** — Probar conexión con el destinatario vacío (400).
- **TC04** — Probar conexión sin servidor SMTP configurado (400 con un
  mensaje específico, distinto del de destinatario vacío).
- **TC05** — Probar conexión exitosa: el mock SMTP recibe el email real.
- **TC06** — Probar conexión con un SMTP mal configurado (host/puerto que
  nadie escucha): a diferencia de "olvidé mi contraseña" — que por diseño
  traga cualquier error de envío para no revelar por enumeración qué
  cuentas existen (ver ADR 0017) — "Probar conexión" es una acción
  explícita de un ADMIN ya autenticado, así que **sí** debe devolver el
  error real de conexión, no un mensaje genérico.

## Nota sobre `ConfiguracionEmail`: fila única y global, sin secreto legible

Mismo problema que `ConfiguracionMercadoLibre` (ver ADR 0025): es una
única fila global (no por empresa) y la API nunca devuelve el
`SmtpPassword` real de vuelta, solo un booleano. Como TC02 necesita
sobrescribir el password real para poder probar que se preserva, la
suite lee el valor real por SQL directo antes de tocar nada y lo
restaura también por SQL directo al final — nunca a través de la API.

## Validado

- 3 corridas limpias y consecutivas: consola y Excel exportado coinciden
  ("6 / 6 casos OK", `exit 0`) las tres veces, sin necesitar ninguna
  corrección — el mock SMTP y los helpers ya estaban maduros por
  reutilizar lo construido para ADR 0021.
- Limpieza confirmada tras la corrida final: `ConfiguracionEmail` quedó
  con exactamente los mismos valores que tenía antes de correr la suite
  (verificado campo por campo), sin proceso `python.exe` del mock
  corriendo, sin filas duplicadas en la tabla.

## Cierre de la tanda

Con esta suite se completan las cuatro pendientes de este pedido (Login ya
estaba de una tanda anterior, ver ADR 0021): ERP (ADR 0023), Repositor
(ADR 0024, encontró y corrigió un defecto real), MercadoLibre (ADR 0025,
encontró y corrigió un defecto real) y Email. Quedan, para más adelante y
fuera de este pedido: suites contra APIs reales (no mocks) de ERP/ML/Email,
y soporte para otros marketplaces.
