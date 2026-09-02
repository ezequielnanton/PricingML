import { useEffect, useRef, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import { getRecordValue } from '../utils/adminHelpers'

const LIMITE_SUGERENCIAS = 10
const DEBOUNCE_MS = 250

// #lupitaFk: mismo criterio que FkAutocompleteInput.jsx -- cualquier campo que despliega un
// menú de sugerencias para elegir el registro lleva la lupita, sea o no una FK real.
function SearchGlassIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="7" cy="7" r="5" />
      <path d="M11 11 14.5 14.5" />
    </svg>
  )
}

// #sugerenciasFiltroTexto: mismo patrón de sugerencias que FkAutocompleteInput, pero para
// un campo de búsqueda de un ABM que NO es un ID de otra entidad (ej. CUIT, SKU). Acá no
// hay una tabla referenciada de la que traer una descripción: la sugerencia es el propio
// valor del campo tal como aparece en los registros existentes, buscado con el mismo
// `filter[campo][contains]` que ya usa el botón Buscar.
function SearchSuggestInput({ endpoint, apiField, value, onChange, onEnter, className = '', placeholder = 'Buscar...' }) {
  const [sugerencias, setSugerencias] = useState([])
  const [abierto, setAbierto] = useState(false)
  const [cargando, setCargando] = useState(false)
  const contenedorRef = useRef(null)
  const debounceRef = useRef(null)

  const buscarSugerencias = async (texto) => {
    setCargando(true)
    try {
      const params = new URLSearchParams({ page: '1', pageSize: String(LIMITE_SUGERENCIAS) })
      if (texto.trim()) params.set(`filter[${apiField}][contains]`, texto.trim())
      const res = await fetch(`${API_BASE_URL}${endpoint}?${params}`)
      const result = await res.json().catch(() => ({}))
      const items = Array.isArray(result) ? result : result.items
      const valores = Array.isArray(items)
        ? [...new Set(
            items
              .map((item) => getRecordValue(item, apiField))
              .filter((v) => v !== undefined && v !== null && String(v).trim() !== ''),
          )]
        : []
      setSugerencias(valores.slice(0, LIMITE_SUGERENCIAS))
    } catch {
      setSugerencias([])
    } finally {
      setCargando(false)
    }
  }

  useEffect(() => {
    if (!abierto) return
    const alClickearAfuera = (event) => {
      if (contenedorRef.current && !contenedorRef.current.contains(event.target)) setAbierto(false)
    }
    document.addEventListener('mousedown', alClickearAfuera)
    return () => document.removeEventListener('mousedown', alClickearAfuera)
  }, [abierto])

  const alEnfocar = () => {
    setAbierto(true)
    buscarSugerencias(value || '')
  }

  const alEscribir = (event) => {
    const texto = event.target.value
    onChange(texto)
    setAbierto(true)
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => buscarSugerencias(texto), DEBOUNCE_MS)
  }

  const elegir = (valor) => {
    onChange(String(valor))
    setAbierto(false)
  }

  return (
    <div className="fk-autocomplete" ref={contenedorRef}>
      <input
        type="text"
        className={className ? `${className} fk-search-input` : 'fk-search-input'}
        value={value ?? ''}
        placeholder={placeholder}
        onFocus={alEnfocar}
        onChange={alEscribir}
        onKeyDown={(event) => {
          if (event.key === 'Enter') {
            setAbierto(false)
            onEnter?.()
          }
        }}
      />
      <span className="fk-autocomplete-search-icon">
        <SearchGlassIcon />
      </span>
      {abierto && (
        <div className="fk-autocomplete-panel">
          {cargando && <div className="fk-autocomplete-mensaje">Buscando…</div>}
          {!cargando && sugerencias.length === 0 && <div className="fk-autocomplete-mensaje">Sin coincidencias.</div>}
          {!cargando && sugerencias.map((valor) => (
            <button type="button" key={valor} className="fk-autocomplete-item" onClick={() => elegir(valor)}>
              {valor}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

export default SearchSuggestInput
