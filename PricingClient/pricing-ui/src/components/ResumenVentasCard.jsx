import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'

const formatoMoneda = (valor) =>
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(valor ?? 0)

// #barrasPorVentana: no hay ventas por día reales en el sistema (MetricasVentasHist
// guarda totales acumulados por ventana rodante, no un ledger diario) — este gráfico de
// barras compara las ventanas 7/15/30/60/90 días que sí existen, en vez de simular una
// granularidad diaria que no se puede sostener con los datos disponibles.
function VentanaBarChart({ ventanas }) {
  if (!ventanas || ventanas.length === 0) return null
  const max = Math.max(1, ...ventanas.map((v) => v.unidadesVendidas))
  const alturaMax = 190

  return (
    <div className="resumen-ventas-chart-card">
      <span className="resumen-ventas-label">Unidades vendidas por ventana</span>
      <span className="resumen-ventas-hint">
        Unidades vendidas acumuladas en cada ventana (7/15/30/60/90 días) — no hay dato de venta por día
      </span>
      <div className="ventana-bar-chart">
        {ventanas.map((v) => {
          const altura = Math.round((v.unidadesVendidas / max) * alturaMax)
          return (
            <div className="ventana-bar-col" key={v.dias}>
              <span className="ventana-bar-valor">{v.unidadesVendidas}</span>
              <div className="ventana-bar-track">
                <div className="ventana-bar-fill" style={{ height: `${Math.max(altura, 2)}px` }} />
              </div>
              <span className="ventana-bar-label">{v.dias}D</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// #tortaCostoRentabilidad: dos porciones que suman la Venta Bruta Total, el mismo
// desglose que ya muestran las tres tarjetas de arriba pero en formato visual. Si la
// rentabilidad es negativa (costo superó la venta bruta) o no hay venta bruta, una torta
// de 2 porciones ya no representa nada coherente (no suman 100% de algo positivo), así
// que se omite en vez de dibujar un gráfico engañoso.
function CostoRentabilidadPie({ ventaBrutaTotal, costoTotal, rentabilidad }) {
  if (!ventaBrutaTotal || ventaBrutaTotal <= 0 || rentabilidad < 0) return null

  const r = 52
  const circunferencia = 2 * Math.PI * r
  const pctCosto = costoTotal / ventaBrutaTotal
  const pctRentabilidad = rentabilidad / ventaBrutaTotal

  return (
    <div className="resumen-ventas-chart-card">
      <span className="resumen-ventas-label">Costo total vs. rentabilidad</span>
      <span className="resumen-ventas-hint">Costo total y Rentabilidad como porcentaje de la Venta bruta total</span>
      <div className="pie-chart-row">
        <svg viewBox="0 0 120 120" className="pie-chart-svg" role="img" aria-label="Costo total vs rentabilidad">
          <circle cx="60" cy="60" r={r} fill="none" stroke="var(--color-primary)" strokeWidth="20"
            strokeDasharray={`${circunferencia * pctCosto} ${circunferencia}`} transform="rotate(-90 60 60)" />
          <circle cx="60" cy="60" r={r} fill="none" stroke="#15803d" strokeWidth="20"
            strokeDasharray={`${circunferencia * pctRentabilidad} ${circunferencia}`}
            strokeDashoffset={-circunferencia * pctCosto} transform="rotate(-90 60 60)" />
        </svg>
        <div className="pie-chart-legend">
          <div className="pie-chart-legend-item">
            <span className="pie-chart-swatch" style={{ background: 'var(--color-primary)' }} />
            Costo total ({(pctCosto * 100).toFixed(1)}%)
          </div>
          <div className="pie-chart-legend-item">
            <span className="pie-chart-swatch" style={{ background: '#15803d' }} />
            Rentabilidad ({(pctRentabilidad * 100).toFixed(1)}%)
          </div>
        </div>
      </div>
    </div>
  )
}

// #resumenVentasPantallaPrincipal: venta bruta / costo total / rentabilidad al entrar a
// Pricing. Es una aproximación (unidades vendidas en los últimos 30 días × precio/costo
// ACTUAL, no el precio real de cada venta en su momento) porque el sistema no guarda un
// historial de órdenes, solo cantidades por ventana rodante — por eso el rótulo aclara
// "aprox." y la ventana de tiempo.
function ResumenVentasCard() {
  const [resumen, setResumen] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)

  useEffect(() => {
    let cancelado = false
    const cargar = async () => {
      setLoading(true)
      setError(false)
      try {
        const res = await fetch(`${API_BASE_URL}/api/admin/resumen-ventas`)
        if (!res.ok) throw new Error()
        const data = await res.json()
        if (!cancelado) setResumen(data)
      } catch {
        if (!cancelado) setError(true)
      } finally {
        if (!cancelado) setLoading(false)
      }
    }
    cargar()
    return () => {
      cancelado = true
    }
  }, [])

  if (loading) {
    return (
      <section className="panel resumen-ventas-card">
        <p className="erp-panel-subtitle">Cargando resumen de ventas…</p>
      </section>
    )
  }

  if (error || !resumen) {
    return null
  }

  return (
    <section className="panel resumen-ventas-card">
      <div className="resumen-ventas-header">
        <h3>Resumen de ventas</h3>
        <span className="erp-panel-subtitle">
          Últimos {resumen.ventanaDias} días (aprox.: unidades vendidas × precio/costo actual)
        </span>
      </div>
      <div className="resumen-ventas-grid">
        <div className="resumen-ventas-item">
          <span className="resumen-ventas-label">Venta bruta total</span>
          <span className="resumen-ventas-valor">{formatoMoneda(resumen.ventaBrutaTotal)}</span>
          <span className="resumen-ventas-hint">= Unidades vendidas (30D) × Precio actual</span>
        </div>
        <div className="resumen-ventas-item">
          <span className="resumen-ventas-label">Costo total</span>
          <span className="resumen-ventas-valor">{formatoMoneda(resumen.costoTotal)}</span>
          <span className="resumen-ventas-hint">= Unidades vendidas (30D) × Costo unitario (compra + comisión ML + envío + logística + financiero + publicidad)</span>
        </div>
        <div className="resumen-ventas-item">
          <span className="resumen-ventas-label">Rentabilidad</span>
          <span className={resumen.rentabilidad >= 0 ? 'resumen-ventas-valor resumen-ventas-positivo' : 'resumen-ventas-valor resumen-ventas-negativo'}>
            {formatoMoneda(resumen.rentabilidad)}
            {resumen.rentabilidadPorc !== null && resumen.rentabilidadPorc !== undefined && (
              <small> ({resumen.rentabilidadPorc.toFixed(2)}%)</small>
            )}
          </span>
          <span className="resumen-ventas-hint">= Venta bruta total − Costo total</span>
        </div>
      </div>
      <div className="resumen-ventas-charts">
        <VentanaBarChart ventanas={resumen.ventasPorVentana} />
        <CostoRentabilidadPie
          ventaBrutaTotal={resumen.ventaBrutaTotal}
          costoTotal={resumen.costoTotal}
          rentabilidad={resumen.rentabilidad}
        />
      </div>
    </section>
  )
}

export default ResumenVentasCard
