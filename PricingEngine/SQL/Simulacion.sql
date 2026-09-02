-- ============================================================================
-- SEED DATA SETUP
-- ============================================================================
USE PRICES_DB;
GO

-- 1. Empresa y Cuentas
INSERT INTO Empresas (RazonSocial, CUIT) VALUES ('ElectroMarket SRL', '30-71123456-8');
DECLARE @EmpresaID INT = SCOPE_IDENTITY();

INSERT INTO CuentasML (EmpresaID, UserIDML, NicknameML) VALUES (@EmpresaID, '12345678', 'ELECTRO_OFFICIAL');
DECLARE @CuentaID INT = SCOPE_IDENTITY();

-- 2. Parámetros Globales
INSERT INTO ConfiguracionParametros (EmpresaID, ClaveParametro, ValorParametro, Descripcion)
VALUES (@EmpresaID, 'MARGEN_MINIMO_PERMITIDO', '15.00', 'Margen neto mínimo para bloqueos de seguridad');

-- 3. Estrategias y Reglas
INSERT INTO ReglasNegocio (CodigoRegla, Nombre, TipoRegla) VALUES 
('REGLA_STOCK_CRITICO', 'Aumento por Stock Crítico', 'OPERATIONAL'),
('REGLA_COMPETENCIA_ABAJO', 'Ajuste por Competencia Mas Barata', 'MARKET'),
('REGLA_EXCESO_STOCK', 'Liquidación por Exceso Stock', 'OPERATIONAL');

INSERT INTO Estrategias (EmpresaID, NombreEstrategia) VALUES (@EmpresaID, 'ESTRATEGIA_BALANCEADA');
DECLARE @EstrategiaID INT = SCOPE_IDENTITY();

INSERT INTO EstrategiaReglas (EstrategiaID, ReglaID, Prioridad)
SELECT @EstrategiaID, ReglaID, 
    CASE CodigoRegla 
        WHEN 'REGLA_STOCK_CRITICO' THEN 10
        WHEN 'REGLA_COMPETENCIA_ABAJO' THEN 20
        WHEN 'REGLA_EXCESO_STOCK' THEN 30
    END
FROM ReglasNegocio;

-- 4. Productos
-- Caso A: Competencia más barata pero bloqueada por Margen Mínimo
INSERT INTO Productos (EmpresaID, SKU, Titulo) VALUES (@EmpresaID, 'SKU-AURICULAR-01', 'Auriculares Bluetooth Pro');
DECLARE @P1 INT = SCOPE_IDENTITY();
INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA) VALUES (@P1, 80000.00, 21.00);
INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
VALUES (@P1, @CuentaID, 'MLA1001', 'gold_pro', 13.00, 'active', 100000.00, 80000.00, 150000.00, DATEADD(DAY, -2, SYSDATETIME()));
INSERT INTO StockEstado (ProductoID, StockActual, StockMinimo, StockMaximo) VALUES (@P1, 20, 5, 50);
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES ((SELECT PublicacionID FROM PublicacionesML WHERE MeliItemID='MLA1001'), 'MLA9999', 85000.00, 1);

-- Caso B: Stock Crítico -> Aumenta Precio
INSERT INTO Productos (EmpresaID, SKU, Titulo) VALUES (@EmpresaID, 'SKU-SMARTWATCH-02', 'Smartwatch Deportivo V2');
DECLARE @P2 INT = SCOPE_IDENTITY();
INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA) VALUES (@P2, 30000.00, 21.00);
INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
VALUES (@P2, @CuentaID, 'MLA1002', 'gold_special', 11.00, 'active', 60000.00, 40000.00, 90000.00, DATEADD(DAY, -2, SYSDATETIME()));
INSERT INTO StockEstado (ProductoID, StockActual, StockMinimo, StockMaximo) VALUES (@P2, 2, 5, 50); -- Stock Actual (2) <= Minimo (5)

-- Caso C: Exceso de Stock -> Liquidación
INSERT INTO Productos (EmpresaID, SKU, Titulo) VALUES (@EmpresaID, 'SKU-CARGADOR-03', 'Cargador Carga Rápida 20W');
DECLARE @P3 INT = SCOPE_IDENTITY();
INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA) VALUES (@P3, 3000.00, 21.00);
INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
VALUES (@P3, @CuentaID, 'MLA1003', 'gold_special', 11.00, 'active', 12000.00, 5000.00, 20000.00, DATEADD(DAY, -3, SYSDATETIME()));
INSERT INTO StockEstado (ProductoID, StockActual, StockMinimo, StockMaximo) VALUES (@P3, 120, 10, 80); -- Stock Actual (120) >= Maximo (80)
GO

