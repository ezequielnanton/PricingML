-- Migración idempotente: configuración de la ejecución automática del ciclo completo
-- (ERP -> evaluar todos los productos -> procesar cola ML -> sincronizar ML). Fila
-- única, mismo patrón que ConfiguracionEmail/ConfiguracionMercadoLibre.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ConfiguracionEjecucionAutomatica')
BEGIN
    CREATE TABLE ConfiguracionEjecucionAutomatica (
        ConfiguracionEjecucionAutomaticaID INT IDENTITY(1,1) NOT NULL,
        Activo BIT NOT NULL CONSTRAINT DF_ConfigEjecAuto_Activo DEFAULT (0),
        IntervaloMinutos INT NOT NULL CONSTRAINT DF_ConfigEjecAuto_Intervalo DEFAULT (30),
        UltimaEjecucion DATETIME2(3) NULL,
        UltimoResultadoOk BIT NULL,
        UltimoResultadoResumen VARCHAR(1000) NULL,
        FechaActualizacion DATETIME2(3) NULL,
        CONSTRAINT PK_ConfigEjecAuto PRIMARY KEY CLUSTERED (ConfiguracionEjecucionAutomaticaID)
    );
    PRINT 'Tabla ConfiguracionEjecucionAutomatica creada.';
END
ELSE
    PRINT 'Tabla ConfiguracionEjecucionAutomatica ya existía.';
