# Integración ERP: conector bidireccional genérico, sin adaptador de ERP concreto

Sin un ERP específico elegido todavía, se necesitaba una forma de que el motor
intercambie datos de productos/costos/stock con el ERP del cliente sin saber de
antemano qué ERP es. La duda inicial era quién inicia la conexión: ¿el ERP llama a
este sistema, o este sistema llama al ERP?

En la práctica, la mayoría de los ERPs (sobre todo los chicos/medianos típicos de
Argentina) no saben hacer llamadas HTTP salientes configurables sin que alguien
programe algo a medida, pero casi todos sí saben *exponer* algo: una API si son
modernos (Tango, Odoo, SAP Business One, NetSuite), o al menos un mecanismo de
exportación/importación de archivos si son más viejos. Pedirle al cliente que su
ERP aprenda a llamar a este sistema (nuevo, desconocido) es más fricción que pedirle
las credenciales de lo que su ERP ya expone.

Se decidió entonces soportar **ambos sentidos**, ya que no se puede asumir cuál
sabe hacer el ERP de un cliente dado:

- **Entrante** (`POST /api/erp/sync`): para ERPs que sí pueden llamar afuera. Se
  autentica con una `ApiKeyEntrante` emitida por empresa (`ErpConexiones`).
- **Saliente** (`POST /api/erp/pull`, disparado por el botón "Actualizar desde ERP"
  en el header de la UI): para ERPs que solo exponen una API de lectura. El motor
  sale a buscarla con `GET` usando la `UrlSalida`/`ApiKeySaliente` configuradas.

Ambos caminos comparten el mismo contrato canónico (`ErpSyncItem`: SKU, título,
costo de compra, IVA, impuestos internos, stock) y el mismo upsert
(`ErpSyncService.UpsertItemsAsync`), que solo toca los campos que le pertenecen al
ERP — nunca los costos operativos (envío, logística, financiero, publicidad) que
configura el analista de pricing.

No existe ningún adaptador de código por ERP, y no hace falta escribir uno: cada
instalación conecta a un solo ERP (no varios al mismo tiempo), así que en vez de un
adaptador por vendor se resolvió con un **mapeo configurable desde la UI**
("Integración ERP"). El admin apunta a la URL `GET` del ERP de ese cliente, el
sistema descubre qué campos devuelve (`POST /api/admin/erp-conexiones/descubrir-campos`,
que autodetecta el array de items dentro de la respuesta y lista sus propiedades) y
el admin indica con qué campo del ERP se llena cada campo canónico
(`ErpCampoMapeos`, uno por empresa). En tiempo de sincronización,
`ErpSyncService.AplicarMapeo` traduce cada item crudo del ERP al contrato canónico
usando ese mapeo — o, si la empresa no configuró ninguno, asume que el ERP ya
devuelve el contrato canónico directamente (mapeo identidad, compatible con el
comportamiento previo a esta pantalla). Esto deja cualquier instalación conectable
a su ERP sin escribir código nuevo por cliente, siempre que el ERP tenga un GET que
devuelva SKU/costo/stock en algún formato tabular razonable.

## Simplificación deliberada: sin Integration DB ni eventos async

El upsert escribe directo en las tablas operativas del motor (`Productos`,
`CostosProducto`, `StockEstado` de `PRICES_DB`), de forma síncrona dentro de la
misma request del POST/GET. Una arquitectura más madura separaría esto en una base
de integración propia (normalizada, independiente del schema del motor) con un
conector por vendor de ERP publicando eventos que el motor consume de forma
asíncrona — desacoplando al motor de la disponibilidad/latencia de cada ERP.

Esa separación no está justificada todavía. Los disparadores reales para
reconsiderarla no son "aparece un segundo ERP" (eso solo justifica escribir un
adaptador por vendor, ver arriba), sino cualquiera de estos tres, que hoy no están
presentes:

- **Confiabilidad**: un ERP lento o inestable empieza a trabar al motor porque el
  pull es síncrono.
- **Otros consumidores**: algo además del motor de pricing (analytics, otro módulo)
  necesita los mismos datos normalizados del ERP.
- **Volumen**: la sincronización pasa de unos pocos SKUs bajo demanda a un volumen
  alto y frecuente en muchos clientes a la vez.

Si aparece cualquiera de los tres, ahí se justifica separar una Integration DB y
desacoplar con eventos — y el contrato canónico ya existente hace esa migración
más simple, porque el "modelo común" del medio ya está definido.
