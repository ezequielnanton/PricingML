-- Migración idempotente: login general (usuario+contraseña) para toda la superficie
-- de la app que hoy es de acceso libre (AdminPanel, Cola ML, Integraciones, Reportes,
-- Pricing). Alcance global (no por Empresa, a diferencia de Repositor).

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Usuarios')
BEGIN
    CREATE TABLE Usuarios (
        UsuarioID INT IDENTITY(1,1) NOT NULL,
        NombreCompleto VARCHAR(150) NOT NULL,
        Usuario VARCHAR(50) NOT NULL,
        PasswordHash VARBINARY(64) NOT NULL,
        PasswordSalt VARBINARY(32) NOT NULL,
        Rol VARCHAR(20) NOT NULL CONSTRAINT DF_Usuarios_Rol DEFAULT ('ADMIN'),
        Activo BIT NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Usuarios PRIMARY KEY CLUSTERED (UsuarioID),
        CONSTRAINT UQ_Usuarios_Usuario UNIQUE (Usuario),
        CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN ('ADMIN','LECTURA'))
    );
    PRINT 'Tabla Usuarios creada.';
END
ELSE
    PRINT 'Tabla Usuarios ya existía.';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ColaEjecucionML') AND name = 'UsuarioAprobacionID')
BEGIN
    ALTER TABLE ColaEjecucionML ADD UsuarioAprobacionID INT NULL
        CONSTRAINT FK_ColaEjecucionML_Usuarios FOREIGN KEY REFERENCES Usuarios(UsuarioID);
    PRINT 'Columna UsuarioAprobacionID agregada a ColaEjecucionML.';
END
ELSE
    PRINT 'ColaEjecucionML ya tenía UsuarioAprobacionID.';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PublicacionCompetidoresManual') AND name = 'UsuarioVinculoID')
BEGIN
    ALTER TABLE PublicacionCompetidoresManual ADD UsuarioVinculoID INT NULL
        CONSTRAINT FK_PubCompManual_Usuarios FOREIGN KEY REFERENCES Usuarios(UsuarioID);
    PRINT 'Columna UsuarioVinculoID agregada a PublicacionCompetidoresManual.';
END
ELSE
    PRINT 'PublicacionCompetidoresManual ya tenía UsuarioVinculoID.';
