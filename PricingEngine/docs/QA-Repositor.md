# QA de Repositor

Este documento describe los casos de uso y los casos de prueba automatizados
que validan la pantalla standalone de Repositor (ver ADR 0003): login por
Usuario+PIN y Recuento absoluto de stock.

## Cómo correr la suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PricingEngine\tests\Run-PruebasRepositor.ps1 -AdminUsuario ADMIN -AdminPassword "................"
```

`-AdminUsuario`/`-AdminPassword` son obligatorios: las credenciales reales
de un ADMIN ya existente en la instalación de destino (necesarias para
provisionar la cuenta de Repositor y el fixture de empresas/productos).

El script:

1. Verifica que la API esté arriba (`GET /health`); nunca la arranca ni la
   reinicia.
2. Limpia el fixture de una corrida anterior (idempotente): dos empresas
   QA, sus productos `QA-REPO-*` y la cuenta `qa_repositor_uno`.
3. Crea el fixture de nuevo: dos empresas (para poder probar aislamiento
   multi-empresa), un producto con stock en cada una, y la cuenta de
   Repositor.
4. Corre los 10 casos de prueba contra la API real.
5. Borra todo el fixture al final, haya fallado algo o no.
6. Exporta a `tests/Resultados-Repositor.xlsx` (PASS en verde, FAIL en
   rosa) y termina con código de salida 1 si algo falló.

## Casos de uso cubiertos

1. **Provisión de cuenta**: un ADMIN da de alta la cuenta de un Repositor
   (Usuario global único + PIN, hasheado server-side).
2. **Login mínimo**: Usuario+PIN da un token de sesión sin exponer datos
   sensibles de la app completa.
3. **Consulta antes de sobrescribir**: el Repositor puede ver el stock
   vigente de un SKU antes de cargar un recuento nuevo.
4. **Recuento absoluto, no incremental**: cargar stock reemplaza
   `StockActual` directamente (no es un +/-), y deja un rastro inmutable
   de auditoría (quién, cuándo, de qué valor a qué valor).
5. **Aislamiento multi-empresa**: un Repositor solo puede ver y cargar
   stock de productos de la empresa a la que está ligado.

## Casos de prueba

| Caso | Qué prueba | Resultado esperado |
|------|------------|---------------------|
| TC01 | Alta de cuenta de Repositor | 201 con RepositorID |
| TC02 | Alta con Usuario o Pin vacío | 400 |
| TC03 | Usuario duplicado (único global) | no crea una segunda fila |
| TC04 | Login: correcto / PIN incorrecto / usuario inexistente | 200 con token / 401 / 401 |
| TC05 | Lookup sin sesión / con token inventado | 401 / 401 |
| TC06 | Lookup de un SKU de la propia empresa | 200, StockActual correcto |
| TC07 | Lookup/carga de un SKU de OTRA empresa | 404 / 404, no ve ni toca el stock ajeno |
| TC08 | Recuento absoluto de stock | StockEstado actualizado, fila en StockCargas |
| TC09 | Recuento con StockNuevo negativo | 400 |
| TC10 | Recuento de un SKU inexistente | 404 |

## Defecto encontrado y corregido durante esta QA

TC07 y TC10 fallaban con `500` en vez de `404` al cargar stock de un SKU
inexistente o de otra empresa: `RepositorStockService.CargarStockAsync`
llamaba a `tx.RollbackAsync()` mientras el `SqlDataReader` de la misma
conexión seguía abierto — el mismo defecto que ADR 0017 ya había
encontrado y corregido en el reset de contraseña. Corregido con el mismo
patrón: resolver el reader por completo (fuera de su `await using`) antes
de decidir si hace falta el rollback. Ver ADR 0024 para el detalle
completo.

## Nota sobre encoding y consola

`Run-PruebasRepositor.ps1` se guarda con BOM UTF-8 y la tabla en consola
usa `Out-String -Width 200`, por los mismos motivos documentados en
`QA-Motor-Pricing.md` y `QA-Login.md`. Ante cualquier duda,
`Resultados-Repositor.xlsx` es la fuente confiable.
