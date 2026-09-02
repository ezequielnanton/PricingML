import { useEffect, useRef, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { API_BASE_URL } from '../utils/apiBase'
import { getToken, getUsuario, setSession, clearSession, refreshStoredUsuario, SESSION_CHANGED_EVENT } from '../utils/auth'
import { UserBadgeIcon } from './icons/HeaderIcons'
import { SunIcon, MoonIcon } from './icons/NavIcons'

// #loginGeneralApp: puerta de entrada a toda la app (AdminPanel, Cola ML, Integraciones,
// Reportes, Pricing) — antes de esto, esas pantallas eran de acceso libre. Mientras no
// exista ningún Usuario en la base, muestra el alta del primer ADMIN (bootstrap); una
// vez que existe al menos uno, pide login normal. No envuelve /repositor/*, que tiene su
// propio login (Usuario+PIN) y protege una superficie de endpoints distinta.
function LoginGate({ children }) {
  const location = useLocation()
  const navigate = useNavigate()
  const [estado, setEstado] = useState('verificando') // verificando | bootstrap | login | autenticado
  const [usuario, setUsuarioState] = useState(() => getUsuario())
  const [form, setForm] = useState({ NombreCompleto: '', Usuario: '', Password: '' })
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')
  const [mostrarCambioPassword, setMostrarCambioPassword] = useState(false)
  const [passwordForm, setPasswordForm] = useState({ PasswordActual: '', PasswordNueva: '', PasswordConfirmar: '' })
  const [cambiandoPassword, setCambiandoPassword] = useState(false)
  const [passwordError, setPasswordError] = useState('')
  const [passwordExito, setPasswordExito] = useState('')

  // #recuperarPassword: "olvidé mi contraseña" desde el login, y la pantalla que abre
  // el link que llega por email — ambas funcionan sin sesión, así que viven acá aparte
  // del resto del formulario de login/bootstrap.
  const [mostrarOlvide, setMostrarOlvide] = useState(false)
  const [olvideUsuario, setOlvideUsuario] = useState('')
  const [olvideEnviando, setOlvideEnviando] = useState(false)
  const [olvideMensaje, setOlvideMensaje] = useState('')

  // #toolbarUnificada: el menú "Cuenta" (nombre, Cambiar contraseña, Cerrar sesión) se
  // arma acá porque acá viven sus datos/handlers, pero se renderiza dentro de la toolbar
  // de App.jsx (pasado como render-prop desde main.jsx) para quedar en una sola franja
  // junto con Sincronización y la campanita, en vez de una franja aparte arriba de todo.
  const [cuentaMenuAbierto, setCuentaMenuAbierto] = useState(false)
  const cuentaMenuRef = useRef(null)

  useEffect(() => {
    if (!cuentaMenuAbierto) return
    const alClickearAfuera = (event) => {
      if (cuentaMenuRef.current && !cuentaMenuRef.current.contains(event.target)) {
        setCuentaMenuAbierto(false)
        setMostrarCambioPassword(false)
      }
    }
    document.addEventListener('mousedown', alClickearAfuera)
    return () => document.removeEventListener('mousedown', alClickearAfuera)
  }, [cuentaMenuAbierto])

  const verificarSesion = async () => {
    const token = getToken()
    if (token) {
      try {
        const res = await fetch(`${API_BASE_URL}/api/auth/me`)
        if (res.ok) {
          const data = await res.json()
          // #permisosPorSeccion: refresca localStorage con lo que diga el servidor, no
          // solo el estado de React — Sidebar/UsuariosPanel leen secciones directo de
          // localStorage, así que si un ADMIN cambió los permisos, se ven en el próximo
          // load sin tener que loguear de nuevo.
          // #evitarLoopSesion: refreshStoredUsuario (no setSession) a propósito -- ver la
          // nota en auth.js. Esta misma función está suscripta a SESSION_CHANGED_EVENT más
          // abajo; usar setSession acá la re-dispararía a sí misma sin parar.
          refreshStoredUsuario(token, data)
          setUsuarioState(data)
          setEstado('autenticado')
          return
        }
      } catch {
        // sigue abajo y cae a login/bootstrap
      }
      clearSession()
    }

    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/existe-usuario`)
      const data = await res.json()
      setEstado(data.existeUsuario ? 'login' : 'bootstrap')
    } catch {
      setError('No se pudo conectar con el servidor.')
      setEstado('login')
    }
  }

  useEffect(() => {
    verificarSesion()
    window.addEventListener(SESSION_CHANGED_EVENT, verificarSesion)
    return () => window.removeEventListener(SESSION_CHANGED_EVENT, verificarSesion)
  }, [])

  // #modoOscuro: aplica el atributo que leen los tokens de color de index.css -- corre en
  // cada cambio de "usuario" (login, /me, toggle, logout) para que el tema siempre refleje
  // la preferencia guardada del Usuario logueado. Sin usuario (todavía sin loguearse) cae a
  // claro -- el login no tiene modo oscuro propio, ver #sidebarSiempreOscuro en App.css.
  useEffect(() => {
    document.documentElement.dataset.theme = usuario?.modoOscuro ? 'dark' : 'light'
  }, [usuario])

  const handleLogin = async (event) => {
    event.preventDefault()
    setEnviando(true)
    setError('')
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Usuario: form.Usuario, Password: form.Password }),
      })
      if (!res.ok) {
        setError('Usuario o contraseña incorrectos.')
        return
      }
      const data = await res.json()
      setSession(data.token, { usuarioID: data.usuarioID, nombreCompleto: data.nombreCompleto, rol: data.rol, secciones: data.secciones, modoOscuro: data.modoOscuro })
    } catch {
      setError('No se pudo conectar con el servidor.')
    } finally {
      setEnviando(false)
    }
  }

  const handleBootstrap = async (event) => {
    event.preventDefault()
    setEnviando(true)
    setError('')
    if (form.Password.length < 8) {
      setError('La contraseña debe tener al menos 8 caracteres.')
      setEnviando(false)
      return
    }
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/setup-primer-admin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        setError(data?.message || 'No se pudo crear el usuario administrador.')
        return
      }
      setSession(data.token, { usuarioID: data.usuarioID, nombreCompleto: data.nombreCompleto, rol: data.rol, secciones: data.secciones, modoOscuro: data.modoOscuro })
    } catch {
      setError('No se pudo conectar con el servidor.')
    } finally {
      setEnviando(false)
    }
  }

  const handleOlvide = async (event) => {
    event.preventDefault()
    setOlvideEnviando(true)
    setOlvideMensaje('')
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/olvide-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Usuario: olvideUsuario }),
      })
      const data = await res.json().catch(() => ({}))
      setOlvideMensaje(data?.message || 'Si el usuario existe y tiene un email cargado, te enviamos instrucciones.')
    } catch {
      setOlvideMensaje('No se pudo conectar con el servidor.')
    } finally {
      setOlvideEnviando(false)
    }
  }

  const handleCambiarPassword = async (event) => {
    event.preventDefault()
    setPasswordError('')
    setPasswordExito('')
    if (passwordForm.PasswordNueva.length < 8) {
      setPasswordError('La contraseña nueva debe tener al menos 8 caracteres.')
      return
    }
    if (passwordForm.PasswordNueva !== passwordForm.PasswordConfirmar) {
      setPasswordError('La confirmación no coincide con la contraseña nueva.')
      return
    }
    setCambiandoPassword(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/cambiar-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ PasswordActual: passwordForm.PasswordActual, PasswordNueva: passwordForm.PasswordNueva }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        setPasswordError(data?.message || 'No se pudo cambiar la contraseña.')
        return
      }
      setPasswordExito('Contraseña actualizada.')
      setPasswordForm({ PasswordActual: '', PasswordNueva: '', PasswordConfirmar: '' })
    } catch {
      setPasswordError('No se pudo conectar con el servidor.')
    } finally {
      setCambiandoPassword(false)
    }
  }

  const handleLogout = async () => {
    try {
      await fetch(`${API_BASE_URL}/api/auth/logout`, { method: 'POST' })
    } catch {
      // no bloquea el logout local
    }
    clearSession()
    setUsuarioState(null)
    setForm({ NombreCompleto: '', Usuario: '', Password: '' })
  }

  // #modoOscuro: togglea al toque (estado local + localStorage) y recién después avisa al
  // servidor -- si el PUT falla (sin red, etc.) el tema ya cambió igual, se reintenta solo
  // la próxima vez que el Usuario lo togglee, sin bloquear la UI por un fetch de por medio.
  const toggleModoOscuro = () => {
    const modoOscuro = !usuario?.modoOscuro
    const usuarioActualizado = { ...usuario, modoOscuro }
    setUsuarioState(usuarioActualizado)
    refreshStoredUsuario(getToken(), usuarioActualizado)
    fetch(`${API_BASE_URL}/api/auth/modo-oscuro`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ModoOscuro: modoOscuro }),
    }).catch(() => {
      // el tema ya se aplicó local -- si esto falló, queda desincronizado del servidor
      // hasta el próximo toggle o el próximo /me, sin mensaje de error para algo tan menor
    })
  }

  // #recuperarPassword: la pantalla que abre el link del email funciona sin sesión y
  // sin importar si ya existe un usuario o no — se resuelve antes que cualquier otro
  // estado del gate.
  if (location.pathname === '/reset-password') {
    return <ResetPasswordCard token={new URLSearchParams(location.search).get('token') || ''} onListo={() => navigate('/')} />
  }

  if (estado === 'verificando') {
    return (
      <LoginShell>
        <p className="login-gate-cargando">Cargando…</p>
      </LoginShell>
    )
  }

  if (estado === 'bootstrap' || estado === 'login') {
    const esBootstrap = estado === 'bootstrap'

    if (!esBootstrap && mostrarOlvide) {
      return (
        <LoginShell>
          <form onSubmit={handleOlvide} className="mini-form login-gate-form">
            <h3>Olvidé mi contraseña</h3>
            <p className="erp-panel-subtitle">Ingresá tu usuario y te mandamos un link por email para elegir una contraseña nueva.</p>
            <label>
              Usuario
              <input value={olvideUsuario} onChange={(e) => setOlvideUsuario(e.target.value)} required />
            </label>
            {olvideMensaje && <div className="alert success">{olvideMensaje}</div>}
            <button type="submit" className="primary-button" disabled={olvideEnviando}>
              {olvideEnviando ? 'Enviando…' : 'Enviar instrucciones'}
            </button>
            <button
              type="button"
              className="ghost-button"
              onClick={() => {
                setMostrarOlvide(false)
                setOlvideMensaje('')
                setOlvideUsuario('')
              }}
            >
              Volver al login
            </button>
          </form>
        </LoginShell>
      )
    }

    return (
      <LoginShell>
        <form onSubmit={esBootstrap ? handleBootstrap : handleLogin} className="mini-form login-gate-form">
          <h3>{esBootstrap ? 'Crear administrador' : 'Iniciar sesión'}</h3>
          {esBootstrap && (
            <p className="erp-panel-subtitle">
              Todavía no hay ningún usuario creado. Completá estos datos para crear el primer administrador.
            </p>
          )}
          {esBootstrap && (
            <label>
              Nombre completo
              <input
                value={form.NombreCompleto}
                onChange={(e) => setForm((f) => ({ ...f, NombreCompleto: e.target.value }))}
                required
              />
            </label>
          )}
          <label>
            Usuario
            <input
              value={form.Usuario}
              onChange={(e) => setForm((f) => ({ ...f, Usuario: e.target.value }))}
              required
            />
          </label>
          <label>
            Contraseña
            <input
              type="password"
              value={form.Password}
              onChange={(e) => setForm((f) => ({ ...f, Password: e.target.value }))}
              placeholder={esBootstrap ? 'Mínimo 8 caracteres' : ''}
              required
            />
          </label>
          {error && <div className="alert error">{error}</div>}
          <button type="submit" className="primary-button" disabled={enviando}>
            {enviando ? 'Enviando…' : esBootstrap ? 'Crear administrador' : 'Ingresar'}
          </button>
          {!esBootstrap && (
            <button type="button" className="ghost-button" onClick={() => setMostrarOlvide(true)}>
              ¿Olvidaste tu contraseña?
            </button>
          )}
        </form>
      </LoginShell>
    )
  }

  const accountMenu = (
    <>
      <button
        type="button"
        className="toolbar-dropdown-trigger icon-only"
        onClick={toggleModoOscuro}
        aria-label={usuario?.modoOscuro ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
        title={usuario?.modoOscuro ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
      >
        {usuario?.modoOscuro ? <SunIcon /> : <MoonIcon />}
      </button>
    <div className="toolbar-dropdown" ref={cuentaMenuRef}>
      <button
        type="button"
        className="toolbar-dropdown-trigger icon-only"
        onClick={() => setCuentaMenuAbierto((v) => !v)}
        aria-label={`${usuario?.nombreCompleto} (${usuario?.rol})`}
        title={`${usuario?.nombreCompleto} (${usuario?.rol})`}
      >
        <UserBadgeIcon />
        <span className={`toolbar-dropdown-chevron ${cuentaMenuAbierto ? 'open' : ''}`} aria-hidden="true">▾</span>
      </button>
      {cuentaMenuAbierto && (
        <div className="toolbar-dropdown-panel toolbar-dropdown-panel-cuenta">
          {!mostrarCambioPassword ? (
            <>
              <div className="toolbar-dropdown-username">
                {usuario?.nombreCompleto} <small>({usuario?.rol})</small>
              </div>
              <button
                type="button"
                className="toolbar-dropdown-item"
                onClick={() => {
                  setMostrarCambioPassword(true)
                  setPasswordError('')
                  setPasswordExito('')
                }}
              >
                Cambiar contraseña
              </button>
              <button
                type="button"
                className="toolbar-dropdown-item"
                onClick={() => {
                  setCuentaMenuAbierto(false)
                  handleLogout()
                }}
              >
                Cerrar sesión
              </button>
            </>
          ) : (
            <form onSubmit={handleCambiarPassword} className="mini-form login-gate-cambiar-password-dropdown">
              <h4>Cambiar contraseña</h4>
              <label>
                Contraseña actual
                <input
                  type="password"
                  value={passwordForm.PasswordActual}
                  onChange={(e) => setPasswordForm((f) => ({ ...f, PasswordActual: e.target.value }))}
                  required
                />
              </label>
              <label>
                Contraseña nueva
                <input
                  type="password"
                  value={passwordForm.PasswordNueva}
                  onChange={(e) => setPasswordForm((f) => ({ ...f, PasswordNueva: e.target.value }))}
                  placeholder="Mínimo 8 caracteres"
                  required
                />
              </label>
              <label>
                Confirmar contraseña nueva
                <input
                  type="password"
                  value={passwordForm.PasswordConfirmar}
                  onChange={(e) => setPasswordForm((f) => ({ ...f, PasswordConfirmar: e.target.value }))}
                  required
                />
              </label>
              {passwordError && <div className="alert error">{passwordError}</div>}
              {passwordExito && <div className="alert success">{passwordExito}</div>}
              <div className="login-gate-cambiar-password-acciones">
                <button type="submit" className="primary-button" disabled={cambiandoPassword}>
                  {cambiandoPassword ? 'Guardando…' : 'Guardar contraseña'}
                </button>
                <button type="button" className="ghost-button" onClick={() => setMostrarCambioPassword(false)}>
                  Volver
                </button>
              </div>
            </form>
          )}
        </div>
      )}
    </div>
    </>
  )

  return children(accountMenu)
}

// #loginMasAtractivo: shell compartido por todas las pantallas sin sesión (login,
// bootstrap, olvidé mi contraseña, reset por email) — logo de marca arriba de cada
// formulario, tarjeta blanca flotando sobre un fondo con degradé (mismos colores que
// el degradé del sidebar) en vez del gris plano que había antes.
function LoginShell({ children }) {
  return (
    <div className="login-gate-shell">
      <div className="login-gate-card">
        <div className="login-gate-branding">
          <div className="login-gate-logo" role="img" aria-label="Pricing Engine" />
          <p className="login-gate-tagline">Pricing inteligente para MercadoLibre</p>
        </div>
        <div className="login-gate-panel">{children}</div>
      </div>
    </div>
  )
}

// #recuperarPassword: formulario que abre el link del email — pide la contraseña nueva
// dos veces y la manda junto con el token de un solo uso que viene en la URL.
function ResetPasswordCard({ token, onListo }) {
  const [passwordNueva, setPasswordNueva] = useState('')
  const [passwordConfirmar, setPasswordConfirmar] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')
  const [exito, setExito] = useState(false)

  const handleSubmit = async (event) => {
    event.preventDefault()
    setError('')
    if (!token) {
      setError('El link no incluye un token válido. Pedí uno nuevo desde "Olvidé mi contraseña".')
      return
    }
    if (passwordNueva.length < 8) {
      setError('La contraseña debe tener al menos 8 caracteres.')
      return
    }
    if (passwordNueva !== passwordConfirmar) {
      setError('La confirmación no coincide con la contraseña nueva.')
      return
    }
    setEnviando(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/resetear-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Token: token, PasswordNueva: passwordNueva }),
      })
      if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        setError(data?.message || 'No se pudo restablecer la contraseña.')
        return
      }
      setExito(true)
    } catch {
      setError('No se pudo conectar con el servidor.')
    } finally {
      setEnviando(false)
    }
  }

  if (exito) {
    return (
      <LoginShell>
        <div className="mini-form login-gate-form">
          <h3>Contraseña actualizada</h3>
          <p className="erp-panel-subtitle">Ya podés iniciar sesión con tu contraseña nueva.</p>
          <button type="button" className="primary-button" onClick={onListo}>
            Ir al login
          </button>
        </div>
      </LoginShell>
    )
  }

  return (
    <LoginShell>
      <form onSubmit={handleSubmit} className="mini-form login-gate-form">
        <h3>Elegir contraseña nueva</h3>
        <label>
          Contraseña nueva
          <input
            type="password"
            value={passwordNueva}
            onChange={(e) => setPasswordNueva(e.target.value)}
            placeholder="Mínimo 8 caracteres"
            required
          />
        </label>
        <label>
          Confirmar contraseña nueva
          <input type="password" value={passwordConfirmar} onChange={(e) => setPasswordConfirmar(e.target.value)} required />
        </label>
        {error && <div className="alert error">{error}</div>}
        <button type="submit" className="primary-button" disabled={enviando}>
          {enviando ? 'Guardando…' : 'Guardar contraseña'}
        </button>
      </form>
    </LoginShell>
  )
}

export default LoginGate
