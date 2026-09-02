import { createContext, useContext, useEffect, useState } from 'react'

// #barraDePantalla: la .screen-toolbar (ScreenToolbar.jsx) es global -- vive una sola vez
// en App.jsx, arriba de <Routes>, siempre visible. Cada pantalla no la renderiza: le avisa
// qué acciones le corresponden a través de este contexto. { onClick: fn } habilita el
// ícono; null lo deja deshabilitado. toggleFilters además lleva `active` para el estado
// visual de "abierto/cerrado" de la carpeta. edit/delete (hoja+lápiz / cruz roja) solo se
// habilitan en los 13 ABMs de AdminPanel.jsx, cuando hay un registro abierto.
const DEFAULT_CONFIG = { newRecord: null, toggleFilters: null, edit: null, delete: null, save: null }

const ToolbarContext = createContext({ config: DEFAULT_CONFIG, setConfig: () => {} })

export function ToolbarProvider({ children }) {
  const [config, setConfig] = useState(DEFAULT_CONFIG)
  return <ToolbarContext.Provider value={{ config, setConfig }}>{children}</ToolbarContext.Provider>
}

export function useToolbarConfig() {
  return useContext(ToolbarContext).config
}

// #registroDeBarraDePantalla: cada pantalla llama este hook con lo que le corresponde
// (ej. { save: { onClick: handleSave } }) -- se completa con null lo que no se pasa, y se
// resetea todo a deshabilitado cuando la pantalla se desmonta, para que la próxima pantalla
// no herede acciones de la anterior mientras React todavía no montó la nueva.
// #pestañasVariasMontadasALaVez: desde que una pantalla puede quedar montada en segundo
// plano (pestaña abierta pero no activa, ver TabsContext.jsx), ya no alcanza con desmontar
// para dejar de pisar la barra -- una pestaña de fondo NO puede tocar el toolbar global en
// absoluto, ni para setearlo ni para resetearlo, porque podría pisar a la pestaña que sí
// está activa. isActive (default true, así ninguna pantalla no-tabbed tiene que cambiar)
// hace que el registro entero sea un no-op mientras la pestaña no es la visible.
export function useRegisterToolbar(partialConfig, deps, isActive = true) {
  const { setConfig } = useContext(ToolbarContext)
  useEffect(() => {
    if (!isActive) return undefined
    setConfig({ ...DEFAULT_CONFIG, ...partialConfig })
    return () => setConfig(DEFAULT_CONFIG)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, isActive])
}
