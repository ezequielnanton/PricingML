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
    @VariacionMinimaPorc DECIMAL(5,2) = 1.50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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
        CantCompetidores INT,
        PosicionCompetitiva INT,
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
            SYSDATETIME(),
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
            @PrecioActual, 'MANTENER_PRECIO', 'Escenario simulado', NULL, 999, 0.80
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
            ISNULL(mv.VelocidadVentaDiaria, 0),
            CASE WHEN ISNULL(mv.VelocidadVentaDiaria, 0) > 0
                 THEN CAST(st.StockDisponible / mv.VelocidadVentaDiaria AS INT)
                 ELSE 9999 END AS DiasStock,
            comp.CompMinPrecio,
            comp.CompRelevantePrecio,
            ISNULL(comp.CantCompetidores, 0),
            ISNULL(comp.PosicionCompetitiva, 1),
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
            0.80
        FROM PublicacionesML pub
        INNER JOIN Productos p ON pub.ProductoID = p.ProductoID
        INNER JOIN CostosProducto c ON p.ProductoID = c.ProductoID
        INNER JOIN StockEstado st ON p.ProductoID = st.ProductoID
        LEFT JOIN MetricasVentasHist mv ON pub.PublicacionID = mv.PublicacionID
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
        WHERE p.EmpresaID = @EmpresaID
          AND (@ProductoID IS NULL OR p.ProductoID = @ProductoID)
          AND pub.Estado = 'active';
    END

    -- 5. APLICACIÓN DE REGLAS BASADA EN ESTRATEGIA

    -- REGLA: STOCK CRÍTICO (Subir Precio para desacelerar venta)
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual * 1.05,
        Accion = 'AUMENTAR_PRECIO',
        Motivo = 'Stock en nivel CRÍTICO. Se incrementa precio 5% para proteger quiebre.',
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
                            WHEN ctx.CompRelevantePrecio IS NOT NULL THEN ctx.CompRelevantePrecio - 10
                            ELSE ctx.CompMinPrecio - 10 
                         END,
        Accion = 'DISMINUIR_PRECIO',
        Motivo = CONCAT('Competidor relevante detectado a menor precio. Ajustando a: ', ISNULL(ctx.CompRelevantePrecio, ctx.CompMinPrecio)),
        ReglaGanadoraID = r.ReglaID,
        PrioridadGanadora = er.Prioridad
    FROM #ContextoDecision ctx
    INNER JOIN EstrategiaReglas er ON er.EstrategiaID = @EstrategiaID
    INNER JOIN ReglasNegocio r ON er.ReglaID = r.ReglaID
    WHERE r.CodigoRegla = 'REGLA_COMPETENCIA_ABAJO' AND er.Activa = 1
      AND ctx.CompMinPrecio < ctx.PrecioActual
      AND ctx.ClasificacionStock NOT IN ('CRITICO')
      AND er.Prioridad < ISNULL(ctx.PrioridadGanadora, 999);

    -- REGLA: EXCESO DE STOCK (Bajar precio agresivamente)
    UPDATE ctx
    SET PrecioSugerido = ctx.PrecioActual * 0.93,
        Accion = 'DISMINUIR_PRECIO',
        Motivo = 'Exceso de stock detectado con baja rotación. Aplicando descuento de liquidación.',
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
            PrecioCompetenciaRef, StockDisponible, ClasificacionStock, ScoreConfianza, EsSimulacion
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
            ctx.StockDisponible,
            ctx.ClasificacionStock,
            ctx.ScoreConfianza,
            @ModoSimulacion
        FROM #ContextoDecision ctx;

        -- Inserta en cola outbound solo en modo producción
        IF @ModoSimulacion = 0
        BEGIN
            INSERT INTO ColaEjecucionML (PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida)
            SELECT PublicacionID, MeliItemID, PrecioSugerido, Accion
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
        PrecioActual,
        PrecioSugerido,
        Accion,
        Motivo,
        MargenActual AS MargenActualPorc,
        dbo.fn_CalcularMargenNetoPorc(
            PrecioSugerido, CostoCompra, ComisionMLPorc, 
            PorcentajeIVA, CostoEnvio, CostoLogistico, 
            CostoFinancieroPorc, CostoPublicidadPorc
        ) AS MargenProyectadoPorc,
        ClasificacionStock,
        StockDisponible,
        CompMinPrecio,
        ScoreConfianza
    FROM #ContextoDecision;

    DROP TABLE #ContextoDecision;
END;
