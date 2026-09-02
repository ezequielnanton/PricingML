import { useEffect, useRef } from 'react'

const WIDTH_MIN = 260
const WIDTH_MAX = 560

// #anchoColumnaRedimensionable: mismo patrón que .sidebar-resize-handle (App.jsx), pero acá
// no hace falta position:fixed ni coordinar con --sidebar-width -- la manija vive como
// último hijo DENTRO de .abm-list-column (que ya es position:sticky, o sea "positioned" para
// sus descendientes absolutos), así que right:-3px la deja pegada al borde derecho de la
// columna sin importar cuánto mida el sidebar ni si está colapsado, y sigue el scroll sticky
// de la columna sola. El ancho se guarda en una variable CSS global (--abm-list-column-width,
// leída por .abm-layout/.reports-layout) en vez de React state, para que valga para todas
// las pestañas de Formularios y para Reportes a la vez sin prop drilling.
function AbmColumnResizeHandle() {
  const handleRef = useRef(null)

  useEffect(() => {
    if (!handleRef.current) return undefined
    const alMover = (event) => {
      const columna = handleRef.current?.parentElement
      if (!columna) return
      const rect = columna.getBoundingClientRect()
      const nuevoAncho = Math.min(WIDTH_MAX, Math.max(WIDTH_MIN, event.clientX - rect.left))
      document.documentElement.style.setProperty('--abm-list-column-width', `${nuevoAncho}px`)
    }
    const alSoltar = () => {
      document.removeEventListener('mousemove', alMover)
      document.removeEventListener('mouseup', alSoltar)
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
    }
    const alBajarElMouse = (event) => {
      event.preventDefault()
      document.addEventListener('mousemove', alMover)
      document.addEventListener('mouseup', alSoltar)
      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
    }
    const handle = handleRef.current
    handle.addEventListener('mousedown', alBajarElMouse)
    return () => {
      handle.removeEventListener('mousedown', alBajarElMouse)
      document.removeEventListener('mousemove', alMover)
      document.removeEventListener('mouseup', alSoltar)
    }
  }, [])

  return <div className="abm-column-resize-handle" ref={handleRef} />
}

export default AbmColumnResizeHandle
