import { useTabs } from '../context/TabsContext'

// #barraDePestañas: una fila de pestañas abiertas (ver TabsContext.jsx) arriba del
// contenido -- clickear el label activa esa pestaña, clickear la × la cierra sin activarla
// primero (por eso stopPropagation).
function TabBar() {
  const { openTabs, activeTabKey, switchTab, closeTab } = useTabs()

  if (openTabs.length === 0) return null

  return (
    <div className="tab-bar">
      {openTabs.map((tab) => (
        <button
          type="button"
          key={tab.key}
          className={tab.key === activeTabKey ? 'tab-bar-item active' : 'tab-bar-item'}
          onClick={() => switchTab(tab.key)}
        >
          <span className="tab-bar-item-label">{tab.label}</span>
          {!tab.pinned && (
            <span
              className="tab-bar-item-close"
              role="button"
              aria-label={`Cerrar pestaña ${tab.label}`}
              onClick={(event) => {
                event.stopPropagation()
                closeTab(tab.key)
              }}
            >
              ×
            </span>
          )}
        </button>
      ))}
    </div>
  )
}

export default TabBar
