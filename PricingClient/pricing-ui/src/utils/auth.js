// #loginGeneralApp: sesión del Usuario logueado (AdminPanel, Cola ML, Integraciones,
// Reportes, Pricing) guardada en localStorage. No confundir con el token de Repositor,
// que vive aparte (RepositorApp) y protege una superficie de endpoints distinta.
const TOKEN_KEY = 'pricingUiToken'
const USUARIO_KEY = 'pricingUiUsuario'
export const SESSION_CHANGED_EVENT = 'pricing-ui-session-changed'

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function getUsuario() {
  try {
    return JSON.parse(localStorage.getItem(USUARIO_KEY) || 'null')
  } catch {
    return null
  }
}

export function setSession(token, usuario) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USUARIO_KEY, JSON.stringify(usuario))
  window.dispatchEvent(new Event(SESSION_CHANGED_EVENT))
}

// #evitarLoopSesion: refresca localStorage con lo que ya confirmó el servidor SIN volver
// a disparar SESSION_CHANGED_EVENT. LoginGate usa esto en su propio re-chequeo periódico
// de sesión (verificarSesion) en vez de setSession: como verificarSesion está suscripta a
// ese mismo evento (para reaccionar a un login/logout real disparado en otro lado), si
// verificarSesion llamaba a setSession en su propio camino de éxito, se retriggereaba a sí
// misma sin parar — un fetch a /api/auth/me tras otro, frenado solo por la latencia de red.
export function refreshStoredUsuario(token, usuario) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USUARIO_KEY, JSON.stringify(usuario))
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USUARIO_KEY)
  window.dispatchEvent(new Event(SESSION_CHANGED_EVENT))
}

// #permisosPorSeccion: qué secciones (ids de NAV_ITEMS en Sidebar.jsx) puede VER el
// usuario logueado. Control de visibilidad en la UI — el límite real de escritura es
// el Rol (ADMIN/LECTURA), aplicado por el backend a toda la API sin distinguir sección.
export function hasSeccion(seccionId) {
  const usuario = getUsuario()
  return Array.isArray(usuario?.secciones) && usuario.secciones.includes(seccionId)
}

// #soloAdminEnConfiguracion: todo lo que cuelga de "Configuración" en el menú pide además
// Rol=ADMIN (ver SectionGuard soloAdmin y AdminPanel para las pestañas de /admin que viven
// ahí) -- un LECTURA con la Sección tildada ya no alcanza para verlas.
export function esAdmin() {
  return getUsuario()?.rol === 'ADMIN'
}
