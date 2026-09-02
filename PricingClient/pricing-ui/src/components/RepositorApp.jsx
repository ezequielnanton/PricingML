import { useEffect, useRef, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import ResultToast from './ResultToast'
import './RepositorApp.css'

const TOKEN_KEY = 'repositor.token'
const NOMBRE_KEY = 'repositor.nombre'

// #cargaOperativaRepositor: pantalla standalone (sin sidebar/admin) pensada para un
// dispositivo de depósito. Login por Usuario+PIN, después un loop de escaneo de SKU
// -> confirmar/ajustar stock -> guardar, listo para el siguiente producto.
function RepositorApp() {
  const [token, setToken] = useState(() => sessionStorage.getItem(TOKEN_KEY) || '')
  const [nombre, setNombre] = useState(() => sessionStorage.getItem(NOMBRE_KEY) || '')

  const [usuario, setUsuario] = useState('')
  const [pin, setPin] = useState('')
  const [loginError, setLoginError] = useState('')
  const [loginLoading, setLoginLoading] = useState(false)

  const [sku, setSku] = useState('')
  const [producto, setProducto] = useState(null)
  const [stockNuevo, setStockNuevo] = useState('')
  const [lookupError, setLookupError] = useState('')
  const [lookupLoading, setLookupLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [toast, setToast] = useState(null)

  const skuInputRef = useRef(null)
  const stockInputRef = useRef(null)

  useEffect(() => {
    if (!toast) return
    const timer = setTimeout(() => setToast(null), 4000)
    return () => clearTimeout(timer)
  }, [toast])

  const clearSession = () => {
    sessionStorage.removeItem(TOKEN_KEY)
    sessionStorage.removeItem(NOMBRE_KEY)
    setToken('')
    setNombre('')
    setProducto(null)
    setSku('')
    setStockNuevo('')
  }

  const handleLogin = async (event) => {
    event.preventDefault()
    setLoginError('')
    setLoginLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/input/repositor/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ usuario, pin }),
      })
      if (!res.ok) {
        setLoginError('Usuario o PIN incorrecto.')
        return
      }
      const data = await res.json()
      sessionStorage.setItem(TOKEN_KEY, data.token)
      sessionStorage.setItem(NOMBRE_KEY, data.nombreCompleto)
      setToken(data.token)
      setNombre(data.nombreCompleto)
      setPin('')
    } catch {
      setLoginError('No se pudo conectar con el servidor.')
    } finally {
      setLoginLoading(false)
    }
  }

  const handleLookup = async (event) => {
    event.preventDefault()
    const skuTrim = sku.trim()
    if (!skuTrim) return
    setLookupError('')
    setLookupLoading(true)
    setProducto(null)
    try {
      const res = await fetch(`${API_BASE_URL}/api/input/stock/lookup?sku=${encodeURIComponent(skuTrim)}`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) {
        clearSession()
        return
      }
      if (!res.ok) {
        setLookupError('SKU no encontrado.')
        return
      }
      const data = await res.json()
      setProducto(data)
      setStockNuevo(String(data.stockActual))
      setTimeout(() => stockInputRef.current?.focus(), 0)
    } catch {
      setLookupError('No se pudo conectar con el servidor.')
    } finally {
      setLookupLoading(false)
    }
  }

  const handleGuardar = async (event) => {
    event.preventDefault()
    if (!producto) return
    const nuevo = Number(stockNuevo)
    if (!Number.isInteger(nuevo) || nuevo < 0) {
      setLookupError('Ingresá una cantidad válida.')
      return
    }
    setSaving(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/input/stock`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ sku: producto.sku, stockNuevo: nuevo }),
      })
      if (res.status === 401) {
        clearSession()
        return
      }
      if (!res.ok) {
        setToast({ type: 'error', message: 'No se pudo guardar el stock.' })
        return
      }
      const data = await res.json()
      setToast({
        type: 'success',
        message: `${data.sku}: stock actualizado de ${data.stockAnterior} a ${data.stockNuevo}.`,
      })
      setProducto(null)
      setSku('')
      setStockNuevo('')
      setTimeout(() => skuInputRef.current?.focus(), 0)
    } catch {
      setToast({ type: 'error', message: 'No se pudo conectar con el servidor.' })
    } finally {
      setSaving(false)
    }
  }

  if (!token) {
    return (
      <div className="repositor-screen">
        <div className="repositor-card">
          <h1>Carga de stock</h1>
          <p className="repositor-subtitle">Ingresá tu usuario y PIN para empezar.</p>
          <form onSubmit={handleLogin} className="repositor-form">
            <label>
              Usuario
              <input value={usuario} onChange={(event) => setUsuario(event.target.value)} autoFocus required />
            </label>
            <label>
              PIN
              <input
                value={pin}
                onChange={(event) => setPin(event.target.value.replace(/\D/g, ''))}
                type="password"
                inputMode="numeric"
                pattern="[0-9]*"
                required
              />
            </label>
            {loginError && <p className="repositor-error">{loginError}</p>}
            <button type="submit" className="repositor-button" disabled={loginLoading}>
              {loginLoading ? 'Ingresando…' : 'Ingresar'}
            </button>
          </form>
        </div>
      </div>
    )
  }

  return (
    <div className="repositor-screen">
      <div className="repositor-card">
        <div className="repositor-header">
          <div>
            <h1>Carga de stock</h1>
            <p className="repositor-subtitle">Hola, {nombre}</p>
          </div>
          <button type="button" className="repositor-link-button" onClick={clearSession}>
            Salir
          </button>
        </div>

        <form onSubmit={handleLookup} className="repositor-form">
          <label>
            SKU / código de barras
            <input
              ref={skuInputRef}
              value={sku}
              onChange={(event) => setSku(event.target.value)}
              autoFocus
              autoComplete="off"
            />
          </label>
          {lookupError && <p className="repositor-error">{lookupError}</p>}
          <button type="submit" className="repositor-button repositor-button-secondary" disabled={lookupLoading}>
            {lookupLoading ? 'Buscando…' : 'Buscar'}
          </button>
        </form>

        {producto && (
          <form onSubmit={handleGuardar} className="repositor-form repositor-form-producto">
            <div className="repositor-producto-info">
              <strong>{producto.titulo}</strong>
              <span>SKU {producto.sku}</span>
              <span>Stock actual: {producto.stockActual}</span>
            </div>
            <label>
              Nuevo recuento de stock
              <input
                ref={stockInputRef}
                value={stockNuevo}
                onChange={(event) => setStockNuevo(event.target.value.replace(/\D/g, ''))}
                inputMode="numeric"
                pattern="[0-9]*"
                required
              />
            </label>
            <button type="submit" className="repositor-button" disabled={saving}>
              {saving ? 'Guardando…' : 'Guardar recuento'}
            </button>
          </form>
        )}
      </div>

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </div>
  )
}

export default RepositorApp
