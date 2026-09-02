-- Migración idempotente: persiste las sesiones de Usuario en la base en vez de solo en
-- memoria, para que un reinicio de la API no desloguee a todo el mundo. Guarda una
-- copia (NombreCompleto/Rol/Secciones) tomada en el momento del login — el mismo
-- diseño "snapshot fijo hasta el próximo login" que ya tenían las sesiones en memoria
-- (ver ADR 0012/0013), solo que ahora sobrevive a un restart.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UsuarioSesiones')
BEGIN
    CREATE TABLE UsuarioSesiones (
        SesionID BIGINT IDENTITY(1,1) NOT NULL,
        Token VARCHAR(100) NOT NULL,
        UsuarioID INT NOT NULL,
        NombreCompleto VARCHAR(150) NOT NULL,
        Rol VARCHAR(20) NOT NULL,
        SeccionesCsv VARCHAR(500) NULL,
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_UsuarioSesiones_Fecha DEFAULT (SYSDATETIME()),
        FechaExpiracion DATETIME2(3) NOT NULL,
        CONSTRAINT PK_UsuarioSesiones PRIMARY KEY CLUSTERED (SesionID),
        CONSTRAINT UQ_UsuarioSesiones_Token UNIQUE (Token),
        CONSTRAINT FK_UsuarioSesiones_Usuarios FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
    );
    PRINT 'Tabla UsuarioSesiones creada.';
END
ELSE
    PRINT 'Tabla UsuarioSesiones ya existía.';