-- ============================================================================
-- SEED DATA EXTENDIDO: 100 PRODUCTOS Y COMPETENCIA MULTI-ESCENARIO
-- ============================================================================

DECLARE @EmpresaSeed INT = (SELECT TOP 1 EmpresaID FROM Empresas WHERE CUIT = '30-71123456-8');
DECLARE @CuentaSeed INT = (SELECT TOP 1 CuentaMLID FROM CuentasML WHERE EmpresaID = @EmpresaSeed);
DECLARE @Indice INT = 1;

WHILE @Indice <= 100
BEGIN
    DECLARE @Escenario VARCHAR(30);
    DECLARE @Sku VARCHAR(50);
    DECLARE @Titulo VARCHAR(255);
    DECLARE @CostoCompra DECIMAL(18,4);
    DECLARE @PrecioActual DECIMAL(18,4);
    DECLARE @PrecioMinimo DECIMAL(18,4);
    DECLARE @PrecioMaximo DECIMAL(18,4);
    DECLARE @StockActual INT;
    DECLARE @StockMinimo INT;
    DECLARE @StockMaximo INT;
    DECLARE @ComisionMLPorc DECIMAL(5,2);
    DECLARE @IVA DECIMAL(5,2);
    DECLARE @CostoEnvio DECIMAL(18,4);
    DECLARE @CostoLogistico DECIMAL(18,4);
    DECLARE @CostoFinanciero DECIMAL(5,2);
    DECLARE @CostoPublicidad DECIMAL(5,2);
    DECLARE @Competidor1 DECIMAL(18,4);
    DECLARE @Competidor2 DECIMAL(18,4);
    DECLARE @Competidor3 DECIMAL(18,4);
    DECLARE @ProductoID INT;
    DECLARE @MeliItemID VARCHAR(50);

    IF @Indice BETWEEN 1 AND 20
    BEGIN
        SET @Escenario = 'CRITICO';
        SET @CostoCompra = 18000.00 + (@Indice * 1200);
        SET @PrecioActual = 42000.00 + (@Indice * 1300);
        SET @PrecioMinimo = 30000.00;
        SET @PrecioMaximo = 90000.00;
        SET @StockActual = 2 + (@Indice % 4);
        SET @StockMinimo = 5;
        SET @StockMaximo = 40;
        SET @ComisionMLPorc = 12.00 + (@Indice % 4);
        SET @IVA = 21.00;
        SET @CostoEnvio = 900.00 + (@Indice * 40);
        SET @CostoLogistico = 500.00 + (@Indice * 30);
        SET @CostoFinanciero = 1.50 + (@Indice % 3);
        SET @CostoPublicidad = 2.50 + (@Indice % 5);
        SET @Competidor1 = @PrecioActual * 0.88;
        SET @Competidor2 = @PrecioActual * 0.93;
        SET @Competidor3 = @PrecioActual * 0.97;
    END
    ELSE IF @Indice BETWEEN 21 AND 40
    BEGIN
        SET @Escenario = 'COMPETENCIA_ABAJO';
        SET @CostoCompra = 12000.00 + (@Indice * 800);
        SET @PrecioActual = 35000.00 + (@Indice * 1000);
        SET @PrecioMinimo = 22000.00;
        SET @PrecioMaximo = 70000.00;
        SET @StockActual = 15 + (@Indice % 8);
        SET @StockMinimo = 8;
        SET @StockMaximo = 70;
        SET @ComisionMLPorc = 11.00 + (@Indice % 3);
        SET @IVA = 21.00;
        SET @CostoEnvio = 700.00 + (@Indice * 35);
        SET @CostoLogistico = 450.00 + (@Indice * 25);
        SET @CostoFinanciero = 1.20 + (@Indice % 4);
        SET @CostoPublicidad = 2.00 + (@Indice % 4);
        SET @Competidor1 = @PrecioActual * 0.82;
        SET @Competidor2 = @PrecioActual * 0.85;
        SET @Competidor3 = @PrecioActual * 0.90;
    END
    ELSE IF @Indice BETWEEN 41 AND 60
    BEGIN
        SET @Escenario = 'EXCESO_STOCK';
        SET @CostoCompra = 7000.00 + (@Indice * 350);
        SET @PrecioActual = 20000.00 + (@Indice * 600);
        SET @PrecioMinimo = 12000.00;
        SET @PrecioMaximo = 50000.00;
        SET @StockActual = 110 + (@Indice * 2);
        SET @StockMinimo = 10;
        SET @StockMaximo = 80;
        SET @ComisionMLPorc = 10.00 + (@Indice % 3);
        SET @IVA = 21.00;
        SET @CostoEnvio = 500.00 + (@Indice * 20);
        SET @CostoLogistico = 350.00 + (@Indice * 18);
        SET @CostoFinanciero = 1.00 + (@Indice % 3);
        SET @CostoPublicidad = 1.80 + (@Indice % 4);
        SET @Competidor1 = @PrecioActual * 0.95;
        SET @Competidor2 = @PrecioActual * 1.00;
        SET @Competidor3 = @PrecioActual * 1.05;
    END
    ELSE IF @Indice BETWEEN 61 AND 80
    BEGIN
        SET @Escenario = 'MARGEN_MINIMO';
        SET @CostoCompra = 24000.00 + (@Indice * 1100);
        SET @PrecioActual = 53000.00 + (@Indice * 1200);
        SET @PrecioMinimo = 35000.00;
        SET @PrecioMaximo = 110000.00;
        SET @StockActual = 18 + (@Indice % 9);
        SET @StockMinimo = 7;
        SET @StockMaximo = 60;
        SET @ComisionMLPorc = 12.50 + (@Indice % 4);
        SET @IVA = 21.00;
        SET @CostoEnvio = 1000.00 + (@Indice * 50);
        SET @CostoLogistico = 600.00 + (@Indice * 30);
        SET @CostoFinanciero = 2.00 + (@Indice % 3);
        SET @CostoPublicidad = 3.00 + (@Indice % 5);
        SET @Competidor1 = @PrecioActual * 0.79;
        SET @Competidor2 = @PrecioActual * 0.82;
        SET @Competidor3 = @PrecioActual * 0.86;
    END
    ELSE
    BEGIN
        SET @Escenario = 'NORMAL';
        SET @CostoCompra = 10000.00 + (@Indice * 500);
        SET @PrecioActual = 28000.00 + (@Indice * 900);
        SET @PrecioMinimo = 18000.00;
        SET @PrecioMaximo = 65000.00;
        SET @StockActual = 25 + (@Indice % 12);
        SET @StockMinimo = 8;
        SET @StockMaximo = 75;
        SET @ComisionMLPorc = 11.00 + (@Indice % 4);
        SET @IVA = 21.00;
        SET @CostoEnvio = 600.00 + (@Indice * 25);
        SET @CostoLogistico = 400.00 + (@Indice * 20);
        SET @CostoFinanciero = 1.00 + (@Indice % 4);
        SET @CostoPublicidad = 1.50 + (@Indice % 4);
        SET @Competidor1 = @PrecioActual * 1.02;
        SET @Competidor2 = @PrecioActual * 1.08;
        SET @Competidor3 = @PrecioActual * 1.12;
    END;

    SET @Sku = CONCAT('SKU-BT-', RIGHT('000' + CAST(@Indice AS VARCHAR(3)), 3));
    SET @Titulo = CONCAT(
        CASE @Escenario
            WHEN 'CRITICO' THEN 'Accesorio Stock Crítico '
            WHEN 'COMPETENCIA_ABAJO' THEN 'Producto Competencia Bajo '
            WHEN 'EXCESO_STOCK' THEN 'Liquidación Exceso Stock '
            WHEN 'MARGEN_MINIMO' THEN 'SKU Margen Mínimo '
            ELSE 'Producto Balanceado '
        END,
        CAST(@Indice AS VARCHAR(3))
    );
    SET @MeliItemID = CONCAT('MLA', 2000 + @Indice);

    INSERT INTO Productos (EmpresaID, SKU, Titulo)
    VALUES (@EmpresaSeed, @Sku, @Titulo);

    SET @ProductoID = SCOPE_IDENTITY();

    INSERT INTO CostosProducto (
        ProductoID,
        CostoCompra,
        PorcentajeIVA,
        ImpuestosInternos,
        CostoEnvioPromedio,
        CostoLogisticoFijo,
        CostoFinancieroPorc,
        CostoPublicidadPorc,
        OtrosCostosFijos
    )
    VALUES (
        @ProductoID,
        @CostoCompra,
        @IVA,
        0,
        @CostoEnvio,
        @CostoLogistico,
        @CostoFinanciero,
        @CostoPublicidad,
        0
    );

    INSERT INTO PublicacionesML (
        ProductoID,
        CuentaMLID,
        MeliItemID,
        TipoPublicacion,
        ComisionMLPorc,
        Estado,
        EsCatalogo,
        PrecioActual,
        PrecioMinimoPermitido,
        PrecioMaximoPermitido,
        PrecioObjetivo,
        FechaUltimoCambioPrecio
    )
    VALUES (
        @ProductoID,
        @CuentaSeed,
        @MeliItemID,
        CASE WHEN @Indice % 2 = 0 THEN 'gold_pro' ELSE 'gold_special' END,
        @ComisionMLPorc,
        'active',
        CASE WHEN @Indice % 5 = 0 THEN 1 ELSE 0 END,
        @PrecioActual,
        @PrecioMinimo,
        @PrecioMaximo,
        @PrecioActual,
        DATEADD(DAY, -(@Indice % 14), SYSDATETIME())
    );

    INSERT INTO StockEstado (
        ProductoID,
        StockActual,
        StockReservado,
        StockMinimo,
        StockMaximo,
        StockObjetivo,
        FechaActualizacion
    )
    VALUES (
        @ProductoID,
        @StockActual,
        0,
        @StockMinimo,
        @StockMaximo,
        CASE WHEN @StockMaximo > 0 THEN CAST(@StockMaximo * 0.5 AS INT) ELSE 10 END,
        SYSDATETIME()
    );

    INSERT INTO CompetenciaSnapshot (
        PublicacionID,
        CompetidorItemID,
        CompetidorVendedorID,
        PrecioCompetidor,
        StockCompetidor,
        TipoPublicacion,
        OfreceEnvioGratis,
        EsCompetidorDirecto,
        NivelRelevancia,
        FechaCaptura
    )
    SELECT
        pub.PublicacionID,
        CONCAT('CMP-', @MeliItemID, '-A'),
        CONCAT('VEND-', @Indice, '-A'),
        @Competidor1,
        CASE WHEN @StockActual <= 5 THEN 3 ELSE 18 END,
        'gold_pro',
        CASE WHEN @Indice % 2 = 0 THEN 1 ELSE 0 END,
        1,
        1,
        SYSDATETIME()
    FROM PublicacionesML pub
    WHERE pub.MeliItemID = @MeliItemID
    UNION ALL
    SELECT
        pub.PublicacionID,
        CONCAT('CMP-', @MeliItemID, '-B'),
        CONCAT('VEND-', @Indice, '-B'),
        @Competidor2,
        CASE WHEN @StockActual >= 100 THEN 50 ELSE 12 END,
        'gold_special',
        CASE WHEN @Indice % 3 = 0 THEN 1 ELSE 0 END,
        CASE WHEN @Escenario IN ('COMPETENCIA_ABAJO', 'MARGEN_MINIMO') THEN 1 ELSE 0 END,
        CASE WHEN @Escenario IN ('COMPETENCIA_ABAJO', 'MARGEN_MINIMO') THEN 1 ELSE 2 END,
        SYSDATETIME()
    FROM PublicacionesML pub
    WHERE pub.MeliItemID = @MeliItemID
    UNION ALL
    SELECT
        pub.PublicacionID,
        CONCAT('CMP-', @MeliItemID, '-C'),
        CONCAT('VEND-', @Indice, '-C'),
        @Competidor3,
        10,
        'gold_pro',
        0,
        CASE WHEN @Escenario = 'NORMAL' THEN 1 ELSE 0 END,
        CASE WHEN @Escenario = 'NORMAL' THEN 2 ELSE 3 END,
        SYSDATETIME()
    FROM PublicacionesML pub
    WHERE pub.MeliItemID = @MeliItemID;

    SET @Indice = @Indice + 1;
END;
GO