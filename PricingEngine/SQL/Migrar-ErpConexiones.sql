-- Migración idempotente: integración con ERPs externos, en ambos sentidos.
-- #integracionErp: el motor actúa como cliente activo (igual que los conectores de
-- marketplace): puede recibir un POST del ERP (si el ERP sabe llamar afuera) y puede
-- salir a buscar datos con GET contra la API del ERP (si el ERP expone una para leer).
-- Ambos caminos comparten el mismo contrato canónico de items y el mismo upsert.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ErpConexiones')
BEGIN
    CREATE TABLE ErpConexiones (
        ErpConexionID INT IDENTITY(1,1) NOT NULL,
        EmpresaID INT NOT NULL,
        ApiKeyEntrante VARCHAR(100) NOT NULL, -- clave que le damos al ERP para que nos haga POST
        UrlSalida VARCHAR(500) NULL,          -- endpoint GET del ERP, si lo tiene
        ApiKeySaliente VARCHAR(200) NULL,     -- token que nosotros mandamos al llamar UrlSalida
        Activo BIT NOT NULL CONSTRAINT DF_ErpConexiones_Activo DEFAULT (1),
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_ErpConexiones_FechaCreacion DEFAULT (SYSDATETIME()),
        UltimaSincronizacion DATETIME2(3) NULL,
        CONSTRAINT PK_ErpConexiones PRIMARY KEY CLUSTERED (ErpConexionID),
        CONSTRAINT FK_ErpConexiones_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
        CONSTRAINT UQ_ErpConexiones_Empresa UNIQUE (EmpresaID),
        CONSTRAINT UQ_ErpConexiones_ApiKeyEntrante UNIQUE (ApiKeyEntrante)
    );
    PRINT 'Tabla ErpConexiones creada.';
END
ELSE
    PRINT 'Tabla ErpConexiones ya existía, sin cambios.';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ErpSincronizaciones')
BEGIN
    CREATE TABLE ErpSincronizaciones (
        ErpSincronizacionID BIGINT IDENTITY(1,1) NOT NULL,
        EmpresaID INT NOT NULL,
        Direccion VARCHAR(10) NOT NULL, -- ENTRANTE (ERP nos hizo POST) o SALIENTE (nosotros hicimos GET)
        CantidadProcesados INT NOT NULL,
        CantidadErrores INT NOT NULL,
        DetalleErrores VARCHAR(MAX) NULL,
        FechaSincronizacion DATETIME2(3) NOT NULL CONSTRAINT DF_ErpSync_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_ErpSincronizaciones PRIMARY KEY CLUSTERED (ErpSincronizacionID),
        CONSTRAINT FK_ErpSincronizaciones_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID)
    );
    PRINT 'Tabla ErpSincronizaciones creada.';
END
ELSE
    PRINT 'Tabla ErpSincronizaciones ya existía, sin cambios.';
