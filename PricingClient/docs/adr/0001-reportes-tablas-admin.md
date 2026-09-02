# Reportes de tablas mediante API administrativa uniforme

## Complemento de implementación

Los recursos especializados de parámetros y mensajes por Estrategia-Regla conservan sus rutas por contexto: `.../estrategia/{id}/vigentes` y `.../estrategia-regla/{id}`. El frontend solicita y valida el identificador requerido antes de consultar. Las fuentes históricas automáticas no disponen de formularios de escritura en el cliente.

Los reportes de todas las tablas, incluyendo historial, auditoría y cola, se exponen como consultas REST de solo lectura bajo `GET /api/admin/{recurso-en-plural}`. Se eligió una convención única con paginación, filtros y ordenamiento dinámicos para que la UI pueda tratar todas las tablas de forma consistente y evitar rutas específicas o acceso directo a SQL.
