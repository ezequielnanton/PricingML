-- Migración idempotente: datos para el flujo OAuth real de conexión de Cuenta ML
-- (SiteId para saber a qué dominio de login de ML mandar al vendedor, RedirectUri
-- que tiene que matchear exacto con lo registrado en la app de ML).

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ConfiguracionMercadoLibre') AND name = 'SiteId')
BEGIN
    ALTER TABLE ConfiguracionMercadoLibre ADD SiteId VARCHAR(10) NULL, RedirectUri VARCHAR(500) NULL;
    PRINT 'Columnas SiteId/RedirectUri agregadas a ConfiguracionMercadoLibre.';
END
ELSE
    PRINT 'ConfiguracionMercadoLibre ya tenía SiteId/RedirectUri.';
