-- ============================================================================
-- SCRIPT: Inicialización de Parámetros de Reglas de Pricing
-- DESCRIPCIÓN: Inserta parámetros iniciales en EstrategiaReglaParametros
--              para que el motor de pricing funcione con valores parametrizados
-- FECHA: 2026-08-18
-- ============================================================================

USE PRICES_DB;
GO

-- ============================================================================
-- ASUME: Existen estrategias y reglas creadas previamente
-- Para verificar:
-- SELECT EstrategiaID, NombreEstrategia FROM Estrategias;
-- SELECT EstrategiaReglaID, EstrategiaID, ReglaID FROM EstrategiaReglas;
-- SELECT ReglaID, CodigoRegla FROM ReglasNegocio;
-- ============================================================================

-- ============================================================================
-- EJEMPLO 1: Estrategia "AGRESIVA" (valores altos para maximizar margen)
-- Asume: @EstrategiaID = 1, y reglas ya vinculadas en EstrategiaReglas
-- ============================================================================

-- Obtener IDs de reglas y estrategia-reglas (adaptar según tus datos)
DECLARE @EstrategiaAgresiva INT = 1;
DECLARE @ReglaStockCriticoID INT;
DECLARE @ReglaOportunidadID INT;
DECLARE @ReglaExcesoStockID INT;
DECLARE @ReglaCompetenciaID INT;

SELECT @ReglaStockCriticoID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_STOCK_CRITICO';
SELECT @ReglaOportunidadID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_OPORTUNIDAD';
SELECT @ReglaExcesoStockID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_EXCESO_STOCK';
SELECT @ReglaCompetenciaID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_COMPETENCIA_ABAJO';

-- Obtener EstrategiaReglaID para cada regla en esta estrategia
DECLARE @EstrategiaReglaStockCritico INT;
DECLARE @EstrategiaReglaOportunidad INT;
DECLARE @EstrategiaReglaExcesoStock INT;
DECLARE @EstrategiaReglaCompetencia INT;

SELECT @EstrategiaReglaStockCritico = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaStockCriticoID;

SELECT @EstrategiaReglaOportunidad = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaOportunidadID;

SELECT @EstrategiaReglaExcesoStock = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaExcesoStockID;

SELECT @EstrategiaReglaCompetencia = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaCompetenciaID;

-- Insertar parámetros para estrategia AGRESIVA
-- (Valores altos para maximizar margen y liquidación de stock)
IF @EstrategiaReglaStockCritico IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaStockCritico, 'PORCENTAJE_INCREMENTO_STOCK_CRITICO', 8.00, 
            'Agresiva: Sube 8% si stock crítico (protege ruptura)');
END

IF @EstrategiaReglaOportunidad IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaOportunidad, 'PORCENTAJE_INCREMENTO_OPORTUNIDAD', 5.00, 
            'Agresiva: Sube 5% si oportunidad de mercado (sin competencia)');
END

IF @EstrategiaReglaExcesoStock IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaExcesoStock, 'PORCENTAJE_DECREMENTO_EXCESO_STOCK', 10.00, 
            'Agresiva: Baja 10% si exceso stock (liquidación agresiva)');
END

IF @EstrategiaReglaCompetencia IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaCompetencia, 'PORCENTAJE_DESCUENTO_COMPETENCIA', 2.00, 
            'Agresiva: Descuenta 2% del precio competencia para ganar posición');
END

-- ============================================================================
-- EJEMPLO 2: Estrategia "CONSERVADORA" (valores bajos para preservar margen)
-- Asume: @EstrategiaID = 2
-- ============================================================================

DECLARE @EstrategiaConservadora INT = 2;

DECLARE @EstrategiaReglaStockCriticoConserv INT;
DECLARE @EstrategiaReglaOportunidadConserv INT;
DECLARE @EstrategiaReglaExcesoStockConserv INT;
DECLARE @EstrategiaReglaCompetenciaConserv INT;

SELECT @EstrategiaReglaStockCriticoConserv = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaStockCriticoID;

SELECT @EstrategiaReglaOportunidadConserv = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaOportunidadID;

SELECT @EstrategiaReglaExcesoStockConserv = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaExcesoStockID;

SELECT @EstrategiaReglaCompetenciaConserv = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaCompetenciaID;

-- Insertar parámetros para estrategia CONSERVADORA
-- (Valores bajos para preservar márgenes)
IF @EstrategiaReglaStockCriticoConserv IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaStockCriticoConserv, 'PORCENTAJE_INCREMENTO_STOCK_CRITICO', 2.00, 
            'Conservadora: Sube apenas 2% si stock crítico (protege margen)');
END

IF @EstrategiaReglaOportunidadConserv IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaOportunidadConserv, 'PORCENTAJE_INCREMENTO_OPORTUNIDAD', 1.00, 
            'Conservadora: Sube 1% si oportunidad (margen es prioridad)');
END

IF @EstrategiaReglaExcesoStockConserv IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaExcesoStockConserv, 'PORCENTAJE_DECREMENTO_EXCESO_STOCK', 3.00, 
            'Conservadora: Baja 3% si exceso stock (liquidación suave)');
END

IF @EstrategiaReglaCompetenciaConserv IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES (@EstrategiaReglaCompetenciaConserv, 'PORCENTAJE_DESCUENTO_COMPETENCIA', 0.50, 
            'Conservadora: Descuenta 0.5% del competencia (defiende margen)');
END

-- ============================================================================
-- VERIFICACIÓN: Listar parámetros creados
-- ============================================================================

PRINT '';
PRINT '=== PARÁMETROS CREADOS ===';
PRINT '';

SELECT 
    e.NombreEstrategia,
    r.CodigoRegla,
    erp.Clave,
    erp.Valor AS ValorParametro,
    erp.Descripcion,
    erp.Activo,
    erp.FechaCreacion
FROM EstrategiaReglaParametros erp
INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
INNER JOIN Estrategias e ON er.EstrategiaID = e.EstrategiaID
INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
ORDER BY e.NombreEstrategia, r.CodigoRegla;

-- ============================================================================
-- NOTA: Cambiar estrategias/reglas según lo que tengas en tu base
-- Ejecuta primero las queries de verificación arriba para obtener IDs reales
-- ============================================================================

PRINT '';
PRINT 'Inicialización completada. Los parámetros son vigentes desde ahora.';
PRINT 'Para consultar parámetros vigentes de una estrategia:';
PRINT '  SELECT * FROM EstrategiaReglaParametros';
PRINT '  WHERE Activo = 1 AND FechaVigencia <= SYSDATETIME()';
PRINT '    AND (FechaFin IS NULL OR FechaFin > SYSDATETIME());';
