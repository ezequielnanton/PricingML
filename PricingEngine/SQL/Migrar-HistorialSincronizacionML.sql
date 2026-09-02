-- Migración idempotente: historial de cada corrida de "Sincronizar ML" (solo la parte
-- de Publicaciones -- precio/estado/competencia), con detalle por publicación de qué
-- se actualizó bien y qué falló. Antes esto se calculaba en memoria y se descartaba
-- apenas se armaba el toast de resultado -- no quedaba ningún rastro para revisar
-- después qué publicación falló o por qué.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SincronizacionMLHistorial')
BEGIN
    CREATE TABLE SincronizacionMLHistorial (
        SincronizacionMLID INT IDENTITY(1,1) NOT NULL,
        FechaEjecucion DATETIME2(3) NOT NULL CONSTRAINT DF_SincronizacionML_Fecha DEFAULT (SYSDATETIME()),
        TotalProcesados INT NOT NULL,
        TotalErrores INT NOT NULL,
        ConCompetenciaActualizada INT NOT NULL,
        CONSTRAINT PK_SincronizacionMLHistorial PRIMARY KEY CLUSTERED (SincronizacionMLID)
    );
    PRINT 'Tabla SincronizacionMLHistorial creada.';
END
ELSE
    PRINT 'Tabla SincronizacionMLHistorial ya existía, sin cambios.';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SincronizacionMLDetalle')
BEGIN
    CREATE TABLE SincronizacionMLDetalle (
        SincronizacionMLDetalleID INT IDENTITY(1,1) NOT NULL,
        SincronizacionMLID INT NOT NULL,
        PublicacionID INT NOT NULL,
        MeliItemID VARCHAR(50) NOT NULL,
        Ok BIT NOT NULL,
        Error VARCHAR(1000) NULL,
        CompetenciaActualizada BIT NOT NULL CONSTRAINT DF_SincronizacionMLDetalle_Competencia DEFAULT (0),
        CONSTRAINT PK_SincronizacionMLDetalle PRIMARY KEY CLUSTERED (SincronizacionMLDetalleID),
        CONSTRAINT FK_SincronizacionMLDetalle_Historial FOREIGN KEY (SincronizacionMLID) REFERENCES SincronizacionMLHistorial(SincronizacionMLID),
        CONSTRAINT FK_SincronizacionMLDetalle_Publicacion FOREIGN KEY (PublicacionID) REFERENCES PublicacionesML(PublicacionID)
    );
    PRINT 'Tabla SincronizacionMLDetalle creada.';
END
ELSE
    PRINT 'Tabla SincronizacionMLDetalle ya existía, sin cambios.';
