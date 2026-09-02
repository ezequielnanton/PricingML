# Campanita de notificaciones (Cola ML pendiente de aprobación)

Antes no había ningún aviso en la app de que hubiera cambios de precio
esperando aprobación — había que entrar a "Cola ML (Aprobación)" para
enterarse. Se agregó una campanita en el header, visible en todas las
pantallas.

## Cómo funciona

- **`NotificationBell`** (nuevo componente, en el header de `App.jsx`, junto
  a "Actualizar desde ERP" / "Procesar cola ML" / "Sincronizar ML"): pide
  `GET /api/marketplace/ml/cola-aprobacion` al montar y cada 30s, y muestra
  un pocito rojo con la cantidad de items pendientes sobre el ícono 🔔.
- Al hacer clic se despliega un listado con cada item pendiente (título, SKU
  y a qué precio sugiere subir/bajar). Clickear cualquiera de esos items
  navega a `/cola-ml-aprobacion` y cierra el desplegable — por ahora todas
  las notificaciones vienen de esa única cola, así que todas llevan al mismo
  lugar. El propio componente cierra el desplegable si se hace clic afuera.
- La campanita no se muestra si el Usuario logueado no tiene tildada la
  **Sección permitida** `cola-ml-aprobacion` (ver ADR 0013) — no tiene
  sentido avisarle de algo a lo que no puede entrar.
- Es de solo lectura y de mejor esfuerzo: si el pedido falla (red, sesión
  vencida, etc.) simplemente no actualiza el contador, sin interrumpir el
  resto de la app con un error.

## Validado

- Probado en navegador contra datos reales de la base (28 items pendientes
  acumulados por corridas repetidas de la suite de regresión del motor):
  el pocito muestra "28", el desplegable lista cada item con su
  título/SKU/precio sugerido, y clickear cualquiera navega a
  `/cola-ml-aprobacion` y cierra el desplegable.
- Suite de regresión del motor (`Run-PruebasMotor.ps1`): no se tocó nada del
  backend para esta pieza, solo se consume un endpoint ya existente — no
  hacía falta rerun, pero la corrida usada para generar los datos de prueba
  visual siguió dando 10/10.

## Siguiente paso natural (no implementado ahora)

Si en el futuro aparecen otras fuentes de notificación (por ejemplo, errores
de sincronización con ML/ERP), este componente tendría que generalizarse
para aceptar más de un endpoint y decidir a qué pantalla navegar según el
tipo de notificación — hoy está deliberadamente resuelto para el único caso
pedido ("por ahora vamos a ir siempre a la pantalla de cola ML").
