-- ============================================================================
-- SEED DE DATOS PARA PRUEBAS DEL MOTOR DE PRICING (spCalcularDecision)
-- ============================================================================
-- Crea una empresa, estrategia, reglas y 8 productos dedicados a QA, cada uno
-- diseñado para disparar (o bloquear) una regla específica del motor de forma
-- aislada. Es IDEMPOTENTE: correrlo varias veces no duplica datos, solo
-- actualiza los valores de precio/stock/competencia a su estado esperado
-- (útil para "resetear" el banco de pruebas antes de cada corrida).
--
-- Usar junto con Run-PruebasMotor.ps1, que ejecuta este script y luego corre
-- los 10 casos de prueba documentados en docs/QA-Motor-Pricing.md.
-- ============================================================================

USE PRICES_DB;
GO
SET NOCOUNT ON;

-- ----------------------------------------------------------------------------
-- 1. Empresa, cuenta ML y estrategia de QA
-- ----------------------------------------------------------------------------
DECLARE @EmpresaID INT;
SELECT @EmpresaID = EmpresaID FROM Empresas WHERE CUIT = '30-00000000-1';
IF @EmpresaID IS NULL
BEGIN
    INSERT INTO Empresas (RazonSocial, CUIT, Activo) VALUES ('Empresa QA Motor', '30-00000000-1', 1);
    SET @EmpresaID = SCOPE_IDENTITY();
END

DECLARE @CuentaMLID INT;
SELECT @CuentaMLID = CuentaMLID FROM CuentasML WHERE EmpresaID = @EmpresaID AND NicknameML = 'QA_MOTOR_ML';
IF @CuentaMLID IS NULL
BEGIN
    INSERT INTO CuentasML (EmpresaID, UserIDML, NicknameML, Activo) VALUES (@EmpresaID, 'QA000000', 'QA_MOTOR_ML', 1);
    SET @CuentaMLID = SCOPE_IDENTITY();
END

DECLARE @EstrategiaID INT;
SELECT @EstrategiaID = EstrategiaID FROM Estrategias WHERE EmpresaID = @EmpresaID AND NombreEstrategia = 'Estrategia QA Motor';
IF @EstrategiaID IS NULL
BEGIN
    INSERT INTO Estrategias (EmpresaID, NombreEstrategia, Descripcion, Activa)
    VALUES (@EmpresaID, 'Estrategia QA Motor', 'Estrategia dedicada al banco de pruebas del motor de pricing.', 1);
    SET @EstrategiaID = SCOPE_IDENTITY();
END

-- ----------------------------------------------------------------------------
-- 1b. Limpieza de lo que dejó la corrida anterior en ColaEjecucionML /
--     DecisionesHistorial para las publicaciones de QA. A diferencia de
--     CompetenciaSnapshot (que cada bloque de fixture ya resetea), estas dos
--     tablas nunca se limpiaban entre corridas y se iban acumulando sin
--     límite corrida tras corrida — esto las deja en cero antes de sembrar
--     de nuevo, así cada corrida arranca desde un estado limpio.
-- ----------------------------------------------------------------------------
DELETE ada
FROM DecisionesDetalleAuditoria ada
JOIN DecisionesHistorial dh ON dh.DecisionID = ada.DecisionID
JOIN PublicacionesML pub ON pub.PublicacionID = dh.PublicacionID
JOIN Productos p ON p.ProductoID = pub.ProductoID
WHERE p.EmpresaID = @EmpresaID;

DELETE dh
FROM DecisionesHistorial dh
JOIN PublicacionesML pub ON pub.PublicacionID = dh.PublicacionID
JOIN Productos p ON p.ProductoID = pub.ProductoID
WHERE p.EmpresaID = @EmpresaID;

DELETE c
FROM ColaEjecucionML c
JOIN PublicacionesML pub ON pub.PublicacionID = c.PublicacionID
JOIN Productos p ON p.ProductoID = pub.ProductoID
WHERE p.EmpresaID = @EmpresaID;

