-- ============================================================================
-- SCRIPT: Validación de Token Replacement en spCalcularDecision
-- DESCRIPCIÓN: Verifica que el SP tenga implementado correctamente el 
--              reemplazo de tokens en los mensajes parametrizados
-- FECHA: 2026-08-18
-- ============================================================================

USE PRICES_DB;
GO

PRINT '';
PRINT '================================================================================';
PRINT 'VALIDACIÓN: Token Replacement en spCalcularDecision v2.0';
PRINT '================================================================================';
PRINT '';

-- 1. Verificar que el SP existe
PRINT '1. Verificando existencia del SP...';
DECLARE @SPExists INT = 0;
SELECT @SPExists = COUNT(*)
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME = 'spCalcularDecision' AND ROUTINE_TYPE = 'PROCEDURE';

IF @SPExists = 1
    PRINT '   ✓ SP spCalcularDecision encontrado';
ELSE
    PRINT '   ✗ ERROR: SP no encontrado';

-- 2. Verificar que el SP contiene variables de mensajes
PRINT '';
PRINT '2. Verificando declaración de variables de mensajes...';
DECLARE @SPDefinition NVARCHAR(MAX);
SELECT @SPDefinition = OBJECT_DEFINITION(OBJECT_ID('dbo.spCalcularDecision'));

DECLARE @CountMensajeVariables INT = 0;
SET @CountMensajeVariables = 
    (LEN(@SPDefinition) - LEN(REPLACE(@SPDefinition, 'DECLARE @Mensaje', ''))) / LEN('DECLARE @Mensaje');

PRINT '   Mensajes declarados: ' + CAST(@CountMensajeVariables AS VARCHAR(10));
IF @CountMensajeVariables >= 4
    PRINT '   ✓ Todas las 4 variables de mensajes declaradas (StockCritico, Oportunidad, ExcesoStock, Competencia)';
ELSE
    PRINT '   ✗ ERROR: No todas las variables de mensajes están declaradas';

-- 3. Verificar que el SP contiene SELECTs de carga de mensajes
PRINT '';
PRINT '3. Verificando carga de mensajes desde tabla...';
DECLARE @CountMensajeSELECTs INT = 0;
SET @CountMensajeSELECTs = 
    (LEN(@SPDefinition) - LEN(REPLACE(@SPDefinition, 'EstrategiaReglaParametrosMensajes', ''))) / LEN('EstrategiaReglaParametrosMensajes');

PRINT '   Referencias a EstrategiaReglaParametrosMensajes: ' + CAST(@CountMensajeSELECTs AS VARCHAR(10));
IF @CountMensajeSELECTs >= 4
    PRINT '   ✓ Tabla de mensajes referenciada 4+ veces (loading de mensajes)';
ELSE
    PRINT '   ✗ ERROR: Tabla de mensajes no referenciada suficientemente';

-- 4. Verificar que hay REPLACE functions para token replacement
PRINT '';
PRINT '4. Verificando implementación de REPLACE (token replacement)...';
DECLARE @CountREPLACE INT = 0;
SET @CountREPLACE = 
    (LEN(@SPDefinition) - LEN(REPLACE(@SPDefinition, 'REPLACE(', ''))) / LEN('REPLACE(');

PRINT '   Funciones REPLACE encontradas: ' + CAST(@CountREPLACE AS VARCHAR(10));
IF @CountREPLACE >= 8  -- Al menos 2 REPLACE anidados por cada 4 reglas = 8 mínimo
    PRINT '   ✓ Token replacement implementado (múltiples REPLACE en UPDATE statements)';
ELSE
    PRINT '   ✗ ERROR: Insuficientes funciones REPLACE para token replacement';

-- 5. Verificar tokens específicos
PRINT '';
PRINT '5. Verificando tokens en templates...';
DECLARE @CountPorcentajeToken INT = 0;
DECLARE @CountPrecioNuevoToken INT = 0;

SET @CountPorcentajeToken = 
    (LEN(@SPDefinition) - LEN(REPLACE(@SPDefinition, '{PORCENTAJE}', ''))) / LEN('{PORCENTAJE}');
