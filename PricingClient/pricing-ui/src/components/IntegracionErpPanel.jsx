import { useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import ResultToast from './ResultToast'

// #integracionErp: pantalla para dejar cualquier instalación conectada a SU ERP sin
// escribir código nuevo. El admin apunta al GET del ERP, el sistema descubre qué
// campos devuelve, y el admin dice con qué campo se llena cada campo canónico.
const CAMPOS_CANONICOS = [
  { key: 'SKU', label: 'SKU', requerido: true },
  { key: 'Titulo', label: 'Título', requerido: false },
  { key: 'CostoCompra', label: 'Costo de compra', requerido: true },
  { key: 'PorcentajeIVA', label: 'IVA %', requerido: false },
  { key: 'ImpuestosInternos', label: 'Impuestos internos', requerido: false },
  { key: 'StockActual', label: 'Stock actual', requerido: true },
  { key: 'StockMinimo', label: 'Stock mínimo', requerido: false },
  { key: 'StockMaximo', label: 'Stock máximo', requerido: false },
]

const emptyMapeo = () => Object.fromEntries(CAMPOS_CANONICOS.map((c) => [c.key, '']))

function IntegracionErpPanel() {
  const [empresaId, setEmpresaId] = useState('')
  const [cargado, setCargado] = useState(false)
  const [erpConexionId, setErpConexionId] = useState(null)
  const [apiKeyEntrante, setApiKeyEntrante] = useState('')
  const [ultimaSincronizacion, setUltimaSincronizacion] = useState(null)

  const [urlSalida, setUrlSalida] = useState('')
  const [apiKeySaliente, setApiKeySaliente] = useState('')

  const [camposDescubiertos, setCamposDescubiertos] = useState([])
  const [muestra, setMuestra] = useState({})
  const [mapeo, setMapeo] = useState(emptyMapeo())

  const [loadingCargar, setLoadingCargar] = useState(false)
  const [loadingConexion, setLoadingConexion] = useState(false)
  const [loadingDescubrir, setLoadingDescubrir] = useState(false)
  const [loadingMapeo, setLoadingMapeo] = useState(false)
  const [toast, setToast] = useState(null)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const handleCargar = async (event) => {
    event.preventDefault()
    if (!empresaId) return
    setLoadingCargar(true)
    try {
      const resConexion = await fetch(`${API_BASE_URL}/api/admin/erp-conexiones/${empresaId}`)
      if (resConexion.ok) {
        const data = await resConexion.json()
        setErpConexionId(data.erpConexionID)
        setUrlSalida(data.urlSalida || '')
        setApiKeySaliente(data.apiKeySaliente || '')
        setUltimaSincronizacion(data.ultimaSincronizacion)
      } else {
        setErpConexionId(null)
        setUrlSalida('')
        setApiKeySaliente('')
        setUltimaSincronizacion(null)
      }

      const resMapeo = await fetch(`${API_BASE_URL}/api/admin/erp-conexiones/${empresaId}/mapeo`)
      const mapeoData = resMapeo.ok ? await resMapeo.json() : []
      const nuevoMapeo = emptyMapeo()
      mapeoData.forEach((m) => {
        nuevoMapeo[m.campoCanonico] = m.campoOrigen
      })
      setMapeo(nuevoMapeo)
      setCamposDescubiertos([])
      setMuestra({})
      setApiKeyEntrante('')
      setCargado(true)
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setLoadingCargar(false)
    }
  }

  const handleGuardarConexion = async () => {
    setLoadingConexion(true)
    try {
      if (erpConexionId) {
        const res = await fetch(`${API_BASE_URL}/api/admin/erp-conexiones/${empresaId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ urlSalida: urlSalida || null, apiKeySaliente: apiKeySaliente || null }),
        })
        if (!res.ok) throw new Error()
        notify('success', 'Conexión actualizada.')
      } else {
        const res = await fetch(`${API_BASE_URL}/api/admin/erp-conexiones`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            empresaID: Number(empresaId),
            urlSalida: urlSalida || null,
            apiKeySaliente: apiKeySaliente || null,
          }),
        })
        if (!res.ok) throw new Error()
        const data = await res.json()
        setErpConexionId(data.erpConexionID)
        setApiKeyEntrante(data.apiKeyEntrante)
        notify('success', 'Conexión creada. Guardá la API key entrante: no se vuelve a mostrar.')
      }
    } catch {
      notify('error', 'No se pudo guardar la conexión.')
    } finally {
      setLoadingConexion(false)
    }
  }

  const handleDescubrirCampos = async () => {
    if (!urlSalida) {
      notify('error', 'Ingresá la URL de lectura (GET) del ERP primero.')
      return
    }
    setLoadingDescubrir(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/erp-conexiones/descubrir-campos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: urlSalida, apiKey: apiKeySaliente || null }),
      })
      const data = await res.json()
      if (!res.ok) {
        notify('error', data.message || 'No se pudieron descubrir los campos.')
        return
      }
      setCamposDescubiertos(data.camposDescubiertos)
      setMuestra(data.muestra)
      notify('success', `${data.camposDescubiertos.length} campos encontrados.`)
    } catch {
      notify('error', 'No se pudo conectar con el ERP.')
    } finally {
      setLoadingDescubrir(false)
    }
  }

  const handleGuardarMapeo = async () => {
    setLoadingMapeo(true)
    try {
      const mapeos = CAMPOS_CANONICOS
        .filter((c) => mapeo[c.key]?.trim())
        .map((c) => ({ campoCanonico: c.key, campoOrigen: mapeo[c.key].trim() }))

      const res = await fetch(`${API_BASE_URL}/api/admin/erp-conexiones/${empresaId}/mapeo`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mapeos }),
      })
      const data = res.status === 204 ? null : await res.json()
      if (!res.ok) {
        notify('error', data?.message || 'No se pudo guardar el mapeo.')
        return
      }
      notify('success', 'Mapeo guardado.')
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setLoadingMapeo(false)
    }
  }

  return (
    <section className="panel erp-integracion-panel">
      <h3>Integración ERP</h3>
      <p className="erp-panel-subtitle">
        Cada instalación conecta a un solo ERP. Apuntá al GET de productos de ese ERP, descubrí sus campos y decile
        con cuál se llena cada campo de acá.
      </p>

      <form onSubmit={handleCargar} className="mini-form erp-empresa-form">
        <label>
          Empresa ID
          <input value={empresaId} onChange={(event) => setEmpresaId(event.target.value)} required />
        </label>
        <button type="submit" className="primary-button icon-width-button" disabled={loadingCargar} title="Cargar" aria-label="Cargar">
          {loadingCargar ? '…' : '->'}
        </button>
      </form>

      {cargado && (
        <>
          <fieldset className="mini-form">
            <legend>Conexión</legend>
            <label>
              URL de lectura del ERP (GET)
              <input
                value={urlSalida}
                onChange={(event) => setUrlSalida(event.target.value)}
                placeholder="Ingresar URL de lectura del ERP"
              />
            </label>
            <label>
              API key para llamar al ERP (si la pide)
              <input value={apiKeySaliente} onChange={(event) => setApiKeySaliente(event.target.value)} />
            </label>
            {ultimaSincronizacion && (
              <p className="erp-panel-subtitle">Última sincronización: {new Date(ultimaSincronizacion).toLocaleString()}</p>
            )}
            {apiKeyEntrante && (
              <p className="erp-api-key-hint">
                API key entrante (para que el ERP nos haga POST): <code>{apiKeyEntrante}</code> — no se vuelve a
                mostrar, guardala ahora.
              </p>
            )}
            <button type="button" className="primary-button" onClick={handleGuardarConexion} disabled={loadingConexion}>
              {loadingConexion ? 'Guardando…' : 'Guardar conexión'}
            </button>
          </fieldset>

          <fieldset className="mini-form">
            <legend>Descubrir campos</legend>
            <button type="button" className="secondary-button" onClick={handleDescubrirCampos} disabled={loadingDescubrir}>
              {loadingDescubrir ? 'Consultando…' : 'Descubrir campos del ERP'}
            </button>

            {camposDescubiertos.length > 0 && (
              <div className="table-container">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Campo del ERP</th>
                      <th>Valor de ejemplo</th>
                    </tr>
                  </thead>
                  <tbody>
                    {camposDescubiertos.map((campo) => (
                      <tr key={campo}>
                        <td>{campo}</td>
                        <td>{muestra[campo]}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </fieldset>

          <fieldset className="mini-form">
            <legend>Mapeo de campos</legend>
            <datalist id="erp-campos-descubiertos">
              {camposDescubiertos.map((campo) => (
                <option key={campo} value={campo} />
              ))}
            </datalist>

            {CAMPOS_CANONICOS.map((campo) => (
              <label key={campo.key}>
                {campo.label}
                {campo.requerido ? ' *' : ''}
                <input
                  list="erp-campos-descubiertos"
                  value={mapeo[campo.key]}
                  onChange={(event) => setMapeo((prev) => ({ ...prev, [campo.key]: event.target.value }))}
                  placeholder={`Ingresar ${campo.label}`}
                />
              </label>
            ))}

            <button type="button" className="primary-button" onClick={handleGuardarMapeo} disabled={loadingMapeo}>
              {loadingMapeo ? 'Guardando…' : 'Guardar mapeo'}
            </button>
          </fieldset>
        </>
      )}

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </section>
  )
}

export default IntegracionErpPanel
