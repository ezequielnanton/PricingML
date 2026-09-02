import { useEffect, useRef, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'

const LIMITE_SUGERENCIAS = 10
const DEBOUNCE_MS = 250

// #lupitaFk: todo campo que busca por descripción de una FK lleva una lupita al final del
// cuadro (adentro del input, pegada al margen derecho), tanto en Filtros de Reportes como
// en los campos de Formularios -- para que se note a simple vista que ese campo se puede
// buscar por texto y no es un ID a tipear a mano.
function SearchGlassIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="7" cy="7" r="5" />
      <path d="M11 11 14.5 14.5" />
    </svg>
  )
}

// #autocompleteDescripcionParaId: input de texto que busca por descripción (no por ID) en
// la entidad referenciada (ver fkLookups.js) y propone hasta 10 coincidencias a medida que
// se escribe -- o los primeros 10 registros si todavía no se escribió nada. Compartido por
// dos contextos (ver CONTEXT.md, término "Autocomplete de descripción para ID"): un Filtro
// de reporte (ReportFilterField.jsx) y un campo ID de un ABM (AdminPanel.jsx). En ambos, lo
// que se manda al elegir una sugerencia sigue siendo el ID real (`onSelect`); esto solo
// cambia cómo el usuario lo encuentra y qué ve mientras lo busca.
function FkAutocompleteInput({ lookup, value, onSelect, disabled = false, className = '' }) {
  const [query, setQuery] = useState('')
  const [label, setLabel] = useState('')
  const [sugerencias, setSugerencias] = useState([])
  const [abierto, setAbierto] = useState(false)
  const [cargando, setCargando] = useState(false)
  const [coords, setCoords] = useState(null)
  const contenedorRef = useRef(null)
  const debounceRef = useRef(null)

  // Si el valor (ID) cambia desde afuera (ej. "Limpiar", o al abrir un registro existente
  // en un ABM) y no coincide con lo que ya estamos mostrando, resolvemos su descripción
  // para mostrarla en el input.
  useEffect(() => {
    let cancelado = false
    const idActual = value ? String(value) : ''
    if (!idActual) {
      setLabel('')
      return
    }
    const buscar = async () => {
      try {
        const params = new URLSearchParams({ page: '1', pageSize: '1' })
        params.set(`filter[${lookup.idField}][eq]`, idActual)
        const res = await fetch(`${API_BASE_URL}${lookup.endpoint}?${params}`)
        const result = await res.json().catch(() => ({}))
        const items = Array.isArray(result) ? result : result.items
        if (!cancelado && Array.isArray(items) && items[0]) setLabel(lookup.label(items[0]))
      } catch {
        // si falla la resolución, se sigue mostrando el ID crudo (ver renderizado abajo)
      }
    }
    buscar()
    return () => { cancelado = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value, lookup.endpoint, lookup.idField])

  const buscarSugerencias = async (texto) => {
    setCargando(true)
    try {
      const params = new URLSearchParams({ page: '1', pageSize: String(LIMITE_SUGERENCIAS) })
      // #buscarPorIdExacto: la mayoría de los lookups buscan por texto parcial (nombre,
      // título, etc.), pero una entidad sin ningún campo de texto propio (ej.
      // Estrategia-Regla, ver fkLookups.js) solo puede buscarse por su ID exacto -- el
      // backend ni siquiera acepta "contains" sobre una columna numérica.
      if (texto.trim()) params.set(`filter[${lookup.searchField}][${lookup.searchType === 'number' ? 'eq' : 'contains'}]`, texto.trim())
      const res = await fetch(`${API_BASE_URL}${lookup.endpoint}?${params}`)
      const result = await res.json().catch(() => ({}))
      const items = Array.isArray(result) ? result : result.items
      setSugerencias(Array.isArray(items) ? items.slice(0, LIMITE_SUGERENCIAS) : [])
    } catch {
      setSugerencias([])
    } finally {
      setCargando(false)
    }
  }

  // #lupaEscapaDelScroll: el desplegable se posiciona con position:fixed (coordenadas
  // calculadas acá, no CSS) en vez de position:absolute relativo al campo -- si quedara
  // absoluto, cualquier ancestro con overflow propio (ej. la grilla de Competidores
  // vinculados, que scrollea horizontal) lo recorta y las opciones no se llegan a ver, aunque
  // el desplegable esté técnicamente abierto. Con fixed no importa qué contenedor scrollee
  // por el medio. Como esas coordenadas quedan desactualizadas apenas la página se mueve, se
  // cierra solo ante cualquier scroll (de la página o de un contenedor interno, por eso
  // capture:true) o resize, en vez de tratar de seguirlo.
  // #tecladoMobileMueveElInput: en mobile, enfocar el campo dispara TANTO un resize (el
  // teclado virtual angosta el viewport) COMO un scroll (el navegador desplaza la página
  // para que el campo quede visible arriba del teclado) -- si empezáramos a escuchar estos
  // eventos ni bien se abre, ese primer scroll/resize "del sistema" cerraba el desplegable
  // antes de que el usuario llegara a verlo (síntoma reportado: no se ve nada hasta
  // escribir, porque escribir vuelve a abrirlo después de que el teclado ya terminó de
  // moverse). Se espera a que ese acomodo inicial termine, y recién ahí se recalculan las
  // coordenadas (el campo pudo haberse movido) y se empieza a escuchar scroll/resize como
  // "esto sí es el usuario moviéndose, hay que cerrar".
  useEffect(() => {
    if (!abierto) return
    document.addEventListener('mousedown', alClickearAfuera)
    const timer = setTimeout(() => {
      if (contenedorRef.current) {
        const rect = contenedorRef.current.getBoundingClientRect()
        setCoords({ top: rect.bottom + 4, left: rect.left, width: rect.width })
      }
      document.addEventListener('scroll', cerrar, true)
      window.addEventListener('resize', cerrar)
    }, 350)
    return () => {
      clearTimeout(timer)
      document.removeEventListener('mousedown', alClickearAfuera)
      document.removeEventListener('scroll', cerrar, true)
      window.removeEventListener('resize', cerrar)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [abierto])

  const cerrar = () => setAbierto(false)

  const alClickearAfuera = (event) => {
    if (contenedorRef.current && !contenedorRef.current.contains(event.target)) setAbierto(false)
  }

  const alEnfocar = () => {
    if (contenedorRef.current) {
      const rect = contenedorRef.current.getBoundingClientRect()
      setCoords({ top: rect.bottom + 4, left: rect.left, width: rect.width })
    }
    setAbierto(true)
    buscarSugerencias(query)
  }

  const alEscribir = (event) => {
    const texto = event.target.value
    setQuery(texto)
    setAbierto(true)
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => buscarSugerencias(texto), DEBOUNCE_MS)
  }

  const elegir = (item) => {
    onSelect(String(item[lookup.idField]))
    setLabel(lookup.label(item))
    setQuery('')
    setAbierto(false)
  }

  const valorMostrado = abierto ? query : (label || (value ? `ID ${value}` : ''))

  return (
    <div className="fk-autocomplete" ref={contenedorRef}>
      <input
        type="text"
        className={className ? `${className} fk-search-input` : 'fk-search-input'}
        value={valorMostrado}
        placeholder="Buscar..."
        disabled={disabled}
        onFocus={alEnfocar}
        onChange={alEscribir}
      />
      <span className="fk-autocomplete-search-icon">
        <SearchGlassIcon />
      </span>
      {abierto && !disabled && coords && (
        <div className="fk-autocomplete-panel" style={{ top: coords.top, left: coords.left, width: coords.width }}>
          {cargando && <div className="fk-autocomplete-mensaje">Buscando…</div>}
          {!cargando && sugerencias.length === 0 && <div className="fk-autocomplete-mensaje">Sin coincidencias.</div>}
          {!cargando && sugerencias.map((item) => (
            <button
              type="button"
              key={item[lookup.idField]}
              className="fk-autocomplete-item"
              onClick={() => elegir(item)}
            >
              {lookup.label(item)}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

export default FkAutocompleteInput
