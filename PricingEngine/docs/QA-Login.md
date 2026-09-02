# QA del Login general (Usuarios, Sesiones, Permisos)

Este documento describe los casos de uso y los casos de prueba automatizados
que validan el sistema de login general (`Usuarios`, `UsuarioSesiones`,
`UsuarioSecciones`, recuperación de contraseña por email). Sirve como
referencia funcional y como checklist de regresión: después de cualquier
cambio en autenticación, roles, secciones, sesiones o recuperación de
contraseña, hay que volver a correr la suite y confirmar que los 8 casos
siguen dando el mismo resultado.

A diferencia de `Run-PruebasMotor.ps1` (que ejecuta un stored procedure
directo contra la base), esta suite corre de punta a punta contra la API
HTTP real: cada caso hace requests reales a un `PricingApi` ya levantado.

## Cómo correr la suite

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\PricingEngine\tests\Run-PruebasLogin.ps1 -AdminUsuario ADMIN -AdminPassword "................"
```

`-AdminUsuario`/`-AdminPassword` son obligatorios: las credenciales reales
de un ADMIN ya existente en la instalación de destino. Nunca se hardcodean
en el script ni se versionan — se piden en cada corrida.

El script:

1. Verifica que la API esté arriba (`GET /health`); nunca la arranca ni la
   reinicia, porque podría estar sirviendo a un usuario real en ese momento.
2. Limpia usuarios `qa_login_*` de una corrida anterior (idempotente).
3. Corre los 8 casos de prueba contra la API real, usando al ADMIN real solo
   para loguearse y crear/eliminar usuarios de prueba.
4. Levanta y apaga un servidor SMTP simulado (`Mock-SmtpServer.py`) para
   probar recuperación de contraseña sin depender de un proveedor de email
   real.
5. Limpia todo lo que creó (usuarios `qa_login_*`, log del mock) al final,
   haya fallado algo o no, y restaura la `ConfiguracionEmail` original.
6. Exporta todo a `tests/Resultados-Login.xlsx` (PASS en verde, FAIL en
   rosa) y termina con código de salida 1 si algo falló.

Si el script marca un FAIL, revisar la columna `Detalle`/`ResultadoObtenido`
de esa fila en el Excel — no confiar solo en la tabla impresa en consola:
ver "Nota sobre encoding y consola" más abajo.

## Casos de uso cubiertos

1. **Bootstrap de un solo uso**: una instalación nueva permite crear
   exactamente un primer ADMIN; cualquier intento posterior se rechaza sin
   tocar el ADMIN ya existente.
2. **Login correcto/incorrecto**: credenciales válidas dan un token;
   inválidas dan 401, sin filtrar si el usuario existe o no.
3. **Gate por Rol**: un usuario `LECTURA` puede leer pero no mutar; un
   `ADMIN` sí llega a la lógica de negocio (404 si el recurso no existe, en
   vez de 403 — confirma que el límite es de Rol, no de datos).
4. **Secciones como snapshot del login**: las secciones que devuelve el
   login reflejan exactamente lo asignado al momento de loguearse.
5. **Cambio de contraseña propio**: requiere la contraseña actual correcta;
   invalida la vieja y habilita la nueva de inmediato.
6. **Recuperación por email**: un usuario con email cargado puede pedir un
   link de reseteo de un solo uso (vale 1 hora), sin revelar si el usuario
   existe; el token no se puede reusar ni inventar.
7. **Eliminación de usuario**: bloqueada si tiene historial de
   aprobación/vínculo (integridad referencial), y bloqueada para
   autoeliminarse mientras se está logueado con esa cuenta.
8. **Sesión persistida, no en memoria**: la sesión sobrevive un reinicio de
   la API porque vive en `UsuarioSesiones`, y desaparece al hacer logout
   explícito.

## Casos de prueba

| Caso | Qué prueba | Resultado esperado |
|------|------------|---------------------|
| TC01 | Guard de bootstrap | `existeUsuario=true`, segundo `setup-primer-admin` = 409, ADMIN real intacto |
| TC02 | Alta + login correcto/incorrecto | alta=201, login OK=200 con token, login incorrecto=401 |
| TC03 | LECTURA no muta, ADMIN sí llega a nivel Rol | lectura GET=200, lectura POST=403, admin POST=404 |
| TC04 | Secciones del login = las asignadas | login devuelve exactamente `["pricing","reports"]` tras asignarlas |
| TC05 | Cambiar contraseña propia | actual incorrecta=400, correcta=204; vieja=401, nueva=200 |
| TC06 | Recuperar contraseña (mock SMTP) | olvide=200, token extraído, corta=400, reset=204, vieja=401, nueva=200, reusado=400, inventado=400 |
| TC07 | Eliminar usuario | sin historial=204, con historial simulado=409 (se saltea si no hay filas para simular), propia cuenta=400 |
| TC08 | Sesión persistida | fila en `UsuarioSesiones` tras login=1, tras logout=0 |

## Defectos encontrados y corregidos durante esta QA

1. **TC06 fallaba siempre porque el cuerpo del email de recuperación llega
   en base64.** `System.Net.Mail.SmtpClient`, con el `BodyEncoding = UTF8`
   que usa `EmailService`, codifica el cuerpo HTML como
   `Content-Transfer-Encoding: base64` aunque el contenido sea ASCII puro —
   el link de reseteo nunca aparece en texto plano dentro del log crudo del
   mock SMTP. El regex que buscaba `reset-password?token=...` directamente
   en el log jamás matcheaba. Corregido agregando, como fallback en el mismo
   loop de espera, la extracción y decodificación del bloque base64 del
   cuerpo antes de buscar el token en el texto ya decodificado.
2. **El conteo final de fallos mentía cuando había exactamente un FAIL.**
   `($rows | Where-Object { $_.Resultado -eq 'FAIL' }).Count`: si el filtro
   matchea un solo elemento, PowerShell no lo envuelve en un array, así que
   `.Count` se evalúa sobre un objeto suelto sin esa propiedad y da `$null`
   — que en aritmética se trata como `0`. Esto hizo que el script reportara
   "8 / 8 casos OK" en varias corridas mientras el Excel exportado mostraba
   un FAIL real en TC06. Corregido envolviendo con `@(...)` para forzar
   contexto de array.
3. **La tabla de consola descartaba silenciosamente la columna
   "Resultado".** `Format-Table -AutoSize` calcula el ancho disponible según
   la consola real; al redirigir la salida a un archivo (sin consola real
   detrás) ese ancho cae a un valor angosto por defecto, y `Format-Table`
   omite columnas enteras que no entran, sin avisar — lo que ocultó el
   defecto 2 durante la depuración. Corregido forzando un ancho fijo con
   `Out-String -Width 200` antes de imprimir.

Los tres defectos se descubrieron encadenados: sin corregir el 3 (columna
oculta) costó notar que el 2 (conteo mentiroso) enmascaraba el 1 (bug real
y permanente en TC06) durante varias corridas que parecían "8/8" en
consola. Ver ADR 0021 para el detalle completo.

## Nota sobre encoding y consola

`Run-PruebasLogin.ps1` se guarda con BOM UTF-8, por el mismo motivo que
`Run-PruebasMotor.ps1` (ver `QA-Motor-Pricing.md`): sin el BOM, Windows
PowerShell 5.1 lee el archivo con la codepage del sistema en vez de UTF-8, y
los literales con tildes/ñ pueden corromperse silenciosamente. Si se edita
el script con otro editor, verificar que se conserve el BOM UTF-8.

Además, no confiar en la tabla impresa en consola como única fuente de
verdad del resultado — según el ancho de consola disponible (especialmente
al redirigir la salida a un archivo), `Format-Table -AutoSize` puede omitir
columnas sin avisar. El script fuerza `Out-String -Width 200` para
evitarlo, pero ante cualquier duda, el Excel exportado (`Resultados-Login.xlsx`)
es la fuente confiable.
