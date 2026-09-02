import { Link, useLocation } from 'react-router-dom'

function DecisionDetail() {
  const location = useLocation()
  const decision = location.state?.decision || null

  if (!decision) {
    return (
      <section className="panel detail-empty">
        <h3>Detalle de decisión</h3>
        <p>No hay una decisión disponible todavía. Evalúa un producto primero.</p>
        <Link to="/" className="primary-button inline-link">Volver al pricing</Link>
      </section>
    )
  }

  const metrics = [
    { label: 'Empresa', value: decision.empresaId ?? 'N/A' },
    { label: 'SKU', value: decision.sku ?? 'N/A' },
    { label: 'Precio actual', value: decision.precioActual ?? 'N/A' },
    { label: 'Precio sugerido', value: decision.precioSugerido ?? 'N/A' },
    { label: 'Acción', value: decision.accion ?? 'N/A' },
    { label: 'Margen', value: `${decision.margenActualPorc ?? 0}%` },
    { label: 'Score', value: `${decision.scoreConfianza ?? 0}` },
    { label: 'Origen', value: decision.fuenteOrigen ?? 'N/A' },
  ]

  return (
    <section className="detail-page">
      <div className="panel detail-header">
        <div>
          <p className="eyebrow">Detalle</p>
          <h3>Resumen de decision</h3>
        </div>
        <Link to="/" className="ghost-button inline-link">Volver</Link>
      </div>

      <div className="detail-grid">
        {metrics.map((metric) => (
          <div key={metric.label} className="panel metric-card">
            <span>{metric.label}</span>
            <strong>{metric.value}</strong>
          </div>
        ))}
      </div>

      <div className="panel detail-body">
        <h4>Motivo</h4>
        <p>{decision.motivo || 'Sin motivo disponible.'}</p>
      </div>
    </section>
  )
}

export default DecisionDetail
