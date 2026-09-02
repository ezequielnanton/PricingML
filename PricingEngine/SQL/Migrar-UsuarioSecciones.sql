-- Migración idempotente: qué secciones de la app puede VER cada Usuario (Pricing,
-- Formularios, Reportes, etc.). Control de visibilidad en la UI — el límite real de
-- escritura sigue siendo el Rol (ADMIN/LECTURA) de Usuarios, aplicado parejo a toda
-- la API en el middleware de Program.cs.

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UsuarioSecciones')
BEGIN
    CREATE TABLE UsuarioSecciones (
        UsuarioID INT NOT NULL,
        Seccion VARCHAR(50) NOT NULL,
        CONSTRAINT PK_UsuarioSecciones PRIMARY KEY CLUSTERED (UsuarioID, Seccion),
        CONSTRAINT FK_UsuarioSecciones_Usuarios FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID) ON DELETE CASCADE
    );
    PRINT 'Tabla UsuarioSecciones creada.';
END
ELSE
    PRINT 'Tabla UsuarioSecciones ya existía.';
