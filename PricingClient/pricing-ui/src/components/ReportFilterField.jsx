import { getFkLookup } from '../utils/fkLookups'
import FkAutocompleteInput from './FkAutocompleteInput'

function ReportFilterField({ filter, onChange, onClear }) {
  const commonInputClasses = 'report-filter-input'
  const fkLookup = !filter.rangeEnabled ? getFkLookup(filter.field) : null

  const renderInput = () => {
    if (fkLookup) {
      return (
        <FkAutocompleteInput
          lookup={fkLookup}
          value={filter.value}
          onSelect={(id) => onChange({ value: id })}
          className={commonInputClasses}
        />
      )
    }

    if (filter.component === 'select') {
      return (
        <select
          className={commonInputClasses}
          value={filter.value ?? ''}
          onChange={(event) => onChange({ value: event.target.value })}
        >
          {(filter.options ?? []).map((option) => (
            <option key={option.value || 'all'} value={option.value}>{option.label}</option>
          ))}
        </select>
      )
    }

    if (filter.type === 'date') {
      if (filter.rangeEnabled) {
        return (
          <div className="report-range-grid">
            <label className="range-field">
              <span>Desde</span>
              <input
                type="date"
                className={commonInputClasses}
                placeholder="Buscar..."
                value={filter.from ?? ''}
                onChange={(event) => onChange({ from: event.target.value })}
              />
            </label>
            <label className="range-field">
              <span>Hasta</span>
              <input
                type="date"
                className={commonInputClasses}
                placeholder="Buscar..."
                value={filter.to ?? ''}
                onChange={(event) => onChange({ to: event.target.value })}
              />
            </label>
          </div>
        )
      }

      return (
        <input
          type="date"
          className={commonInputClasses}
          placeholder="Buscar..."
          value={filter.value ?? ''}
          onChange={(event) => onChange({ value: event.target.value })}
        />
      )
    }

    if (filter.rangeEnabled) {
      return (
        <div className="report-range-grid">
          <label className="range-field">
            <span>Desde</span>
            <input
              type={filter.type === 'number' ? 'number' : 'text'}
              step={filter.type === 'number' ? 'any' : undefined}
              className={commonInputClasses}
              placeholder="Buscar..."
              value={filter.from ?? ''}
              onChange={(event) => onChange({ from: event.target.value })}
            />
          </label>
          <label className="range-field">
            <span>Hasta</span>
            <input
              type={filter.type === 'number' ? 'number' : 'text'}
              step={filter.type === 'number' ? 'any' : undefined}
              className={commonInputClasses}
              placeholder="Buscar..."
              value={filter.to ?? ''}
              onChange={(event) => onChange({ to: event.target.value })}
            />
          </label>
        </div>
      )
    }

    return (
      <input
        type={filter.type === 'number' ? 'number' : 'text'}
        step={filter.type === 'number' ? 'any' : undefined}
        className={commonInputClasses}
        placeholder="Buscar..."
        value={filter.value ?? ''}
        onChange={(event) => onChange({ value: event.target.value })}
      />
    )
  }

  return (
    <div className="report-filter-field">
      <label className="report-filter-label">{filter.label}</label>
      <div className="report-filter-control">
        {renderInput()}
        {!filter.rangeEnabled && filter.value !== '' && (
          <button type="button" className="clear-filter-button" onClick={onClear}>Limpiar</button>
        )}
        {filter.allowRange && (
          <input
            type="checkbox"
            className="range-toggle-checkbox"
            checked={Boolean(filter.rangeEnabled)}
            onChange={(event) => onChange({ rangeEnabled: event.target.checked, value: '', from: '', to: '' })}
            title="Rango"
            aria-label="Rango"
          />
        )}
      </div>
    </div>
  )
}

export default ReportFilterField
