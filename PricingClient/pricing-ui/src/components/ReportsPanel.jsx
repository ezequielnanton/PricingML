import { useEffect, useMemo, useState } from 'react'
import { useLocation } from 'react-router-dom'
import ReportFilterField from './ReportFilterField'
import AbmColumnResizeHandle from './AbmColumnResizeHandle'
import { useRegisterToolbar } from '../context/ToolbarContext'
import { buildFilterQueryParams, normalizeFiltersForReport, REPORT_TABLE_DEFINITIONS, validateReportFilters } from '../utils/reportFilters'

import { API_BASE_URL } from '../utils/apiBase'
const PAGE_SIZE = 50
const metadata = REPORT_TABLE_DEFINITIONS
const EMPTY_FIELDS = []
const standardReports = [
  ['empresas', 'Empresas', 'empresas'], ['monedas', 'Monedas', 'monedas'], ['cuentasMl', 'Cuentas ML', 'cuentas-ml'], ['estrategias', 'Estrategias', 'estrategias'], ['reglas', 'Reglas', 'reglas'], ['estrategiaReglas', 'Estrategia-Reglas', 'estrategia-reglas'], ['productos', 'Productos', 'productos'], ['publicacionesMl', 'Publicaciones ML', 'publicaciones-ml'], ['parametrosGenerales', 'Parámetros', 'parametros-generales'], ['configuracionParametros', 'Config. parámetros', 'configuracion-parametros'], ['decisiones', 'Decisiones', 'decisiones'], ['sincronizacionesMl', 'Sincronizaciones ML', 'sincronizaciones-ml'],
].map(([id, label, resource]) => ({ id, label, endpoint: `/api/admin/${resource}` }))
// #reporteMaestroDetalle: en vez de pestañas de Reportes separadas (madre e hija) que
// obligan a copiar a mano el ID de la madre en un filtro de la hija, la madre y sus hijas
// viven en la misma pantalla -- clickear una fila de la grilla de arriba refresca las
// grillas de detalle de abajo, filtradas por esa fila puntual. Una madre puede tener más de
// una hija (ver publicacionesMl): cada una es su propia grilla independiente, todas
// refrescadas por el mismo click.
const MASTER_DETAIL_REPORTS = {
  sincronizacionesMl: {
    masterIdField: 'sincronizacionMLID',
    details: [
      { id: 'sincronizacionesMlDetalle', detailEndpoint: '/api/admin/sincronizaciones-ml-detalle', detailFilterField: 'sincronizacionMLID', detailLabel: 'Detalle de la sincronización', detailWaitingMessage: 'Elegí una fila de arriba para ver el detalle de esa sincronización.' },
    ],
  },
  decisiones: {
    masterIdField: 'decisionID',
    details: [
      { id: 'decisionesDetalle', detailEndpoint: '/api/admin/decisiones-detalle-auditoria', detailFilterField: 'decisionID', detailLabel: 'Detalle de auditoría', detailWaitingMessage: 'Elegí una fila de arriba para ver el detalle de auditoría de esa decisión.' },
    ],
  },
  publicacionesMl: {
    masterIdField: 'publicacionID',
    details: [
      { id: 'competencia', detailEndpoint: '/api/admin/competencia-snapshot', detailFilterField: 'publicacionID', detailLabel: 'Competencia', detailWaitingMessage: 'Elegí una publicación de arriba para ver su competencia.' },
      { id: 'metricasVentas', detailEndpoint: '/api/admin/metricas-ventas-hist', detailFilterField: 'publicacionID', detailLabel: 'Métricas ventas', detailWaitingMessage: 'Elegí una publicación de arriba para ver sus métricas de venta.' },
      { id: 'colaEjecucion', detailEndpoint: '/api/admin/cola-ejecucion-ml', detailFilterField: 'publicacionID', detailLabel: 'Cola ejecución ML', detailWaitingMessage: 'Elegí una publicación de arriba para ver su cola de ejecución.' },
    ],
  },
  productos: {
    masterIdField: 'productoID',
    details: [
      { id: 'costosProducto', detailEndpoint: '/api/admin/costos-producto', detailFilterField: 'productoID', detailLabel: 'Costos Producto', detailWaitingMessage: 'Elegí un producto de arriba para ver su historial de costos.' },
      { id: 'stockEstado', detailEndpoint: '/api/admin/stock-estado', detailFilterField: 'productoID', detailLabel: 'Stock', detailWaitingMessage: 'Elegí un producto de arriba para ver su estado de stock.' },
    ],
  },
  monedas: {
    masterIdField: 'monedaID',
    details: [
      { id: 'cotizaciones', detailEndpoint: '/api/admin/cotizaciones', detailFilterField: 'monedaID', detailLabel: 'Cotizaciones', detailWaitingMessage: 'Elegí una moneda de arriba para ver su historial de cotización.' },
    ],
  },
  // #historialPorReporte: Parámetros/Mensajes de Regla pasaron a Activo/Inactivo simple
  // (ya no versionado por fecha, ver Migrar-ParametrosMensajesReglaActivoSimple.sql) -- el
  // historial de valores pasados (filas ya inactivas, nunca se borran) se ve acá, filtrando
  // por la Estrategia-Regla elegida arriba, con el mismo mecanismo genérico `?filter[campo]
  // [eq]=` que Producto → Costos/Stock (ya no hace falta el endpoint con ID por path que
  // tenían los Controllers viejos).
  estrategiaReglas: {
    masterIdField: 'estrategiaReglaID',
    details: [
      { id: 'parametrosRegla', detailEndpoint: '/api/admin/estrategias-reglas-parametros', detailFilterField: 'estrategiaReglaID', detailLabel: 'Parámetros de Regla', detailWaitingMessage: 'Elegí una estrategia-regla de arriba para ver sus parámetros (activos e inactivos).' },
      { id: 'mensajesRegla', detailEndpoint: '/api/admin/estrategias-reglas-parametros-mensajes', detailFilterField: 'estrategiaReglaID', detailLabel: 'Mensajes de Regla', detailWaitingMessage: 'Elegí una estrategia-regla de arriba para ver sus mensajes (activos e inactivos).' },
    ],
  },
}
const DEFAULT_DETAIL_STATE = { data: [], loading: false, error: '', page: 1, totalCount: 0, sortField: '', sortDir: 'asc' }
const isPathParamDetail = (detailConfig) => detailConfig.detailEndpoint.includes('{id}')
const reports = standardReports

