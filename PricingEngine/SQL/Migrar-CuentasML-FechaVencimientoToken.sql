-- ============================================================================
-- MIGRACIÓN: Fecha de vencimiento del token de Mercado Libre en CuentasML
-- DESCRIPCIÓN: Actualiza una base existente sin recrear tablas ni perder datos.
-- ============================================================================

USE PRICES_DB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.CuentasML') AND name = 'FechaVencimientoToken'
)
BEGIN
    ALTER TABLE dbo.CuentasML ADD FechaVencimientoToken DATETIME2(3) NULL;
END
GO
