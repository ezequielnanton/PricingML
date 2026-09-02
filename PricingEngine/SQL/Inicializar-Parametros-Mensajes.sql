-- ============================================================================
-- SCRIPT: Inicialización de Mensajes Parametrizados de Reglas de Pricing
-- DESCRIPCIÓN: Inserta mensajes iniciales en EstrategiaReglaParametrosMensajes
--              en Español e Inglés (ejemplos multi-idioma)
-- FECHA: 2026-08-18
-- ============================================================================

USE PRICES_DB;
GO

-- ============================================================================
-- CONTEXTO: Asume que existen:
-- 1. Estrategias (AGRESIVA, CONSERVADORA)
-- 2. EstrategiaReglas vinculadas para 4 reglas
-- 3. Parámetros numéricos ya creados
-- ============================================================================

-- Obtener estrategias como referencia
DECLARE @EstrategiaAgresiva INT = 1;
DECLARE @EstrategiaConservadora INT = 2;

-- Obtener EstrategiaReglaIDs para cada regla en estrategia AGRESIVA
DECLARE @ErAgresiva_StockCritico INT;
DECLARE @ErAgresiva_Oportunidad INT;
DECLARE @ErAgresiva_ExcesoStock INT;
DECLARE @ErAgresiva_Competencia INT;

-- Obtener EstrategiaReglaIDs para cada regla en estrategia CONSERVADORA
DECLARE @ErConserv_StockCritico INT;
DECLARE @ErConserv_Oportunidad INT;
DECLARE @ErConserv_ExcesoStock INT;
DECLARE @ErConserv_Competencia INT;

-- Obtener ReglaIDs
DECLARE @ReglaStockCriticoID INT;
DECLARE @ReglaOportunidadID INT;
DECLARE @ReglaExcesoStockID INT;
DECLARE @ReglaCompetenciaID INT;

SELECT @ReglaStockCriticoID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_STOCK_CRITICO';
SELECT @ReglaOportunidadID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_OPORTUNIDAD';
SELECT @ReglaExcesoStockID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_EXCESO_STOCK';
SELECT @ReglaCompetenciaID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = 'REGLA_COMPETENCIA_ABAJO';

-- Obtener EstrategiaReglaIDs
SELECT @ErAgresiva_StockCritico = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaStockCriticoID;

SELECT @ErAgresiva_Oportunidad = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaOportunidadID;

SELECT @ErAgresiva_ExcesoStock = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaExcesoStockID;

SELECT @ErAgresiva_Competencia = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaAgresiva AND ReglaID = @ReglaCompetenciaID;

-- Conservadora
SELECT @ErConserv_StockCritico = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaStockCriticoID;

SELECT @ErConserv_Oportunidad = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaOportunidadID;

SELECT @ErConserv_ExcesoStock = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaExcesoStockID;

SELECT @ErConserv_Competencia = EstrategiaReglaID
FROM EstrategiaReglas 
WHERE EstrategiaID = @EstrategiaConservadora AND ReglaID = @ReglaCompetenciaID;

-- ============================================================================
-- ESTRATEGIA AGRESIVA - MENSAJES EN ESPAÑOL
-- ============================================================================

PRINT '';
PRINT '=== INSERTANDO MENSAJES: ESTRATEGIA AGRESIVA (ESPAÑOL) ===';

IF @ErAgresiva_StockCritico IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErAgresiva_StockCritico, 
     'MENSAJE_STOCK_CRITICO', 
     'Stock en nivel CRÍTICO: Precio subido {PORCENTAJE}% para reducir venta y proteger ruptura. Acción urgente recomendada.',
     'Agresivo: tono directo sobre urgencia');
END

IF @ErAgresiva_Oportunidad IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErAgresiva_Oportunidad, 
     'MENSAJE_OPORTUNIDAD', 
     'Oportunidad de mercado detectada: Subiendo precio {PORCENTAJE}% sin competencia directa. ¡Margen optimizado!',
     'Agresivo: enfoque en captura de margen');
END

IF @ErAgresiva_ExcesoStock IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErAgresiva_ExcesoStock, 
     'MENSAJE_EXCESO_STOCK', 
     'Liquidación de stock: Descuento agresivo de {PORCENTAJE}% para acelerar movimiento y recuperar flujo de caja.',
     'Agresivo: urgencia en liquidación');
END

