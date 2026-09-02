import { useEffect, useRef, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import { hasSeccion } from '../utils/auth'
import { useTabs } from '../context/TabsContext'

const POLL_MS = 30000

// #avisoPendientesColaMl: campanita en el header que avisa cuántos cambios de precio
// esperan aprobación en "Cola ML (Aprobación)", sin tener que entrar a esa pantalla para
// enterarse. Por ahora la única fuente de notificaciones es esa cola; cada notificación
// lleva siempre ahí al clickearla (no hay todavía otras pantallas que notifiquen).
function NotificationBell() {
  const { openTab } = useTabs()
  const [items, setItems] = useState([])
  const [open, setOpen] = useState(false)
  const contenedorRef = useRef(null)

  const puedeVerColaMl = hasSeccion('cola-ml-aprobacion')

  const cargar = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/cola-aprobacion`)
      if (!res.ok) return
      const data = await res.json()
      setItems(Array.isArray(data) ? data : [])
    } catch {
      // silencioso: la campanita no debe interrumpir el resto de la app si falla
    }
  }

  useEffect(() => {
    if (!puedeVerColaMl) return
    cargar()
    const interval = setInterval(cargar, POLL_MS)
    return () => clearInterval(interval)
  }, [puedeVerColaMl])

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (contenedorRef.current && !contenedorRef.current.contains(event.target)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  if (!puedeVerColaMl) return null

  // #clickAbrePestaña: mismo mecanismo que el resto del menú (ver onSelect en App.jsx) --
  // navigate() de react-router por sí solo cambia la URL pero no abre/activa la pestaña
  // (el efecto que sincroniza URL -> pestaña corre una sola vez al montar la app, no en
  // cada navegación posterior), así que un click acá no llevaba a ningún lado visible.
  const irACola = () => {
    setOpen(false)
    openTab({ key: 'cola-ml-aprobacion', kind: 'standalone', screenId: 'cola-ml-aprobacion', label: 'Cola ML (Aprobación)', path: '/cola-ml-aprobacion' })
  }

  return (
    <div className="notification-bell-container" ref={contenedorRef}>
      <button
        type="button"
        className="notification-bell-button"
        onClick={() => setOpen((v) => !v)}
        aria-label="Notificaciones"
      >
        🔔
        {items.length > 0 && <span className="notification-badge">{items.length}</span>}
      </button>

      {open && (
        <div className="notification-dropdown">
          {items.length === 0 ? (
            <p className="notification-empty">No hay notificaciones.</p>
          ) : (
            <>
              {items.map((item) => (
                <button key={item.colaID} type="button" className="notification-item" onClick={irACola}>
                  <strong>{item.titulo}</strong>
                  <span>
                    SKU {item.sku} · {item.accionRequerida === 'AUMENTAR_PRECIO' ? 'Subir' : 'Bajar'} a $
                    {item.precioNuevo.toFixed(2)}
                  </span>
                </button>
              ))}
            </>
          )}
        </div>
      )}
    </div>
  )
}

export default NotificationBell
