# Suite de regresión de Integración ERP

Continuación del punch list de suites de regresión (ver ADR 0021, Login): el
usuario pidió todas las que quedaban pendientes — ERP, Repositor,
MercadoLibre y Email — de una sola vez. Esta es la de **Integración ERP**
(ver ADR 0004), la primera de las cuatro.

## Qué cubre

`C:\PricingEngine\tests\Run-PruebasErp.ps1`, mismo estilo que
`Run-PruebasMotor.ps1`/`Run-PruebasLogin.ps1`, contra una API real ya
levantada (nunca la arranca ni la reinicia):

- **TC01–TC04** — Ciclo de vida de una **Conexión ERP**: crearla y leerla,
  que el `UNIQUE` de una conexión por empresa se respete (una segunda
  creación no duplica la fila), actualizar `UrlSalida`/`ApiKeySaliente`, y
  que actualizar la conexión de una empresa sin una creada todavía
  devuelva 400 en vez de un error crudo.
- **TC05–TC07** — El **Mapeo de campos ERP** configurable: descubrir
  campos contra una URL real (y que una URL rota dé 400, no un 500),
  guardar un mapeo válido y leerlo de vuelta, y que guardar un mapeo con
  un campo canónico inventado o sin los campos obligatorios (SKU,
  CostoCompra, StockActual) devuelva 400 con el motivo.
- **TC08–TC10** — El sentido **entrante** (`POST /api/erp/sync`, el ERP
  llama al motor): crea un producto nuevo con su costo y stock; el mismo
  SKU en una segunda llamada actualiza en vez de duplicar, y **nunca toca
  los costos operativos que no le pertenecen al ERP** (envío, logística,
  financiero, publicidad — los configura el analista de pricing); sin
  `ApiKey` o con una inventada da 401, y un ítem sin SKU no es un error
  HTTP sino un ítem señalado dentro del resultado (`errores=1`).
- **TC11–TC12** — El sentido **saliente** (`POST /api/erp/pull`, el motor
  llama al ERP): aplica el mapeo configurado contra un ERP simulado con
  nombres de campo no canónicos a propósito, deja rastro en
  `ErpSincronizaciones` y actualiza `UltimaSincronizacion`; con una
  `ApiKeySaliente` incorrecta, la empresa queda con `Ok=false` en el
  resumen sin tirar abajo el resto de la corrida (más de una empresa
  puede estar configurada a la vez).

Fixture: **"Empresa QA ERP"** (CUIT `30-00000002-1`) y sus productos
`QA-ERP-*`, creados y borrados en cada corrida — nunca toca datos fuera de
esa empresa.

## Mock ERP (`Mock-ErpServer.py`, nuevo fixture permanente)

Mismo espíritu que `Mock-SmtpServer.py` para Login: un servidor HTTP
mínimo (`http.server` de Python, sin dependencias) que simula el `GET` que
expondría el ERP de un cliente. A propósito devuelve nombres de campo
**no canónicos** (`codigo_sku`, `precio_compra`, `existencias`, etc.) en
vez de un mapeo identidad, para ejercitar de punta a punta el
descubrimiento de campos y el mapeo configurable — no alcanza con probar
que el upsert funciona si nunca se prueba la traducción de nombres reales.
Opcionalmente exige `Authorization: Bearer <token>` (device por parámetro)
y devuelve 401 si falta o no coincide, para poder probar también una
`ApiKeySaliente` mal configurada (TC12).

## Nota de diseño (no un defecto, comportamiento ya existente)

`POST /api/erp/pull` no tiene ninguna autenticación propia — no está bajo
`/api/admin/*` (por eso no pasa por el login-gate de Usuario) ni pide
ninguna clave: cualquiera que llegue a la API puede dispararlo. Esto ya
era así antes de esta suite (dispara el botón "Actualizar desde ERP" del
header, pensado para cualquier Usuario logueado en el navegador) y no se
tocó — se deja documentado acá porque apareció al mapear qué rutas exige
proteger la suite y no está cubierto por ningún ADR anterior.

## Validado

- 3 corridas limpias y consecutivas: consola y Excel exportado coinciden
  ("12 / 12 casos OK", `exit 0`) las tres veces.
- Limpieza confirmada tras la corrida final: sin "Empresa QA ERP" ni sus
  productos `QA-ERP-*` remanentes, sin proceso `python.exe` del mock
  corriendo. Los sockets en `TIME_WAIT` sobre el puerto 8090 que
  `netstat` muestra después de cada corrida son la baja normal de las
  conexiones TCP ya cerradas, no un proceso escuchando — las tres
  corridas consecutivas lo confirman (el puerto se reutiliza sin
  problema en cada una).

## Pendiente

Repositor, MercadoLibre y Email quedan como las próximas de esta misma
tanda (ver ADR 0021 y este mismo pedido del usuario, "todas las suites de
regresión").
