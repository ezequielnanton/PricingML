import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import ResultToast from './ResultToast'
import { useRegisterToolbar } from '../context/ToolbarContext'

// #integracionMlUiCredenciales: client_id/client_secret de la app de ML, configurables
// acá en vez de solo por appsettings.json. El secreto guardado nunca se muestra de
// nuevo; dejar el campo vacío al guardar conserva el que ya está.
function IntegracionMercadoLibrePanel({ isActiveTab = true }) {
  const [clientId, setClientId] = useState('')
  const [clientSecret, setClientSecret] = useState('')
  const [clientSecretConfigurado, setClientSecretConfigurado] = useState(false)
  const [apiBaseUrl, setApiBaseUrl] = useState('')
  const [siteId, setSiteId] = useState('MLA')
  const [redirectUri, setRedirectUri] = useState('')
  const [fechaActualizacion, setFechaActualizacion] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [toast, setToast] = useState(null)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const cargar = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/ml-configuracion`)
      const data = await res.json()
      setClientId(data.clientId || '')
      setClientSecretConfigurado(!!data.clientSecretConfigurado)
      setApiBaseUrl(data.apiBaseUrl || '')
      setSiteId(data.siteId || 'MLA')
      setRedirectUri(data.redirectUri || '')
      setFechaActualizacion(data.fechaActualizacion)
      setClientSecret('')
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  const handleGuardar = async () => {
    setSaving(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/ml-configuracion`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clientId: clientId || null,
          clientSecret: clientSecret || null,
          apiBaseUrl: apiBaseUrl || null,
          siteId: siteId || null,
          redirectUri: redirectUri || null,
        }),
      })
      if (!res.ok) throw new Error()
      notify('success', 'Configuración de MercadoLibre guardada.')
      await cargar()
    } catch {
      notify('error', 'No se pudo guardar la configuración.')
    } finally {
      setSaving(false)
    }
  }

  // #barraDePantalla: reemplaza el botón "Guardar" -- ver ScreenToolbar.jsx / ToolbarContext.jsx.
  // #closureObsoletaBarraDePantalla: los deps tienen que incluir todos los campos que lee
  // handleGuardar -- si faltan (como pasaba antes solo con [loading, saving]), la barra
  // global queda con una versión vieja de la función que guarda los valores de cuando se
  // registró, no los últimos tipeados en el formulario.
  useRegisterToolbar({
    save: !loading && !saving ? { onClick: handleGuardar } : null,
  }, [loading, saving, clientId, clientSecret, apiBaseUrl, siteId, redirectUri], isActiveTab)

  return (
    <section className="panel erp-integracion-panel">
      <h3>Integración MercadoLibre</h3>
      <p className="erp-panel-subtitle">
        Credenciales de la app de MercadoLibre (una sola por instalación). Cada Cuenta ML autoriza esta misma app vía
        OAuth para obtener su propio Access/Refresh Token.
      </p>

      {loading ? (
        <p className="erp-panel-subtitle">Cargando…</p>
      ) : (
        <form onSubmit={(event) => { event.preventDefault(); handleGuardar() }} className="mini-form">
          <label>
            Client ID
            <input value={clientId} onChange={(event) => setClientId(event.target.value)} />
          </label>
          <label>
            Client Secret
            <input
              type="password"
              value={clientSecret}
              onChange={(event) => setClientSecret(event.target.value)}
              placeholder={clientSecretConfigurado ? '•••••••• (configurado; dejar vacío para no cambiarlo)' : 'sin configurar'}
            />
          </label>
          <label>
            URL base de la API (opcional, solo para pruebas contra un mock)
            <input
              value={apiBaseUrl}
              onChange={(event) => setApiBaseUrl(event.target.value)}
              placeholder="Ingresar URL base de la API"
            />
          </label>
          <label>
            Sitio ML
            <select value={siteId} onChange={(event) => setSiteId(event.target.value)}>
              <option value="MLA">MLA – Argentina</option>
              <option value="MLB">MLB – Brasil</option>
              <option value="MLM">MLM – México</option>
              <option value="MLC">MLC – Chile</option>
              <option value="MCO">MCO – Colombia</option>
              <option value="MLU">MLU – Uruguay</option>
              <option value="MPE">MPE – Perú</option>
              <option value="MLV">MLV – Venezuela</option>
              <option value="MEC">MEC – Ecuador</option>
            </select>
          </label>
          <label>
            Redirect URI
            <input
              value={redirectUri}
              onChange={(event) => setRedirectUri(event.target.value)}
              placeholder="Ingresar Redirect URI"
            />
            <span className="erp-panel-subtitle">Tiene que coincidir exacto con la redirect_uri registrada en la app de ML.</span>
          </label>
          {fechaActualizacion && (
            <p className="erp-panel-subtitle">Última actualización: {new Date(fechaActualizacion).toLocaleString()}</p>
          )}
        </form>
      )}

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </section>
  )
}

export default IntegracionMercadoLibrePanel
