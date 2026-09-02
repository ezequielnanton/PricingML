-- Migración idempotente: vínculo manual de competidores para publicaciones que NO
-- son de catálogo. ML no define esta relación automáticamente ahí (a diferencia de
-- catálogo, que usa price_to_win) — el usuario busca en ML y elige a quién vincular;
-- ningún vínculo se crea sin esa confirmación explícita.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PublicacionCompetidoresManual')
BEGIN
    CREATE TABLE PublicacionCompetidoresManual (
        VinculoID INT IDENTITY(1,1) NOT NULL,
        PublicacionID INT NOT NULL,
        CompetidorItemID VARCHAR(50) NOT NULL,
        CompetidorTitulo VARCHAR(255) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_PubCompManual_Activo DEFAULT (1),
        FechaVinculo DATETIME2(3) NOT NULL CONSTRAINT DF_PubCompManual_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_PublicacionCompetidoresManual PRIMARY KEY CLUSTERED (VinculoID),
        CONSTRAINT FK_PubCompManual_Publicacion FOREIGN KEY (PublicacionID) REFERENCES PublicacionesML(PublicacionID),
        CONSTRAINT UQ_PubCompManual_Publicacion_Item UNIQUE (PublicacionID, CompetidorItemID)
    );
    PRINT 'Tabla PublicacionCompetidoresManual creada.';
END
ELSE
    PRINT 'Tabla PublicacionCompetidoresManual ya existía, sin cambios.';
