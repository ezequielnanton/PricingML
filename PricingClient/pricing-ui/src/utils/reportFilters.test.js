import test from 'node:test'
import assert from 'node:assert/strict'

import { buildFilterQueryParams, REPORT_TABLE_DEFINITIONS, validateReportFilters } from './reportFilters.js'

test('table definitions keep the SQL schema field names and map them to API fields', () => {
  const empresaIdField = REPORT_TABLE_DEFINITIONS.empresas.find((column) => column.field === 'EmpresaID')

  assert.ok(empresaIdField)
  assert.equal(empresaIdField.apiField, 'empresaID')
  assert.equal(empresaIdField.type, 'number')
})

test('number simple value becomes equality filter', () => {
  const filters = [
    { field: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: true, rangeEnabled: false, value: '120', from: '', to: '' },
  ]

  const params = buildFilterQueryParams(filters)
  assert.deepEqual(params, [{ field: 'empresaID', operator: 'eq', value: 120 }])
})

test('number range includes from and to when both are set', () => {
  const filters = [
    { field: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: true, rangeEnabled: true, value: '', from: '100', to: '500' },
  ]

  const params = buildFilterQueryParams(filters)
  assert.deepEqual(params, [
    { field: 'empresaID', operator: 'gte', value: 100 },
    { field: 'empresaID', operator: 'lte', value: 500 },
  ])
})

test('date range keeps end date inclusive for the full day', () => {
  const filters = [
    { field: 'fechaCreacion', label: 'Fecha Creación', type: 'date', allowRange: true, rangeEnabled: true, value: '', from: '2026-01-01', to: '2026-01-31' },
  ]

  const params = buildFilterQueryParams(filters)
  assert.equal(params[0].operator, 'gte')
  assert.equal(params[0].value, '2026-01-01T00:00:00.000Z')
  assert.equal(params[1].operator, 'lte')
  assert.equal(params[1].value, '2026-01-31T23:59:59.999Z')
})

test('range validation rejects from greater than to', () => {
  const filters = [
    { field: 'empresaID', label: 'Empresa ID', type: 'number', allowRange: true, rangeEnabled: true, value: '', from: '500', to: '100' },
  ]

  const error = validateReportFilters(filters)
  assert.match(error, /Desde no puede ser mayor/i)
})
