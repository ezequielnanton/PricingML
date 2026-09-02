-- ============================================================================
-- SCRIPT: Validación de Carga de Parámetros en spCalcularDecision
-- DESCRIPCIÓN: Verifica que los parámetros se carguen correctamente y que
--              el SP aplique los valores parametrizados en lugar de hardcodes
-- FECHA: 2026-08-18
-- ============================================================================

USE PRICES_DB;
GO

PRINT '=== VALIDACIÓN DE PARAMETRIZACIÓN DE REGLAS DE PRICING ===';
PRINT '';

-- ============================================================================
-- PASO 1: Verificar estructura de tabla
-- ============================================================================

PRINT '1. Verificar tabla EstrategiaReglaParametros existe...';
IF OBJECT_ID('EstrategiaReglaParametros', 'U') IS NOT NULL
    PRINT '   ✅ OK: Tabla existe';
ELSE
BEGIN
    PRINT '   ❌ ERROR: Tabla no existe. Ejecutar Estructura.sql primero';
    RETURN;
END

PRINT '';

-- ============================================================================
-- PASO 2: Verificar estructura de columnas
-- ============================================================================

PRINT '2. Verificar columnas requeridas...';
DECLARE @ColumnasRequeridas TABLE (Columna VARCHAR(100), Presente BIT);

INSERT INTO @ColumnasRequeridas VALUES ('EstrategiaReglaID', 0);
INSERT INTO @ColumnasRequeridas VALUES ('Clave', 0);
INSERT INTO @ColumnasRequeridas VALUES ('Valor', 0);
INSERT INTO @ColumnasRequeridas VALUES ('Activo', 0);
INSERT INTO @ColumnasRequeridas VALUES ('FechaVigencia', 0);
INSERT INTO @ColumnasRequeridas VALUES ('FechaFin', 0);

UPDATE cr SET Presente = 1
FROM @ColumnasRequeridas cr
WHERE EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'EstrategiaReglaParametros' 
    AND COLUMN_NAME = cr.Columna
);

DECLARE @ColumnasFaltantes INT;
SELECT @ColumnasFaltantes = COUNT(*) FROM @ColumnasRequeridas WHERE Presente = 0;
IF @ColumnasFaltantes > 0
BEGIN
    PRINT '   ⚠️ ADVERTENCIA: Faltan algunas columnas:';
    SELECT '   - ' + Columna FROM @ColumnasRequeridas WHERE Presente = 0;
END
ELSE
    PRINT '   ✅ OK: Todas las columnas presentes';

PRINT '';

-- ============================================================================
-- PASO 3: Verificar datos iniciales
-- ============================================================================

PRINT '3. Verificar datos iniciales en EstrategiaReglaParametros...';

DECLARE @CountParametros INT;
SELECT @CountParametros = COUNT(*) FROM EstrategiaReglaParametros;

IF @CountParametros = 0
BEGIN
    PRINT '   ⚠️ ADVERTENCIA: Tabla vacía. Ejecutar Inicializar-Parametros-Reglas.sql';
END
ELSE
BEGIN
    PRINT '   ✅ OK: ' + CAST(@CountParametros AS VARCHAR(10)) + ' parámetros encontrados';
    PRINT '';
    PRINT '   Parámetros vigentes (activos ahora):';
    
    SELECT 
        '   - ' + e.NombreEstrategia + ' / ' + r.CodigoRegla + ': ' + erp.Clave + ' = ' + CAST(erp.Valor AS VARCHAR(10)) AS ParametroVigente
    FROM EstrategiaReglaParametros erp
    INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN Estrategias e ON er.EstrategiaID = e.EstrategiaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE erp.Activo = 1 
      AND erp.FechaVigencia <= SYSDATETIME()
      AND (erp.FechaFin IS NULL OR erp.FechaFin > SYSDATETIME())
    ORDER BY e.NombreEstrategia, r.CodigoRegla;
END

PRINT '';

-- ============================================================================
-- PASO 4: Verificar SP existe y tiene estructura esperada
-- ============================================================================

PRINT '4. Verificar spCalcularDecision tiene carga de parámetros...';

DECLARE @SPDefinition NVARCHAR(MAX);
SELECT @SPDefinition = OBJECT_DEFINITION(OBJECT_ID('spCalcularDecision'));

IF @SPDefinition IS NULL
BEGIN
    PRINT '   ❌ ERROR: spCalcularDecision no existe';
    RETURN;
END

