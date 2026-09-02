-- Migración idempotente: credenciales de la app de MercadoLibre configurables desde
-- la UI, en vez de solo por appsettings.json. Fila única (una app de ML por
-- instalación, autorizada por cada Cuenta ML vía OAuth).

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ConfiguracionMercadoLibre')
BEGIN
    CREATE TABLE ConfiguracionMercadoLibre (
        ConfiguracionMercadoLibreID INT IDENTITY(1,1) NOT NULL,
        ClientId VARCHAR(200) NULL,
        ClientSecret VARCHAR(200) NULL,
        ApiBaseUrl VARCHAR(300) NULL,
        FechaActualizacion DATETIME2(3) NOT NULL CONSTRAINT DF_ConfigML_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_ConfiguracionMercadoLibre PRIMARY KEY CLUSTERED (ConfiguracionMercadoLibreID)
    );
    PRINT 'Tabla ConfiguracionMercadoLibre creada.';
END
ELSE
    PRINT 'Tabla ConfiguracionMercadoLibre ya existía, sin cambios.';
