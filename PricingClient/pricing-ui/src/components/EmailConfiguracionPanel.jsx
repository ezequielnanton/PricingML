import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import ResultToast from './ResultToast'
import { useRegisterToolbar } from '../context/ToolbarContext'

// #recuperarPassword: servidor SMTP configurable desde acá (una sola app de email por
// instalación, mismo patrón que Integración MercadoLibre). Lo usa el link de "olvidé mi
// contraseña" para saber a qué dirección/dominio mandar el correo y qué URL de frontend
// poner en el link de reseteo.
function EmailConfiguracionPanel({ isActiveTab = true }) {
  const [smtpHost, setSmtpHost] = useState('')
  const [smtpPort, setSmtpPort] = useState('')
  const [smtpUsuario, setSmtpUsuario] = useState('')
  const [smtpPassword, setSmtpPassword] = useState('')
  const [smtpPasswordConfigurada, setSmtpPasswordConfigurada] = useState(false)
  const [usarSsl, setUsarSsl] = useState(true)
  const [emailDesde, setEmailDesde] = useState('')
  const [nombreDesde, setNombreDesde] = useState('')
  const [frontendBaseUrl, setFrontendBaseUrl] = useState('')
  const [fechaActualizacion, setFechaActualizacion] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [destinatarioPrueba, setDestinatarioPrueba] = useState('')
  const [probando, setProbando] = useState(false)
  const [toast, setToast] = useState(null)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const cargar = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/email-configuracion`)
      const data = await res.json()
      setSmtpHost(data.smtpHost || '')
      setSmtpPort(data.smtpPort ?? '')
      setSmtpUsuario(data.smtpUsuario || '')
      setSmtpPasswordConfigurada(!!data.smtpPasswordConfigurada)
      setUsarSsl(data.usarSsl ?? true)
      setEmailDesde(data.emailDesde || '')
      setNombreDesde(data.nombreDesde || '')
      setFrontendBaseUrl(data.frontendBaseUrl || '')
      setFechaActualizacion(data.fechaActualizacion)
      setSmtpPassword('')
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
      const res = await fetch(`${API_BASE_URL}/api/admin/email-configuracion`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          smtpHost: smtpHost || null,
          smtpPort: smtpPort ? Number(smtpPort) : null,
          smtpUsuario: smtpUsuario || null,
          smtpPassword: smtpPassword || null,
          usarSsl,
          emailDesde: emailDesde || null,
          nombreDesde: nombreDesde || null,
          frontendBaseUrl: frontendBaseUrl || null,
        }),
      })
      if (!res.ok) throw new Error()
      notify('success', 'Configuración de email guardada.')
      await cargar()
    } catch {
      notify('error', 'No se pudo guardar la configuración.')
    } finally {
      setSaving(false)
    }
  }

  const handleProbar = async (event) => {
    event.preventDefault()
    if (!destinatarioPrueba) {
      notify('error', 'Ingresá un destinatario para la prueba.')
      return
    }
    setProbando(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/email-configuracion/probar`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Destinatario: destinatarioPrueba }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        notify('error', data?.message || 'No se pudo enviar el email de prueba.')
        return
      }
      notify('success', 'Email de prueba enviado. Revisá la casilla.')
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setProbando(false)
    }
  }

  // #barraDePantalla: reemplaza el botón "Guardar" -- ver ScreenToolbar.jsx / ToolbarContext.jsx.
  // #closureObsoletaBarraDePantalla: los deps tienen que incluir todos los campos que lee
  // handleGuardar -- ver misma nota en IntegracionMercadoLibrePanel.jsx / AdminPanel.jsx.
  useRegisterToolbar({
    save: !loading && !saving ? { onClick: handleGuardar } : null,
  }, [loading, saving, smtpHost, smtpPort, smtpUsuario, smtpPassword, usarSsl, emailDesde, nombreDesde, frontendBaseUrl], isActiveTab)

  return (
    <section className="panel erp-integracion-panel">
      <h3>Integración Email</h3>
      <p className="erp-panel-subtitle">
        Servidor SMTP (una sola app de email por instalación), usado para el link de "olvidé mi contraseña" que le
        llega a cada Usuario.
      </p>

      {loading ? (
        <p className="erp-panel-subtitle">Cargando…</p>
      ) : (
        <>
          <form onSubmit={(event) => { event.preventDefault(); handleGuardar() }} className="mini-form">
            <label>
              Host SMTP
              <input value={smtpHost} onChange={(event) => setSmtpHost(event.target.value)} placeholder="Ingresar Host SMTP" />
            </label>
            <label>
              Puerto
              <input type="number" value={smtpPort} onChange={(event) => setSmtpPort(event.target.value)} placeholder="Ingresar Puerto" />
            </label>
            <label>
              Usuario SMTP
              <input value={smtpUsuario} onChange={(event) => setSmtpUsuario(event.target.value)} />
            </label>
            <label>
              Contraseña SMTP
              <input
                type="password"
                value={smtpPassword}
                onChange={(event) => setSmtpPassword(event.target.value)}
                placeholder={smtpPasswordConfigurada ? '•••••••• (configurada; dejar vacío para no cambiarla)' : 'sin configurar'}
              />
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={usarSsl} onChange={(event) => setUsarSsl(event.target.checked)} />
              Usar SSL/TLS
            </label>
            <label>
              Email remitente
              <input value={emailDesde} onChange={(event) => setEmailDesde(event.target.value)} placeholder="Ingresar Email remitente" />
            </label>
            <label>
              Nombre remitente
              <input value={nombreDesde} onChange={(event) => setNombreDesde(event.target.value)} placeholder="Ingresar Nombre remitente" />
            </label>
            <label>
              URL base del frontend
              <input
                value={frontendBaseUrl}
                onChange={(event) => setFrontendBaseUrl(event.target.value)}
                placeholder="Ingresar URL base del frontend"
              />
              <span className="erp-panel-subtitle">Se usa para armar el link de reseteo (ej. {'{'}esta URL{'}'}/reset-password?token=...).</span>
            </label>
            {fechaActualizacion && (
              <p className="erp-panel-subtitle">Última actualización: {new Date(fechaActualizacion).toLocaleString()}</p>
            )}
          </form>

          <form onSubmit={handleProbar} className="mini-form email-prueba-form">
            <h4>Enviar email de prueba</h4>
            <label>
              Destinatario
              <input
                type="email"
                value={destinatarioPrueba}
                onChange={(event) => setDestinatarioPrueba(event.target.value)}
                placeholder="Ingresar Destinatario"
              />
            </label>
            <button type="submit" className="secondary-button" disabled={probando}>
              {probando ? 'Enviando…' : 'Enviar prueba'}
            </button>
          </form>
        </>
      )}

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </section>
  )
}

export default EmailConfiguracionPanel
