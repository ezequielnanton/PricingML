-- Migración idempotente: agrega la preferencia de tema (claro/oscuro) a Usuarios --
-- se guarda en la cuenta de cada uno (no en localStorage del navegador) para que lo
-- siga a donde inicie sesión, en cualquier dispositivo.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Usuarios') AND name = 'ModoOscuro')
BEGIN
    ALTER TABLE Usuarios ADD ModoOscuro BIT NOT NULL CONSTRAINT DF_Usuarios_ModoOscuro DEFAULT (0);
    PRINT 'Columna ModoOscuro agregada a Usuarios.';
END
ELSE
    PRINT 'Columna ModoOscuro ya existía, sin cambios.';
