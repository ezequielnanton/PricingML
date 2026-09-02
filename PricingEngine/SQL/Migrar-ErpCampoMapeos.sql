-- Migración idempotente: mapeo configurable de campos ERP -> contrato canónico.
-- #integracionErp: permite adaptar a CUALQUIER ERP sin escribir código nuevo por
-- cliente: el admin apunta al GET/POST de su ERP, el sistema descubre los campos
-- que devuelve, y el admin dice con qué campo del ERP se llena cada campo canónico
-- (SKU, CostoCompra, StockActual, etc.). Un mapeo por empresa (cada instalación
-- conecta a un solo ERP).

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ErpCampoMapeos')
BEGIN
    CREATE TABLE ErpCampoMapeos (
        ErpCampoMapeoID INT IDENTITY(1,1) NOT NULL,
        EmpresaID INT NOT NULL,
        CampoCanonico VARCHAR(50) NOT NULL,
        CampoOrigen VARCHAR(200) NOT NULL,
        CONSTRAINT PK_ErpCampoMapeos PRIMARY KEY CLUSTERED (ErpCampoMapeoID),
        CONSTRAINT FK_ErpCampoMapeos_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
        CONSTRAINT UQ_ErpCampoMapeos_Empresa_Campo UNIQUE (EmpresaID, CampoCanonico)
    );
    PRINT 'Tabla ErpCampoMapeos creada.';
END
ELSE
    PRINT 'Tabla ErpCampoMapeos ya existía, sin cambios.';
