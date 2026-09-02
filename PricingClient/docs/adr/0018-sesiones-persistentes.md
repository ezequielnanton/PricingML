# Sesiones de Usuario persistentes (sobreviven a un reinicio de la API)

Las sesiones de Usuario (ADR 0012) vivían en un `ConcurrentDictionary` en
memoria — un reinicio de la API (deploy, crash, mantenimiento) desloguea a
todo el mundo de golpe. Con más gente usando la app día a día, ese costo
empezó a pesar.

## Cómo funciona

- **`UsuarioSesiones`** (tabla nueva): reemplaza al diccionario en memoria.
  Cada fila es un token con una copia (`NombreCompleto`, `Rol`,
  `SeccionesCsv`) tomada en el momento del login, más su vencimiento.
- **Mismo diseño de siempre, ahora persistido**: la sesión sigue siendo un
  snapshot fijo desde el login — un cambio de Rol o de Secciones (ADR 0013)
  no se refleja hasta el próximo login, exactamente igual que cuando vivía
  en memoria. Lo único que cambia es *dónde* vive ese snapshot.
- `LoginAsync` inserta la fila; `LogoutAsync` (antes `Logout`, ahora async)
  la borra; `ResolveToken`/`ResolveSession` (también ahora async) la leen
  de la base y, si ya venció, la borran ahí mismo (limpieza perezosa, sin
  job de background).
- Todo el resto del flujo de auth (middleware de `Program.cs`, `/api/auth/
  me`, `/api/auth/logout`, `/api/auth/cambiar-password`) se actualizó para
  `await` estos métodos.

## Validado

- Login → `GET /api/auth/me` funciona → **se mata el proceso de la API de
  verdad** (no solo se reinicia el código) → se levanta de nuevo → el
  mismo token, sin volver a loguearse, sigue funcionando.
- Logout borra la fila de `UsuarioSesiones` y el token deja de servir
  (401) de inmediato.
- Una sesión vencida (insertada a mano con `FechaExpiracion` en el pasado)
  se rechaza (401) y la fila se borra sola en ese mismo request.
- Probado en navegador real: login, entrar a "Usuarios", todo funciona
  igual que antes del cambio.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): 10/10 sin cambios
  — el cambio es puramente de sesión HTTP, no toca `spCalcularDecision`.
