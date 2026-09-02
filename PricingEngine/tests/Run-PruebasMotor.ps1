<#
.SYNOPSIS
    Corre el banco de pruebas del motor de pricing (spCalcularDecision) y deja
    un Excel con lo esperado vs. lo obtenido en cada caso.

.DESCRIPTION
    1) Re-siembra los datos de prueba (SQL/Seed-PruebasMotor.sql) para dejar
       cada producto QA-TC01..QA-TC08 en su estado esperado (idempotente).
    2) Ejecuta dbo.spCalcularDecision para cada caso documentado en
       docs/QA-Motor-Pricing.md (10 casos: una regla por caso, más los
       bloqueos de margen/clamp/anti-oscilación, la comparación
       simulación-vs-real, y los efectos colaterales de persistir una
       decisión).
    3) Compara el resultado contra lo esperado y arma un Excel con columnas
       Producto / Precio / Stock / Competencia / Resultado esperado /
       Resultado obtenido / Pass-Fail.

    Volver a correr este script después de cualquier cambio en
    spCalcularDecision (o en las reglas/parámetros de negocio) para confirmar
    que el comportamiento no cambió.

.EXAMPLE
    pwsh -File .\Run-PruebasMotor.ps1
#>

param(
    [string]$ServerInstance = "localhost\SQLEXPRESS",
    [string]$Database = "PRICES_DB",
    [string]$OutputExcel = "$PSScriptRoot\Resultados-Motor-Pricing.xlsx"
)

$ErrorActionPreference = "Stop"
Import-Module SQLPS -DisableNameChecking -ErrorAction SilentlyContinue
if (-not (Get-Module -ListAvailable ImportExcel)) {
    throw "Falta el módulo ImportExcel. Instalarlo con: Install-Module ImportExcel -Scope CurrentUser"
}
Import-Module ImportExcel

function Invoke-Sql($query) {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query
}

Write-Host "== 1. Re-sembrando datos de prueba ==" -ForegroundColor Cyan
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -InputFile "$PSScriptRoot\..\SQL\Seed-PruebasMotor.sql" | Out-Null

$estrategia = Invoke-Sql "SELECT TOP 1 EstrategiaID, EmpresaID FROM Estrategias WHERE NombreEstrategia = 'Estrategia QA Motor'"
if (-not $estrategia) { throw "No se encontró la Estrategia QA Motor. ¿Corrió el seed correctamente?" }
$EstrategiaID = $estrategia.EstrategiaID
$EmpresaID = $estrategia.EmpresaID

function Get-Fixture($sku) {
    Invoke-Sql "
        SELECT p.ProductoID, pub.PublicacionID, pub.PrecioActual, pub.PrecioMinimoPermitido, pub.PrecioMaximoPermitido,
               se.StockActual, se.StockMinimo, se.StockMaximo,
               (SELECT COUNT(*) FROM CompetenciaSnapshot cs WHERE cs.PublicacionID = pub.PublicacionID) AS Competidores,
               (SELECT MIN(PrecioCompetidor) FROM CompetenciaSnapshot cs WHERE cs.PublicacionID = pub.PublicacionID) AS PrecioCompetenciaMin
        FROM Productos p
        JOIN PublicacionesML pub ON pub.ProductoID = p.ProductoID
        JOIN StockEstado se ON se.ProductoID = p.ProductoID
        WHERE p.SKU = '$sku'"
}

function Invoke-Decision {
    param([int]$ProductoID, [int]$ModoSimulacion = 0, [string]$ContextSource = 'BASE', [int]$Persistir = 1)
    Invoke-Sql "EXEC dbo.spCalcularDecision @EmpresaID=$EmpresaID, @ProductoID=$ProductoID, @EstrategiaID=$EstrategiaID, @ModoSimulacion=$ModoSimulacion, @Persistir=$Persistir, @ContextSource='$ContextSource'"
}

function Invoke-DecisionTemp {
    param([decimal]$PrecioActual, [int]$StockActual, [int]$StockMinimo, [int]$StockMaximo,
          [decimal]$CostoCompra, [decimal]$IVA, [decimal]$ComisionMLPorc, [decimal]$CostoEnvio, [decimal]$CostoLogistico)
    Invoke-Sql "EXEC dbo.spCalcularDecision
        @EmpresaID=$EmpresaID, @ProductoID=NULL, @EstrategiaID=$EstrategiaID,
        @ModoSimulacion=1, @Persistir=0, @ContextSource='TEMP',
        @SKU='QA-TC09-TEMP', @Titulo='QA Temp',
        @PrecioActual=$PrecioActual, @StockActual=$StockActual, @StockMinimo=$StockMinimo, @StockMaximo=$StockMaximo,
        @CostoCompra=$CostoCompra, @IVA=$IVA, @ComisionMLPorc=$ComisionMLPorc,
        @CostoEnvioPromedio=$CostoEnvio, @CostoLogisticoFijo=$CostoLogistico,
        @CostoFinancieroPorc=0, @CostoPublicidadPorc=0"
}

