import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import ResultToast from './ResultToast'
import { useRegisterToolbar } from '../context/ToolbarContext'

// #ejecucionAutomatica: prender/apagar el ciclo completo (ERP -> evaluar todos los
// productos -> procesar cola ML -> sincronizar ML) sin apretar los 4 botones del
// header a mano. Config simple: on/off + cada cuántos minutos, sin horarios
// específicos — el backend revisa cada un minuto si ya toca correr de nuevo.
function EjecucionAutomaticaPanel({ isActiveTab = true }) {
  const [activo, setActivo] = useState(false)
  const [intervaloMinutos, setIntervaloMinutos] = useState(30)
  const [ultimaEjecucion, setUltimaEjecucion] = useState(null)
  const [ultimoResultadoOk, setUltimoResultadoOk] = useState(null)
  const [ultimoResultadoResumen, setUltimoResultadoResumen] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [ejecutandoAhora, setEjecutandoAhora] = useState(false)
  const [toast, setToast] = useState(null)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const cargar = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/ejecucion-automatica`)
      const data = await res.json()
      setActivo(!!data.activo)
      setIntervaloMinutos(data.intervaloMinutos ?? 30)
      setUltimaEjecucion(data.ultimaEjecucion)
      setUltimoResultadoOk(data.ultimoResultadoOk)
      setUltimoResultadoResumen(data.ultimoResultadoResumen)
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  const handleGuardar = async () => {
    setSaving(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/ejecucion-automatica`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Activo: activo, IntervaloMinutos: Number(intervaloMinutos) || 30 }),
      })
      if (!res.ok) throw new Error()
      notify('success', 'Configuración guardada.')
      await cargar()
    } catch {
      notify('error', 'No se pudo guardar la configuración.')
    } finally {
      setSaving(false)
    }
  }

  const handleEjecutarAhora = async () => {
    setEjecutandoAhora(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/ejecucion-automatica/ejecutar-ahora`, { method: 'POST' })
      if (!res.ok) throw new Error()
      const data = await res.json()
      setUltimaEjecucion(data.ultimaEjecucion)
      setUltimoResultadoOk(data.ultimoResultadoOk)
      setUltimoResultadoResumen(data.ultimoResultadoResumen)
      notify(data.ultimoResultadoOk ? 'success' : 'error', 'Ciclo ejecutado. Ver resultado abajo.')
    } catch {
      notify('error', 'No se pudo ejecutar el ciclo.')
    } finally {
      setEjecutandoAhora(false)
    }
  }

  // #barraDePantalla: reemplaza el botón "Guardar" -- ver ScreenToolbar.jsx / ToolbarContext.jsx.
  // #closureObsoletaBarraDePantalla: los deps tienen que incluir todos los campos que lee
  // handleGuardar -- ver misma nota en IntegracionMercadoLibrePanel.jsx / AdminPanel.jsx.
  useRegisterToolbar({
    save: !loading && !saving ? { onClick: handleGuardar } : null,
  }, [loading, saving, activo, intervaloMinutos], isActiveTab)

  return (
    <section className="panel erp-integracion-panel">
      <h3>Ejecución automática</h3>
      <p className="erp-panel-subtitle">
        Corre solo, cada tantos minutos, el mismo ciclo completo de los botones del header: Actualizar desde ERP,
        evaluar todos los productos activos (persistiendo la decisión), Procesar cola ML y Sincronizar ML.
      </p>

      {loading ? (
        <p className="erp-panel-subtitle">Cargando…</p>
      ) : (
        <>
          <form onSubmit={(event) => { event.preventDefault(); handleGuardar() }} className="mini-form">
            <label className="checkbox-row">
              <input type="checkbox" checked={activo} onChange={(e) => setActivo(e.target.checked)} />
              Activar ejecución automática
            </label>
            <label>
              Cada cuántos minutos
              <input
                type="number"
                min="1"
                value={intervaloMinutos}
                onChange={(e) => setIntervaloMinutos(e.target.value)}
              />
            </label>
          </form>

          <div className="ejecucion-automatica-estado">
            <h4>Última corrida</h4>
            {ultimaEjecucion ? (
              <>
                <p>
                  {new Date(ultimaEjecucion).toLocaleString()} —{' '}
                  <span className={ultimoResultadoOk ? 'ejecucion-ok' : 'ejecucion-error'}>
                    {ultimoResultadoOk ? 'OK' : 'Con errores'}
                  </span>
                </p>
                {ultimoResultadoResumen && <p className="erp-panel-subtitle">{ultimoResultadoResumen}</p>}
              </>
            ) : (
              <p className="erp-panel-subtitle">Todavía no corrió ninguna vez.</p>
            )}
            <button type="button" className="secondary-button" onClick={handleEjecutarAhora} disabled={ejecutandoAhora}>
              {ejecutandoAhora ? 'Ejecutando…' : 'Ejecutar ahora'}
            </button>
          </div>
        </>
      )}

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </section>
  )
}

export default EjecucionAutomaticaPanel
