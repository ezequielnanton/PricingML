import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import { getFkLookup } from '../utils/fkLookups'
import FkAutocompleteInput from './FkAutocompleteInput'
import ResultToast from './ResultToast'

// #competidoresManualesMl: vincular manualmente los competidores de una publicación
// que NO es de catálogo. MercadoLibre bloquea tanto la búsqueda pública por texto
// (GET /sites/{site}/search) como leer una publicación ajena por ID (GET /items/{id})
// para apps de terceros -- 403 confirmado contra la API real, con token válido o sin
// él. No hay ninguna forma de que la app traiga el precio de un competidor, ni al
// vincularlo ni después: el usuario carga el ID/link, título, moneda y precio que ve
// en su propio navegador, y los puede reescribir cuando quiera con "Actualizar
// precio" -- no hay refresco automático, por eso se muestra hace cuánto se
// actualizó cada uno. La moneda por defecto es la Moneda Principal de la Empresa
// dueña de la publicación.
function diasDesde(fechaIso) {
  if (!fechaIso) return null
  return Math.floor((Date.now() - new Date(fechaIso).getTime()) / 86400000)
}

function formatoRelativo(fechaIso) {
  const dias = diasDesde(fechaIso)
  if (dias === null) return 'nunca actualizado'
  if (dias <= 0) return 'hoy'
  if (dias === 1) return 'hace 1 día'
  return `hace ${dias} días`
}

// Un link real de ML tiene la forma https://articulo.mercadolibre.com.ar/MLA-1894800292 --
// MercadoLibre redirige ese formato (sitio + guion + número) a la publicación real. El ID
// guardado ya viene normalizado por el backend (ExtraerItemId, sitio + número sin guion), así
// que alcanza con reconstruirlo insertando el guion; si por algún motivo no matchea ese
// formato (dato viejo, o un ID que no se pudo normalizar), se linkea igual con el ID crudo --
// siempre tiene que haber un link clickeable, aunque en ese caso no se pueda garantizar que
// redirija bien.
function linkPublicacion(itemId) {
  if (!itemId) return null
  const match = /^([A-Za-z]{2,4})(\d+)$/.exec(itemId)
  const idParaUrl = match ? `${match[1]}-${match[2]}` : itemId
  return `https://articulo.mercadolibre.com.ar/${idParaUrl}`
}

function ExternalLinkIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M6.5 3H3a1 1 0 0 0-1 1v9a1 1 0 0 0 1 1h9a1 1 0 0 0 1-1V10.5" />
      <path d="M9 2.5h4.5V7" />
      <path d="M13.2 2.8 7.5 8.5" />
    </svg>
  )
}

const FILA_VACIA = { idOrLink: '', titulo: '', monedaId: '', precio: '' }

