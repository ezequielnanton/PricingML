-- ============================================================================
-- SCRIPT: Validación de mensajes parametrizados
-- ============================================================================

USE PRICES_DB;
GO

PRINT '=== VALIDACIÓN DE MENSAJES PARAMETRIZADOS ===';

DECLARE @TableExists BIT = CASE WHEN OBJECT_ID('dbo.EstrategiaReglaParametrosMensajes', 'U') IS NULL THEN 0 ELSE 1 END;
IF @TableExists = 0
BEGIN
    PRINT 'ERROR: No existe EstrategiaReglaParametrosMensajes.';
    RETURN;
END
PRINT 'OK: Tabla EstrategiaReglaParametrosMensajes existe.';

DECLARE @RequiredColumns TABLE (ColumnName SYSNAME);
INSERT INTO @RequiredColumns VALUES ('MensajeID'), ('EstrategiaReglaID'), ('Clave'), ('Idioma'), ('Valor'), ('FechaVigencia'), ('FechaFin'), ('Activo'), ('FechaCreacion');

DECLARE @MissingColumns INT;
SELECT @MissingColumns = COUNT(*)
FROM @RequiredColumns c
WHERE NOT EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS ic
    WHERE ic.TABLE_SCHEMA = 'dbo'
      AND ic.TABLE_NAME = 'EstrategiaReglaParametrosMensajes'
      AND ic.COLUMN_NAME = c.ColumnName
);

IF @MissingColumns = 0
    PRINT 'OK: Todas las columnas requeridas existen.';
ELSE
BEGIN
    PRINT 'ERROR: Faltan ' + CAST(@MissingColumns AS VARCHAR(10)) + ' columnas.';
    SELECT c.ColumnName
    FROM @RequiredColumns c
    WHERE NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS ic
        WHERE ic.TABLE_SCHEMA = 'dbo'
          AND ic.TABLE_NAME = 'EstrategiaReglaParametrosMensajes'
          AND ic.COLUMN_NAME = c.ColumnName
    );
END

DECLARE @Total INT;
DECLARE @Vigentes INT;
DECLARE @InvalidLanguages INT;
DECLARE @OverlapGroups INT;

SELECT @Total = COUNT(*) FROM dbo.EstrategiaReglaParametrosMensajes;
SELECT @Vigentes = COUNT(*)
FROM dbo.EstrategiaReglaParametrosMensajes
WHERE Activo = 1
  AND FechaVigencia <= SYSDATETIME()
  AND (FechaFin IS NULL OR FechaFin > SYSDATETIME());
SELECT @InvalidLanguages = COUNT(*)
FROM dbo.EstrategiaReglaParametrosMensajes
WHERE Idioma NOT IN ('ES', 'EN', 'PT');
SELECT @OverlapGroups = COUNT(*)
FROM (
    SELECT a.MensajeID
    FROM dbo.EstrategiaReglaParametrosMensajes a
    INNER JOIN dbo.EstrategiaReglaParametrosMensajes b
        ON b.EstrategiaReglaID = a.EstrategiaReglaID
       AND b.Clave = a.Clave
       AND b.Idioma = a.Idioma
       AND b.MensajeID <> a.MensajeID
       AND a.Activo = 1
       AND b.Activo = 1
       AND a.FechaVigencia < ISNULL(b.FechaFin, CONVERT(DATETIME2(3), '9999-12-31'))
       AND b.FechaVigencia < ISNULL(a.FechaFin, CONVERT(DATETIME2(3), '9999-12-31'))
    GROUP BY a.MensajeID
) overlaps;

PRINT 'Mensajes totales: ' + CAST(@Total AS VARCHAR(10));
PRINT 'Mensajes vigentes: ' + CAST(@Vigentes AS VARCHAR(10));
PRINT 'Idiomas inválidos: ' + CAST(@InvalidLanguages AS VARCHAR(10));
PRINT 'Solapamientos detectados: ' + CAST(@OverlapGroups AS VARCHAR(10));

IF @MissingColumns = 0 AND @InvalidLanguages = 0 AND @OverlapGroups = 0
    PRINT 'OK: Validación de mensajes completada.';
ELSE
    PRINT 'ERROR: Revisar columnas, idiomas o períodos superpuestos.';

SELECT e.NombreEstrategia, r.CodigoRegla, m.Clave, m.Idioma, m.Activo, m.FechaVigencia, m.FechaFin
FROM dbo.EstrategiaReglaParametrosMensajes m
INNER JOIN dbo.EstrategiaReglas er ON er.EstrategiaReglaID = m.EstrategiaReglaID
INNER JOIN dbo.Estrategias e ON e.EstrategiaID = er.EstrategiaID
INNER JOIN dbo.ReglasNegocio r ON r.ReglaID = er.ReglaID
ORDER BY e.NombreEstrategia, r.CodigoRegla, m.Clave, m.Idioma, m.FechaVigencia DESC;
GO
