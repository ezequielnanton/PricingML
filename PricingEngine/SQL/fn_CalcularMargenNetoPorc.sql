--Funciones Auxiliares para Cálculos de Margen y Competencia
CREATE OR ALTER FUNCTION dbo.fn_CalcularMargenNetoPorc (
    @PrecioFinal DECIMAL(18,4),
    @CostoCompra DECIMAL(18,4),
    @ComisionMLPorc DECIMAL(5,2),
    @PorcentajeIVA DECIMAL(5,2),
    @CostoEnvio DECIMAL(18,4),
    @CostoLogistico DECIMAL(18,4),
    @CostoFinancieroPorc DECIMAL(5,2),
    @CostoPublicidadPorc DECIMAL(5,2)
)
RETURNS DECIMAL(7,2)
AS
BEGIN
    IF ISNULL(@PrecioFinal, 0) = 0 RETURN 0.00;

    DECLARE @PrecioSinIVA DECIMAL(18,4) = @PrecioFinal / (1.0 + (@PorcentajeIVA / 100.0));
    DECLARE @MontoComision DECIMAL(18,4) = @PrecioFinal * (@ComisionMLPorc / 100.0);
    DECLARE @MontoFinanciero DECIMAL(18,4) = @PrecioFinal * (@CostoFinancieroPorc / 100.0);
    DECLARE @MontoPublicidad DECIMAL(18,4) = @PrecioFinal * (@CostoPublicidadPorc / 100.0);
    
    DECLARE @CostoTotal DECIMAL(18,4) = @CostoCompra + @MontoComision + @CostoEnvio 
                                         + @CostoLogistico + @MontoFinanciero + @MontoPublicidad;

    DECLARE @GananciaNeta DECIMAL(18,4) = @PrecioSinIVA - @CostoTotal;
    DECLARE @MargenNetoPorc DECIMAL(7,2) = (@GananciaNeta / @PrecioFinal) * 100.0;

    RETURN CAST(@MargenNetoPorc AS DECIMAL(7,2));
END;
GO