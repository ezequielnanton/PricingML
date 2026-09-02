-- Migración idempotente: "Competidores vinculados" (no catálogo) pasa a mostrarse
-- como una grilla (link, título, moneda, precio) en vez de una lista simple.
-- MonedaID es la moneda en la que el usuario cargó el precio del competidor --
-- por defecto se sugiere la Moneda Principal de la Empresa dueña de la publicación
-- (ParametrosGenerales.MonedaPrincipalID), pero el usuario puede elegir otra.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PublicacionCompetidoresManual') AND name = 'MonedaID')
BEGIN
    ALTER TABLE PublicacionCompetidoresManual ADD MonedaID INT NULL;
    ALTER TABLE PublicacionCompetidoresManual ADD CONSTRAINT FK_PublicacionCompetidoresManual_Moneda FOREIGN KEY (MonedaID) REFERENCES Monedas(MonedaID);
    PRINT 'Columna MonedaID agregada a PublicacionCompetidoresManual.';
END
ELSE
    PRINT 'Columna MonedaID ya existía, sin cambios.';
