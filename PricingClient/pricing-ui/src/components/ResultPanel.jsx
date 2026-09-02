function ResultPanel({ title, data, placeholder, onViewDetail }) {
  return (
    <div className="panel response-panel">
      <div className="result-header">
        <h3>{title}</h3>
        {data && (
          <button type="button" className="secondary-button small-button" onClick={onViewDetail}>
            Ver detalle
          </button>
        )}
      </div>
      <pre>{data ? JSON.stringify(data, null, 2) : placeholder}</pre>
    </div>
  )
}

export default ResultPanel
