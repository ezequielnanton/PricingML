# QA de la integración con MercadoLibre

Este documento describe los casos de uso y los casos de prueba automatizados
que validan la integración con MercadoLibre (ver ADR 0005-0011): OAuth,
procesamiento de cola, sincronización de publicaciones/ventas, aprobación de
cola y competidores vinculados a mano.

## Cómo correr la suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PricingEngine\tests\Run-PruebasMercadoLibre.ps1 -AdminUsuario ADMIN -AdminPassword "................"
```

`-AdminUsuario`/`-AdminPassword` son obligatorios. Requiere Python en el
PATH (para `Mock-MercadoLibreServer.py`, que la suite levanta y apaga sola).

El script:

1. Verifica que la API esté arriba; nunca la arranca ni la reinicia.
2. Limpia "Empresa QA ML" de una corrida anterior, guarda por SQL directo el
   valor REAL de `ConfiguracionMercadoLibre` (la API nunca expone el
   `ClientSecret`) y guarda qué filas ya estaban `PENDIENTE` en
   `ColaEjecucionML` antes de tocar nada.
3. Levanta `Mock-MercadoLibreServer.py`, que simula OAuth, `items`,
   `price_to_win`, `orders/search` y `sites/search`.
4. Corre los 10 casos de prueba contra la API real.
5. Apaga el mock, restaura `ConfiguracionMercadoLibre` a su valor real
   original (por SQL directo) y borra la empresa/publicaciones/cola de
   prueba, haya fallado algo o no.
6. Exporta a `tests/Resultados-MercadoLibre.xlsx` (PASS en verde, FAIL en
   rosa) y termina con código de salida 1 si algo falló.

## Casos de uso cubiertos

1. **Configuración centralizada**: `ClientId`/`ClientSecret`/`ApiBaseUrl`/
   `SiteId`/`RedirectUri` se administran desde una sola pantalla.
2. **Conexión OAuth real**: el vendedor se loguea en ML y autoriza la app;
   el `state` es de un solo uso.
3. **Procesamiento de cola con aprobación humana opcional**: una fila
   puede requerir revisión antes de tocar el precio real en ML.
4. **Renovación automática de token**: un token vencido se renueva solo
   con el `RefreshToken`, sin intervención manual.
5. **Resiliencia ante errores de ML**: un ítem que ML rechaza no frena el
   procesamiento del resto de la cola.
6. **Sincronización de entrada**: precio/estado real y competencia (por
   catálogo o vinculada a mano) se traen de vuelta desde ML.
7. **Ventas históricas por ventana**: la API de Órdenes de ML alimenta
   `MetricasVentasHist` sin que ML tenga un endpoint directo de "ventas
   por ventana".

## Casos de prueba

| Caso | Qué prueba | Resultado esperado |
|------|------------|---------------------|
| TC01 | Configuración ML | guardar=204, get refleja lo guardado |
| TC02 | OAuth iniciar: válido / cuenta inexistente | 302 al dominio correcto / 400 |
| TC03 | OAuth callback: sin datos / state inventado | ambos terminan en error, sin tocar la cuenta |
| TC04 | OAuth callback exitoso + reuso de state | cuenta actualizada; reuso da error |
| TC05 | Procesar cola (1ra corrida) | renueva token, procesa/salta/error según corresponda, filas preexistentes intactas |
| TC06 | Aprobación de cola | listar, aprobar, rechazar |
| TC07 | Procesar cola (2da corrida) | aprobada se procesa, rechazada nunca se reprocesa |
| TC08 | Competidor vinculado manualmente | vincular x2 con precio a mano, listar, actualizar precio, desvincular, listar |
| TC09 | Sincronizar publicaciones | catálogo actualiza precio/competencia; no catálogo no toca el vínculo manual |
| TC10 | Sincronizar ventas | unidades por ventana agregadas correctamente |

## Defecto encontrado y corregido durante esta QA

El HTML de la página de callback de OAuth nunca declaraba `charset=utf-8`
en el header `Content-Type` (solo en un `<meta>` del propio HTML, que los
navegadores sí sniffean pero un cliente HTTP común no) — cualquier cliente
que decidiera la codificación por el header decodificaba mal los acentos
(`"inválido"` llegaba como `"invǭlido"`). Corregido agregando
`; charset=utf-8` a las tres respuestas de esa ruta. Ver ADR 0025 para el
detalle completo.

## Defecto encontrado post-QA: MercadoLibre bloquea toda forma de leer una publicación ajena

El flujo original de "Competidores vinculados" (para publicaciones que no son de
catálogo) buscaba en `GET /sites/{site}/search?q=...` y el usuario elegía a quién
vincular de los resultados. Contra la API real, ese endpoint devuelve
`403 {"message":"forbidden"}` para aplicaciones de terceros, con o sin token válido
— confirmado probándolo directo, autenticado y sin autenticar, con el mismo
resultado en ambos casos. Es una restricción de plataforma, no un límite temporal
como el `PA_UNAUTHORIZED_RESULT_FROM_POLICIES` de otras partes de esta suite.

Se probó como reemplazo pegar el ID/link de la publicación y resolverlo vía
`GET /items/{id}` (que en un primer test, contra nuestra propia publicación, dio
`200 OK`). Una segunda ronda de pruebas reveló que ese mismo endpoint también
devuelve `403 {"error":"access_denied"}` cuando el ítem consultado **no pertenece a
la cuenta conectada** — con un token recién renovado, scope completo, catálogo o no
catálogo, siempre el mismo resultado. Se revisó la documentación oficial vigente de
MercadoLibre (Items & Searches, Autenticación y Autorización, Developer Partner
Program): confirman que la API está scopeada a *"within your seller account"*, que
no existe un scope más granular para esto, y que el Developer Partner Program
certifica administradores de múltiples cuentas propias, no acceso a datos de
terceros. Tampoco es viable leer la página pública del ítem por HTML: un pedido de
servidor (sin navegador real) es redirigido de inmediato a un desafío anti-bot de
MercadoLibre, tanto para la búsqueda como para la página de un ítem puntual.

**Diseño final**: sin ninguna vía posible de MercadoLibre, el usuario carga a mano
el ID/link, título, moneda y precio del competidor al vincular
(`VincularCompetidorAsync`), y los puede actualizar cuando quiera con "Actualizar
precio" (`ActualizarPrecioCompetidorAsync`, nuevo endpoint
`PUT /publicaciones/{id}/competidores/{vinculoId}/precio`) — sin ningún llamado a
MercadoLibre en este flujo. La Moneda se sugiere por defecto como la Moneda
Principal de la Empresa dueña de la publicación
(`ObtenerMonedaPrincipalAsync`, nuevo endpoint
`GET /publicaciones/{id}/moneda-principal`), pero el usuario puede elegir otra. La
UI se rediseñó como una grilla (link a la publicación real, título, moneda,
precio) en vez de una lista simple. Se quitó también el intento de refresco
automático que
tenía "Sincronizar ML" para estos vínculos (fallaba en silencio para cualquier
competidor real, por el mismo bloqueo). Catálogo no se ve afectado: `price_to_win`
siempre se llama con el ID de la propia publicación, nunca con el de un competidor
ajeno.

## Nota de diseño: la cola de ejecución no tiene alcance por empresa

`ProcesarColaAsync` y `GetColaPendienteAprobacionAsync` operan sobre TODAS
las filas del sistema, sin filtrar por empresa — comportamiento ya
existente, no tocado por esta suite. La suite se protege explícitamente:
guarda qué filas `PENDIENTE` ya existían antes de tocar nada y confirma
que sigan intactas después de cada "Procesar cola".

## Nota sobre encoding y consola

`Run-PruebasMercadoLibre.ps1` se guarda con BOM UTF-8 y la tabla en
consola usa `Out-String -Width 200`, por los mismos motivos documentados
en `QA-Motor-Pricing.md` y `QA-Login.md`. Ante cualquier duda,
`Resultados-MercadoLibre.xlsx` es la fuente confiable.
