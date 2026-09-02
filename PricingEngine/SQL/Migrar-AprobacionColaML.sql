-- Migración idempotente: workflow de aprobación para la cola de MercadoLibre.
-- #aprobacionColaMl: las publicaciones que NO son de catálogo siempre piden
-- aprobación antes de subir el precio a ML (no hay competencia confiable ahí).
-- Las de catálogo suben automático solo si ParametrosGenerales.SubidaAutomaticaCatalogoML
-- está activo para esa Empresa; si no, también piden aprobación.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ParametrosGenerales') AND name = 'SubidaAutomaticaCatalogoML')
BEGIN
    ALTER TABLE ParametrosGenerales ADD SubidaAutomaticaCatalogoML BIT NOT NULL CONSTRAINT DF_ParametrosGenerales_SubidaAutoML DEFAULT (0);
    PRINT 'Columna SubidaAutomaticaCatalogoML agregada a ParametrosGenerales.';
END
ELSE
    PRINT 'ParametrosGenerales ya tenía SubidaAutomaticaCatalogoML.';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('DecisionesHistorial') AND name = 'CompetidorItemIDRef')
BEGIN
    ALTER TABLE DecisionesHistorial ADD CompetidorItemIDRef VARCHAR(50) NULL;
    PRINT 'Columna CompetidorItemIDRef agregada a DecisionesHistorial.';
END
ELSE
    PRINT 'DecisionesHistorial ya tenía CompetidorItemIDRef.';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ColaEjecucionML') AND name = 'RequiereAprobacion')
BEGIN
    ALTER TABLE ColaEjecucionML ADD
        Motivo VARCHAR(500) NULL,
        CompetidorItemIDRef VARCHAR(50) NULL,
        PrecioCompetidorRef DECIMAL(18,4) NULL,
        RequiereAprobacion BIT NOT NULL CONSTRAINT DF_ColaEjecucionML_RequiereAprobacion DEFAULT (0),
        Aprobado BIT NULL,
        FechaAprobacion DATETIME2(3) NULL;
    PRINT 'Columnas de aprobación agregadas a ColaEjecucionML.';
END
ELSE
    PRINT 'ColaEjecucionML ya tenía las columnas de aprobación.';
