import { useEffect, useRef, useState } from 'react'
import { REPORT_TABLE_DEFINITIONS } from '../utils/reportFilters'
import { getRecordValue, toApiField } from '../utils/adminHelpers'
import { getFkLookup } from '../utils/fkLookups'
import FkAutocompleteInput from './FkAutocompleteInput'
import SearchSuggestInput from './SearchSuggestInput'

import { API_BASE_URL } from '../utils/apiBase'
const PAGE_SIZE = 8

// #tipoDeBusqueda: texto/CUIT usa coincidencia parcial, número/fecha usa coincidencia exacta,
// igual que ya está definido para los Reportes (ver CONTEXT.md).
const getSearchFieldType = (reportKey, fieldName) => {
  if (/fecha|date/i.test(fieldName)) return 'date'
  const definitions = REPORT_TABLE_DEFINITIONS[reportKey] || []
  const definition = definitions.find((entry) => entry.field === fieldName)
  if (!definition) return 'text'
  return definition.type === 'boolean' ? 'text' : definition.type
}

function AbmRecordList({ entity, config, selectedId, onSelect, refreshToken }) {
  const [searchValues, setSearchValues] = useState({})
  const [appliedSearch, setAppliedSearch] = useState({})
  const [page, setPage] = useState(1)
  const [items, setItems] = useState([])
  const [totalCount, setTotalCount] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [fkLabels, setFkLabels] = useState({})

  // #divisorArrastrable: reparto Filtros/Registros arrancando 50/50 (ver App.css
  // #mitadYmitad), pero ajustable a mano arrastrando la línea divisoria -- mismo patrón que
  // .sidebar-resize-handle en App.jsx (mousedown en la manija, mousemove/mouseup en el
  // document para no perder el arrastre si el mouse se sale de la manija angosta). El
  // porcentaje se mide contra el alto real del contenedor (columnRef), no contra la ventana,
  // así funciona igual sin importar cuánto mida la franja en cada pantalla.
  const [filtrosRatio, setFiltrosRatio] = useState(0.5)
  const columnRef = useRef(null)
  const dividerRef = useRef(null)

  useEffect(() => {
    if (!dividerRef.current) return undefined
    const RATIO_MIN = 0.15
    const RATIO_MAX = 0.85
    const alMover = (event) => {
      const columna = columnRef.current
      if (!columna) return
      const rect = columna.getBoundingClientRect()
      const nuevaRatio = (event.clientY - rect.top) / rect.height
      setFiltrosRatio(Math.min(RATIO_MAX, Math.max(RATIO_MIN, nuevaRatio)))
    }
    const alSoltar = () => {
      document.removeEventListener('mousemove', alMover)
      document.removeEventListener('mouseup', alSoltar)
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
    }
    const alBajarElMouse = (event) => {
      event.preventDefault()
      document.addEventListener('mousemove', alMover)
      document.addEventListener('mouseup', alSoltar)
      document.body.style.cursor = 'row-resize'
      document.body.style.userSelect = 'none'
    }
    const handle = dividerRef.current
    handle.addEventListener('mousedown', alBajarElMouse)
    return () => {
      handle.removeEventListener('mousedown', alBajarElMouse)
      document.removeEventListener('mousemove', alMover)
      document.removeEventListener('mouseup', alSoltar)
    }
  }, [])

  useEffect(() => {
    let cancelled = false

    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const params = new URLSearchParams({ page: String(page), pageSize: String(PAGE_SIZE) })
        config.searchFields.forEach((field) => {
          const value = String(appliedSearch[field] ?? '').trim()
          if (!value) return
          const type = getSearchFieldType(config.reportKey, field)
          const apiField = toApiField(field)
          if (type === 'date') {
            const start = new Date(value)
            if (!Number.isNaN(start.getTime())) {
              const end = new Date(start.getTime() + 24 * 60 * 60 * 1000)
              params.set(`filter[${apiField}][gte]`, start.toISOString())
              params.set(`filter[${apiField}][lt]`, end.toISOString())
            }
          } else if (type === 'number') {
            params.set(`filter[${apiField}][eq]`, value)
          } else {
            params.set(`filter[${apiField}][contains]`, value)
          }
        })

        const response = await fetch(`${API_BASE_URL}${config.endpoint}?${params}`)
        const data = await response.json().catch(() => ({}))
        if (cancelled) return
        if (!response.ok) throw new Error(data?.message || `HTTP ${response.status}`)
        const list = Array.isArray(data) ? data : (data.items || [])
        setItems(list)
        setTotalCount(Array.isArray(data) ? list.length : Number(data.totalCount ?? list.length))
      } catch (requestError) {
        if (cancelled) return
        setError('No se pudo cargar el listado.')
        setItems([])
        setTotalCount(0)
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    load()
    return () => {
      cancelled = true
    }
  }, [config, appliedSearch, page, refreshToken])

  // #descripcionEnListadoAbm: el listado de un ABM sale de su propio endpoint (sin joins),
  // así que un campo FK en searchFields (ej. EstrategiaID) llega como número crudo, no con
  // la descripción de la entidad referenciada. Para que la fila muestre algo más útil que
  // el ID (ej. "Estrategia QA Motor" en vez de "1"), se resuelve la descripción de cada ID
  // que aparece en la página actual -- una sola vez por ID, en paralelo, cacheada en
  // fkLabels para no repetir la consulta si el mismo ID vuelve a aparecer en otra página.
  useEffect(() => {
    let cancelled = false
    const fkFields = config.searchFields.filter((field) => getFkLookup(field))
    if (fkFields.length === 0) return undefined

    const resolve = async () => {
      for (const field of fkFields) {
        const lookup = getFkLookup(field)
        const idsEnPagina = [...new Set(
          items
            .map((record) => getRecordValue(record, field))
            .filter((value) => value !== undefined && value !== null && String(value).trim() !== ''),
        )]
        const idsPorResolver = idsEnPagina.filter((id) => fkLabels[field]?.[String(id)] === undefined)
        if (idsPorResolver.length === 0) continue

        const resultados = await Promise.all(
          idsPorResolver.map(async (id) => {
            try {
              const params = new URLSearchParams({ page: '1', pageSize: '1' })
              params.set(`filter[${lookup.idField}][eq]`, String(id))
              const res = await fetch(`${API_BASE_URL}${lookup.endpoint}?${params}`)
              const result = await res.json().catch(() => ({}))
              const found = Array.isArray(result) ? result[0] : result.items?.[0]
              return [String(id), found ? lookup.label(found) : null]
            } catch {
              return [String(id), null]
            }
          }),
        )
        if (cancelled) return
        setFkLabels((previous) => ({
          ...previous,
          [field]: {
            ...previous[field],
            ...Object.fromEntries(resultados.filter(([, label]) => label !== null)),
          },
        }))
      }
    }

    resolve()
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items, config])

  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE))

  const runSearch = () => {
    setAppliedSearch(searchValues)
    setPage(1)
  }

  const clearSearch = () => {
    setSearchValues({})
    setAppliedSearch({})
    setPage(1)
  }

  const getRowId = (record) => getRecordValue(record, config.idField) ?? getRecordValue(record, 'id')
  const getRawValue = (record, field) => {
    const value = getRecordValue(record, field)
    return value === undefined || value === null || String(value).trim() === '' ? '—' : value
  }
  // #registrosEstiloExcel: la lista de Registros se muestra como grilla, no como una sola
  // línea concatenada. Un campo FK (ej. EmpresaID) se parte en dos columnas -- el ID crudo
  // tal como lo devuelve el endpoint, y la descripción resuelta (ej. "Softland") -- en vez
  // de reemplazar el ID por la descripción, que ocultaba el dato real de la columna.
  const getFieldValue = (record, field) => {
    const value = getRecordValue(record, field)
    if (value === undefined || value === null || String(value).trim() === '') return '—'
    const fkLookup = getFkLookup(field)
    return fkLookup ? (fkLabels[field]?.[String(value)] ?? value) : value
  }
  const tableColumns = config.searchFields.flatMap((field) => {
    const fkLookup = getFkLookup(field)
    if (fkLookup) {
      return [
        { key: field, header: field, getValue: (record) => getRawValue(record, field) },
        { key: `${field}__desc`, header: field.replace(/ID$/, ''), getValue: (record) => getFieldValue(record, field) },
      ]
    }
    return [{ key: field, header: field, getValue: (record) => getFieldValue(record, field) }]
  })

  return (
    <div className="panel abm-list" ref={columnRef}>
      <div className="abm-list-filtros" style={{ flexGrow: filtrosRatio }}>
        <h4>Filtros</h4>
        <div className="abm-list-search">
          {config.searchFields.map((field) => {
            const fkLookup = getFkLookup(field)
            if (fkLookup) {
              return (
                <label key={field} className="abm-list-search-field">
                  <span className="abm-list-search-label">{field}</span>
                  <FkAutocompleteInput
                    lookup={fkLookup}
                    className="abm-list-search-input"
                    value={searchValues[field] ?? ''}
                    onSelect={(id) => setSearchValues((previous) => ({ ...previous, [field]: id }))}
                  />
                </label>
              )
            }
            const type = getSearchFieldType(config.reportKey, field)
            if (type !== 'number' && type !== 'date') {
              return (
                <label key={field} className="abm-list-search-field">
                  <span className="abm-list-search-label">{field}</span>
                  <SearchSuggestInput
                    endpoint={config.endpoint}
                    apiField={toApiField(field)}
                    className="abm-list-search-input"
                    placeholder="Buscar..."
                    value={searchValues[field] ?? ''}
                    onChange={(text) => setSearchValues((previous) => ({ ...previous, [field]: text }))}
                    onEnter={runSearch}
                  />
                </label>
              )
            }
            const inputType = type === 'date' ? 'date' : 'number'
            return (
              <label key={field} className="abm-list-search-field">
                <span className="abm-list-search-label">{field}</span>
                <input
                  type={inputType}
                  className="abm-list-search-input"
                  placeholder="Buscar..."
                  value={searchValues[field] ?? ''}
                  onChange={(event) => setSearchValues((previous) => ({ ...previous, [field]: event.target.value }))}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter') runSearch()
                  }}
                />
              </label>
            )
          })}
          <div className="abm-list-search-actions">
            <button type="button" className="ghost-button small-button" onClick={runSearch}>
              Buscar
            </button>
            <button type="button" className="ghost-button small-button" onClick={clearSearch}>
              Limpiar
            </button>
          </div>
        </div>
      </div>

      <div className="abm-list-divider" ref={dividerRef} />

      <div className="abm-list-registros" style={{ flexGrow: 1 - filtrosRatio }}>
        <h4 className="abm-list-body-title">Registros</h4>
        <div className="abm-list-body">
          {error && <div className="abm-list-empty">{error}</div>}
          {!error && loading && <div className="abm-list-empty">Cargando...</div>}
          {!error && !loading && items.length === 0 && <div className="abm-list-empty">Sin registros para mostrar.</div>}
          {!error && !loading && items.length > 0 && (
            <div className="abm-list-table-wrapper">
              <table className="abm-list-table">
                <thead>
                  <tr>
                    {tableColumns.map((col) => (
                      <th key={col.key}>{col.header}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {items.map((record) => {
                    const id = getRowId(record)
                    return (
                      <tr
                        key={id}
                        className={String(id) === String(selectedId) ? 'abm-list-table-row active' : 'abm-list-table-row'}
                        onClick={() => onSelect(record, id)}
                      >
                        {tableColumns.map((col) => (
                          <td key={col.key}>{col.getValue(record)}</td>
                        ))}
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="abm-list-pagination">
          <button type="button" className="ghost-button small-button" disabled={loading || page === 1} onClick={() => setPage((current) => current - 1)}>
            ‹
          </button>
          <span>
            {page} / {totalPages}
          </span>
          <button type="button" className="ghost-button small-button" disabled={loading || page >= totalPages} onClick={() => setPage((current) => current + 1)}>
            ›
          </button>
        </div>
      </div>
    </div>
  )
}

export default AbmRecordList
