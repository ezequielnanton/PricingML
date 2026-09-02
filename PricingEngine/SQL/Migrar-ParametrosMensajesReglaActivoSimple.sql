-- Los índices filtrados (WHERE Activo = 1) exigen QUOTED_IDENTIFIER ON en la sesión.
SET QUOTED_IDENTIFIER ON;
GO

-- Migración idempotente: Parámetros de Regla y Mensajes de Regla pasan de un modelo
-- versionado por fecha (cada alta/edición insertaba una fila nueva y le cerraba FechaFin a
-- la anterior) a un simple Activo/Inactivo, igual que el resto de los ABMs de la app. El
-- historial de valores pasados sigue viéndose por Reportes (las filas viejas no se borran),
-- no por un botón "Ver Histórico" aparte.
--
-- Las UNIQUE existentes (UQ_EstrategiaRegla_Clave_Vigente / UQ_EstrategiaRegla_Clave_Mensaje_Vigente,
-- sobre FechaFin) no sirven para esto: SQL Server permite múltiples NULL en una columna
-- UNIQUE, así que con el alta simple (que nunca vuelve a tocar FechaFin) esas constraints no
-- evitarían dos parámetros activos con la misma Clave para la misma Estrategia-Regla. Se
-- agregan índices UNIQUE filtrados (WHERE Activo = 1) para eso -- las constraints viejas se
-- dejan como quedaron (no hacen daño, cubren los datos históricos ya cargados).

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_EstrategiaReglaParametros_Activo' AND object_id = OBJECT_ID('EstrategiaReglaParametros'))
BEGIN
    CREATE UNIQUE INDEX UQ_EstrategiaReglaParametros_Activo ON EstrategiaReglaParametros(EstrategiaReglaID, Clave) WHERE Activo = 1;
    PRINT 'Índice UQ_EstrategiaReglaParametros_Activo creado.';
END
ELSE
    PRINT 'Índice UQ_EstrategiaReglaParametros_Activo ya existía, sin cambios.';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_EstrategiaReglaParametrosMensajes_Activo' AND object_id = OBJECT_ID('EstrategiaReglaParametrosMensajes'))
BEGIN
    CREATE UNIQUE INDEX UQ_EstrategiaReglaParametrosMensajes_Activo ON EstrategiaReglaParametrosMensajes(EstrategiaReglaID, Clave, Idioma) WHERE Activo = 1;
    PRINT 'Índice UQ_EstrategiaReglaParametrosMensajes_Activo creado.';
END
ELSE
    PRINT 'Índice UQ_EstrategiaReglaParametrosMensajes_Activo ya existía, sin cambios.';
