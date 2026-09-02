# Permisos por sección (qué pantallas ve cada Usuario)

El login general (ADR 0012) ya distinguía ADMIN de LECTURA, pero era binario:
o veías todo o solo podías consultar todo. El usuario pidió, además, poder
tildar qué secciones concretas ve cada Usuario al darlo de alta (Pricing,
Formularios, Reportes, Documentación, API Check, Integración ERP, Integración
MercadoLibre, Cola ML, Usuarios).

## Decisión de alcance (confirmada con el usuario)

Los permisos por sección son **de visibilidad en la UI**, no un segundo
sistema de autorización a nivel de API. El límite real de qué se puede
modificar sigue siendo el Rol (ADMIN/LECTURA) del ADR 0012, aplicado parejo a
toda la API. Se evaluó bloquear también por sección en el backend, pero hoy
"Formularios" y "Reportes" comparten literalmente las mismas rutas
`/api/admin/*` (el ABM y el reporte de una misma entidad usan el mismo
endpoint GET) — separarlas de verdad requeriría reorganizar esas rutas antes,
así que queda para una vuelta aparte si hace falta.

## Cómo funciona

- **`UsuarioSecciones`** (tabla nueva): pares `(UsuarioID, Seccion)`, donde
  `Seccion` es un id de texto libre — la misma lista de ids que ya usan los
  `NAV_ITEMS` de nivel superior en `Sidebar.jsx` (`pricing`, `admin`,
  `reports`, `manual`, `health`, `erp`, `ml-integracion`,
  `cola-ml-aprobacion`, `usuarios`). No hay un enum separado en el backend
  para no duplicar esa lista en dos lugares que podrían desincronizarse.
- El primer ADMIN (bootstrap, ADR 0012) recibe automáticamente **todas** las
  secciones — no tiene sentido pedirle que tilde algo para verse a sí mismo
  todo. Cualquier Usuario creado después arranca sin ninguna sección: quien
  lo da de alta elige explícitamente cuáles tildar.
- En el frontend, `Sidebar.jsx` solo lista en el menú las secciones que el
  Usuario logueado tiene tildadas. `SectionGuard` (nuevo) envuelve cada
  `<Route>` de `App.jsx` y muestra un panel "Sin acceso" en vez del contenido
  real si la sección no está permitida — cubre tanto entrar por el menú
  (que ya no muestra el ítem) como escribir la URL a mano.
- Pantalla "Usuarios": el alta de un usuario nuevo tiene un checkbox por
  sección; cada fila del listado tiene un botón "Editar permisos" que abre
  el mismo grupo de checkboxes y los guarda con `PUT /api/admin/usuarios/
  {id}/secciones`.
- `LoginGate` refresca `localStorage` con la respuesta de `GET /api/auth/me`
  en cada carga de página (no solo al loguearse) — así, si un ADMIN cambia
  los permisos de alguien que ya tiene sesión abierta, esa persona los ve
  actualizados la próxima vez que recarga, sin tener que volver a loguearse.

## Validado

- Bootstrap del primer ADMIN → devuelve las 9 secciones sin pedir nada.
- Usuario LECTURA creado con solo `["pricing","reports"]` → editado después a
  solo `["pricing"]` vía `PUT .../secciones` → el listado de Usuarios refleja
  el cambio.
- Probado en navegador real: logueado como ese Usuario, el menú solo muestra
  "Pricing"; navegar a `/reports` directo por URL muestra "Sin acceso" en vez
  del reporte.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios.
