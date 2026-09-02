-- Migración idempotente: "Competidores vinculados" (no catálogo) pasa de intentar
-- refrescar el precio del competidor contra la API real de ML a que el usuario lo
-- cargue y lo actualice a mano -- MercadoLibre bloquea tanto la búsqueda pública por
-- texto (GET /sites/{site}/search) como la lectura de una publicación ajena por ID
-- (GET /items/{id}) para apps de terceros, confirmado contra la API real (ver ADR
-- 0010). Como nunca se puede traer el precio solo, UltimoPrecio/FechaUltimoPrecio
-- guardan el último valor que el usuario escribió y cuándo, para poder mostrar
-- "actualizado hace X días" en vez de fingir un dato en vivo que no existe.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PublicacionCompetidoresManual') AND name = 'UltimoPrecio')
BEGIN
    ALTER TABLE PublicacionCompetidoresManual ADD UltimoPrecio DECIMAL(18,2) NULL;
    PRINT 'Columna UltimoPrecio agregada a PublicacionCompetidoresManual.';
END
ELSE
    PRINT 'Columna UltimoPrecio ya existía, sin cambios.';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PublicacionCompetidoresManual') AND name = 'FechaUltimoPrecio')
BEGIN
    ALTER TABLE PublicacionCompetidoresManual ADD FechaUltimoPrecio DATETIME2(3) NULL;
    PRINT 'Columna FechaUltimoPrecio agregada a PublicacionCompetidoresManual.';
END
ELSE
    PRINT 'Columna FechaUltimoPrecio ya existía, sin cambios.';
