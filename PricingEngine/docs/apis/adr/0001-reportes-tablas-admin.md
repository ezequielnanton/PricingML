# Reportes de tablas mediante API administrativa uniforme

Los reportes de todas las tablas, incluyendo historial, auditoría y cola, se exponen como consultas REST de solo lectura bajo `GET /api/admin/{recurso-en-plural}`. Se eligió una convención única con paginación, filtros y ordenamiento dinámicos para que la UI pueda tratar todas las tablas de forma consistente y evitar rutas específicas o acceso directo a SQL.
