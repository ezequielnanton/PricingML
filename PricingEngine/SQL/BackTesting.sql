CREATE TABLE BacktestingResultados (
    ExecutionID BIGINT IDENTITY(1,1) PRIMARY KEY,
    EstrategiaID INT NOT NULL,
    FechaSimulada DATE NOT NULL,
    FacturacionProyectada DECIMAL(18,2) NOT NULL DEFAULT 0,
    GananciaNetaProyectada DECIMAL(18,2) NOT NULL DEFAULT 0,
    CantidadCambiosPrecio INT NOT NULL DEFAULT 0,
    FechaEjecucion DATETIME2(3) NOT NULL CONSTRAINT DF_Backtesting_Exec DEFAULT (SYSDATETIME())
);
GO

CREATE OR ALTER PROCEDURE dbo.spEjecutarBacktesting
    @EmpresaID INT,
    @EstrategiaID INT = NULL,
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @EmpresaID IS NULL OR @EmpresaID <= 0
    BEGIN
        RAISERROR('El parámetro @EmpresaID es obligatorio y debe ser mayor a 0.', 16, 1);
        RETURN;
    END;

    IF @FechaInicio IS NULL OR @FechaFin IS NULL
    BEGIN
        RAISERROR('Los parámetros @FechaInicio y @FechaFin son obligatorios.', 16, 1);
        RETURN;
    END;

    IF @FechaInicio > @FechaFin
    BEGIN
        RAISERROR('La fecha de inicio no puede ser mayor que la fecha de fin.', 16, 1);
        RETURN;
    END;

    IF @EstrategiaID IS NULL
    BEGIN
        SELECT TOP 1 @EstrategiaID = EstrategiaID
        FROM Estrategias
        WHERE EmpresaID = @EmpresaID AND Activa = 1
        ORDER BY EstrategiaID;
    END;

    IF @EstrategiaID IS NULL
    BEGIN
        RAISERROR('No existe una estrategia activa para la empresa indicada.', 16, 1);
        RETURN;
    END;

    PRINT CONCAT('Iniciando Backtesting para la Empresa ', @EmpresaID, ' y la Estrategia ', @EstrategiaID);
    PRINT CONCAT('Rango de simulación: ', CONVERT(VARCHAR(10), @FechaInicio, 120), ' al ', CONVERT(VARCHAR(10), @FechaFin, 120));

    CREATE TABLE #DiasSimulados (
        FechaSimulada DATE NOT NULL PRIMARY KEY
    );

    ;WITH Dias AS (
        SELECT @FechaInicio AS FechaSimulada
        UNION ALL
        SELECT DATEADD(DAY, 1, FechaSimulada)
        FROM Dias
        WHERE DATEADD(DAY, 1, FechaSimulada) <= @FechaFin
    )
    INSERT INTO #DiasSimulados (FechaSimulada)
    SELECT FechaSimulada
    FROM Dias;

    CREATE TABLE #DecisionDiaTemp (
        PublicacionID INT NOT NULL,
        MeliItemID VARCHAR(50) NOT NULL,
        PrecioActual DECIMAL(18,4) NOT NULL,
        PrecioSugerido DECIMAL(18,4) NOT NULL,
        Accion VARCHAR(50) NOT NULL,
        Motivo VARCHAR(500) NOT NULL,
        MargenActualPorc DECIMAL(7,2) NOT NULL,
        MargenProyectadoPorc DECIMAL(7,2) NOT NULL,
        ClasificacionStock VARCHAR(20) NOT NULL,
        StockDisponible INT NOT NULL,
        CompMinPrecio DECIMAL(18,4) NULL,
        ScoreConfianza DECIMAL(5,2) NOT NULL
    );

    CREATE TABLE #BacktestingPorDia (
        FechaSimulada DATE NOT NULL,
        PublicacionID INT NOT NULL,
        MeliItemID VARCHAR(50) NOT NULL,
        PrecioActual DECIMAL(18,4) NOT NULL,
        PrecioSugerido DECIMAL(18,4) NOT NULL,
        Accion VARCHAR(50) NOT NULL,
        Motivo VARCHAR(500) NOT NULL,
        MargenActualPorc DECIMAL(7,2) NOT NULL,
        MargenProyectadoPorc DECIMAL(7,2) NOT NULL,
        ClasificacionStock VARCHAR(20) NOT NULL,
        StockDisponible INT NOT NULL,
        CompMinPrecio DECIMAL(18,4) NULL,
        ScoreConfianza DECIMAL(5,2) NOT NULL,
        UnidadesDiarias DECIMAL(18,4) NOT NULL
    );

    DECLARE @FechaActual DATE;
    DECLARE CurDias CURSOR LOCAL FAST_FORWARD FOR
        SELECT FechaSimulada
        FROM #DiasSimulados
        ORDER BY FechaSimulada;

    OPEN CurDias;
    FETCH NEXT FROM CurDias INTO @FechaActual;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DELETE FROM #DecisionDiaTemp;

        INSERT INTO #DecisionDiaTemp (
            PublicacionID,
            MeliItemID,
            PrecioActual,
            PrecioSugerido,
            Accion,
            Motivo,
            MargenActualPorc,
            MargenProyectadoPorc,
            ClasificacionStock,
            StockDisponible,
            CompMinPrecio,
            ScoreConfianza
        )
        EXEC dbo.spCalcularDecision
            @EmpresaID = @EmpresaID,
            @EstrategiaID = @EstrategiaID,
            @ModoSimulacion = 1;

        INSERT INTO #BacktestingPorDia (
            FechaSimulada,
            PublicacionID,
            MeliItemID,
            PrecioActual,
            PrecioSugerido,
            Accion,
            Motivo,
            MargenActualPorc,
            MargenProyectadoPorc,
            ClasificacionStock,
            StockDisponible,
            CompMinPrecio,
            ScoreConfianza,
            UnidadesDiarias
        )
        SELECT 
            @FechaActual,
            d.PublicacionID,
            d.MeliItemID,
            d.PrecioActual,
            d.PrecioSugerido,
            d.Accion,
            d.Motivo,
            d.MargenActualPorc,
            d.MargenProyectadoPorc,
            d.ClasificacionStock,
            d.StockDisponible,
            d.CompMinPrecio,
            d.ScoreConfianza,
            CASE
                WHEN ISNULL(mv.VelocidadVentaDiaria, 0) > 0 THEN CAST(CEILING(mv.VelocidadVentaDiaria) AS DECIMAL(18,4))
                ELSE 1.00
            END
        FROM #DecisionDiaTemp d
        LEFT JOIN MetricasVentasHist mv ON mv.PublicacionID = d.PublicacionID;

        FETCH NEXT FROM CurDias INTO @FechaActual;
    END;

    CLOSE CurDias;
    DEALLOCATE CurDias;

    INSERT INTO BacktestingResultados (
        EstrategiaID,
        FechaSimulada,
        FacturacionProyectada,
        GananciaNetaProyectada,
        CantidadCambiosPrecio
    )
    SELECT
        @EstrategiaID,
        b.FechaSimulada,
        CAST(SUM(b.PrecioSugerido * b.UnidadesDiarias) AS DECIMAL(18,2)) AS FacturacionProyectada,
        CAST(SUM((b.PrecioSugerido * b.UnidadesDiarias) * (b.MargenProyectadoPorc / 100.0)) AS DECIMAL(18,2)) AS GananciaNetaProyectada,
        SUM(CASE WHEN b.Accion IN ('AUMENTAR_PRECIO', 'DISMINUIR_PRECIO') THEN 1 ELSE 0 END) AS CantidadCambiosPrecio
    FROM #BacktestingPorDia b
    GROUP BY b.FechaSimulada
    ORDER BY b.FechaSimulada;

    SELECT
        b.ExecutionID,
        b.EstrategiaID,
        b.FechaSimulada,
        b.FacturacionProyectada,
        b.GananciaNetaProyectada,
        b.CantidadCambiosPrecio,
        b.FechaEjecucion
    FROM BacktestingResultados b
    WHERE b.EstrategiaID = @EstrategiaID
      AND b.FechaSimulada BETWEEN @FechaInicio AND @FechaFin
    ORDER BY b.FechaSimulada;

    DROP TABLE #DiasSimulados;
    DROP TABLE #DecisionDiaTemp;
    DROP TABLE #BacktestingPorDia;
END;
GO