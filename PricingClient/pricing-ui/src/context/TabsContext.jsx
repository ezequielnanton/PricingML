import { createContext, useContext, useState } from 'react'

// #pestañaInicioFija: "Inicio" arranca siempre abierta y no se puede cerrar (pinned: true),
// para que cerrar todas las demás pestañas nunca deje el panel principal en blanco.
export const INICIO_TAB = { key: 'pricing', kind: 'pricing-home', label: 'Inicio', path: '/', pinned: true }

// #pestañasDeLaApp: registro de qué pantallas están abiertas a la vez (una por cada ítem
// hoja del menú que se haya clickeado, ver Sidebar.jsx) y cuál es la visible. Todas las
// pestañas abiertas quedan MONTADAS a la vez (App.jsx las renderiza todas, ocultando con
// CSS las que no son la activa) -- por eso cambiar de pestaña no pierde lo que estabas
// tipeando en las demás, a diferencia de <Routes> de react-router, que desmonta la pantalla
// anterior en cada navegación.
const TabsContext = createContext({ openTabs: [INICIO_TAB], activeTabKey: INICIO_TAB.key, openTab: () => {}, closeTab: () => {} })

export function TabsProvider({ children }) {
  const [openTabs, setOpenTabs] = useState([INICIO_TAB])
  const [activeTabKey, setActiveTabKey] = useState(INICIO_TAB.key)

  // #reusarPestañaExistente: clickear de nuevo un ítem del menú que ya está abierto no
  // duplica la pestaña -- la activa tal cual está (con lo que ya tenía cargado).
  const openTab = (tab) => {
    setOpenTabs((current) => (current.some((t) => t.key === tab.key) ? current : [...current, tab]))
    setActiveTabKey(tab.key)
  }

  // #vecinoAlCerrar: si se cierra la pestaña activa, pasa a estar activa la que queda a su
  // izquierda (o la primera que quede, si cerrás la primera) -- como "Inicio" nunca se
  // cierra (ver #pestañaInicioFija), siempre queda al menos una pestaña, nunca hay que caer
  // a "ninguna activa".
  const closeTab = (key) => {
    setOpenTabs((current) => {
      const index = current.findIndex((t) => t.key === key)
      if (index === -1 || current[index].pinned) return current
      const next = current.filter((t) => t.key !== key)
      if (activeTabKey === key) {
        const vecino = next[index - 1] || next[0] || null
        setActiveTabKey(vecino ? vecino.key : null)
      }
      return next
    })
  }

  const switchTab = (key) => setActiveTabKey(key)

  return (
    <TabsContext.Provider value={{ openTabs, activeTabKey, openTab, closeTab, switchTab }}>
      {children}
    </TabsContext.Provider>
  )
}

export function useTabs() {
  return useContext(TabsContext)
}
