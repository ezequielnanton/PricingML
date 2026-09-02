const booleanSelectOptions = [{ value: '', label: 'Todos' }, { value: 'true', label: 'Sí' }, { value: 'false', label: 'No' }]

export const REPORT_TABLE_DEFINITIONS = {
  empresas: [
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'CUIT', apiField: 'cUIT', label: 'CUIT', type: 'cuit', allowRange: true, component: 'text' },
    { field: 'Activo', apiField: 'activo', label: 'Activo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'FechaCreacion', apiField: 'fechaCreacion', label: 'Fecha Creación', type: 'date', allowRange: true, component: 'date' },
  ],
  monedas: [
    { field: 'MonedaID', apiField: 'monedaID', label: 'Moneda ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'CodigoISO', apiField: 'codigoISO', label: 'Código ISO', type: 'text', allowRange: true, component: 'text' },
    { field: 'Simbolo', apiField: 'simbolo', label: 'Símbolo', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activa', apiField: 'activa', label: 'Activa', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
  ],
  cotizaciones: [
    { field: 'CotizacionID', apiField: 'cotizacionID', label: 'Cotización ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'MonedaID', apiField: 'monedaID', label: 'Moneda ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'Cotizacion', apiField: 'cotizacion', label: 'Cotización', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaCotizacion', apiField: 'fechaCotizacion', label: 'Fecha de cotización', type: 'date', allowRange: true, component: 'date' },
  ],
  parametrosGenerales: [
    { field: 'ParametroGeneralID', apiField: 'parametroGeneralID', label: 'Parámetro general ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'MonedaPrincipalID', apiField: 'monedaPrincipalID', label: 'Moneda principal ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'MonedaSecundariaID', apiField: 'monedaSecundariaID', label: 'Moneda secundaria ID', type: 'number', allowRange: false, component: 'number' },
  ],
  cuentasMl: [
    { field: 'CuentaMLID', apiField: 'cuentaMLID', label: 'Cuenta ML ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'UserIDML', apiField: 'userIDML', label: 'User ID ML', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activo', apiField: 'activo', label: 'Activo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
  ],
  productos: [
    { field: 'ProductoID', apiField: 'productoID', label: 'Producto ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'SKU', apiField: 'sku', label: 'SKU', type: 'text', allowRange: true, component: 'text' },
    { field: 'CategoriaID', apiField: 'categoriaID', label: 'Categoría ID', type: 'text', allowRange: true, component: 'text' },
    { field: 'Marca', apiField: 'marca', label: 'Marca', type: 'text', allowRange: true, component: 'text' },
    { field: 'Modelo', apiField: 'modelo', label: 'Modelo', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activo', apiField: 'activo', label: 'Activo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'FechaCreacion', apiField: 'fechaCreacion', label: 'Fecha de creación', type: 'date', allowRange: true, component: 'date' },
  ],
  costosProducto: [
    { field: 'CostoID', apiField: 'costoID', label: 'Costo ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'ProductoID', apiField: 'productoID', label: 'Producto ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'CostoCompra', apiField: 'costoCompra', label: 'Costo de compra', type: 'number', allowRange: true, component: 'number' },
    { field: 'PorcentajeIVA', apiField: 'porcentajeIVA', label: '% IVA', type: 'number', allowRange: true, component: 'number' },
    { field: 'ImpuestosInternos', apiField: 'impuestosInternos', label: 'Impuestos internos', type: 'number', allowRange: true, component: 'number' },
    { field: 'CostoEnvioPromedio', apiField: 'costoEnvioPromedio', label: 'Costo envío promedio', type: 'number', allowRange: true, component: 'number' },
    { field: 'CostoLogisticoFijo', apiField: 'costoLogisticoFijo', label: 'Costo logístico fijo', type: 'number', allowRange: true, component: 'number' },
    { field: 'CostoFinancieroPorc', apiField: 'costoFinancieroPorc', label: '% costo financiero', type: 'number', allowRange: true, component: 'number' },
    { field: 'CostoPublicidadPorc', apiField: 'costoPublicidadPorc', label: '% costo publicidad', type: 'number', allowRange: true, component: 'number' },
    { field: 'OtrosCostosFijos', apiField: 'otrosCostosFijos', label: 'Otros costos fijos', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaUltimaActualizacion', apiField: 'fechaUltimaActualizacion', label: 'Fecha última actualización', type: 'date', allowRange: true, component: 'date' },
  ],
  publicacionesMl: [
    { field: 'PublicacionID', apiField: 'publicacionID', label: 'Publicación ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'ProductoID', apiField: 'productoID', label: 'Producto ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'CuentaMLID', apiField: 'cuentaMLID', label: 'Cuenta ML ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'TipoPublicacion', apiField: 'tipoPublicacion', label: 'Tipo publicación', type: 'text', allowRange: true, component: 'text' },
    { field: 'ComisionMLPorc', apiField: 'comisionMLPorc', label: '% comisión ML', type: 'number', allowRange: true, component: 'number' },
    { field: 'Estado', apiField: 'estado', label: 'Estado', type: 'text', allowRange: true, component: 'text' },
    { field: 'EsCatalogo', apiField: 'esCatalogo', label: 'Es catálogo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'PrecioActual', apiField: 'precioActual', label: 'Precio actual', type: 'number', allowRange: true, component: 'number' },
    { field: 'PrecioMinimoPermitido', apiField: 'precioMinimoPermitido', label: 'Precio mínimo permitido', type: 'number', allowRange: true, component: 'number' },
    { field: 'PrecioMaximoPermitido', apiField: 'precioMaximoPermitido', label: 'Precio máximo permitido', type: 'number', allowRange: true, component: 'number' },
    { field: 'PrecioObjetivo', apiField: 'precioObjetivo', label: 'Precio objetivo', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaUltimoCambioPrecio', apiField: 'fechaUltimoCambioPrecio', label: 'Fecha último cambio de precio', type: 'date', allowRange: true, component: 'date' },
  ],
  stockEstado: [
    { field: 'StockID', apiField: 'stockID', label: 'Stock ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'ProductoID', apiField: 'productoID', label: 'Producto ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'StockActual', apiField: 'stockActual', label: 'Stock actual', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockReservado', apiField: 'stockReservado', label: 'Stock reservado', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockDisponible', apiField: 'stockDisponible', label: 'Stock disponible', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockMinimo', apiField: 'stockMinimo', label: 'Stock mínimo', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockMaximo', apiField: 'stockMaximo', label: 'Stock máximo', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockObjetivo', apiField: 'stockObjetivo', label: 'Stock objetivo', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaActualizacion', apiField: 'fechaActualizacion', label: 'Fecha actualización', type: 'date', allowRange: true, component: 'date' },
  ],
  metricasVentas: [
    { field: 'MetricaID', apiField: 'metricaID', label: 'Métrica ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'PublicacionID', apiField: 'publicacionID', label: 'Publicación ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'VentasHoy', apiField: 'ventasHoy', label: 'Ventas hoy', type: 'number', allowRange: true, component: 'number' },
    { field: 'Ventas7D', apiField: 'ventas7D', label: 'Ventas 7D', type: 'number', allowRange: true, component: 'number' },
    { field: 'Ventas15D', apiField: 'ventas15D', label: 'Ventas 15D', type: 'number', allowRange: true, component: 'number' },
    { field: 'Ventas30D', apiField: 'ventas30D', label: 'Ventas 30D', type: 'number', allowRange: true, component: 'number' },
    { field: 'Ventas60D', apiField: 'ventas60D', label: 'Ventas 60D', type: 'number', allowRange: true, component: 'number' },
    { field: 'Ventas90D', apiField: 'ventas90D', label: 'Ventas 90D', type: 'number', allowRange: true, component: 'number' },
    { field: 'VelocidadVentaDiaria', apiField: 'velocidadVentaDiaria', label: 'Velocidad venta diaria', type: 'number', allowRange: true, component: 'number' },
    { field: 'TendenciaPorc', apiField: 'tendenciaPorc', label: 'Tendencia %', type: 'number', allowRange: true, component: 'number' },
    { field: 'DiasStockDisponibles', apiField: 'diasStockDisponibles', label: 'Días stock disponibles', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaCalculo', apiField: 'fechaCalculo', label: 'Fecha cálculo', type: 'date', allowRange: true, component: 'date' },
  ],
  competencia: [
    { field: 'SnapshotID', apiField: 'snapshotID', label: 'Snapshot ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'PublicacionID', apiField: 'publicacionID', label: 'Publicación ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'CompetidorItemID', apiField: 'competidorItemID', label: 'Competidor item ID', type: 'text', allowRange: true, component: 'text' },
    { field: 'CompetidorVendedorID', apiField: 'competidorVendedorID', label: 'Competidor vendedor ID', type: 'text', allowRange: true, component: 'text' },
    { field: 'PrecioCompetidor', apiField: 'precioCompetidor', label: 'Precio competidor', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockCompetidor', apiField: 'stockCompetidor', label: 'Stock competidor', type: 'number', allowRange: true, component: 'number' },
    { field: 'TipoPublicacion', apiField: 'tipoPublicacion', label: 'Tipo publicación', type: 'text', allowRange: true, component: 'text' },
    { field: 'OfreceEnvioGratis', apiField: 'ofreceEnvioGratis', label: 'Ofrece envío gratis', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'EsCompetidorDirecto', apiField: 'esCompetidorDirecto', label: 'Es competidor directo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'NivelRelevancia', apiField: 'nivelRelevancia', label: 'Nivel relevancia', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaCaptura', apiField: 'fechaCaptura', label: 'Fecha captura', type: 'date', allowRange: true, component: 'date' },
  ],
  estrategias: [
    { field: 'EstrategiaID', apiField: 'estrategiaID', label: 'Estrategia ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'Descripcion', apiField: 'descripcion', label: 'Descripción', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activa', apiField: 'activa', label: 'Activa', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
  ],
  reglas: [
    { field: 'ReglaID', apiField: 'reglaID', label: 'Regla ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'CodigoRegla', apiField: 'codigoRegla', label: 'Código regla', type: 'text', allowRange: true, component: 'text' },
    { field: 'TipoRegla', apiField: 'tipoRegla', label: 'Tipo regla', type: 'text', allowRange: true, component: 'text' },
    { field: 'Descripcion', apiField: 'descripcion', label: 'Descripción', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activa', apiField: 'activa', label: 'Activa', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
  ],
  estrategiaReglas: [
    { field: 'EstrategiaReglaID', apiField: 'estrategiaReglaID', label: 'Estrategia regla ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'EstrategiaID', apiField: 'estrategiaID', label: 'Estrategia ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'ReglaID', apiField: 'reglaID', label: 'Regla ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'Prioridad', apiField: 'prioridad', label: 'Prioridad', type: 'number', allowRange: true, component: 'number' },
    { field: 'ParametrosJSON', apiField: 'parametrosJSON', label: 'Parámetros JSON', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activa', apiField: 'activa', label: 'Activa', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
  ],
  estrategiasReglasParametros: [
    { field: 'ParametroID', apiField: 'parametroID', label: 'Parámetro ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'EstrategiaReglaID', apiField: 'estrategiaReglaID', label: 'Estrategia-Regla ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'Clave', apiField: 'clave', label: 'Clave', type: 'text', allowRange: true, component: 'text' },
    { field: 'Valor', apiField: 'valor', label: 'Valor', type: 'number', allowRange: true, component: 'number' },
    { field: 'Descripcion', apiField: 'descripcion', label: 'Descripción', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activo', apiField: 'activo', label: 'Activo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'FechaVigencia', apiField: 'fechaVigencia', label: 'Fecha vigencia', type: 'date', allowRange: true, component: 'date' },
    { field: 'FechaFin', apiField: 'fechaFin', label: 'Fecha fin', type: 'date', allowRange: true, component: 'date' },
    { field: 'FechaCreacion', apiField: 'fechaCreacion', label: 'Fecha creación', type: 'date', allowRange: true, component: 'date' },
  ],
  estrategiasReglasParametrosMensajes: [
    { field: 'MensajeID', apiField: 'mensajeID', label: 'Mensaje ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'EstrategiaReglaID', apiField: 'estrategiaReglaID', label: 'Estrategia-Regla ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'Clave', apiField: 'clave', label: 'Clave', type: 'text', allowRange: true, component: 'text' },
    { field: 'Idioma', apiField: 'idioma', label: 'Idioma', type: 'text', allowRange: true, component: 'text' },
    { field: 'Valor', apiField: 'valor', label: 'Valor', type: 'text', allowRange: true, component: 'text' },
    { field: 'Descripcion', apiField: 'descripcion', label: 'Descripción', type: 'text', allowRange: true, component: 'text' },
    { field: 'Activo', apiField: 'activo', label: 'Activo', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'FechaVigencia', apiField: 'fechaVigencia', label: 'Fecha vigencia', type: 'date', allowRange: true, component: 'date' },
    { field: 'FechaFin', apiField: 'fechaFin', label: 'Fecha fin', type: 'date', allowRange: true, component: 'date' },
    { field: 'FechaCreacion', apiField: 'fechaCreacion', label: 'Fecha creación', type: 'date', allowRange: true, component: 'date' },
  ],
  configuracionParametros: [
    { field: 'ParametroID', apiField: 'parametroID', label: 'Parámetro ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'ClaveParametro', apiField: 'claveParametro', label: 'Clave parámetro', type: 'text', allowRange: true, component: 'text' },
    { field: 'ValorParametro', apiField: 'valorParametro', label: 'Valor parámetro', type: 'text', allowRange: true, component: 'text' },
    { field: 'Descripcion', apiField: 'descripcion', label: 'Descripción', type: 'text', allowRange: true, component: 'text' },
  ],
  decisiones: [
    { field: 'DecisionID', apiField: 'decisionID', label: 'Decision ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'EmpresaID', apiField: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'PublicacionID', apiField: 'publicacionID', label: 'Publicación ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'EstrategiaID', apiField: 'estrategiaID', label: 'Estrategia ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'PrecioAnterior', apiField: 'precioAnterior', label: 'Precio anterior', type: 'number', allowRange: true, component: 'number' },
    { field: 'PrecioCalculado', apiField: 'precioCalculado', label: 'Precio calculado', type: 'number', allowRange: true, component: 'number' },
    { field: 'PrecioSugerido', apiField: 'precioSugerido', label: 'Precio sugerido', type: 'number', allowRange: true, component: 'number' },
    { field: 'Accion', apiField: 'accion', label: 'Acción', type: 'text', allowRange: true, component: 'text' },
    { field: 'Motivo', apiField: 'motivo', label: 'Motivo', type: 'text', allowRange: true, component: 'text' },
    { field: 'ReglaGanadoraID', apiField: 'reglaGanadoraID', label: 'Regla ganadora ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'PrioridadAplicada', apiField: 'prioridadAplicada', label: 'Prioridad aplicada', type: 'number', allowRange: true, component: 'number' },
    { field: 'MargenActualPorc', apiField: 'margenActualPorc', label: '% margen actual', type: 'number', allowRange: true, component: 'number' },
    { field: 'MargenProyectadoPorc', apiField: 'margenProyectadoPorc', label: '% margen proyectado', type: 'number', allowRange: true, component: 'number' },
    { field: 'PosicionCompetitiva', apiField: 'posicionCompetitiva', label: 'Posición competitiva', type: 'number', allowRange: true, component: 'number' },
    { field: 'PrecioCompetenciaRef', apiField: 'precioCompetenciaRef', label: 'Precio competencia de referencia', type: 'number', allowRange: true, component: 'number' },
    { field: 'StockDisponible', apiField: 'stockDisponible', label: 'Stock disponible', type: 'number', allowRange: true, component: 'number' },
    { field: 'ClasificacionStock', apiField: 'clasificacionStock', label: 'Clasificación stock', type: 'text', allowRange: true, component: 'text' },
    { field: 'ScoreConfianza', apiField: 'scoreConfianza', label: 'Score confianza', type: 'number', allowRange: true, component: 'number' },
    { field: 'EsSimulacion', apiField: 'esSimulacion', label: 'Es simulación', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'FechaDecision', apiField: 'fechaDecision', label: 'Fecha decisión', type: 'date', allowRange: true, component: 'date' },
  ],
  decisionesDetalle: [
    { field: 'AuditoriaID', apiField: 'auditoriaID', label: 'Auditoría ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'DecisionID', apiField: 'decisionID', label: 'Decision ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'ReglaID', apiField: 'reglaID', label: 'Regla ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'Prioridad', apiField: 'prioridad', label: 'Prioridad', type: 'number', allowRange: true, component: 'number' },
    { field: 'EvaluacionResultado', apiField: 'evaluacionResultado', label: 'Evaluación resultado', type: 'text', allowRange: true, component: 'text' },
    { field: 'ValorPrecioPropuesto', apiField: 'valorPrecioPropuesto', label: 'Valor precio propuesto', type: 'number', allowRange: true, component: 'number' },
    { field: 'DetalleJSON', apiField: 'detalleJSON', label: 'Detalle JSON', type: 'text', allowRange: true, component: 'text' },
  ],
  colaEjecucion: [
    { field: 'ColaID', apiField: 'colaID', label: 'Cola ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'PublicacionID', apiField: 'publicacionID', label: 'Publicación ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'MeliItemID', apiField: 'meliItemID', label: 'Meli item ID', type: 'text', allowRange: true, component: 'text' },
    { field: 'PrecioNuevo', apiField: 'precioNuevo', label: 'Precio nuevo', type: 'number', allowRange: true, component: 'number' },
    { field: 'AccionRequerida', apiField: 'accionRequerida', label: 'Acción requerida', type: 'text', allowRange: true, component: 'text' },
    { field: 'EstadoEjecucion', apiField: 'estadoEjecucion', label: 'Estado ejecución', type: 'text', allowRange: true, component: 'text' },
    { field: 'MensajeError', apiField: 'mensajeError', label: 'Mensaje error', type: 'text', allowRange: true, component: 'text' },
    { field: 'FechaCreacion', apiField: 'fechaCreacion', label: 'Fecha creación', type: 'date', allowRange: true, component: 'date' },
    { field: 'FechaProcesado', apiField: 'fechaProcesado', label: 'Fecha procesado', type: 'date', allowRange: true, component: 'date' },
  ],
  // #historialSincronizacionMl: tabla madre (una fila por corrida de "Sincronizar ML",
  // solo la parte de Publicaciones) -- ver PersistirHistorialSincronizacionAsync en
  // MercadoLibreSyncService.cs.
  sincronizacionesMl: [
    { field: 'SincronizacionMLID', apiField: 'sincronizacionMLID', label: 'Sincronización ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'FechaEjecucion', apiField: 'fechaEjecucion', label: 'Fecha ejecución', type: 'date', allowRange: true, component: 'date' },
    { field: 'TotalProcesados', apiField: 'totalProcesados', label: 'Total procesados', type: 'number', allowRange: true, component: 'number' },
    { field: 'TotalErrores', apiField: 'totalErrores', label: 'Total errores', type: 'number', allowRange: true, component: 'number' },
    { field: 'ConCompetenciaActualizada', apiField: 'conCompetenciaActualizada', label: 'Con competencia actualizada', type: 'number', allowRange: true, component: 'number' },
  ],
  // #historialSincronizacionMl: tabla hija -- una fila por publicación de esa corrida,
  // filtrable por Sincronización ID para ver el detalle de una corrida puntual.
  sincronizacionesMlDetalle: [
    { field: 'SincronizacionMLDetalleID', apiField: 'sincronizacionMLDetalleID', label: 'Detalle ID', type: 'number', allowRange: true, component: 'number' },
    { field: 'SincronizacionMLID', apiField: 'sincronizacionMLID', label: 'Sincronización ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'PublicacionID', apiField: 'publicacionID', label: 'Publicación ID', type: 'number', allowRange: false, component: 'number' },
    { field: 'MeliItemID', apiField: 'meliItemID', label: 'Meli item ID', type: 'text', allowRange: true, component: 'text' },
    { field: 'Ok', apiField: 'ok', label: 'OK', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
    { field: 'Error', apiField: 'error', label: 'Error', type: 'text', allowRange: true, component: 'text' },
    { field: 'CompetenciaActualizada', apiField: 'competenciaActualizada', label: 'Competencia actualizada', type: 'boolean', allowRange: false, component: 'select', options: booleanSelectOptions },
  ],
}

export const REPORT_FIELD_DEFINITIONS = REPORT_TABLE_DEFINITIONS.empresas

export const getReportFieldDefinition = (fieldName, definitions = REPORT_FIELD_DEFINITIONS) => {
  const normalizedFieldName = String(fieldName ?? '')
  return definitions.find((definition) => definition.field === normalizedFieldName || definition.apiField === normalizedFieldName) || {
    field: normalizedFieldName,
    apiField: normalizedFieldName,
    label: normalizedFieldName,
    type: 'text',
    allowRange: true,
    component: 'text',
  }
}

const parseNumber = (value) => {
  if (value === null || value === undefined || value === '') return null
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const parseDateInput = (value) => {
  if (!value) return null
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return null
  return date
}

const toISODate = (value, endOfDay = false) => {
  const date = parseDateInput(value)
  if (!date) return null
  if (endOfDay) {
    date.setUTCHours(23, 59, 59, 999)
  } else {
    date.setUTCHours(0, 0, 0, 0)
  }
  return new Date(date).toISOString()
}

export const validateReportFilters = (filters) => {
  for (const filter of filters) {
    const { field, type, rangeEnabled, from, to } = filter

    if (rangeEnabled) {
      const fromValue = from?.trim?.() ?? ''
      const toValue = to?.trim?.() ?? ''

      if (!!fromValue && !!toValue) {
        const fromParsed = type === 'date' ? parseDateInput(fromValue) : parseNumber(fromValue)
        const toParsed = type === 'date' ? parseDateInput(toValue) : parseNumber(toValue)

        if (fromParsed === null || toParsed === null) {
          return `${filter.label || field}: valores de rango inválidos.`
        }

        if (fromParsed > toParsed) {
          return `${filter.label || field}: Desde no puede ser mayor que Hasta.`
        }
      }

      if (type === 'date') {
        if (fromValue && parseDateInput(fromValue) === null) return `${filter.label || field}: La fecha de inicio no es válida.`
        if (toValue && parseDateInput(toValue) === null) return `${filter.label || field}: La fecha final no es válida.`
      }

      if (type === 'number') {
        if (fromValue && parseNumber(fromValue) === null) return `${filter.label || field}: El valor de Desde debe ser numérico.`
        if (toValue && parseNumber(toValue) === null) return `${filter.label || field}: El valor de Hasta debe ser numérico.`
      }
    } else if (type === 'number' && filter.value && parseNumber(filter.value) === null) {
      return `${filter.label || field}: El valor ingresado no es un número válido.`
    }

    if (type === 'date' && !rangeEnabled && filter.value && parseDateInput(filter.value) === null) {
      return `${filter.label || field}: La fecha ingresada no es válida.`
    }
  }

  return ''
}

const buildValueForFilter = (filter) => {
  const value = filter.value?.trim?.() ?? ''
  const from = filter.from?.trim?.() ?? ''
  const to = filter.to?.trim?.() ?? ''

  if (filter.type === 'date') {
    if (filter.rangeEnabled) {
      const conditions = []
      if (from) conditions.push({ operator: 'gte', value: toISODate(from, false) })
      if (to) conditions.push({ operator: 'lte', value: toISODate(to, true) })
      return conditions
    }
    return value ? [{ operator: 'eq', value: toISODate(value, true) }] : []
  }

  if (filter.type === 'boolean') {
    const selected = String(value ?? '').trim()
    if (!selected || selected === 'all' || selected === '') return []
    return [{ operator: 'eq', value: selected === 'true' }]
  }

  if (filter.type === 'number') {
    if (filter.rangeEnabled) {
      const conditions = []
      if (from) conditions.push({ operator: 'gte', value: Number(from) })
      if (to) conditions.push({ operator: 'lte', value: Number(to) })
      return conditions
    }

    if (value === '') return []
    return [{ operator: 'eq', value: Number(value) }]
  }

  if (filter.rangeEnabled) {
    const conditions = []
    if (from) conditions.push({ operator: 'gte', value: from.trim() })
    if (to) conditions.push({ operator: 'lte', value: to.trim() })
    return conditions
  }

  if (!value) return []
  return [{ operator: 'contains', value }]
}

export const buildFilterQueryParams = (filters = []) => {
  if (!Array.isArray(filters)) return []

  const params = []
  for (const filter of filters) {
    const normalized = {
      ...filter,
      field: String(filter.field ?? '').trim(),
      apiField: String(filter.apiField ?? filter.field ?? '').trim(),
      label: filter.label ?? filter.field ?? '',
      type: filter.type ?? 'text',
      rangeEnabled: Boolean(filter.rangeEnabled),
      value: filter.value ?? '',
      from: filter.from ?? '',
      to: filter.to ?? '',
    }

    const requestField = normalized.apiField || normalized.field

    if (!requestField) continue
    if (normalized.type === 'boolean' && !normalized.rangeEnabled) {
      const selected = String(normalized.value ?? '').trim()
      if (selected && selected !== 'all' && selected !== '') {
        params.push({ field: requestField, operator: 'eq', value: selected === 'true' })
      }
      continue
    }

    const conditions = buildValueForFilter(normalized)
    conditions.forEach((condition) => {
      params.push({ field: requestField, operator: condition.operator, value: condition.value })
    })
  }

  return params
}

export const normalizeFiltersForReport = (filters = [], reportDefinition = []) => {
  return filters.map((filter) => {
    const definition = getReportFieldDefinition(filter.field, reportDefinition)
    return {
      ...filter,
      field: filter.field ?? definition.field,
      apiField: filter.apiField ?? definition.apiField ?? (filter.field ?? definition.field),
      label: filter.label || definition.label || filter.field || definition.field,
      type: filter.type || definition.type || 'text',
      allowRange: filter.allowRange ?? definition.allowRange ?? true,
      component: filter.component || definition.component || 'text',
      rangeEnabled: Boolean(filter.rangeEnabled),
      value: filter.value ?? '',
      from: filter.from ?? '',
      to: filter.to ?? '',
    }
  })
}
