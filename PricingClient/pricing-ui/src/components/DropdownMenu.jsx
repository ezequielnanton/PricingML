import { useEffect, useRef, useState } from 'react'

// #toolbarUnificada: menú desplegable genérico para agrupar botones sueltos de la
// toolbar (Sincronización, etc.) en un solo trigger — se cierra solo al hacer click en
// cualquier ítem de adentro o en cualquier lugar afuera del menú.
function DropdownMenu({ label, icon, iconOnly = false, children }) {
  const [abierto, setAbierto] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    if (!abierto) return
    const alClickearAfuera = (event) => {
      if (ref.current && !ref.current.contains(event.target)) setAbierto(false)
    }
    document.addEventListener('mousedown', alClickearAfuera)
    return () => document.removeEventListener('mousedown', alClickearAfuera)
  }, [abierto])

  return (
    <div className="toolbar-dropdown" ref={ref}>
      <button
        type="button"
        className={iconOnly ? 'toolbar-dropdown-trigger icon-only' : 'toolbar-dropdown-trigger'}
        onClick={() => setAbierto((v) => !v)}
        aria-label={label}
        title={iconOnly ? label : undefined}
      >
        {icon}
        {!iconOnly && <span>{label}</span>}
        <span className={`toolbar-dropdown-chevron ${abierto ? 'open' : ''}`} aria-hidden="true">▾</span>
      </button>
      {abierto && (
        <div className="toolbar-dropdown-panel" onClick={() => setAbierto(false)}>
          {children}
        </div>
      )}
    </div>
  )
}

export default DropdownMenu