$rows = @()

function Test-Caso {
    param(
        [string]$Id, [string]$Descripcion, [string]$Sku,
        [string]$Competencia, [string]$ReglaEsperada,
        [string]$AccionEsperada, [decimal]$PrecioEsperado, [string]$MotivoContiene,
        [decimal]$Tolerancia = 0.01
    )

    $fx = Get-Fixture $sku
    $result = Invoke-Decision -ProductoID $fx.ProductoID

    $accionOk = ($result.Accion -eq $AccionEsperada)
    $precioOk = ([Math]::Abs([decimal]$result.PrecioSugerido - $PrecioEsperado) -le $Tolerancia)
    $motivoOk = [string]::IsNullOrEmpty($MotivoContiene) -or ($result.Motivo -match [regex]::Escape($MotivoContiene))
    $pass = $accionOk -and $precioOk -and $motivoOk

    $stockTxt = "$($fx.StockActual)/$($fx.StockMinimo)/$($fx.StockMaximo) (act/min/max)"
    $compTxt = if ($fx.Competidores -gt 0) { "$($fx.Competidores) competidor(es), min `$$($fx.PrecioCompetenciaMin)" } else { "sin competencia" }

    $script:rows += [PSCustomObject]@{
        Caso                 = $Id
        Descripcion          = $Descripcion
        Producto             = $sku
        Precio                = [decimal]$fx.PrecioActual
        Stock                = $stockTxt
        Competencia          = $compTxt
        ReglaEsperada        = $ReglaEsperada
        'ResultadoEsperado'  = "$AccionEsperada `$$PrecioEsperado"
        'ResultadoObtenido'  = "$($result.Accion) `$$([decimal]$result.PrecioSugerido)"
        MotivoObtenido       = $result.Motivo
        MargenProyectadoPorc = $result.MargenProyectadoPorc
        Resultado            = if ($pass) { "PASS" } else { "FAIL" }
        Detalle              = if ($pass) { "" } else {
            @(
                if (-not $accionOk) { "acción esperada '$AccionEsperada', obtuvo '$($result.Accion)'" }
                if (-not $precioOk) { "precio esperado $PrecioEsperado, obtuvo $($result.PrecioSugerido)" }
                if (-not $motivoOk) { "motivo no contiene '$MotivoContiene' (obtuvo: $($result.Motivo))" }
            ) -join '; '
        }
    }
}

Write-Host "== 2. Corriendo casos de prueba ==" -ForegroundColor Cyan

Test-Caso -Id "TC01" -Descripcion "Stock crítico sube el precio 5%" -Sku "QA-TC01" `
    -Competencia "sin competencia" -ReglaEsperada "REGLA_STOCK_CRITICO" `
    -AccionEsperada "AUMENTAR_PRECIO" -PrecioEsperado 10500.00 -MotivoContiene "CRÍTICO"

Test-Caso -Id "TC02" -Descripcion "Stock bajo sin ventaja de precio: no dispara ninguna regla" -Sku "QA-TC02" `
    -Competencia "1 competidor más caro" -ReglaEsperada "(ninguna)" `
    -AccionEsperada "MANTENER_PRECIO" -PrecioEsperado 10000.00 -MotivoContiene "Sin cambios"

Test-Caso -Id "TC03" -Descripcion "Competencia más barata baja el precio 1% por debajo del competidor" -Sku "QA-TC03" `
    -Competencia "1 competidor relevante a `$9000" -ReglaEsperada "REGLA_COMPETENCIA_ABAJO" `
    -AccionEsperada "DISMINUIR_PRECIO" -PrecioEsperado 8910.00 -MotivoContiene "Competidor"

Test-Caso -Id "TC04" -Descripcion "Sin competidores y stock normal: sube el precio 3% por oportunidad" -Sku "QA-TC04" `
    -Competencia "sin competencia" -ReglaEsperada "REGLA_OPORTUNIDAD" `
    -AccionEsperada "AUMENTAR_PRECIO" -PrecioEsperado 10300.00 -MotivoContiene "oportunidad"

