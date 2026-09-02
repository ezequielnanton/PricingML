import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import ResultToast from './ResultToast'

// #aprobacionColaMl: mejor esfuerzo para armar el link público a una publicación de
// ML a partir del prefijo del item_id (MLA=Argentina, MLB=Brasil, etc.). Con datos de
// prueba (ids ficticios) el link no va a resolver a un producto real, pero el
// mecanismo es el mismo que se usaría con ids reales de ML.
const SITIOS_ML = { MLA: 'mercadolibre.com.ar', MLB: 'mercadolivre.com.br', MLM: 'mercadolibre.com.mx', MLC: 'mercadolibre.cl' }
function linkPublicacionMl(itemId) {
  if (!itemId) return null
  const prefijo = itemId.slice(0, 3).toUpperCase()
  const dominio = SITIOS_ML[prefijo] || 'mercadolibre.com'
  return `https://articulo.${dominio}/${itemId}`
}

function ColaMlAprobacionPanel() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [procesandoId, setProcesandoId] = useState(null)
  const [toast, setToast] = useState(null)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const cargar = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/cola-aprobacion`)
      const data = await res.json()
      setItems(Array.isArray(data) ? data : [])
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  const decidir = async (colaId, accion) => {
    setProcesandoId(colaId)
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/cola-aprobacion/${colaId}/${accion}`, { method: 'POST' })
      if (!res.ok) {
        notify('error', 'No se pudo registrar la decisión (puede que ya se haya resuelto).')
        await cargar()
        return
      }
      setItems((prev) => prev.filter((item) => item.colaID !== colaId))
      notify('success', accion === 'aprobar' ? 'Cambio aprobado.' : 'Cambio rechazado.')
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setProcesandoId(null)
    }
  }

  return (
    <section className="panel cola-ml-aprobacion-panel">
      <div className="panel-header">
        <h3>Cola ML — Aprobación</h3>
        <button type="button" className="secondary-button" onClick={cargar} disabled={loading}>
          {loading ? 'Actualizando…' : 'Actualizar'}
        </button>
      </div>
      <p className="erp-panel-subtitle">
        Cambios de precio que el motor calculó y todavía no se subieron a MercadoLibre. Las publicaciones que no son
        de catálogo siempre pasan por acá; las de catálogo solo si "Subir precio a ML automáticamente" está
        desactivado en Parámetro General.
      </p>

      {!loading && items.length === 0 && <p className="erp-panel-subtitle">No hay cambios pendientes de aprobación.</p>}

      {items.length > 0 && (
        <div className="cola-ml-lista">
          {items.map((item) => (
            <div key={item.colaID} className="cola-ml-item">
              <div className="cola-ml-item-header">
                <strong>{item.titulo}</strong>
                <span>SKU {item.sku} · {item.meliItemID}{item.esCatalogo ? ' · Catálogo' : ''}</span>
              </div>
              <div className="cola-ml-item-precios">
                <span>Precio actual: ${item.precioActual.toFixed(2)}</span>
                <span className="cola-ml-flecha">→</span>
                <span className={item.accionRequerida === 'AUMENTAR_PRECIO' ? 'cola-ml-precio-sube' : 'cola-ml-precio-baja'}>
                  Precio sugerido: ${item.precioNuevo.toFixed(2)}
                </span>
              </div>
              {item.motivo && <p className="cola-ml-motivo">{item.motivo}</p>}
              {item.competidorItemIDRef && (
                <p className="cola-ml-competidor">
                  Comparado contra{' '}
                  <a href={linkPublicacionMl(item.competidorItemIDRef)} target="_blank" rel="noreferrer">
                    {item.competidorItemIDRef}
                  </a>{' '}
                  (${item.precioCompetidorRef?.toFixed(2)})
                </p>
              )}
              <div className="cola-ml-item-acciones">
                <button
                  type="button"
                  className="primary-button"
                  onClick={() => decidir(item.colaID, 'aprobar')}
                  disabled={procesandoId === item.colaID}
                >
                  Aprobar
                </button>
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => decidir(item.colaID, 'rechazar')}
                  disabled={procesandoId === item.colaID}
                >
                  Rechazar
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </section>
  )
}

export default ColaMlAprobacionPanel