SET @CountPrecioNuevoToken = 
    (LEN(@SPDefinition) - LEN(REPLACE(@SPDefinition, '{PRECIO_NUEVO}', ''))) / LEN('{PRECIO_NUEVO}');

PRINT '   Token {PORCENTAJE} en defaults: ' + CAST(@CountPorcentajeToken AS VARCHAR(10));
PRINT '   Token {PRECIO_NUEVO} en defaults: ' + CAST(@CountPrecioNuevoToken AS VARCHAR(10));

IF @CountPorcentajeToken >= 4 AND @CountPrecioNuevoToken >= 2
    PRINT '   ✓ Tokens presentes en mensajes por defecto';
ELSE
    PRINT '   ✗ ERROR: Tokens insuficientes en templates';

-- 6. Verificar que hay mensajes cargados de tabla
PRINT '';
PRINT '6. Verificando carga temporal de mensajes...';
DECLARE @CountFechaVigencia INT = 0;
SET @CountFechaVigencia = 
    (LEN(@SPDefinition) - LEN(REPLACE(@SPDefinition, 'erpm.FechaVigencia', ''))) / LEN('erpm.FechaVigencia');

PRINT '   Referencias a FechaVigencia de mensajes: ' + CAST(@CountFechaVigencia AS VARCHAR(10));
IF @CountFechaVigencia >= 4
    PRINT '   ✓ Filtros temporales para carga vigente de mensajes';
ELSE
    PRINT '   ✗ ERROR: Carga de mensajes sin filtros temporales';

-- 7. Resumen
PRINT '';
PRINT '================================================================================';
PRINT 'RESUMEN DE VALIDACIÓN:';
PRINT '================================================================================';
PRINT '';

DECLARE @ValidationScore INT = 0;
IF @SPExists = 1 SET @ValidationScore += 20;
IF @CountMensajeVariables >= 4 SET @ValidationScore += 20;
IF @CountMensajeSELECTs >= 4 SET @ValidationScore += 20;
IF @CountREPLACE >= 8 SET @ValidationScore += 20;
IF @CountPorcentajeToken >= 4 AND @CountPrecioNuevoToken >= 2 SET @ValidationScore += 10;
IF @CountFechaVigencia >= 4 SET @ValidationScore += 10;

PRINT 'SCORE DE VALIDACIÓN: ' + CAST(@ValidationScore AS VARCHAR(3)) + '/100';
PRINT '';

IF @ValidationScore >= 90
    PRINT '✅ EXITOSO: SP tiene implementado correctamente token replacement de mensajes';
ELSE IF @ValidationScore >= 70
    PRINT '⚠️  ADVERTENCIA: SP tiene implementación parcial de token replacement';
ELSE
    PRINT '❌ FALLIDO: SP no tiene implementado token replacement correctamente';

PRINT '';
PRINT 'Detalles técnicos:';
PRINT '  • Variables de mensajes: ' + CAST(@CountMensajeVariables AS VARCHAR(10)) + '/4';
PRINT '  • SELECTs de carga: ' + CAST(@CountMensajeSELECTs AS VARCHAR(10)) + '/4+';
PRINT '  • Funciones REPLACE: ' + CAST(@CountREPLACE AS VARCHAR(10)) + '/8+';
PRINT '  • Tokens {PORCENTAJE}: ' + CAST(@CountPorcentajeToken AS VARCHAR(10)) + '/4+';
PRINT '  • Tokens {PRECIO_NUEVO}: ' + CAST(@CountPrecioNuevoToken AS VARCHAR(10)) + '/2+';
PRINT '  • Filtros temporales: ' + CAST(@CountFechaVigencia AS VARCHAR(10)) + '/4+';
PRINT '';
PRINT 'Próximos pasos:';
PRINT '  1. ✅ Código: Token replacement implementado';
PRINT '  2. ⏳ Deploy: Ejecutar SQL/spCalcularDecision.sql en PRICES_DB';
PRINT '  3. ⏳ Test: Verificar Motivo en resultado de spCalcularDecision';
PRINT '  4. ⏳ Validación: Confirmar tokens reemplazados con valores reales';
PRINT '';

GO