// #pestañaFijaPorReporte: fixedReport ancla esta instancia a UN reporte cuando vive en su
// propia pestaña de la app (ver #pestañaFijaPorEntidad en AdminPanel.jsx, mismo patrón) --
// ignora el hash, que ahora describe la pestaña activa, no necesariamente esta instancia.
function ReportsPanel({ fixedReport = null, isActiveTab = true }) {
  const location = useLocation()
  const [activeReport, setActiveReport] = useState(fixedReport || 'empresas')
  const [data, setData] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [page, setPage] = useState(1)
  const [totalCount, setTotalCount] = useState(0)
  const [sortField, setSortField] = useState('')
  const [sortDir, setSortDir] = useState('asc')
  const [filters, setFilters] = useState([])
  const [filtersCollapsed, setFiltersCollapsed] = useState(false)
  const currentReport = reports.find((report) => report.id === activeReport)
  const currentEndpoint = currentReport?.endpoint
  const reportFields = metadata[activeReport] ?? EMPTY_FIELDS
  const activeFilters = useMemo(() => normalizeFiltersForReport(filters, reportFields), [filters, reportFields])
  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE))

  // #reporteMaestroDetalle: una fila de estado por hija (`detailStates`, por `detail.id`) --
  // cada una pagina/ordena/carga en forma independiente. Solo consultan cuando hay una fila
  // madre seleccionada; su único filtro es el ID de esa fila, fijo, sin panel propio.
  const masterDetailConfig = MASTER_DETAIL_REPORTS[activeReport]
  const [selectedMasterId, setSelectedMasterId] = useState(null)
  const [detailStates, setDetailStates] = useState({})

  const updateDetailState = (detailId, changes) => {
    setDetailStates((prev) => ({ ...prev, [detailId]: { ...(prev[detailId] ?? DEFAULT_DETAIL_STATE), ...changes } }))
  }

  const resetReport = (reportId) => {
    setFilters((metadata[reportId] ?? []).map((field) => ({ ...field, value: '', from: '', to: '', rangeEnabled: false })))
    setPage(1); setSortField(''); setSortDir('asc'); setError(''); setData([]); setTotalCount(0)
    setSelectedMasterId(null); setDetailStates({})
  }

  const loadReport = async (filterState = activeFilters, targetPage = page, sortState = { field: sortField, dir: sortDir }) => {
    if (!currentEndpoint) return
    setLoading(true)
    try {
      const params = new URLSearchParams({ page: String(targetPage), pageSize: String(PAGE_SIZE) })
      if (sortState.field) params.set('sort', `${sortState.field}:${sortState.dir}`)
      buildFilterQueryParams(filterState).forEach(({ field, operator, value }) => params.set(`filter[${field}][${operator}]`, String(value)))
      const response = await fetch(`${API_BASE_URL}${currentEndpoint}?${params}`)
      const result = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(result.message || `HTTP ${response.status}: ${response.statusText}`)
      const items = Array.isArray(result) ? result : result.items
      if (!Array.isArray(items)) throw new Error('La respuesta debe contener un arreglo items.')
      setData(items); setTotalCount(Array.isArray(result) ? items.length : Number(result.totalCount ?? items.length))
    } catch (requestError) { setError(`Error al cargar datos: ${requestError.message}`); setData([]); setTotalCount(0) } finally { setLoading(false) }
  }

  const runFilters = () => {
    const validationError = validateReportFilters(activeFilters)
    if (validationError) return setError(validationError)
    setError(''); setPage(1); loadReport(activeFilters, 1)
  }

  const loadDetail = async (detailConfig, masterId, targetPage = 1, sortState = { field: '', dir: 'asc' }) => {
    if (masterId == null) return
    updateDetailState(detailConfig.id, { loading: true })
    const pathParam = isPathParamDetail(detailConfig)
    try {
      const url = pathParam
        ? `${API_BASE_URL}${detailConfig.detailEndpoint.replace('{id}', encodeURIComponent(masterId))}`
        : (() => {
            const params = new URLSearchParams({ page: String(targetPage), pageSize: String(PAGE_SIZE) })
            if (sortState.field) params.set('sort', `${sortState.field}:${sortState.dir}`)
            params.set(`filter[${detailConfig.detailFilterField}][eq]`, String(masterId))
            return `${API_BASE_URL}${detailConfig.detailEndpoint}?${params}`
          })()
      const response = await fetch(url)
      // Los endpoints "vigentes" devuelven 404 (no 200 + arreglo vacío) cuando no hay
      // filas -- se trata como "sin datos todavía", no como un error real.
      if (pathParam && response.status === 404) {
        updateDetailState(detailConfig.id, { data: [], totalCount: 0, page: 1, sortField: sortState.field, sortDir: sortState.dir, error: '', loading: false })
        return
      }
      const result = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(result.message || `HTTP ${response.status}: ${response.statusText}`)
      let items = Array.isArray(result) ? result : result.items
      if (!Array.isArray(items)) throw new Error('La respuesta debe contener un arreglo items.')
      if (pathParam && sortState.field) {
        items = [...items].sort((a, b) => {
          const left = a[sortState.field]; const right = b[sortState.field]
          if (left === right) return 0
          return (left > right ? 1 : -1) * (sortState.dir === 'asc' ? 1 : -1)
        })
      }
      updateDetailState(detailConfig.id, { data: items, totalCount: pathParam ? items.length : (Array.isArray(result) ? items.length : Number(result.totalCount ?? items.length)), page: pathParam ? 1 : targetPage, sortField: sortState.field, sortDir: sortState.dir, error: '', loading: false })
    } catch (requestError) {
      updateDetailState(detailConfig.id, { error: `Error al cargar datos: ${requestError.message}`, data: [], totalCount: 0, loading: false })
    }
  }

  const selectMasterRow = (row) => {
    if (!masterDetailConfig) return
    const masterId = row[masterDetailConfig.masterIdField]
    setSelectedMasterId(masterId)
    masterDetailConfig.details.forEach((detailConfig) => loadDetail(detailConfig, masterId, 1, { field: '', dir: 'asc' }))
  }

  const handleDetailSort = (detailConfig, header) => {
    const current = detailStates[detailConfig.id] ?? DEFAULT_DETAIL_STATE
    const nextDir = current.sortField === header && current.sortDir === 'asc' ? 'desc' : 'asc'
    loadDetail(detailConfig, selectedMasterId, 1, { field: header, dir: nextDir })
  }

  useEffect(() => {
    if (fixedReport) return
    const id = (location.hash || '#empresas').slice(1)
    if (reports.some((report) => report.id === id)) setActiveReport(id)
  }, [location.hash, fixedReport])
  useEffect(() => { resetReport(activeReport) }, [activeReport])

  const updateFilter = (name, changes) => { setFilters((items) => items.map((item) => item.field === name ? { ...item, ...changes } : item)); setPage(1) }
  const headers = [...new Set(data.flatMap((row) => Object.keys(row)))]

  const handleSort = (header) => {
    const nextDir = sortField === header && sortDir === 'asc' ? 'desc' : 'asc'
    setSortField(header); setSortDir(nextDir); setPage(1)
    loadReport(activeFilters, 1, { field: header, dir: nextDir })
  }

  // #barraDePantalla: reemplaza la flecha de colapsar filtros -- ver ScreenToolbar.jsx /
  // ToolbarContext.jsx. Reportes no tiene "Nuevo registro" ni "Guardar".
  useRegisterToolbar({
    toggleFilters: { onClick: () => setFiltersCollapsed((current) => !current), active: !filtersCollapsed },
  }, [filtersCollapsed], isActiveTab)

  return <div className={filtersCollapsed ? 'reports-layout collapsed-search' : 'reports-layout'}>
    <div className="abm-list-column">
      <div className="side-column-body">
        <div className="panel abm-list">
          <h4>Filtros</h4>
          <div className="abm-list-search">
            <div className="report-filters-grid">
              {activeFilters.map((filter) => <ReportFilterField key={filter.field} filter={filter} onChange={(changes) => updateFilter(filter.field, changes)} onClear={() => updateFilter(filter.field, { value: '', from: '', to: '', rangeEnabled: false })} />)}
            </div>
            <div className="abm-list-search-actions">
              <button type="button" className="ghost-button small-button" onClick={runFilters} disabled={loading}>Buscar</button>
              <button type="button" className="ghost-button small-button" onClick={() => resetReport(activeReport)}>Limpiar</button>
            </div>
          </div>
        </div>
      </div>
      <AbmColumnResizeHandle />
    </div>
    <div className="reports-content"><div className="panel report-panel"><div className="report-header"><div><h3>{currentReport?.label}</h3><small className="endpoint-label">GET {currentEndpoint}</small></div><span className="record-count">{totalCount} registros</span></div>
      {error && <div className="alert error">{error}</div>}{loading ? <div className="loading-state">Cargando datos...</div> : data.length === 0 ? <div className="empty-state">No hay datos para mostrar</div> : <div className="table-container"><table className="data-table"><thead><tr>{headers.map((header) => <th key={header} className="sortable-th" onClick={() => handleSort(header)}>{header}<span className="sort-indicator">{sortField === header ? (sortDir === 'asc' ? ' ▲' : ' ▼') : ''}</span></th>)}</tr></thead><tbody>{data.map((row, rowIndex) => { const masterId = masterDetailConfig ? row[masterDetailConfig.masterIdField] : null; return <tr key={rowIndex} className={masterDetailConfig ? (masterId === selectedMasterId ? 'report-row-selectable selected' : 'report-row-selectable') : undefined} onClick={masterDetailConfig ? () => selectMasterRow(row) : undefined}>{headers.map((header) => { const raw = row[header]; const value = raw !== null && typeof raw === 'object' ? JSON.stringify(raw) : String(raw ?? ''); return <td key={`${rowIndex}-${header}`} title={value}>{value.length > 80 ? `${value.slice(0, 80)}...` : value}</td> })}</tr> })}</tbody></table></div>}
      <div className="report-pagination"><button type="button" className="ghost-button" disabled={loading || page === 1} onClick={() => { const next = page - 1; setPage(next); loadReport(activeFilters, next) }}>Anterior</button><span>Página {page} de {totalPages}</span><button type="button" className="ghost-button" disabled={loading || page >= totalPages} onClick={() => { const next = page + 1; setPage(next); loadReport(activeFilters, next) }}>Siguiente</button></div>
    </div>
    {masterDetailConfig?.details.map((detailConfig) => {
      const detailState = detailStates[detailConfig.id] ?? DEFAULT_DETAIL_STATE
      const detailHeaders = [...new Set(detailState.data.flatMap((row) => Object.keys(row)))]
      const detailTotalPages = Math.max(1, Math.ceil(detailState.totalCount / PAGE_SIZE))
      const pathParam = isPathParamDetail(detailConfig)
      const detailEndpointDisplay = pathParam && selectedMasterId != null ? detailConfig.detailEndpoint.replace('{id}', selectedMasterId) : detailConfig.detailEndpoint
      return <div className="panel report-panel report-panel-detail" key={detailConfig.id}>
        <div className="report-header"><div><h3>{detailConfig.detailLabel}</h3><small className="endpoint-label">GET {detailEndpointDisplay}</small></div><span className="record-count">{detailState.totalCount} registros</span></div>
        {detailState.error && <div className="alert error">{detailState.error}</div>}
        {selectedMasterId == null ? <div className="empty-state">{detailConfig.detailWaitingMessage}</div> :
          detailState.loading ? <div className="loading-state">Cargando datos...</div> :
          detailState.data.length === 0 ? <div className="empty-state">No hay datos para mostrar</div> :
          <div className="table-container"><table className="data-table"><thead><tr>{detailHeaders.map((header) => <th key={header} className="sortable-th" onClick={() => handleDetailSort(detailConfig, header)}>{header}<span className="sort-indicator">{detailState.sortField === header ? (detailState.sortDir === 'asc' ? ' ▲' : ' ▼') : ''}</span></th>)}</tr></thead><tbody>{detailState.data.map((row, rowIndex) => <tr key={rowIndex}>{detailHeaders.map((header) => { const raw = row[header]; const value = raw !== null && typeof raw === 'object' ? JSON.stringify(raw) : String(raw ?? ''); return <td key={`${rowIndex}-${header}`} title={value}>{value.length > 80 ? `${value.slice(0, 80)}...` : value}</td> })}</tr>)}</tbody></table></div>}
        {!pathParam && selectedMasterId != null && detailState.data.length > 0 && <div className="report-pagination"><button type="button" className="ghost-button" disabled={detailState.loading || detailState.page === 1} onClick={() => loadDetail(detailConfig, selectedMasterId, detailState.page - 1, { field: detailState.sortField, dir: detailState.sortDir })}>Anterior</button><span>Página {detailState.page} de {detailTotalPages}</span><button type="button" className="ghost-button" disabled={detailState.loading || detailState.page >= detailTotalPages} onClick={() => loadDetail(detailConfig, selectedMasterId, detailState.page + 1, { field: detailState.sortField, dir: detailState.sortDir })}>Siguiente</button></div>}
      </div>
    })}
    </div>
  </div>
}

export default ReportsPanel
