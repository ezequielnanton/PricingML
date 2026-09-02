# Login general para el resto de la app

Hasta ahora, solo la pantalla de Repositor tenía autenticación. AdminPanel, Cola
ML (Aprobación), Integración ERP/MercadoLibre, Reportes y la evaluación de
Pricing eran de acceso libre — cualquiera con la URL podía entrar, y ninguna
aprobación o vínculo de competidor quedaba atado a una persona.

## Decisiones (confirmadas con el usuario)

- **Usuarios nombrados con rol**, no una sola contraseña compartida: permite
  saber después quién aprobó/rechazó cada cambio de precio (`ColaEjecucionML.
  UsuarioAprobacionID`) y quién vinculó cada competidor manual
  (`PublicacionCompetidoresManual.UsuarioVinculoID`).
- **Alcance global**, no por Empresa (a diferencia de Repositor): estas
  pantallas ya operan sobre todas las Empresas de la instalación sin filtrar,
  así que el login no cambia qué datos se ven, solo agrega la puerta de
  entrada.
- **Rol simple** (`ADMIN` / `LECTURA`), interpretado por verbo HTTP: cualquier
  sesión válida puede hacer GET; POST/PUT/DELETE/PATCH requieren `ADMIN`. Un
  usuario LECTURA puede ver todo pero no aprobar, vincular ni guardar nada.

## Cómo funciona

- Tabla `Usuarios` (Usuario+contraseña hasheada con PBKDF2, igual patrón que
  `Repositores`), sesiones por token en memoria (12h), mismo esquema que
  `RepositorAuthService` — sin JWT ni tabla de sesión.
- Un middleware en `Program.cs` exige `Authorization: Bearer` válido para todo
  lo que empiece con `/api/admin`, `/api/marketplace`, `/pricing/evaluate` o
  `/api/input/ui`. Quedan explícitamente afuera: `/health`, `/api/auth/*` (el
  login mismo), y las rutas de integración externa que ya tienen su propio
  modelo de auth — Repositor por Usuario+PIN (`/api/input/repositor/*`,
  `/api/input/stock/*`) y ERP por ApiKey (`/api/erp/*`) — exigirles un token de
  Usuario rompería flujos que no opera una persona logueada en el navegador.
- **Excepción deliberada**: `GET /api/marketplace/ml/oauth/iniciar` y
  `GET /api/marketplace/ml/oauth/callback` (ADR 0011) quedan fuera del gate.
  Son navegaciones de navegador comunes (un `<a href>` y la redirección que
  hace MercadoLibre de vuelta), nunca llevan el header `Authorization` — su
  propia protección es el `state` de un solo uso, no un token de Usuario.
- **Bootstrap sin chicken-and-egg**: mientras la tabla `Usuarios` esté vacía,
  `POST /api/auth/setup-primer-admin` (fuera del gate, no requiere sesión)
  crea el primer `ADMIN`. Una vez que existe al menos uno, ese endpoint
  devuelve 409 y el alta pasa a requerir sesión ADMIN vía `POST /api/admin/
  usuarios`.
- En el frontend, `LoginGate` envuelve el árbol de `App` (nunca
  `/repositor/*`, que tiene su propio login) y muestra el alta del primer
  admin o el login normal según `GET /api/auth/existe-usuario`.
  `authFetch.js` parchea `window.fetch` una sola vez, en el arranque, para
  agregar el Bearer token a todo request contra la propia API — evita tener
  que retocar los fetch() ya escritos en más de una decena de componentes, y
  limpia la sesión local si la API responde 401.
- Pantalla nueva "Usuarios" (alta/baja, visible para cualquier sesión; el
  formulario de alta solo se muestra si el usuario logueado es ADMIN).

## Validado

- Ruta protegida sin token → 401; con token de sesión válida → 200.
- Bootstrap crea el primer ADMIN; un segundo intento de bootstrap → 409.
- Usuario LECTURA: GET permitido, POST de aprobación → 403 ("Tu usuario es de
  solo lectura").
- `iniciar`/`callback` de OAuth siguen funcionando sin ningún header de
  autenticación (400/200 según corresponda, nunca 401).
- Probado en navegador real: bootstrap → sesión activa → Usuarios lista al
  admin recién creado → Cerrar sesión → vuelve a login (no a bootstrap,
  porque ya existe un usuario) → login exitoso vuelve a la misma ruta.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios —
  el gate es puramente HTTP, no toca `spCalcularDecision`.
