# QA de la Integración Email

Este documento describe los casos de uso y los casos de prueba automatizados
que validan la Integración Email (ver ADR 0017) más allá del camino de
recuperación de contraseña, que ya cubre a fondo TC06 de
`docs/QA-Login.md`. El email en este sistema solo se usa para dos cosas:
recuperación de contraseña (ya cubierta) y el botón "Probar conexión" —
esta suite es todo lo que queda por cubrir, no una versión recortada.

## Cómo correr la suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PricingEngine\tests\Run-PruebasEmail.ps1 -AdminUsuario ADMIN -AdminPassword "................"
```

`-AdminUsuario`/`-AdminPassword` son obligatorios. Requiere Python en el
PATH (reusa `Mock-SmtpServer.py`, el mismo fixture que `Run-PruebasLogin.ps1`).

El script:

1. Verifica que la API esté arriba; nunca la arranca ni la reinicia.
2. Guarda por SQL directo el valor REAL de `ConfiguracionEmail` (la API
   nunca expone el `SmtpPassword`).
3. Levanta el mock SMTP.
4. Corre los 6 casos de prueba contra la API real.
5. Apaga el mock, restaura `ConfiguracionEmail` a su valor real original
   (por SQL directo), haya fallado algo o no.
6. Exporta a `tests/Resultados-Email.xlsx` (PASS en verde, FAIL en rosa) y
   termina con código de salida 1 si algo falló.

## Casos de uso cubiertos

1. **Configuración centralizada del SMTP saliente**: una sola pantalla
   administra host/puerto/usuario/password/SSL/remitente.
2. **El password no se re-pide en cada edición**: igual que otras
   integraciones de este sistema (MercadoLibre), guardar cambios sin
   tocar el campo de password no lo borra.
3. **Probar antes de confiar**: un ADMIN puede confirmar que la
   configuración SMTP funciona sin tener que disparar un reset de
   contraseña real para probarlo.
4. **Errores explícitos donde no hay riesgo de enumeración**: a
   diferencia de "olvidé mi contraseña" (que oculta errores para no
   revelar cuentas), "Probar conexión" es una acción de ADMIN y sí
   informa el error real.

## Casos de prueba

| Caso | Qué prueba | Resultado esperado |
|------|------------|---------------------|
| TC01 | Guardar configuración completa + leerla | 204, get refleja todo lo guardado |
| TC02 | Password se preserva si no se manda uno nuevo | 204, el valor real en la base no cambia |
| TC03 | Probar con destinatario vacío | 400 |
| TC04 | Probar sin SMTP configurado | 400, mensaje específico |
| TC05 | Probar conexión exitosa | 200, el mock recibe el email |
| TC06 | Probar con SMTP mal configurado | 400 con el error real de conexión |

## Nota sobre `ConfiguracionEmail`: fila única y global, sin secreto legible

Es una única fila global (no por empresa), y la API nunca devuelve el
`SmtpPassword` real. TC02 necesita sobrescribirlo para poder probar que
se preserva, así que la suite lee el valor real por SQL directo antes de
tocar nada y lo restaura también por SQL directo al final.

## Nota sobre encoding y consola

`Run-PruebasEmail.ps1` se guarda con BOM UTF-8 y la tabla en consola usa
`Out-String -Width 200`, por los mismos motivos documentados en
`QA-Motor-Pricing.md` y `QA-Login.md`. Ante cualquier duda,
`Resultados-Email.xlsx` es la fuente confiable.
