# Suite de regresión de Repositor

Segunda de las cuatro suites pendientes de este pedido (ver ADR 0021 y
0023): **Repositor** (ver ADR 0003), la pantalla standalone de carga de
stock por Usuario+PIN para clientes sin ERP propio.

## Qué cubre

`C:\PricingEngine\tests\Run-PruebasRepositor.ps1`, mismo estilo que las
suites anteriores, contra una API real ya levantada:

- **TC01–TC03** — Alta de cuenta de Repositor (provisión por ADMIN):
  crearla, que Usuario/Pin vacíos den 400, y que un Usuario duplicado (el
  `Usuario` es único a nivel global, no por empresa) no deje una segunda
  fila.
- **TC04** — Login: correcto (200 con token), PIN incorrecto (401),
  usuario inexistente (401) — sin revelar cuál de las dos cosas falló.
- **TC05–TC07** — Lookup y carga de stock: sin sesión o con un token
  inventado (401 en ambos), lookup de un SKU de la propia empresa (200),
  y el caso más importante — **aislamiento multi-empresa**: un Repositor
  no puede ver ni cargar stock de un SKU que pertenece a OTRA empresa
  (404, porque desde su perspectiva ese SKU "no existe", no 403).
- **TC08–TC10** — Recuento absoluto de stock: actualiza
  `StockEstado.StockActual` y deja rastro inmutable en `StockCargas` con
  el `RepositorID` correcto; `StockNuevo` negativo da 400; un SKU
  inexistente da 404.

Fixture: dos empresas (**"Empresa QA Repositor A"** y **"...B"**, para
poder probar el aislamiento) con un producto cada una (`QA-REPO-A`,
`QA-REPO-B`) y una cuenta `qa_repositor_uno` ligada a la Empresa A —
todo se crea y borra en cada corrida.

## Defecto encontrado y corregido durante esta QA

**TC07 y TC10 fallaban con 500 en vez de 404** al intentar cargar stock
(`POST /api/input/stock`) para un SKU inexistente o de otra empresa —
exactamente **el mismo defecto que ADR 0017 ya encontró y corrigió** en
el reset de contraseña: `RepositorStockService.CargarStockAsync` llamaba
a `tx.RollbackAsync()` mientras el `SqlDataReader` de esa misma conexión
seguía abierto (todavía dentro de su bloque `await using`, sin haberse
liberado), lo que SQL Server/`SqlClient` no permite y termina en una
excepción no controlada que ASP.NET convierte en 500. El lookup
(`LookupAsync`, sin transacción) nunca tuvo este problema — solo la
carga (`CargarStockAsync`, que sí abre una transacción) lo tenía. Se
corrigió con el mismo patrón que ADR 0017: resolver el `reader` primero,
decidir si hubo o no resultado con una variable local (`encontrado`), y
recién después — ya fuera del bloque `await using` que lo dispone — llamar
a `tx.RollbackAsync()` si no se encontró el producto.

Que este mismo defecto haya aparecido dos veces en dos servicios
distintos (`UsuarioAuthService` en ADR 0017, ahora `RepositorStockService`)
sugiere que el patrón "abrir un reader dentro de una transacción y
potencialmente hacer rollback antes de que se libere" es un riesgo real
en este código base — vale la pena tenerlo presente al revisar servicios
nuevos que combinen ambas cosas.

## Validado

- Antes de la corrección: TC07 y TC10 reproducidos con `ResultadoObtenido`
  mostrando `carga=500` (TC07) y `500` (TC10) contra el `404` esperado —
  confirmado con el Excel exportado, no solo con la consola.
- Después de la corrección: 3 corridas limpias y consecutivas, consola y
  Excel exportado coinciden ("10 / 10 casos OK", `exit 0`) las tres veces.
- Limpieza confirmada tras la corrida final: sin "Empresa QA Repositor A/B"
  ni sus productos `QA-REPO-*`, sin cuenta `qa_repositor_uno` remanente.

## Pendiente

MercadoLibre y Email quedan como las próximas de esta misma tanda.
