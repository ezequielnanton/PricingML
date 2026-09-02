import { API_BASE_URL } from './apiBase'
import { getToken, clearSession } from './auth'

// #loginGeneralApp: agrega el Authorization Bearer a todo request contra nuestra propia
// API sin tener que retocar cada uno de los fetch() ya escritos en los componentes —
// hay más de una decena de pantallas que llaman fetch directamente. Importar este
// módulo una sola vez (en main.jsx, antes de renderizar) alcanza para cubrirlas todas.
// Si la API devuelve 401 (sesión vencida o inexistente), limpia la sesión guardada para
// que LoginGate vuelva a mostrar el formulario de login.
const originalFetch = window.fetch.bind(window)

window.fetch = async (input, init = {}) => {
  const url = typeof input === 'string' || input instanceof URL ? String(input) : input.url
  if (!url.startsWith(API_BASE_URL)) {
    return originalFetch(input, init)
  }

  const token = getToken()
  const headers = new Headers(init.headers ?? (typeof input === 'object' && 'headers' in input ? input.headers : undefined))
  if (token && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const response = await originalFetch(input, { ...init, headers })
  if (response.status === 401) {
    clearSession()
  }
  return response
}
