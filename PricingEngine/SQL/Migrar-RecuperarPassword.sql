-- Migración idempotente: recuperación de contraseña por email real. Agrega el email
-- de cada Usuario, la configuración del servidor SMTP (una sola app de email por
-- instalación, mismo patrón que ConfiguracionMercadoLibre) y los tokens de un solo uso
-- para el link de "olvidé mi contraseña".

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Usuarios') AND name = 'Email')
BEGIN
    ALTER TABLE Usuarios ADD Email VARCHAR(200) NULL;
    PRINT 'Columna Email agregada a Usuarios.';
END
ELSE
    PRINT 'Usuarios ya tenía Email.';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ConfiguracionEmail')
BEGIN
    CREATE TABLE ConfiguracionEmail (
        ConfiguracionEmailID INT IDENTITY(1,1) NOT NULL,
        SmtpHost VARCHAR(200) NULL,
        SmtpPort INT NULL,
        SmtpUsuario VARCHAR(200) NULL,
        SmtpPassword VARCHAR(200) NULL,
        UsarSsl BIT NOT NULL CONSTRAINT DF_ConfiguracionEmail_UsarSsl DEFAULT (1),
        EmailDesde VARCHAR(200) NULL,
        NombreDesde VARCHAR(150) NULL,
        FrontendBaseUrl VARCHAR(300) NULL,
        FechaActualizacion DATETIME2(3) NULL,
        CONSTRAINT PK_ConfiguracionEmail PRIMARY KEY CLUSTERED (ConfiguracionEmailID)
    );
    PRINT 'Tabla ConfiguracionEmail creada.';
END
ELSE
    PRINT 'Tabla ConfiguracionEmail ya existía.';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PasswordResetTokens')
BEGIN
    CREATE TABLE PasswordResetTokens (
        TokenID INT IDENTITY(1,1) NOT NULL,
        UsuarioID INT NOT NULL,
        Token VARCHAR(100) NOT NULL,
        FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_PasswordResetTokens_Fecha DEFAULT (SYSDATETIME()),
        FechaExpiracion DATETIME2(3) NOT NULL,
        Usado BIT NOT NULL CONSTRAINT DF_PasswordResetTokens_Usado DEFAULT (0),
        CONSTRAINT PK_PasswordResetTokens PRIMARY KEY CLUSTERED (TokenID),
        CONSTRAINT UQ_PasswordResetTokens_Token UNIQUE (Token),
        CONSTRAINT FK_PasswordResetTokens_Usuarios FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
    );
    PRINT 'Tabla PasswordResetTokens creada.';
END
ELSE
    PRINT 'Tabla PasswordResetTokens ya existía.';
