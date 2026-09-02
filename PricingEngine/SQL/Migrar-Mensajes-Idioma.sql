-- ============================================================================
-- MIGRACIÓN: Idioma explícito para mensajes parametrizados
-- DESCRIPCIÓN: Actualiza una base existente sin recrear tablas ni perder datos.
-- ============================================================================

USE PRICES_DB;
GO

IF OBJECT_ID('dbo.EstrategiaReglaParametros', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EstrategiaReglaParametros (
        ParametroID INT IDENTITY(1,1) NOT NULL,
        EstrategiaReglaID INT NOT NULL,
        Clave VARCHAR(100) NOT NULL,
        Valor DECIMAL(18,4) NOT NULL,
        Descripcion VARCHAR(255) NULL,
        FechaVigencia DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametros_FechaVigencia DEFAULT (SYSDATETIME()),
        FechaFin DATETIME2(3) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_EstrategiaReglaParametros_Activo DEFAULT (1),
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametros_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_EstrategiaReglaParametros PRIMARY KEY CLUSTERED (ParametroID),
        CONSTRAINT FK_EstrategiaReglaParametros_EstrategiaRegla FOREIGN KEY (EstrategiaReglaID) REFERENCES dbo.EstrategiaReglas(EstrategiaReglaID),
        CONSTRAINT UQ_EstrategiaRegla_Clave_Vigente UNIQUE (EstrategiaReglaID, Clave, FechaFin)
    );
END
GO

IF OBJECT_ID('dbo.EstrategiaReglaParametrosMensajes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EstrategiaReglaParametrosMensajes (
        MensajeID INT IDENTITY(1,1) NOT NULL,
        EstrategiaReglaID INT NOT NULL,
        Clave VARCHAR(100) NOT NULL,
        Idioma VARCHAR(5) NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_Idioma DEFAULT ('ES'),
        Valor NVARCHAR(MAX) NOT NULL,
        Descripcion VARCHAR(255) NULL,
        FechaVigencia DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_FechaVigencia DEFAULT (SYSDATETIME()),
        FechaFin DATETIME2(3) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_Activo DEFAULT (1),
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_EstrategiaReglaParametrosMensajes PRIMARY KEY CLUSTERED (MensajeID),
        CONSTRAINT FK_EstrategiaReglaParametrosMensajes_EstrategiaRegla FOREIGN KEY (EstrategiaReglaID) REFERENCES dbo.EstrategiaReglas(EstrategiaReglaID),
        CONSTRAINT UQ_EstrategiaRegla_Clave_Mensaje_Vigente UNIQUE (EstrategiaReglaID, Clave, Idioma, FechaFin)
    );
END
GO

IF COL_LENGTH('dbo.EstrategiaReglaParametrosMensajes', 'Idioma') IS NULL
BEGIN
    ALTER TABLE dbo.EstrategiaReglaParametrosMensajes
        ADD Idioma VARCHAR(5) NOT NULL
            CONSTRAINT DF_EstrategiaReglaParametrosMensajes_Idioma DEFAULT ('ES');
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = 'UQ_EstrategiaRegla_Clave_Mensaje_Vigente'
      AND parent_object_id = OBJECT_ID('dbo.EstrategiaReglaParametrosMensajes')
)
BEGIN
    ALTER TABLE dbo.EstrategiaReglaParametrosMensajes
        DROP CONSTRAINT UQ_EstrategiaRegla_Clave_Mensaje_Vigente;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE name = 'UQ_EstrategiaRegla_Clave_Mensaje_Vigente'
      AND parent_object_id = OBJECT_ID('dbo.EstrategiaReglaParametrosMensajes')
)
BEGIN
    ALTER TABLE dbo.EstrategiaReglaParametrosMensajes
        ADD CONSTRAINT UQ_EstrategiaRegla_Clave_Mensaje_Vigente
        UNIQUE (EstrategiaReglaID, Clave, Idioma, FechaFin);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_EstrategiaReglaParametrosMensajes_Vigentes'
      AND object_id = OBJECT_ID('dbo.EstrategiaReglaParametrosMensajes')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_EstrategiaReglaParametrosMensajes_Vigentes
    ON dbo.EstrategiaReglaParametrosMensajes
       (EstrategiaReglaID, Clave, Idioma, Activo, FechaVigencia)
    INCLUDE (FechaFin, Valor);
END
GO
