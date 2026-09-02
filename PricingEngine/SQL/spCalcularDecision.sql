CREATE OR ALTER PROCEDURE dbo.spCalcularDecision
    @EmpresaID INT,
    @ProductoID INT = NULL,
    @EstrategiaID INT = NULL,
    @ModoSimulacion BIT = 1,
    @Persistir BIT = 0,
    @ContextSource VARCHAR(20) = 'BASE',
    @SKU VARCHAR(100) = NULL,
    @Titulo NVARCHAR(200) = NULL,
    @PrecioActual DECIMAL(18,4) = NULL,
    @StockActual INT = NULL,
    @StockMinimo INT = NULL,
    @StockMaximo INT = NULL,
    @CostoCompra DECIMAL(18,4) = NULL,
    @IVA DECIMAL(5,2) = NULL,
    @ComisionMLPorc DECIMAL(5,2) = NULL,
    @CostoEnvioPromedio DECIMAL(18,4) = NULL,
    @CostoLogisticoFijo DECIMAL(18,4) = NULL,
    @CostoFinancieroPorc DECIMAL(5,2) = NULL,
    @CostoPublicidadPorc DECIMAL(5,2) = NULL,
    @EstadoPublicacion VARCHAR(50) = NULL,
    @CooldownHoras INT = 12,
    @VariacionMinimaPorc DECIMAL(5,2) = 1.50,
    @Idioma VARCHAR(5) = 'ES'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Idioma = UPPER(LTRIM(RTRIM(ISNULL(@Idioma, 'ES'))));
    IF @Idioma NOT IN ('ES', 'EN', 'PT')
        SET @Idioma = 'ES';

    -- 1. Determinar Estrategia
    IF @EstrategiaID IS NULL
    BEGIN
        SELECT TOP 1 @EstrategiaID = EstrategiaID
        FROM Estrategias
        WHERE EmpresaID = @EmpresaID AND Activa = 1;
    END

    IF @EstrategiaID IS NULL
    BEGIN
        RAISERROR('No existe una estrategia activa configurada para la empresa.', 16, 1);
        RETURN;
    END

    -- 2. Cargar Parámetros Globales/Locales
    DECLARE @MargenMinimoGlobal DECIMAL(5,2) = 15.00;
    
    SELECT TOP 1 @MargenMinimoGlobal = CAST(ValorParametro AS DECIMAL(5,2))
    FROM ConfiguracionParametros
    WHERE EmpresaID = @EmpresaID AND ClaveParametro = 'MARGEN_MINIMO_PERMITIDO';

    -- #aprobacionColaMl: si está en 0 (default), toda subida a ML pasa por aprobación
    -- humana; si está en 1, las publicaciones de CATÁLOGO suben solas (las que no son
    -- de catálogo siempre piden aprobación, sin importar este valor).
    DECLARE @SubidaAutomaticaCatalogoML BIT = 0;
    SELECT TOP 1 @SubidaAutomaticaCatalogoML = SubidaAutomaticaCatalogoML
    FROM ParametrosGenerales
    WHERE EmpresaID = @EmpresaID;

    -- 2.1. Cargar Parámetros de Reglas por Estrategia (Valores por defecto)
    DECLARE @PorcentajeStockCritico DECIMAL(5,2) = 5.00;
    DECLARE @PorcentajeOportunidad DECIMAL(5,2) = 3.00;
    DECLARE @PorcentajeExcesoStock DECIMAL(5,2) = 7.00;
    DECLARE @PorcentajeDescuentoCompetencia DECIMAL(5,2) = 1.00;
    -- #ventanaVelocidadConfigurable: por defecto usa Ventas30D (comportamiento previo),
    -- pero se puede pedir 7/15/60/90 vía el parámetro VENTANA_VELOCIDAD_DIAS de
    -- REGLA_OPORTUNIDAD. Cualquier otro valor cae en el default de 30.
    DECLARE @VentanaVelocidadDias INT = 30;

    -- Cargar Stock Crítico
    SELECT TOP 1 @PorcentajeStockCritico = erp.Valor
    FROM EstrategiaReglaParametros erp
    INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_STOCK_CRITICO'
      AND erp.Clave = 'PORCENTAJE_INCREMENTO_STOCK_CRITICO'
      AND erp.Activo = 1
      AND erp.FechaVigencia <= SYSDATETIME()
      AND (erp.FechaFin IS NULL OR erp.FechaFin > SYSDATETIME())
    ORDER BY erp.FechaVigencia DESC;

    -- Cargar Oportunidad
    SELECT TOP 1 @PorcentajeOportunidad = erp.Valor
    FROM EstrategiaReglaParametros erp
    INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_OPORTUNIDAD'
      AND erp.Clave = 'PORCENTAJE_INCREMENTO_OPORTUNIDAD'
      AND erp.Activo = 1
      AND erp.FechaVigencia <= SYSDATETIME()
      AND (erp.FechaFin IS NULL OR erp.FechaFin > SYSDATETIME())
    ORDER BY erp.FechaVigencia DESC;

    -- Cargar Ventana de Velocidad (7/15/30/60/90 días; default 30 si no está configurado)
    SELECT TOP 1 @VentanaVelocidadDias = CAST(erp.Valor AS INT)
    FROM EstrategiaReglaParametros erp
    INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_OPORTUNIDAD'
      AND erp.Clave = 'VENTANA_VELOCIDAD_DIAS'
      AND erp.Activo = 1
      AND erp.FechaVigencia <= SYSDATETIME()
      AND (erp.FechaFin IS NULL OR erp.FechaFin > SYSDATETIME())
    ORDER BY erp.FechaVigencia DESC;

    IF @VentanaVelocidadDias NOT IN (7, 15, 30, 60, 90)
        SET @VentanaVelocidadDias = 30;

    -- Cargar Exceso Stock
    SELECT TOP 1 @PorcentajeExcesoStock = erp.Valor
    FROM EstrategiaReglaParametros erp
    INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_EXCESO_STOCK'
      AND erp.Clave = 'PORCENTAJE_DECREMENTO_EXCESO_STOCK'
      AND erp.Activo = 1
      AND erp.FechaVigencia <= SYSDATETIME()
      AND (erp.FechaFin IS NULL OR erp.FechaFin > SYSDATETIME())
    ORDER BY erp.FechaVigencia DESC;

    -- Cargar Descuento por Competencia
    SELECT TOP 1 @PorcentajeDescuentoCompetencia = erp.Valor
    FROM EstrategiaReglaParametros erp
    INNER JOIN EstrategiaReglas er ON erp.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_COMPETENCIA_ABAJO'
      AND erp.Clave = 'PORCENTAJE_DESCUENTO_COMPETENCIA'
      AND erp.Activo = 1
      AND erp.FechaVigencia <= SYSDATETIME()
      AND (erp.FechaFin IS NULL OR erp.FechaFin > SYSDATETIME())
    ORDER BY erp.FechaVigencia DESC;

    -- 2.2. Cargar Mensajes Parametrizados por Estrategia (con defaults)
    DECLARE @MensajeStockCritico NVARCHAR(MAX) = 'Stock en nivel CRÍTICO. Se incrementa precio {PORCENTAJE}% para proteger quiebre.';
    DECLARE @MensajeOportunidad NVARCHAR(MAX) = 'Captura de margen por oportunidad de mercado ({PORCENTAJE}%). Ausencia de competencia directa o alta demanda.';
    DECLARE @MensajeExcesoStock NVARCHAR(MAX) = 'Exceso de stock detectado con baja rotación. Aplicando descuento de liquidación {PORCENTAJE}%.';
    DECLARE @MensajeCompetencia NVARCHAR(MAX) = 'Competidor relevante detectado a menor precio. Descuentando {PORCENTAJE}%. Ajustando a: {PRECIO_NUEVO}';

    -- Cargar Mensaje Stock Crítico
    SELECT TOP 1 @MensajeStockCritico = erpm.Valor
    FROM EstrategiaReglaParametrosMensajes erpm
    INNER JOIN EstrategiaReglas er ON erpm.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_STOCK_CRITICO'
      AND erpm.Clave = 'MENSAJE_STOCK_CRITICO'
    AND erpm.Idioma IN (@Idioma, 'ES')
      AND erpm.Activo = 1
      AND erpm.FechaVigencia <= SYSDATETIME()
      AND (erpm.FechaFin IS NULL OR erpm.FechaFin > SYSDATETIME())
    ORDER BY CASE WHEN erpm.Idioma = @Idioma THEN 0 ELSE 1 END, erpm.FechaVigencia DESC;

    -- Cargar Mensaje Oportunidad
    SELECT TOP 1 @MensajeOportunidad = erpm.Valor
    FROM EstrategiaReglaParametrosMensajes erpm
    INNER JOIN EstrategiaReglas er ON erpm.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_OPORTUNIDAD'
      AND erpm.Clave = 'MENSAJE_OPORTUNIDAD'
    AND erpm.Idioma IN (@Idioma, 'ES')
      AND erpm.Activo = 1
      AND erpm.FechaVigencia <= SYSDATETIME()
      AND (erpm.FechaFin IS NULL OR erpm.FechaFin > SYSDATETIME())
    ORDER BY CASE WHEN erpm.Idioma = @Idioma THEN 0 ELSE 1 END, erpm.FechaVigencia DESC;

    -- Cargar Mensaje Exceso Stock
    SELECT TOP 1 @MensajeExcesoStock = erpm.Valor
    FROM EstrategiaReglaParametrosMensajes erpm
    INNER JOIN EstrategiaReglas er ON erpm.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_EXCESO_STOCK'
      AND erpm.Clave = 'MENSAJE_EXCESO_STOCK'
    AND erpm.Idioma IN (@Idioma, 'ES')
      AND erpm.Activo = 1
      AND erpm.FechaVigencia <= SYSDATETIME()
      AND (erpm.FechaFin IS NULL OR erpm.FechaFin > SYSDATETIME())
    ORDER BY CASE WHEN erpm.Idioma = @Idioma THEN 0 ELSE 1 END, erpm.FechaVigencia DESC;

    -- Cargar Mensaje Competencia
    SELECT TOP 1 @MensajeCompetencia = erpm.Valor
    FROM EstrategiaReglaParametrosMensajes erpm
    INNER JOIN EstrategiaReglas er ON erpm.EstrategiaReglaID = er.EstrategiaReglaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE er.EstrategiaID = @EstrategiaID
      AND r.CodigoRegla = 'REGLA_COMPETENCIA_ABAJO'
      AND erpm.Clave = 'MENSAJE_COMPETENCIA'
    AND erpm.Idioma IN (@Idioma, 'ES')
      AND erpm.Activo = 1
      AND erpm.FechaVigencia <= SYSDATETIME()
      AND (erpm.FechaFin IS NULL OR erpm.FechaFin > SYSDATETIME())
    ORDER BY CASE WHEN erpm.Idioma = @Idioma THEN 0 ELSE 1 END, erpm.FechaVigencia DESC;

    -- 3. Tabla Temporal para procesamiento Set-Based
    CREATE TABLE #ContextoDecision (
        PublicacionID INT,
        ProductoID INT,
        MeliItemID VARCHAR(50),
        PrecioActual DECIMAL(18,4),
        PrecioMinimoPermitido DECIMAL(18,4),
        PrecioMaximoPermitido DECIMAL(18,4),
        FechaUltimoCambio DATETIME2(3),
        StockDisponible INT,
        StockMinimo INT,
        StockMaximo INT,
        ClasificacionStock VARCHAR(20),
        VelocidadVentaDiaria DECIMAL(10,4),
        DiasStock INT,
        CompMinPrecio DECIMAL(18,4),
        CompRelevantePrecio DECIMAL(18,4),
        CompetidorItemIDRef VARCHAR(50),
        CantCompetidores INT,
        PosicionCompetitiva INT,
        EsCatalogo BIT,
        CostoCompra DECIMAL(18,4),
        PorcentajeIVA DECIMAL(5,2),
        ComisionMLPorc DECIMAL(5,2),
        CostoEnvio DECIMAL(18,4),
        CostoLogistico DECIMAL(18,4),
        CostoFinancieroPorc DECIMAL(5,2),
        CostoPublicidadPorc DECIMAL(5,2),
        MargenActual DECIMAL(7,2),
        PrecioSugerido DECIMAL(18,4),
        Accion VARCHAR(50),
        Motivo VARCHAR(500),
        ReglaGanadoraID INT,
        PrioridadGanadora INT,
        ScoreConfianza DECIMAL(5,2)
    );

    -- 4. Ingesta de Datos al Contexto: TEMP (Simulación) vs BASE (Producción)
    IF @ContextSource = 'TEMP'
    BEGIN
        -- Carga desde parámetros de entrada (simulación)
        INSERT INTO #ContextoDecision (
            ProductoID, MeliItemID, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido,
            FechaUltimoCambio, StockDisponible, StockMinimo, StockMaximo, ClasificacionStock,
            CompMinPrecio, CompRelevantePrecio, CantCompetidores, PosicionCompetitiva,
            CostoCompra, PorcentajeIVA, ComisionMLPorc, CostoEnvio, CostoLogistico,
            CostoFinancieroPorc, CostoPublicidadPorc, MargenActual, PrecioSugerido,
            Accion, Motivo, ReglaGanadoraID, PrioridadGanadora, ScoreConfianza
        )
        VALUES (
            @ProductoID,
            @SKU,
            @PrecioActual,
            ISNULL(@PrecioActual * 0.90, @PrecioActual),
            ISNULL(@PrecioActual * 1.20, @PrecioActual),
            NULL,
            @StockActual,
            @StockMinimo,
            @StockMaximo,
            CASE 
                WHEN @StockActual <= @StockMinimo THEN 'CRITICO'
                WHEN @StockActual <= (@StockMinimo * 1.5) THEN 'BAJO'
                WHEN @StockActual >= @StockMaximo THEN 'EXCESO'
                WHEN @StockActual > (@StockMaximo * 0.8) THEN 'ALTO'
                ELSE 'NORMAL'
            END,
            NULL, NULL, 0, 1,
            @CostoCompra, @IVA, @ComisionMLPorc, @CostoEnvioPromedio, @CostoLogisticoFijo,
            @CostoFinancieroPorc, @CostoPublicidadPorc,
            dbo.fn_CalcularMargenNetoPorc(
                @PrecioActual, @CostoCompra, @ComisionMLPorc, @IVA,
                @CostoEnvioPromedio, @CostoLogisticoFijo, @CostoFinancieroPorc, @CostoPublicidadPorc
            ),
            @PrecioActual, 'MANTENER_PRECIO', 'Escenario simulado', NULL, 999, CAST(0.50 AS DECIMAL(5,2))
        );
    END
    ELSE
    BEGIN
        -- Carga desde tablas base (producción)
        INSERT INTO #ContextoDecision
        SELECT 
            pub.PublicacionID,
            p.ProductoID,
            pub.MeliItemID,
            pub.PrecioActual,
            pub.PrecioMinimoPermitido,
            pub.PrecioMaximoPermitido,
            pub.FechaUltimoCambioPrecio,
            st.StockDisponible,
            st.StockMinimo,
            st.StockMaximo,
            CASE 
                WHEN st.StockDisponible <= st.StockMinimo THEN 'CRITICO'
                WHEN st.StockDisponible <= (st.StockMinimo * 1.5) THEN 'BAJO'
                WHEN st.StockDisponible >= st.StockMaximo THEN 'EXCESO'
                WHEN st.StockDisponible > (st.StockMaximo * 0.8) THEN 'ALTO'
                ELSE 'NORMAL'
            END AS ClasificacionStock,
            vel.VelocidadCalculada,
            CASE WHEN vel.VelocidadCalculada > 0
                 THEN CAST(st.StockDisponible / vel.VelocidadCalculada AS INT)
                 ELSE 9999 END AS DiasStock,
            comp.CompMinPrecio,
            comp.CompRelevantePrecio,
            compGanador.CompetidorItemIDGanador,
            ISNULL(comp.CantCompetidores, 0),
            ISNULL(comp.PosicionCompetitiva, 1),
            pub.EsCatalogo,
            c.CostoCompra,
            c.PorcentajeIVA,
            pub.ComisionMLPorc,
            c.CostoEnvioPromedio,
            c.CostoLogisticoFijo,
            c.CostoFinancieroPorc,
            c.CostoPublicidadPorc,
            dbo.fn_CalcularMargenNetoPorc(
                pub.PrecioActual, c.CostoCompra, pub.ComisionMLPorc, 
                c.PorcentajeIVA, c.CostoEnvioPromedio, c.CostoLogisticoFijo, 
                c.CostoFinancieroPorc, c.CostoPublicidadPorc
            ) AS MargenActual,
            pub.PrecioActual,
            'MANTENER_PRECIO',
            'Sin cambios requeridos',
            NULL,
            999,
            CAST(
                0.50 
                + (CASE WHEN ISNULL(comp.CantCompetidores, 0) > 5 THEN 5.0 ELSE ISNULL(comp.CantCompetidores, 0) END / 10.0)
                + (CASE WHEN vel.VelocidadCalculada >= 1.0 THEN 0.20 ELSE 0.00 END)
            AS DECIMAL(5,2))
        FROM PublicacionesML pub
        INNER JOIN Productos p ON pub.ProductoID = p.ProductoID
        INNER JOIN CostosProducto c ON p.ProductoID = c.ProductoID
        INNER JOIN StockEstado st ON p.ProductoID = st.ProductoID
        LEFT JOIN MetricasVentasHist mv ON pub.PublicacionID = mv.PublicacionID
        CROSS APPLY (
            SELECT CASE @VentanaVelocidadDias
                WHEN 7  THEN ISNULL(mv.Ventas7D, 0)  / 7.0
                WHEN 15 THEN ISNULL(mv.Ventas15D, 0) / 15.0
                WHEN 60 THEN ISNULL(mv.Ventas60D, 0) / 60.0
                WHEN 90 THEN ISNULL(mv.Ventas90D, 0) / 90.0
                ELSE ISNULL(mv.Ventas30D, 0) / 30.0
            END AS VelocidadCalculada
        ) vel
        OUTER APPLY (
            SELECT 
                MIN(cs.PrecioCompetidor) AS CompMinPrecio,
                MAX(CASE WHEN cs.NivelRelevancia = 1 THEN cs.PrecioCompetidor END) AS CompRelevantePrecio,
                COUNT(*) AS CantCompetidores,
                (SELECT COUNT(*) FROM CompetenciaSnapshot cs2
                 WHERE cs2.PublicacionID = pub.PublicacionID
                   AND cs2.FechaCaptura >= DATEADD(HOUR, -48, SYSDATETIME())
                   AND cs2.PrecioCompetidor < pub.PrecioActual) + 1 AS PosicionCompetitiva
            FROM CompetenciaSnapshot cs
            WHERE cs.PublicacionID = pub.PublicacionID
              AND cs.FechaCaptura >= DATEADD(HOUR, -48, SYSDATETIME())
        ) comp
        -- #aprobacionColaMl: identifica el competidor puntual (no solo el precio agregado)
        -- para poder mostrar un link real en la pantalla de aprobación de la cola ML.
        -- Prioriza el más barato entre los "relevantes" (NivelRelevancia=1); si no hay
        -- ninguno, el más barato en general. No cambia PrecioSugerido de ninguna regla.
        OUTER APPLY (
            SELECT TOP 1 cs.CompetidorItemID AS CompetidorItemIDGanador
            FROM CompetenciaSnapshot cs
            WHERE cs.PublicacionID = pub.PublicacionID
              AND cs.FechaCaptura >= DATEADD(HOUR, -48, SYSDATETIME())
            ORDER BY CASE WHEN cs.NivelRelevancia = 1 THEN 0 ELSE 1 END, cs.PrecioCompetidor ASC
        ) compGanador
        WHERE p.EmpresaID = @EmpresaID
          AND (@ProductoID IS NULL OR p.ProductoID = @ProductoID)
          AND pub.Estado = 'active';
    END

    -- 5. APLICACIÓN DE REGLAS BASADA EN ESTRATEGIA

    -- REGLA: STOCK CRÍTICO (Subir Precio para desacelerar venta)
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual * (1 + (@PorcentajeStockCritico / 100)),
        Accion = 'AUMENTAR_PRECIO',
        Motivo = REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(@MensajeStockCritico, '{PORCENTAJE}', CAST(@PorcentajeStockCritico AS VARCHAR(10))),
                    '{PRECIO_NUEVO}', CAST(ctx.PrecioActual * (1 + (@PorcentajeStockCritico / 100)) AS VARCHAR(20))
                ),
                '{PRECIO_ANTERIOR}', CAST(ctx.PrecioActual AS VARCHAR(20))
            ),
            '{COMPETIDOR_PRECIO}', ISNULL(CAST(ISNULL(ctx.CompRelevantePrecio, ctx.CompMinPrecio) AS VARCHAR(20)), 'N/D')
        ),
        ReglaGanadoraID = r.ReglaID,
        PrioridadGanadora = er.Prioridad
    FROM #ContextoDecision ctx
    INNER JOIN EstrategiaReglas er ON er.EstrategiaID = @EstrategiaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE r.CodigoRegla = 'REGLA_STOCK_CRITICO' AND er.Activa = 1
      AND ctx.ClasificacionStock = 'CRITICO'
      AND er.Prioridad < ISNULL(ctx.PrioridadGanadora, 999);

    -- REGLA: COMPETENCIA MÁS BARATA (Bajar precio para ganar competitividad)
    UPDATE ctx
    SET PrecioSugerido = CASE 
                            WHEN ctx.CompRelevantePrecio IS NOT NULL THEN ctx.CompRelevantePrecio * (1 - (@PorcentajeDescuentoCompetencia / 100))
                            ELSE ctx.CompMinPrecio * (1 - (@PorcentajeDescuentoCompetencia / 100))
                         END,
        Accion = 'DISMINUIR_PRECIO',
        Motivo = REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(@MensajeCompetencia, '{PORCENTAJE}', CAST(@PorcentajeDescuentoCompetencia AS VARCHAR(10))),
                    '{PRECIO_NUEVO}', CAST(ISNULL(ctx.CompRelevantePrecio * (1 - (@PorcentajeDescuentoCompetencia / 100)), ctx.CompMinPrecio * (1 - (@PorcentajeDescuentoCompetencia / 100))) AS VARCHAR(20))
                ),
                '{PRECIO_ANTERIOR}', CAST(ctx.PrecioActual AS VARCHAR(20))
            ),
            '{COMPETIDOR_PRECIO}', ISNULL(CAST(ISNULL(ctx.CompRelevantePrecio, ctx.CompMinPrecio) AS VARCHAR(20)), 'N/D')
        ),
        ReglaGanadoraID = r.ReglaID,
        PrioridadGanadora = er.Prioridad
    FROM #ContextoDecision ctx
    INNER JOIN EstrategiaReglas er ON er.EstrategiaID = @EstrategiaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE r.CodigoRegla = 'REGLA_COMPETENCIA_ABAJO' AND er.Activa = 1
      AND ctx.CompMinPrecio < ctx.PrecioActual
      AND ctx.ClasificacionStock NOT IN ('CRITICO')
      AND er.Prioridad < ISNULL(ctx.PrioridadGanadora, 999);

    -- REGLA: OPORTUNIDAD (Subir precio ante ausencia de competencia o alta rotación)
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual * (1 + (@PorcentajeOportunidad / 100)),
        Accion = 'AUMENTAR_PRECIO',
        Motivo = REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(@MensajeOportunidad, '{PORCENTAJE}', CAST(@PorcentajeOportunidad AS VARCHAR(10))),
                    '{PRECIO_NUEVO}', CAST(ctx.PrecioActual * (1 + (@PorcentajeOportunidad / 100)) AS VARCHAR(20))
                ),
                '{PRECIO_ANTERIOR}', CAST(ctx.PrecioActual AS VARCHAR(20))
            ),
            '{COMPETIDOR_PRECIO}', ISNULL(CAST(ISNULL(ctx.CompRelevantePrecio, ctx.CompMinPrecio) AS VARCHAR(20)), 'N/D')
        ),
        ReglaGanadoraID = r.ReglaID,
        PrioridadGanadora = er.Prioridad
    FROM #ContextoDecision ctx
    INNER JOIN EstrategiaReglas er ON er.EstrategiaID = @EstrategiaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE r.CodigoRegla = 'REGLA_OPORTUNIDAD' AND er.Activa = 1
      AND (ctx.CantCompetidores = 0 OR ctx.VelocidadVentaDiaria > 1.0)
      AND ctx.ClasificacionStock NOT IN ('CRITICO', 'BAJO')
      AND er.Prioridad < ISNULL(ctx.PrioridadGanadora, 999);

    -- REGLA: EXCESO DE STOCK (Bajar precio agresivamente)
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual * (1 - (@PorcentajeExcesoStock / 100)),
        Accion = 'DISMINUIR_PRECIO',
        Motivo = REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(@MensajeExcesoStock, '{PORCENTAJE}', CAST(@PorcentajeExcesoStock AS VARCHAR(10))),
                    '{PRECIO_NUEVO}', CAST(ctx.PrecioActual * (1 - (@PorcentajeExcesoStock / 100)) AS VARCHAR(20))
                ),
                '{PRECIO_ANTERIOR}', CAST(ctx.PrecioActual AS VARCHAR(20))
            ),
            '{COMPETIDOR_PRECIO}', ISNULL(CAST(ISNULL(ctx.CompRelevantePrecio, ctx.CompMinPrecio) AS VARCHAR(20)), 'N/D')
        ),
        ReglaGanadoraID = r.ReglaID,
        PrioridadGanadora = er.Prioridad
    FROM #ContextoDecision ctx
    INNER JOIN EstrategiaReglas er ON er.EstrategiaID = @EstrategiaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE r.CodigoRegla = 'REGLA_EXCESO_STOCK' AND er.Activa = 1
      AND ctx.ClasificacionStock = 'EXCESO'
      AND er.Prioridad < ISNULL(ctx.PrioridadGanadora, 999);

    -- 6. APLICACIÓN DE RESTRICCIONES DURA Y ANTI-OSCILACIÓN

    -- Validación de Margen Mínimo Permitido
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual,
        Accion = 'NO_MODIFICAR',
        Motivo = CONCAT('BLOQUEO SEGURIDAD: La baja sugerida viola el margen mínimo permitido (', @MargenMinimoGlobal, '%).'),
        ScoreConfianza = 0.95
    FROM #ContextoDecision ctx
    WHERE ctx.Accion = 'DISMINUIR_PRECIO'
      AND dbo.fn_CalcularMargenNetoPorc(
            ctx.PrecioSugerido, ctx.CostoCompra, ctx.ComisionMLPorc,
            ctx.PorcentajeIVA, ctx.CostoEnvio, ctx.CostoLogistico,
            ctx.CostoFinancieroPorc, ctx.CostoPublicidadPorc
      ) < @MargenMinimoGlobal;

    -- Validación de Límites Min/Max de Publicación
    UPDATE #ContextoDecision
    SET PrecioSugerido = CASE 
                            WHEN PrecioSugerido < PrecioMinimoPermitido THEN PrecioMinimoPermitido
                            WHEN PrecioSugerido > PrecioMaximoPermitido THEN PrecioMaximoPermitido
                            ELSE PrecioSugerido 
                         END,
        Motivo = CASE 
                    WHEN PrecioSugerido < PrecioMinimoPermitido THEN 'Ajustado al Límite Mínimo Permitido por Publicación'
                    WHEN PrecioSugerido > PrecioMaximoPermitido THEN 'Ajustado al Límite Máximo Permitido por Publicación'
                    ELSE Motivo 
                 END;

    -- Anti-Oscilación (Cooldown Period e Histéresis)
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual,
        Accion = 'MANTENER_PRECIO',
        Motivo = 'BLOQUEO COOLDOWN/HISTÉRESIS: Cambio omitido por reciente actualización o variación menor al umbral mínimo.'
    FROM #ContextoDecision ctx
    WHERE ctx.Accion IN ('AUMENTAR_PRECIO', 'DISMINUIR_PRECIO')
      AND (
            DATEDIFF(HOUR, ctx.FechaUltimoCambio, SYSDATETIME()) < @CooldownHoras
            OR (ABS(ctx.PrecioSugerido - ctx.PrecioActual) / ctx.PrecioActual * 100.0) < @VariacionMinimaPorc
          );

    -- 7. PERSISTENCIA EN HISTORIAL Y COLA DE EJECUCIÓN (solo si @Persistir = 1)
    IF @Persistir = 1
    BEGIN
        BEGIN TRANSACTION;

        INSERT INTO DecisionesHistorial (
            EmpresaID, PublicacionID, EstrategiaID, PrecioAnterior, PrecioCalculado,
            PrecioSugerido, Accion, Motivo, ReglaGanadoraID, PrioridadAplicada,
            MargenActualPorc, MargenProyectadoPorc, PosicionCompetitiva,
            PrecioCompetenciaRef, CompetidorItemIDRef, StockDisponible, ClasificacionStock, ScoreConfianza, EsSimulacion
        )
        SELECT
            @EmpresaID,
            ISNULL(ctx.PublicacionID, -1),
            @EstrategiaID,
            ctx.PrecioActual,
            ctx.PrecioSugerido,
            ctx.PrecioSugerido,
            ctx.Accion,
            ctx.Motivo,
            ctx.ReglaGanadoraID,
            ctx.PrioridadGanadora,
            ctx.MargenActual,
            dbo.fn_CalcularMargenNetoPorc(
                ctx.PrecioSugerido, ctx.CostoCompra, ctx.ComisionMLPorc,
                ctx.PorcentajeIVA, ctx.CostoEnvio, ctx.CostoLogistico,
                ctx.CostoFinancieroPorc, ctx.CostoPublicidadPorc
            ),
            ctx.PosicionCompetitiva,
            ISNULL(ctx.CompRelevantePrecio, ctx.CompMinPrecio),
            ctx.CompetidorItemIDRef,
            ctx.StockDisponible,
            ctx.ClasificacionStock,
            ctx.ScoreConfianza,
            @ModoSimulacion
        FROM #ContextoDecision ctx;

        -- Inserta en cola outbound solo en modo producción. Las publicaciones que no son
        -- de catálogo SIEMPRE piden aprobación; las de catálogo solo si
        -- @SubidaAutomaticaCatalogoML está en 0 para la empresa (ver #aprobacionColaMl).
        IF @ModoSimulacion = 0
        BEGIN
            INSERT INTO ColaEjecucionML (
                PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida, Motivo,
                CompetidorItemIDRef, PrecioCompetidorRef, RequiereAprobacion, Aprobado
            )
            SELECT
                PublicacionID, MeliItemID, PrecioSugerido, Accion, Motivo,
                CompetidorItemIDRef,
                ISNULL(CompRelevantePrecio, CompMinPrecio),
                CASE WHEN EsCatalogo = 1 AND @SubidaAutomaticaCatalogoML = 1 THEN 0 ELSE 1 END,
                CASE WHEN EsCatalogo = 1 AND @SubidaAutomaticaCatalogoML = 1 THEN 1 ELSE NULL END
            FROM #ContextoDecision
            WHERE Accion IN ('AUMENTAR_PRECIO', 'DISMINUIR_PRECIO');

            UPDATE pub
            SET FechaUltimoCambioPrecio = SYSDATETIME()
            FROM PublicacionesML pub
            INNER JOIN #ContextoDecision ctx ON pub.PublicacionID = ctx.PublicacionID
            WHERE ctx.Accion IN ('AUMENTAR_PRECIO', 'DISMINUIR_PRECIO');
        END

        COMMIT TRANSACTION;
    END

    -- 8. RETORNO DE RESULTADOS
    SELECT
        ISNULL(PublicacionID, -1) AS PublicacionID,
        ISNULL(MeliItemID, '') AS MeliItemID,
        ISNULL(PrecioActual, 0) AS PrecioActual,
        ISNULL(PrecioSugerido, 0) AS PrecioSugerido,
        Accion,
        Motivo,
        ISNULL(MargenActual, 0) AS MargenActualPorc,
        ISNULL(dbo.fn_CalcularMargenNetoPorc(
            PrecioSugerido, CostoCompra, ComisionMLPorc, 
            PorcentajeIVA, CostoEnvio, CostoLogistico, 
            CostoFinancieroPorc, CostoPublicidadPorc
        ), 0) AS MargenProyectadoPorc,
        ClasificacionStock,
        ISNULL(StockDisponible, 0) AS StockDisponible,
        ISNULL(CompMinPrecio, 0) AS CompMinPrecio,
        ISNULL(ScoreConfianza, 0) AS ScoreConfianza
    FROM #ContextoDecision;

    DROP TABLE #ContextoDecision;
END;
