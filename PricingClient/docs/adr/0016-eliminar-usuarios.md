# Eliminar usuarios definitivamente

Hasta ahora, la pantalla "Usuarios" solo permitía desactivar/reactivar
cuentas (ADR 0012), nunca borrarlas. El usuario pidió poder eliminarlas de
verdad.

## Decisión: DELETE real, pero protegido por la propia integridad referencial

`DELETE /api/admin/usuarios/{id}` hace un `DELETE FROM Usuarios` real — no
un soft-delete ni un flag. Pero las columnas que registran auditoría
(`ColaEjecucionML.UsuarioAprobacionID` y `PublicacionCompetidoresManual.
UsuarioVinculoID`, agregadas en ADR 0012) tienen `FOREIGN KEY` sin `ON DELETE
CASCADE` ni `SET NULL` — a propósito, sin necesidad de código extra: si el
Usuario aprobó/rechazó una cola o vinculó un competidor alguna vez, SQL
Server rechaza el `DELETE` (error 547) antes de perder ese rastro. El
endpoint atrapa ese error puntual y devuelve 409 con un mensaje claro
("Desactivalo en su lugar para conservar la trazabilidad") en vez de dejar
pasar un 500 genérico.

Esto mantiene la prioridad que se sostuvo en toda la sesión de login (ADR
0012/0013): nunca perder de vista quién aprobó o vinculó algo. "Eliminar"
solo es posible para cuentas sin esa historia — típicamente las creadas por
error o de prueba.

## Otras protecciones

- **No se puede eliminar la propia cuenta** mientras estás logueado con
  ella (400) — evita quedarte afuera de tu propia sesión sin querer.
- **Confirmación explícita** en la UI (`ConfirmDialog`, el mismo componente
  que ya usa el resto de los ABM) antes de mandar el DELETE — acción
  irreversible, coherente con el resto de la app.
- El botón "Eliminar" ni siquiera se muestra para la fila del usuario
  logueado en la tabla de "Usuarios".

## Validado

- Usuario sin historial → DELETE → 204, desaparece del listado.
- Usuario con historial (simulado apuntando una fila de `ColaEjecucionML` a
  su `UsuarioID`) → DELETE → 409 con el mensaje esperado, la cuenta sigue
  existiendo.
- Intentar eliminar la propia cuenta logueada → 400.
- ID inexistente → 404.
- Probado en navegador real: alta de un usuario de prueba, botón "Eliminar"
  visible solo para esa fila (no para ADMIN logueado), diálogo de
  confirmación con el mensaje completo, y la fila desaparece del listado
  tras confirmar.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios.