-- ----------------------------------------------------------------------------
-- 2. Reglas de negocio (catálogo global) + vínculo con la estrategia de QA
-- ----------------------------------------------------------------------------
DECLARE @Reglas TABLE (CodigoRegla VARCHAR(50), Nombre VARCHAR(100), TipoRegla VARCHAR(30), Prioridad INT);
INSERT INTO @Reglas VALUES
    ('REGLA_STOCK_CRITICO', 'Stock crítico', 'HARD_RESTRICTION', 1),
    ('REGLA_COMPETENCIA_ABAJO', 'Competencia más barata', 'MARKET', 2),
    ('REGLA_OPORTUNIDAD', 'Oportunidad de mercado', 'OPPORTUNITY', 3),
    ('REGLA_EXCESO_STOCK', 'Exceso de stock', 'OPERATIONAL', 4);

DECLARE @CodigoRegla VARCHAR(50), @NombreRegla VARCHAR(100), @TipoRegla VARCHAR(30), @Prioridad INT, @ReglaID INT;
DECLARE regla_cursor CURSOR LOCAL FOR SELECT CodigoRegla, Nombre, TipoRegla, Prioridad FROM @Reglas;
OPEN regla_cursor;
FETCH NEXT FROM regla_cursor INTO @CodigoRegla, @NombreRegla, @TipoRegla, @Prioridad;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @ReglaID = ReglaID FROM ReglasNegocio WHERE CodigoRegla = @CodigoRegla;
    IF @ReglaID IS NULL
    BEGIN
        INSERT INTO ReglasNegocio (CodigoRegla, Nombre, TipoRegla, Descripcion, Activa)
        VALUES (@CodigoRegla, @NombreRegla, @TipoRegla, 'Regla estándar del motor (ver spCalcularDecision.sql).', 1);
        SET @ReglaID = SCOPE_IDENTITY();
    END

    IF NOT EXISTS (SELECT 1 FROM EstrategiaReglas WHERE EstrategiaID = @EstrategiaID AND ReglaID = @ReglaID)
        INSERT INTO EstrategiaReglas (EstrategiaID, ReglaID, Prioridad, Activa) VALUES (@EstrategiaID, @ReglaID, @Prioridad, 1);
    ELSE
        UPDATE EstrategiaReglas SET Prioridad = @Prioridad, Activa = 1 WHERE EstrategiaID = @EstrategiaID AND ReglaID = @ReglaID;

    SET @ReglaID = NULL;
    FETCH NEXT FROM regla_cursor INTO @CodigoRegla, @NombreRegla, @TipoRegla, @Prioridad;
END
CLOSE regla_cursor;
DEALLOCATE regla_cursor;

-- ----------------------------------------------------------------------------
-- 3. Helper: crea/actualiza un producto completo (producto + costo + stock +
--    publicación activa) y deja su ProductoID/PublicacionID en variables.
--    Se repite un bloque por caso de prueba (TC01..TC08) con sus propios
--    valores; ver docs/QA-Motor-Pricing.md para el detalle de cada uno.
-- ----------------------------------------------------------------------------

-- === TC01 · REGLA_STOCK_CRITICO ============================================
DECLARE @ProductoID INT, @PublicacionID INT;
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC01';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC01', 'QA Stock Crítico', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 3, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=3, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC01';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC01', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID; -- TC01: sin competencia relevante

-- === TC02 · Sin gatillo (stock bajo, sin ventaja de precio) ================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC02';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC02', 'QA Sin Gatillo (Stock Bajo)', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 12, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=12, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC02';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC02', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID;
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES (@PublicacionID, 'MLA-COMP-TC02', 10500, 2); -- más caro: no gatilla competencia

-- === TC03 · REGLA_COMPETENCIA_ABAJO =========================================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC03';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC03', 'QA Competencia Más Barata', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 50, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=50, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC03';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC03', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID;
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES (@PublicacionID, 'MLA-COMP-TC03', 9000, 1); -- competidor relevante más barato