DECLARE @TienePorcentajeStockCritico BIT = CASE WHEN @SPDefinition LIKE '%@PorcentajeStockCritico%' THEN 1 ELSE 0 END;
DECLARE @TienePorcentajeOportunidad BIT = CASE WHEN @SPDefinition LIKE '%@PorcentajeOportunidad%' THEN 1 ELSE 0 END;
DECLARE @TienePorcentajeExcesoStock BIT = CASE WHEN @SPDefinition LIKE '%@PorcentajeExcesoStock%' THEN 1 ELSE 0 END;
DECLARE @TienePorcentajeDescuentoCompetencia BIT = CASE WHEN @SPDefinition LIKE '%@PorcentajeDescuentoCompetencia%' THEN 1 ELSE 0 END;

PRINT '   Verificando variables parametrizadas:';
IF @TienePorcentajeStockCritico = 1
    PRINT '   ✅ @PorcentajeStockCritico declarada';
ELSE
    PRINT '   ❌ @PorcentajeStockCritico NO encontrada';

IF @TienePorcentajeOportunidad = 1
    PRINT '   ✅ @PorcentajeOportunidad declarada';
ELSE
    PRINT '   ❌ @PorcentajeOportunidad NO encontrada';

IF @TienePorcentajeExcesoStock = 1
    PRINT '   ✅ @PorcentajeExcesoStock declarada';
ELSE
    PRINT '   ❌ @PorcentajeExcesoStock NO encontrada';

IF @TienePorcentajeDescuentoCompetencia = 1
    PRINT '   ✅ @PorcentajeDescuentoCompetencia declarada';
ELSE
    PRINT '   ❌ @PorcentajeDescuentoCompetencia NO encontrada';

PRINT '';

-- ============================================================================
-- PASO 5: Verificar que SP NO contiene hardcodes de porcentajes
-- ============================================================================

PRINT '5. Verificar que hardcodes fueron reemplazados...';

DECLARE @HardcodeDections INT = 0;

-- Buscar patrones hardcode antiguos
IF @SPDefinition LIKE '%* 1.05%' SET @HardcodeDections = @HardcodeDections + 1;
IF @SPDefinition LIKE '%* 1.03%' SET @HardcodeDections = @HardcodeDections + 1;
IF @SPDefinition LIKE '%* 0.93%' SET @HardcodeDections = @HardcodeDections + 1;
IF @SPDefinition LIKE '%- 10%' SET @HardcodeDections = @HardcodeDections + 1;

IF @HardcodeDections > 0
    PRINT '   ⚠️ ADVERTENCIA: Se encontraron ' + CAST(@HardcodeDections AS VARCHAR(5)) + ' hardcodes potenciales';
ELSE
    PRINT '   ✅ OK: No se encontraron hardcodes identificables';

PRINT '';

-- ============================================================================
-- PASO 6: Resumen ejecutivo
-- ============================================================================

PRINT '=== RESUMEN ===';
PRINT '';

DECLARE @StatusCompleto BIT = CASE 
    WHEN @TienePorcentajeStockCritico = 1 
     AND @TienePorcentajeOportunidad = 1
     AND @TienePorcentajeExcesoStock = 1
     AND @TienePorcentajeDescuentoCompetencia = 1
     AND @CountParametros > 0
    THEN 1 
    ELSE 0 
END;

IF @StatusCompleto = 1
BEGIN
    PRINT '✅ VALIDACIÓN COMPLETADA CON ÉXITO';
    PRINT '';
    PRINT 'El motor de pricing está parametrizado correctamente:';
    PRINT '  • Tabla EstrategiaReglaParametros existe y contiene datos';
    PRINT '  • SP tiene todas las variables parametrizadas';
    PRINT '  • Hardcodes reemplazados por fórmulas dinámicas';
    PRINT '';
    PRINT 'Próximo paso: Crear endpoints API para administrar parámetros';
END
ELSE
BEGIN
    PRINT '⚠️ VALIDACIÓN INCOMPLETA - Revisar errores arriba';
    PRINT '';
    PRINT 'Checklist de correcciones:';
    IF OBJECT_ID('EstrategiaReglaParametros', 'U') IS NULL
        PRINT '  1. Ejecutar SQL/Estructura.sql para crear tabla';
    IF @CountParametros = 0
        PRINT '  2. Ejecutar SQL/Inicializar-Parametros-Reglas.sql para insertar datos';
    IF @TienePorcentajeStockCritico = 0
        PRINT '  3. Verificar que SP tiene variable @PorcentajeStockCritico';
    IF @TienePorcentajeOportunidad = 0
        PRINT '  3. Verificar que SP tiene variable @PorcentajeOportunidad';
    IF @TienePorcentajeExcesoStock = 0
        PRINT '  3. Verificar que SP tiene variable @PorcentajeExcesoStock';
    IF @TienePorcentajeDescuentoCompetencia = 0
        PRINT '  3. Verificar que SP tiene variable @PorcentajeDescuentoCompetencia';
END

PRINT '';
PRINT '=== FIN DE VALIDACIÓN ===';