function CompetidoresManualPanel({ publicacionId }) {
  const [vinculados, setVinculados] = useState([])
  const [loadingVinculados, setLoadingVinculados] = useState(true)
  const [nuevaFila, setNuevaFila] = useState(FILA_VACIA)
  const [vinculando, setVinculando] = useState(false)
  const [editandoId, setEditandoId] = useState(null)
  const [precioEditado, setPrecioEditado] = useState('')
  const [actualizando, setActualizando] = useState(false)
  const [toast, setToast] = useState(null)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const cargarVinculados = async () => {
    setLoadingVinculados(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/publicaciones/${publicacionId}/competidores`)
      const data = await res.json()
      setVinculados(Array.isArray(data) ? data : [])
    } catch {
      notify('error', 'No se pudo cargar los competidores vinculados.')
    } finally {
      setLoadingVinculados(false)
    }
  }

  const cargarMonedaPrincipal = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/publicaciones/${publicacionId}/moneda-principal`)
      const data = await res.json()
      setNuevaFila((prev) => ({ ...prev, monedaId: data.monedaID ? String(data.monedaID) : '' }))
    } catch {
      // sin moneda principal configurada, el usuario la elige a mano
    }
  }

  useEffect(() => {
    if (!publicacionId) return
    cargarVinculados()
    setNuevaFila(FILA_VACIA)
    setEditandoId(null)
    cargarMonedaPrincipal()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [publicacionId])

  const handleVincular = async (event) => {
    event.preventDefault()
    if (!nuevaFila.idOrLink.trim() || !nuevaFila.titulo.trim() || !nuevaFila.monedaId || nuevaFila.precio === '') return
    setVinculando(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/publicaciones/${publicacionId}/competidores`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          competidorItemID: nuevaFila.idOrLink.trim(),
          competidorTitulo: nuevaFila.titulo.trim(),
          monedaID: Number(nuevaFila.monedaId),
          precio: Number(nuevaFila.precio),
        }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        notify('error', data.message || 'No se pudo vincular.')
        return
      }
      notify('success', `${nuevaFila.titulo.trim()} vinculado como competidor.`)
      setNuevaFila((prev) => ({ ...FILA_VACIA, monedaId: prev.monedaId }))
      await cargarVinculados()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setVinculando(false)
    }
  }

  const handleDesvincular = async (vinculo) => {
    try {
      const res = await fetch(
        `${API_BASE_URL}/api/marketplace/ml/publicaciones/${publicacionId}/competidores/${vinculo.vinculoID}`,
        { method: 'DELETE' }
      )
      if (!res.ok) {
        notify('error', 'No se pudo desvincular.')
        return
      }
      setVinculados((prev) => prev.filter((v) => v.vinculoID !== vinculo.vinculoID))
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    }
  }

  const iniciarEdicionPrecio = (vinculo) => {
    setEditandoId(vinculo.vinculoID)
    setPrecioEditado(vinculo.ultimoPrecio != null ? String(vinculo.ultimoPrecio) : '')
  }

  const handleActualizarPrecio = async (vinculo) => {
    if (precioEditado === '') return
    setActualizando(true)
    try {
      const res = await fetch(
        `${API_BASE_URL}/api/marketplace/ml/publicaciones/${publicacionId}/competidores/${vinculo.vinculoID}/precio`,
        { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ precio: Number(precioEditado) }) }
      )
      if (!res.ok) {
        notify('error', 'No se pudo actualizar el precio.')
        return
      }
      setEditandoId(null)
      await cargarVinculados()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setActualizando(false)
    }
  }

  return (
    <div className="competidores-manual-panel">
      <h4>Competidores vinculados</h4>
      <p className="erp-panel-subtitle">
        Esta publicación no es de catálogo: MercadoLibre no define su competencia automáticamente, y no permite que
        esta app consulte publicaciones de otros vendedores. Encontrá la publicación competidora navegando
        MercadoLibre y cargala acá abajo — vas a poder actualizar el precio cuando quieras.
      </p>

      <div className="table-container competidores-grid-container">
        <table className="data-table competidores-grid">
          <thead>
            <tr>
              <th>Publicación</th>
              <th>Título</th>
              <th>Moneda</th>
              <th>Precio</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loadingVinculados ? (
              <tr><td colSpan={5} className="loading-state">Cargando…</td></tr>
            ) : vinculados.length === 0 ? (
              <tr><td colSpan={5} className="empty-state">Todavía no vinculaste ningún competidor.</td></tr>
            ) : (
              vinculados.map((v) => {
                const link = linkPublicacion(v.competidorItemID)
                return (
                  <tr key={v.vinculoID}>
                    <td>
                      <a href={link} target="_blank" rel="noreferrer" className="competidores-grid-link">
                        {v.competidorItemID}
                        <ExternalLinkIcon />
                      </a>
                    </td>
                    <td title={v.competidorTitulo || ''}>{v.competidorTitulo || '—'}</td>
                    <td>{v.monedaCodigoISO || '—'}</td>
                    <td className="competidores-celda-numero">
                      {editandoId === v.vinculoID ? (
                        <div className="competidores-editar-precio">
                          <input
                            type="number"
                            step="0.01"
                            value={precioEditado}
                            onChange={(event) => setPrecioEditado(event.target.value)}
                            placeholder="Precio actual"
                          />
                          <button type="button" className="primary-button" disabled={actualizando} onClick={() => handleActualizarPrecio(v)}>
                            {actualizando ? 'Guardando…' : 'Guardar'}
                          </button>
                          <button type="button" className="ghost-button" onClick={() => setEditandoId(null)}>Cancelar</button>
                        </div>
                      ) : (
                        <>
                          {v.ultimoPrecio != null ? `${v.monedaSimbolo || ''} ${Number(v.ultimoPrecio).toFixed(2)}` : '—'}
                          <br />
                          <small className="erp-panel-subtitle">{formatoRelativo(v.fechaUltimoPrecio)}</small>
                        </>
                      )}
                    </td>
                    <td className="competidores-acciones-celda">
                      {editandoId !== v.vinculoID && (
                        <>
                          <button type="button" className="ghost-button" onClick={() => iniciarEdicionPrecio(v)}>Actualizar precio</button>
                          <button type="button" className="ghost-button" onClick={() => handleDesvincular(v)}>Desvincular</button>
                        </>
                      )}
                    </td>
                  </tr>
                )
              })
            )}
            <tr className="competidores-fila-nueva">
              <td>
                <input
                  value={nuevaFila.idOrLink}
                  onChange={(event) => setNuevaFila((prev) => ({ ...prev, idOrLink: event.target.value }))}
                  placeholder="ID o link de MercadoLibre…"
                />
              </td>
              <td>
                <input
                  value={nuevaFila.titulo}
                  onChange={(event) => setNuevaFila((prev) => ({ ...prev, titulo: event.target.value }))}
                  placeholder="Título…"
                />
              </td>
              <td>
                <FkAutocompleteInput
                  lookup={getFkLookup('MonedaID')}
                  value={nuevaFila.monedaId}
                  onSelect={(id) => setNuevaFila((prev) => ({ ...prev, monedaId: id }))}
                />
              </td>
              <td className="competidores-celda-numero">
                <input
                  type="number"
                  step="0.01"
                  value={nuevaFila.precio}
                  onChange={(event) => setNuevaFila((prev) => ({ ...prev, precio: event.target.value }))}
                  placeholder="Precio"
                />
              </td>
              <td className="competidores-acciones-celda">
                <button type="button" className="primary-button" disabled={vinculando} onClick={handleVincular}>
                  {vinculando ? 'Vinculando…' : 'Vincular'}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </div>
  )
}

export default CompetidoresManualPanel