IF @ErAgresiva_Competencia IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErAgresiva_Competencia, 
     'MENSAJE_COMPETENCIA', 
     'Competencia detectada más barata: Descuento del {PORCENTAJE}% para ganar posición. Precio final: ${PRECIO_NUEVO}',
     'Agresivo: focus en ganar posición de mercado');
END

-- ============================================================================
-- ESTRATEGIA CONSERVADORA - MENSAJES EN ESPAÑOL
-- ============================================================================

PRINT '';
PRINT '=== INSERTANDO MENSAJES: ESTRATEGIA CONSERVADORA (ESPAÑOL) ===';

IF @ErConserv_StockCritico IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErConserv_StockCritico, 
     'MENSAJE_STOCK_CRITICO', 
     'Ajuste de precio por stock bajo: +{PORCENTAJE}% para equilibrio. Mantener margen seguro.',
     'Conservador: ajuste suave, proteger margen');
END

IF @ErConserv_Oportunidad IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErConserv_Oportunidad, 
     'MENSAJE_OPORTUNIDAD', 
     'Condiciones favorables de mercado: +{PORCENTAJE}% aplicado. Protegiendo márgenes sanos.',
     'Conservador: incremento moderado');
END

IF @ErConserv_ExcesoStock IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErConserv_ExcesoStock, 
     'MENSAJE_EXCESO_STOCK', 
     'Gestión de inventario: -{PORCENTAJE}% para normalizar stock. Margen mínimo garantizado.',
     'Conservador: descuento controlado');
END

IF @ErConserv_Competencia IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Valor, Descripcion)
    VALUES 
    (@ErConserv_Competencia, 
     'MENSAJE_COMPETENCIA', 
     'Ajuste competitivo: -{PORCENTAJE}% respecto a competidor. Precio actual: ${PRECIO_NUEVO}. Margen preservado.',
     'Conservador: defensa suave de margen');
END

-- ============================================================================
-- EJEMPLO MULTI-IDIOMA: INGLÉS (Estrategia AGRESIVA)
-- ============================================================================

PRINT '';
PRINT '=== INSERTAR MENSAJES: ESTRATEGIA AGRESIVA (INGLÉS) ===';

IF @ErAgresiva_StockCritico IS NOT NULL
BEGIN
    INSERT INTO EstrategiaReglaParametrosMensajes 
    (EstrategiaReglaID, Clave, Idioma, Valor, Descripcion, FechaVigencia)
    VALUES 
    (@ErAgresiva_StockCritico, 
     'MENSAJE_STOCK_CRITICO',
     'EN',
     'CRITICAL STOCK LEVEL: Price increased by {PORCENTAJE}% to reduce sales velocity and prevent stockout. Immediate action recommended.',
     'Aggressive: English version with direct tone',
     DATEADD(DAY, 1, SYSDATETIME()));  -- Vigente desde mañana
END

-- ============================================================================
-- VERIFICACIÓN: Listar mensajes creados
-- ============================================================================

PRINT '';
PRINT '=== MENSAJES PARAMETRIZADOS CREADOS ===';
PRINT '';

SELECT 
    e.NombreEstrategia,
    r.CodigoRegla,
    erpm.Clave,
    LEFT(erpm.Valor, 80) AS ValorPreview,
    erpm.Descripcion,
    erpm.Activo,
    erpm.FechaCreacion,
    erpm.FechaVigencia
FROM EstrategiaReglaParametrosMensajes erpm
INNER JOIN EstrategiaReglas er ON erpm.EstrategiaReglaID = er.EstrategiaReglaID
INNER JOIN Estrategias e ON er.EstrategiaID = e.EstrategiaID
INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
ORDER BY e.NombreEstrategia, r.CodigoRegla, erpm.FechaVigencia DESC;

PRINT '';
PRINT 'Inicialización de mensajes completada.';
PRINT '';
PRINT 'Tokens disponibles en plantillas:';
PRINT '  {PORCENTAJE} → Valor del parámetro numérico';
PRINT '  {PRECIO_NUEVO} → Precio calculado final';
PRINT '  {PRECIO_ANTERIOR} → Precio antes del cambio';
PRINT '  {COMPETIDOR_PRECIO} → Precio del competidor';
PRINT '';
PRINT 'Nota: El SP reemplaza automáticamente los tokens con valores reales.';
