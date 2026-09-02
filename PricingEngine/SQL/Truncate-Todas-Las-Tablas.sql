-- ============================================================================
-- SCRIPT DE LIMPIEZA TOTAL DE PRICES_DB
-- ============================================================================
-- ADVERTENCIA: DESTRUYE TODOS LOS DATOS DE LAS TABLAS DE NEGOCIO.
-- No elimina tablas, constraints, índices, procedimientos ni funciones.
--
-- SQL Server no permite TRUNCATE TABLE sobre tablas referenciadas por FK.
-- Por eso se usa DELETE en orden de dependencias y se reinician los IDENTITY.
--
-- EJECUTAR SOLO DESPUES DE CONFIRMAR BACKUP.
-- ============================================================================

USE PRICES_DB;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

BEGIN TRY
    -- Tablas independientes o de mayor nivel de dependencia
    DELETE FROM dbo.BacktestingResultados;
    DELETE FROM dbo.ColaEjecucionML;
    DELETE FROM dbo.DecisionesDetalleAuditoria;
    DELETE FROM dbo.CompetenciaSnapshot;
    DELETE FROM dbo.MetricasVentasHist;
    DELETE FROM dbo.EstrategiaReglaParametrosMensajes;
    DELETE FROM dbo.EstrategiaReglaParametros;
    DELETE FROM dbo.StockEstado;
    DELETE FROM dbo.CostosProducto;
    DELETE FROM dbo.Cotizaciones;
    DELETE FROM dbo.ParametrosGenerales;
    DELETE FROM dbo.DecisionesHistorial;
    DELETE FROM dbo.PublicacionesML;
    DELETE FROM dbo.EstrategiaReglas;
    DELETE FROM dbo.Estrategias;
    DELETE FROM dbo.CuentasML;
    DELETE FROM dbo.Productos;
    DELETE FROM dbo.ConfiguracionParametros;
    DELETE FROM dbo.ReglasNegocio;
    DELETE FROM dbo.Monedas;
    DELETE FROM dbo.Empresas;

    -- Reiniciar columnas IDENTITY para que el próximo registro comience en 1.
    DBCC CHECKIDENT ('dbo.BacktestingResultados', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.ColaEjecucionML', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.CompetenciaSnapshot', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.ConfiguracionParametros', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.CostosProducto', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Cotizaciones', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.CuentasML', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DecisionesDetalleAuditoria', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DecisionesHistorial', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Empresas', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.EstrategiaReglaParametros', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.EstrategiaReglaParametrosMensajes', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.EstrategiaReglas', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Estrategias', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.MetricasVentasHist', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Monedas', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.ParametrosGenerales', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.Productos', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.PublicacionesML', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.ReglasNegocio', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.StockEstado', RESEED, 0) WITH NO_INFOMSGS;

    COMMIT TRANSACTION;
    PRINT 'Limpieza completada correctamente.';
    PRINT 'Todos los datos fueron eliminados y los IDENTITY fueron reiniciados.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Verificación posterior opcional:
-- SELECT t.name AS Tabla, p.rows AS Filas
-- FROM sys.tables t
-- INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
-- WHERE t.is_ms_shipped = 0
-- ORDER BY t.name;
