import FkAutocompleteInput from './FkAutocompleteInput'
import { getFkLookup } from '../utils/fkLookups'
import { useRegisterToolbar } from '../context/ToolbarContext'

function PricingForm({ productForm, onChange, onEvaluate, onIngest, loading, validationErrors, isActiveTab = true }) {
  const updateField = (field, value) => onChange(field, value)

  // #barraDePantalla: reemplaza "Persistir y evaluar" -- ver ScreenToolbar.jsx /
  // ToolbarContext.jsx. "Evaluar" (sin persistir) sigue siendo un botón de texto normal.
  useRegisterToolbar({
    save: !loading ? { onClick: onIngest } : null,
  }, [loading, onIngest], isActiveTab)

  return (
    <div className="panel">
      <div className="panel-header">
        <h3>Evaluación de precio</h3>
        <div className="toggle-row">
          <button type="button" className="secondary-button" onClick={onEvaluate} disabled={loading}>
            {loading ? 'Procesando...' : 'Evaluar'}
          </button>
        </div>
      </div>

      {validationErrors.length > 0 && (
        <div className="validation-box">
          {validationErrors.map((issue) => (
            <span key={issue}>{issue}</span>
          ))}
        </div>
      )}

      <div className="form-grid">
        <label>
          Empresa ID
          <FkAutocompleteInput
            lookup={getFkLookup('EmpresaID')}
            value={productForm.empresaId}
            onSelect={(id) => updateField('empresaId', id)}
          />
        </label>
        <label>
          SKU
          <input value={productForm.sku} onChange={(e) => updateField('sku', e.target.value)} />
        </label>
        <label className="full-span">
          Título
          <input value={productForm.titulo} onChange={(e) => updateField('titulo', e.target.value)} />
        </label>
        <label>
          Precio propuesto
          <input type="number" value={productForm.precioPropuesto} onChange={(e) => updateField('precioPropuesto', e.target.value)} />
        </label>
        <label>
          Precio mínimo
          <input type="number" value={productForm.precioMinimoPermitido} onChange={(e) => updateField('precioMinimoPermitido', e.target.value)} />
        </label>
        <label>
          Precio máximo
          <input type="number" value={productForm.precioMaximoPermitido} onChange={(e) => updateField('precioMaximoPermitido', e.target.value)} />
        </label>
        <label>
          Stock disponible
          <input type="number" value={productForm.stockDisponible} onChange={(e) => updateField('stockDisponible', e.target.value)} />
        </label>
        <label>
          Stock mínimo
          <input type="number" value={productForm.stockMinimo} onChange={(e) => updateField('stockMinimo', e.target.value)} />
        </label>
        <label>
          Stock máximo
          <input type="number" value={productForm.stockMaximo} onChange={(e) => updateField('stockMaximo', e.target.value)} />
        </label>
        <label>
          Costo base
          <input type="number" value={productForm.costoBase} onChange={(e) => updateField('costoBase', e.target.value)} />
        </label>
        <label>
          IVA %
          <input type="number" value={productForm.iva} onChange={(e) => updateField('iva', e.target.value)} />
        </label>
        <label>
          Comisión ML %
          <input type="number" value={productForm.comisionMLPorc} onChange={(e) => updateField('comisionMLPorc', e.target.value)} />
        </label>
        <label>
          Costo envío promedio
          <input type="number" value={productForm.costoEnvioPromedio} onChange={(e) => updateField('costoEnvioPromedio', e.target.value)} />
        </label>
        <label>
          Costo logístico fijo
          <input type="number" value={productForm.costoLogisticoFijo} onChange={(e) => updateField('costoLogisticoFijo', e.target.value)} />
        </label>
        <label>
          Costo financiero %
          <input type="number" value={productForm.costoFinancieroPorc} onChange={(e) => updateField('costoFinancieroPorc', e.target.value)} />
        </label>
        <label>
          Costo publicidad %
          <input type="number" value={productForm.costoPublicidadPorc} onChange={(e) => updateField('costoPublicidadPorc', e.target.value)} />
        </label>
        <label>
          Estado publicación
          <input value={productForm.estadoPublicacion} onChange={(e) => updateField('estadoPublicacion', e.target.value)} />
        </label>
        <label>
          Origen
          <input value={productForm.origen} onChange={(e) => updateField('origen', e.target.value)} />
        </label>
        <label>
          Idioma del motivo
          <select value={productForm.idioma} onChange={(e) => updateField('idioma', e.target.value)}>
            <option value="ES">Español</option>
            <option value="EN">English</option>
            <option value="PT">Português</option>
          </select>
        </label>
        <label className="checkbox-row">
          <input type="checkbox" checked={productForm.modoSimulacion} onChange={(e) => updateField('modoSimulacion', e.target.checked)} />
          Modo simulación
        </label>
        <label className="checkbox-row">
          <input type="checkbox" checked={productForm.persistir} onChange={(e) => updateField('persistir', e.target.checked)} />
          Persistir
        </label>
      </div>
    </div>
  )
}

export default PricingForm