-- === TC04 · REGLA_OPORTUNIDAD ===============================================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC04';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC04', 'QA Oportunidad Sin Competencia', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 50, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=50, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC04';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC04', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID; -- TC04: cero competidores es la condición que dispara la regla

-- === TC05 · REGLA_EXCESO_STOCK ==============================================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC05';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC05', 'QA Exceso De Stock', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 100, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=100, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC05';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC05', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID;
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES (@PublicacionID, 'MLA-COMP-TC05', 10800, 2); -- más caro: evita que gane Competencia u Oportunidad

-- === TC06 · Bloqueo por margen mínimo =======================================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC06';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC06', 'QA Bloqueo Margen Mínimo', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 4664, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=4664, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 50, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=50, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC06';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC06', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID;
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES (@PublicacionID, 'MLA-COMP-TC06', 8700, 1);

-- === TC07 · Clamp a PrecioMinimoPermitido ===================================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC07';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC07', 'QA Clamp Precio Mínimo', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 50, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=50, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC07';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC07', 'gold_special', 10, 'active', 10000, 8500, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=8500, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID;
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES (@PublicacionID, 'MLA-COMP-TC07', 8000, 1);

-- === TC08 · Anti-oscilación por variación mínima ============================
SET @ProductoID = NULL;
SELECT @ProductoID = ProductoID FROM Productos WHERE EmpresaID = @EmpresaID AND SKU = 'QA-TC08';
IF @ProductoID IS NULL
BEGIN
    INSERT INTO Productos (EmpresaID, SKU, Titulo, Activo) VALUES (@EmpresaID, 'QA-TC08', 'QA Anti-Oscilación', 1);
    SET @ProductoID = SCOPE_IDENTITY();
END
IF NOT EXISTS (SELECT 1 FROM CostosProducto WHERE ProductoID = @ProductoID)
    INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc)
    VALUES (@ProductoID, 2864, 21, 300, 100, 0, 0);
ELSE
    UPDATE CostosProducto SET CostoCompra=2864, PorcentajeIVA=21, CostoEnvioPromedio=300, CostoLogisticoFijo=100, CostoFinancieroPorc=0, CostoPublicidadPorc=0 WHERE ProductoID = @ProductoID;
IF NOT EXISTS (SELECT 1 FROM StockEstado WHERE ProductoID = @ProductoID)
    INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo) VALUES (@ProductoID, 50, 0, 10, 100, 30);
ELSE
    UPDATE StockEstado SET StockActual=50, StockReservado=0, StockMinimo=10, StockMaximo=100 WHERE ProductoID = @ProductoID;
SET @PublicacionID = NULL;
SELECT @PublicacionID = PublicacionID FROM PublicacionesML WHERE MeliItemID = 'MLA-QA-TC08';
IF @PublicacionID IS NULL
BEGIN
    INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, FechaUltimoCambioPrecio)
    VALUES (@ProductoID, @CuentaMLID, 'MLA-QA-TC08', 'gold_special', 10, 'active', 10000, 6000, 15000, NULL);
    SET @PublicacionID = SCOPE_IDENTITY();
END
ELSE
    UPDATE PublicacionesML SET PrecioActual=10000, PrecioMinimoPermitido=6000, PrecioMaximoPermitido=15000, ComisionMLPorc=10, Estado='active', FechaUltimoCambioPrecio=NULL WHERE PublicacionID = @PublicacionID;
DELETE FROM CompetenciaSnapshot WHERE PublicacionID = @PublicacionID;
INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, PrecioCompetidor, NivelRelevancia) VALUES (@PublicacionID, 'MLA-COMP-TC08', 9970, 1);

PRINT 'Seed de pruebas del motor completo. EmpresaID=' + CAST(@EmpresaID AS VARCHAR(10)) + ', EstrategiaID=' + CAST(@EstrategiaID AS VARCHAR(10));
GO
