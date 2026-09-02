# QA de la Integración ERP

Este documento describe los casos de uso y los casos de prueba automatizados
que validan la Integración ERP (ver ADR 0004): la Conexión ERP, el Mapeo de
campos configurable, y los dos sentidos de sincronización (entrante y
saliente). Sirve como referencia funcional y como checklist de regresión.

## Cómo correr la suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PricingEngine\tests\Run-PruebasErp.ps1 -AdminUsuario ADMIN -AdminPassword "................"
```

`-AdminUsuario`/`-AdminPassword` son obligatorios: las credenciales reales
de un ADMIN ya existente en la instalación de destino. Requiere Python
disponible en el PATH (para `Mock-ErpServer.py`, que la suite levanta y
apaga sola).

El script:

1. Verifica que la API esté arriba (`GET /health`); nunca la arranca ni la
   reinicia.
2. Limpia "Empresa QA ERP" y sus productos `QA-ERP-*` de una corrida
   anterior (idempotente), y crea la empresa de nuevo.
3. Levanta `Mock-ErpServer.py`, que simula el `GET` de un ERP de cliente
   con nombres de campo no canónicos.
4. Corre los 12 casos de prueba contra la API real.
5. Apaga el mock y borra la empresa y los productos de prueba, haya fallado
   algo o no.
6. Exporta todo a `tests/Resultados-Erp.xlsx` (PASS en verde, FAIL en
   rosa) y termina con código de salida 1 si algo falló.

## Casos de uso cubiertos

1. **Provisión de una Conexión ERP por empresa**: cada empresa tiene como
   máximo una conexión (con su propia `ApiKeyEntrante`), nunca dos.
2. **Configurar el sentido saliente**: `UrlSalida`/`ApiKeySaliente` se
   pueden cargar y actualizar después de crear la conexión.
3. **Descubrir campos sin adivinar**: antes de armar el mapeo, el admin
   puede pedirle al sistema que le muestre qué campos devuelve el `GET`
   real del ERP del cliente.
4. **Mapeo configurable en vez de un adaptador por ERP**: cualquier ERP
   con un `GET` que devuelva SKU/costo/stock en algún formato tabular se
   puede conectar declarando qué campo propio llena cada campo canónico,
   sin escribir código nuevo.
5. **Entrante**: un ERP que sabe hacer POST empuja su catálogo al motor,
   autenticado por `ApiKey`.
6. **Saliente**: un ERP que solo expone lectura es consultado por el
   motor con el botón "Actualizar desde ERP".
7. **Aislamiento de costos**: el ERP nunca pisa los costos operativos que
   configura el analista de pricing (envío, logística, financiero,
   publicidad), solo costo de compra, IVA e impuestos internos.

## Casos de prueba

| Caso | Qué prueba | Resultado esperado |
|------|------------|---------------------|
| TC01 | Crear Conexión ERP + leerla | crear=201 con `apiKeyEntrante`, get=200 con `urlSalida=null` |
| TC02 | UNIQUE de una conexión por empresa | segunda creación no da 201, sigue habiendo 1 fila |
| TC03 | Actualizar UrlSalida/ApiKeySaliente | actualizar=204, get refleja los valores nuevos |
| TC04 | Actualizar la conexión de una empresa sin una creada | 400 |
| TC05 | Descubrir campos: URL válida / URL rota | válida=200 con los 8 campos reales, rota=400 |
| TC06 | Guardar mapeo válido + leerlo | guardar=204, get devuelve 8 mapeos |
| TC07 | Mapeo inválido: campo canónico inventado / faltan obligatorios | 400 / 400 |
| TC08 | Entrante crea un producto nuevo | procesados=1, costo y stock correctos |
| TC09 | Entrante actualiza (no duplica) y protege costos operativos ajenos | 1 producto, costo/stock nuevos, costo operativo intacto |
| TC10 | Entrante: sin ApiKey / ApiKey inventada / item sin SKU | 401 / 401 / 200 con `errores=1` |
| TC11 | Saliente aplica el mapeo configurado contra el mock | pull=200, ok=true, valores mapeados correctos, fila en ErpSincronizaciones |
| TC12 | Saliente con ApiKeySaliente incorrecta | resumen de la empresa con `ok=false`, no rompe la corrida |

## Nota de diseño (no un defecto)

`POST /api/erp/pull` no exige ninguna autenticación propia — no está bajo
`/api/admin/*` así que no pasa por el login-gate de Usuario, y tampoco pide
una `ApiKey` propia. Es el comportamiento ya existente (dispara el botón
"Actualizar desde ERP" del header) y no se tocó al construir esta suite;
queda documentado acá porque no estaba en ningún ADR anterior.

## Nota sobre encoding y consola

`Run-PruebasErp.ps1` se guarda con BOM UTF-8, por el mismo motivo que
`Run-PruebasMotor.ps1` y `Run-PruebasLogin.ps1` (ver `QA-Motor-Pricing.md`
y `QA-Login.md`). La tabla en consola se imprime con `Out-String -Width 200`
para que `Format-Table -AutoSize` no descarte columnas al redirigir la
salida a un archivo; ante cualquier duda, `Resultados-Erp.xlsx` es la
fuente confiable.
