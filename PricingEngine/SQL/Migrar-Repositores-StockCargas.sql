-- Migración idempotente: agrega Repositores y StockCargas para la carga operativa
-- de stock por un repositor (clientes sin ERP), con login simple Usuario+PIN.
-- Ver #cargaOperativaRepositor en Estructura.sql.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Repositores')
BEGIN
    CREATE TABLE Repositores (
        RepositorID INT IDENTITY(1,1) NOT NULL,
        EmpresaID INT NOT NULL,
        NombreCompleto VARCHAR(150) NOT NULL,
        Usuario VARCHAR(50) NOT NULL,
        PinHash VARBINARY(64) NOT NULL,
        PinSalt VARBINARY(32) NOT NULL,
        Activo BIT NOT NULL CONSTRAINT DF_Repositores_Activo DEFAULT (1),
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Repositores_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Repositores PRIMARY KEY CLUSTERED (RepositorID),
        CONSTRAINT FK_Repositores_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
        CONSTRAINT UQ_Repositores_Usuario UNIQUE (Usuario)
    );
    PRINT 'Tabla Repositores creada.';
END
ELSE
    PRINT 'Tabla Repositores ya existía, sin cambios.';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'StockCargas')
BEGIN
    CREATE TABLE StockCargas (
        StockCargaID BIGINT IDENTITY(1,1) NOT NULL,
        ProductoID INT NOT NULL,
        RepositorID INT NOT NULL,
        StockAnterior INT NOT NULL,
        StockNuevo INT NOT NULL,
        FechaCarga DATETIME2(3) NOT NULL CONSTRAINT DF_StockCargas_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_StockCargas PRIMARY KEY CLUSTERED (StockCargaID),
        CONSTRAINT FK_StockCargas_Productos FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
        CONSTRAINT FK_StockCargas_Repositores FOREIGN KEY (RepositorID) REFERENCES Repositores(RepositorID)
    );
    PRINT 'Tabla StockCargas creada.';
END
ELSE
    PRINT 'Tabla StockCargas ya existía, sin cambios.';