Test-Caso -Id "TC05" -Descripcion "Exceso de stock baja el precio 7% para liquidar" -Sku "QA-TC05" `
    -Competencia "1 competidor más caro" -ReglaEsperada "REGLA_EXCESO_STOCK" `
    -AccionEsperada "DISMINUIR_PRECIO" -PrecioEsperado 9300.00 -MotivoContiene "Exceso"

Test-Caso -Id "TC06" -Descripcion "Bajar al precio de competencia violaría el margen mínimo: se bloquea" -Sku "QA-TC06" `
    -Competencia "1 competidor relevante a `$8700 (costo alto)" -ReglaEsperada "REGLA_COMPETENCIA_ABAJO (bloqueada)" `
    -AccionEsperada "NO_MODIFICAR" -PrecioEsperado 10000.00 -MotivoContiene "BLOQUEO SEGURIDAD"

Test-Caso -Id "TC07" -Descripcion "El precio de competencia calculado queda por debajo del mínimo permitido: se ajusta al piso" -Sku "QA-TC07" `
    -Competencia "1 competidor relevante a `$8000 (precio mín. publicación `$8500)" -ReglaEsperada "REGLA_COMPETENCIA_ABAJO (clamp)" `
    -AccionEsperada "DISMINUIR_PRECIO" -PrecioEsperado 8500.00 -MotivoContiene "Límite Mínimo"

Test-Caso -Id "TC08" -Descripcion "La baja calculada es menor al 1.5% mínimo de variación: se bloquea (anti-oscilación)" -Sku "QA-TC08" `
    -Competencia "1 competidor relevante a `$9970" -ReglaEsperada "REGLA_COMPETENCIA_ABAJO (bloqueada)" `
    -AccionEsperada "MANTENER_PRECIO" -PrecioEsperado 10000.00 -MotivoContiene "COOLDOWN"

# --- TC09: Modo Simulación (TEMP) ignora la competencia real de la base ---
Write-Host "== TC09: comparando Simulación (TEMP) vs Producción (BASE) para el mismo producto ==" -ForegroundColor Cyan
$fxTc03 = Get-Fixture "QA-TC03"
$tempResult = Invoke-DecisionTemp -PrecioActual 10000 -StockActual 50 -StockMinimo 10 -StockMaximo 100 `
    -CostoCompra 2864 -IVA 21 -ComisionMLPorc 10 -CostoEnvio 300 -CostoLogistico 100
$accionOk = ($tempResult.Accion -eq "AUMENTAR_PRECIO")
$precioOk = ([Math]::Abs([decimal]$tempResult.PrecioSugerido - 10300.00) -le 0.01)
$pass = $accionOk -and $precioOk
$rows += [PSCustomObject]@{
    Caso                 = "TC09"
    Descripcion          = "El mismo producto de TC03 (con competencia real más barata en la base), evaluado en modo Simulación, ignora esa competencia y sube 3% por oportunidad"
    Producto             = "QA-TC03 (modo TEMP)"
    Precio                = 10000
    Stock                = "50/10/100 (act/min/max)"
    Competencia          = "existe en la base ($($fxTc03.Competidores) competidor a `$$($fxTc03.PrecioCompetenciaMin)) pero TEMP no la lee"
    ReglaEsperada        = "REGLA_OPORTUNIDAD (TEMP fuerza 0 competidores)"
    'ResultadoEsperado'  = "AUMENTAR_PRECIO `$10300.00"
    'ResultadoObtenido'  = "$($tempResult.Accion) `$$([decimal]$tempResult.PrecioSugerido)"
    MotivoObtenido       = $tempResult.Motivo
    MargenProyectadoPorc = $tempResult.MargenProyectadoPorc
    Resultado            = if ($pass) { "PASS" } else { "FAIL" }
    Detalle              = if ($pass) { "" } else { "accion=$($tempResult.Accion) precio=$($tempResult.PrecioSugerido)" }
}

# --- TC10: efectos colaterales de persistir una decisión (TC01) ---
Write-Host "== TC10: verificando efectos colaterales de persistir la decisión de TC01 ==" -ForegroundColor Cyan
$fxTc01 = Get-Fixture "QA-TC01"
$cola = Invoke-Sql "SELECT TOP 1 * FROM ColaEjecucionML WHERE PublicacionID = $($fxTc01.PublicacionID) ORDER BY ColaID DESC"
$pubActualizada = Invoke-Sql "SELECT FechaUltimoCambioPrecio FROM PublicacionesML WHERE PublicacionID = $($fxTc01.PublicacionID)"
$decisionHist = Invoke-Sql "SELECT TOP 1 * FROM DecisionesHistorial WHERE PublicacionID = $($fxTc01.PublicacionID) ORDER BY DecisionID DESC"

$colaOk = ($cola -and $cola.AccionRequerida -eq 'AUMENTAR_PRECIO' -and [Math]::Abs([decimal]$cola.PrecioNuevo - 10500.00) -le 0.01 -and $cola.EstadoEjecucion -eq 'PENDIENTE')
$fechaOk = ($null -ne $pubActualizada.FechaUltimoCambioPrecio)
$histOk = ($null -ne $decisionHist -and $decisionHist.Accion -eq 'AUMENTAR_PRECIO')
$pass = $colaOk -and $fechaOk -and $histOk
$rows += [PSCustomObject]@{
    Caso                 = "TC10"
    Descripcion          = "Persistir una decisión con cambio de precio (TC01) deja rastro en DecisionesHistorial, encola la tarea en ColaEjecucionML y actualiza FechaUltimoCambioPrecio"
    Producto             = "QA-TC01 (efectos colaterales)"
    Precio                = 10000
    Stock                = "3/10/100 (act/min/max)"
    Competencia          = "sin competencia"
    ReglaEsperada        = "(verificación de persistencia, no de una regla)"
    'ResultadoEsperado'  = "Fila en ColaEjecucionML (PENDIENTE, `$10500), FechaUltimoCambioPrecio seteada, fila en DecisionesHistorial"
    'ResultadoObtenido'  = "Cola: $(if($cola){"$($cola.AccionRequerida) `$$($cola.PrecioNuevo) [$($cola.EstadoEjecucion)]"}else{'(no encontrada)'}); Fecha: $(if($fechaOk){'seteada'}else{'NULL'}); Historial: $(if($histOk){'OK'}else{'(no encontrado)'})"
    MotivoObtenido       = ""
    MargenProyectadoPorc = $null
    Resultado            = if ($pass) { "PASS" } else { "FAIL" }
    Detalle              = if ($pass) { "" } else { "colaOk=$colaOk fechaOk=$fechaOk histOk=$histOk" }
}

Write-Host "== 3. Resultado ==" -ForegroundColor Cyan
$rows | Format-Table Caso, Descripcion, Resultado -AutoSize -Wrap

$failCount = ($rows | Where-Object { $_.Resultado -eq 'FAIL' }).Count
$total = $rows.Count
Write-Host "$($total - $failCount) / $total casos OK" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })

Write-Host "== 4. Exportando a Excel: $OutputExcel ==" -ForegroundColor Cyan
if (Test-Path $OutputExcel) { Remove-Item $OutputExcel -Force }

$excelParams = @{
    Path          = $OutputExcel
    WorksheetName = "Casos de prueba"
    AutoSize      = $true
    AutoFilter    = $true
    FreezeTopRow  = $true
    TableStyle    = 'Medium2'
    BoldTopRow    = $true
}
$rows | Select-Object Caso, Descripcion, Producto, Precio, Stock, Competencia, ReglaEsperada, ResultadoEsperado, ResultadoObtenido, MotivoObtenido, MargenProyectadoPorc, Resultado, Detalle |
    Export-Excel @excelParams

Close-ExcelPackage (Open-ExcelPackage -Path $OutputExcel) -ErrorAction SilentlyContinue

# Coloreo PASS/FAIL con formato condicional
$pkg = Open-ExcelPackage -Path $OutputExcel
$ws = $pkg.Workbook.Worksheets["Casos de prueba"]
$lastRow = $ws.Dimension.End.Row
$resultCol = ($ws.Cells["A1:Z1"] | Where-Object { $_.Text -eq 'Resultado' }).Start.Column
if ($resultCol) {
    $colLetter = [OfficeOpenXml.ExcelCellAddress]::new(1, $resultCol).Address -replace '\d', ''
    $range = "${colLetter}2:$colLetter$lastRow"
    Add-ConditionalFormatting -Worksheet $ws -Address $range -RuleType Equal -ConditionValue "PASS" -BackgroundColor LightGreen
    Add-ConditionalFormatting -Worksheet $ws -Address $range -RuleType Equal -ConditionValue "FAIL" -BackgroundColor LightPink
}
Close-ExcelPackage $pkg

Write-Host "Listo: $OutputExcel" -ForegroundColor Green

if ($failCount -gt 0) { exit 1 } else { exit 0 }
