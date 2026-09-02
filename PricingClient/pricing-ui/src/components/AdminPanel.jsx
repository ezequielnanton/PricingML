import { useState, useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import AbmRecordList from './AbmRecordList'
import AbmColumnResizeHandle from './AbmColumnResizeHandle'
import ConfirmDialog from './ConfirmDialog'
import ResultToast from './ResultToast'
import CompetidoresManualPanel from './CompetidoresManualPanel'
import FkAutocompleteInput from './FkAutocompleteInput'
import { normaliseKey, getRecordValue, getOptionId } from '../utils/adminHelpers'
import { getFkLookup } from '../utils/fkLookups'
import { useRegisterToolbar } from '../context/ToolbarContext'
import { esAdmin } from '../utils/auth'

import { API_BASE_URL } from '../utils/apiBase'
const ADMIN_OPERATION_IDS = ['empresa', 'moneda', 'cotizacion', 'parametro', 'cuentaML', 'producto', 'costoProducto', 'publicacionML', 'stockEstado', 'estrategia', 'regla', 'estrategiaRegla', 'parametrosRegla', 'mensajesRegla', 'configuracion']
// #soloAdminEnConfiguracion: estas 4 pestañas viven en el menú adentro de "Configuración"
// (subgrupo "Empresas"/"MercadoLibre"), que pide Rol=ADMIN además del permiso de Sección de
// siempre (ver SectionGuard soloAdmin) -- pero comparten la misma ruta /admin que el resto
// de Formularios (Producto, Estrategia, etc.), que NO es admin-only, así que el chequeo no
// puede ir en el SectionGuard de la ruta: tiene que ser pestaña por pestaña, acá adentro.
const ADMIN_ONLY_TABS = ['empresa', 'parametro', 'cuentaML', 'configuracion']

const ADMIN_FORM_CONFIG = {
  empresa: { endpoint: '/api/admin/empresas', idField: 'empresaID', searchFields: ['CUIT'], reportKey: 'empresas', label: 'Empresa' },
  moneda: { endpoint: '/api/admin/monedas', idField: 'monedaID', searchFields: ['CodigoISO'], reportKey: 'monedas', label: 'Moneda' },
  cotizacion: { endpoint: '/api/admin/cotizaciones', idField: 'cotizacionID', searchFields: ['MonedaID', 'FechaCotizacion'], reportKey: 'cotizaciones', label: 'Cotización' },
  parametro: { endpoint: '/api/admin/parametros-generales', idField: 'parametroGeneralID', searchFields: ['EmpresaID'], reportKey: 'parametrosGenerales', label: 'Parámetro General' },
  cuentaML: { endpoint: '/api/admin/cuentas-ml', idField: 'cuentaMLID', searchFields: ['EmpresaID', 'NicknameML'], reportKey: 'cuentasMl', label: 'Cuenta ML' },
  producto: { endpoint: '/api/admin/productos', idField: 'productoID', searchFields: ['EmpresaID', 'SKU'], reportKey: 'productos', label: 'Producto' },
  costoProducto: { endpoint: '/api/admin/costos-producto', idField: 'costoID', searchFields: ['ProductoID'], reportKey: 'costosProducto', label: 'Costo Producto' },
  publicacionML: { endpoint: '/api/admin/publicaciones-ml', idField: 'publicacionID', searchFields: ['MeliItemID'], reportKey: 'publicacionesMl', label: 'Publicación ML' },
  stockEstado: { endpoint: '/api/admin/stock-estado', idField: 'stockID', searchFields: ['ProductoID'], reportKey: 'stockEstado', label: 'Stock Estado' },
  estrategia: { endpoint: '/api/admin/estrategias', idField: 'estrategiaID', searchFields: ['EmpresaID', 'NombreEstrategia'], reportKey: 'estrategias', label: 'Estrategia' },
  regla: { endpoint: '/api/admin/reglas', idField: 'reglaID', searchFields: ['CodigoRegla'], reportKey: 'reglas', label: 'Regla' },
  estrategiaRegla: { endpoint: '/api/admin/estrategia-reglas', idField: 'estrategiaReglaID', searchFields: ['EstrategiaID', 'ReglaID'], reportKey: 'estrategiaReglas', label: 'Estrategia-Regla' },
  parametrosRegla: { endpoint: '/api/admin/estrategias-reglas-parametros', idField: 'parametroID', searchFields: ['EstrategiaReglaID', 'Clave'], reportKey: 'estrategiasReglasParametros', label: 'Parámetros de Regla' },
  mensajesRegla: { endpoint: '/api/admin/estrategias-reglas-parametros-mensajes', idField: 'mensajeID', searchFields: ['EstrategiaReglaID', 'Clave'], reportKey: 'estrategiasReglasParametrosMensajes', label: 'Mensajes de Regla' },
  configuracion: { endpoint: '/api/admin/configuracion-parametros', idField: 'parametroID', searchFields: ['EmpresaID', 'ClaveParametro'], reportKey: 'configuracionParametros', label: 'Configuración Parámetros' },
}

// #pestañaFijaPorEntidad: cuando esta instancia vive adentro de una pestaña de la app (ver
// TabsContext.jsx / App.jsx), fixedEntity la ancla a UNA sola entidad -- se ignora el hash de
// la URL (que ahora solo describe la pestaña ACTIVA, no esta instancia puntual, que puede
// estar montada en segundo plano) y no hay selector interno de entidad para esta instancia:
// cambiar de entidad significa abrir/activar otra pestaña, no tocar el hash. isActiveTab
// (false mientras esta pestaña no es la visible) apaga el registro del toolbar global, ver
// #pestañasVariasMontadasALaVez en ToolbarContext.jsx.
function AdminPanel({ adminForm, onChange, onCreate, onClearFields, loading, fixedEntity = null, isActiveTab = true }) {
  const location = useLocation()
  // #defaultNoAdminOnly: "empresa" pasó a ser una pestaña admin-only (ver ADMIN_ONLY_TABS)
  // -- si fuera la pestaña por defecto, cualquier LECTURA que entrara a Formularios sin
  // elegir una pestaña puntual se encontraría con "Sin acceso" de entrada, aunque el resto
  // de Formularios sí le corresponda ver. "moneda" es una pestaña cualquiera sin esa
  // restricción.
  const [activeTab, setActiveTab] = useState(fixedEntity || 'moneda')
  const [mode, setMode] = useState('create')
  const [openRecordId, setOpenRecordId] = useState(null)
  const [listRefreshToken, setListRefreshToken] = useState(0)
  const [deleteDialog, setDeleteDialog] = useState(null)
  const [deleteLoading, setDeleteLoading] = useState(false)
  const [toast, setToast] = useState(null)
  const [searchCollapsed, setSearchCollapsed] = useState(false)

  const modeLabel = mode === 'view' ? 'Ver' : mode === 'edit' ? 'Editar' : 'Crear'

  const updateField = (entity, field, value) => onChange(entity, field, value)

  const getRecordId = (entity, field) => field
    ? getOptionId(entity, field)
    : openRecordId

  const applyRecoveredRecord = (entity, record) => {
    const currentFields = adminForm[entity] || {}
    Object.entries(record).forEach(([responseField, value]) => {
      const formField = Object.keys(currentFields).find((field) => normaliseKey(field) === normaliseKey(responseField))
      if (!formField) return
      const isDateField = value && /fecha|date/i.test(formField) && typeof value === 'string'
      const usesDateTime = entity === 'cuentaML' && formField === 'FechaVencimientoToken'
      const formattedValue = isDateField ? value.slice(0, usesDateTime ? 16 : 10) : value
      updateField(entity, formField, formattedValue && typeof formattedValue === 'object' ? JSON.stringify(formattedValue) : formattedValue)
    })
  }

  useEffect(() => {
    setMode('create')
    setOpenRecordId(null)
  }, [activeTab])

  useEffect(() => {
    if (!toast) return undefined
    const timer = setTimeout(() => setToast(null), 4000)
    return () => clearTimeout(timer)
  }, [toast])

  const handleOpenRecord = (record, id) => {
    applyRecoveredRecord(activeTab, record)
    setOpenRecordId(id)
    setMode('view')
  }

  const handleNewRecord = () => {
    onClearFields(activeTab)
    setOpenRecordId(null)
    setMode('create')
  }

  const handleEdit = () => setMode('edit')

  const handleSave = async (entity) => {
    const config = ADMIN_FORM_CONFIG[entity]
    const recordId = getRecordId(entity)
    const method = recordId !== null && recordId !== undefined ? 'PUT' : 'POST'
    const result = await onCreate(entity, { method, id: recordId })
    if (!result?.ok) {
      setToast({ type: 'error', message: result?.error || `No se pudo guardar ${config.label}.` })
      return
    }
    const savedId = getRecordValue(result.data, config.idField) ?? recordId
    applyRecoveredRecord(entity, result.data)
    setOpenRecordId(savedId)
    setMode('view')
    setListRefreshToken((count) => count + 1)
    setToast({ type: 'success', message: `${config.label} guardada correctamente.` })
  }

  const handleDeleteRequest = (entity) => {
    const recordId = getRecordId(entity)
    if (recordId === null || recordId === undefined) return
    setDeleteDialog({ entity, recordId })
  }

  const handleDeleteCancel = () => setDeleteDialog(null)

  const handleDeleteConfirm = async () => {
    if (!deleteDialog) return
    const { entity, recordId } = deleteDialog
    setDeleteLoading(true)
    const result = await onCreate(entity, { method: 'DELETE', id: recordId })
    setDeleteLoading(false)
    setDeleteDialog(null)
    if (!result?.ok) {
      setToast({ type: 'error', message: result?.error || `No se pudo eliminar ${ADMIN_FORM_CONFIG[entity]?.label || entity}.` })
      return
    }
    onClearFields(entity)
    setOpenRecordId(null)
    setMode('create')
    setListRefreshToken((count) => count + 1)
    setToast({ type: 'success', message: `${ADMIN_FORM_CONFIG[entity]?.label || entity} eliminada correctamente.` })
  }

  useEffect(() => {
    if (fixedEntity) return
    const hashValue = (location.hash || '#moneda').replace('#', '')
    const validTabs = ADMIN_OPERATION_IDS
    if (validTabs.includes(hashValue)) {
      setActiveTab(hashValue)
    }
  }, [location.hash, fixedEntity])

  const tiposRegla = ['MARGEN', 'DESCUENTO', 'PROMOCION', 'RESTRICCION']
  const _estadosActivos = [true, false]

  const activeConfig = ADMIN_FORM_CONFIG[activeTab]

  // #barraDePantalla: reemplaza el botón "+Nuevo registro", la flecha de colapsar
  // búsqueda, "Editar"/"Eliminar" (antes AdminActions) y el "Guardar" de cada formulario --
  // ver ScreenToolbar.jsx / ToolbarContext.jsx. Editar/Eliminar solo se habilitan con un
  // registro abierto (openRecordId no nulo); Editar además exige modo 'view' (en 'edit' ya
  // está editando) y Eliminar exige 'view' o 'edit'.
  // #closureObsoletaBarraDePantalla: adminForm tiene que estar en los deps -- handleSave lee
  // sus campos indirectamente vía onCreate/adminForm. Sin esto, la barra global queda con una
  // versión de handleSave capturada en el último cambio de activeTab/mode/openRecordId, así
  // que Guardar terminaba mandando los valores de cuando se entró a modo edición, no lo
  // último tipeado en el formulario (bug real, encontrado editando Empresa: el cambio de
  // Razón Social no se guardaba).
  useRegisterToolbar({
    newRecord: { onClick: handleNewRecord },
    toggleFilters: { onClick: () => setSearchCollapsed((current) => !current), active: !searchCollapsed },
    edit: mode === 'view' && openRecordId != null ? { onClick: handleEdit } : null,
    delete: (mode === 'view' || mode === 'edit') && openRecordId != null ? { onClick: () => handleDeleteRequest(activeTab) } : null,
    save: mode !== 'view' && !loading ? { onClick: () => handleSave(activeTab) } : null,
  }, [activeTab, mode, searchCollapsed, loading, openRecordId, adminForm], isActiveTab)

  if (ADMIN_ONLY_TABS.includes(activeTab) && !esAdmin()) {
    return (
      <div className="admin-panel-container">
        <section className="panel">
          <h3>Sin acceso</h3>
          <p className="erp-panel-subtitle">
            Esta sección es solo para usuarios con Rol ADMIN. Pedile a un administrador que la revise por vos.
          </p>
        </section>
      </div>
    )
  }

  return (
    <div className="admin-panel-container">
      <div className={searchCollapsed ? 'abm-layout collapsed-search' : 'abm-layout'}>
        <div className="abm-list-column">
          <div className="side-column-body">
            <AbmRecordList
              key={activeTab}
              entity={activeTab}
              config={activeConfig}
              selectedId={openRecordId}
              onSelect={handleOpenRecord}
              refreshToken={listRefreshToken}
            />
          </div>
          <AbmColumnResizeHandle />
        </div>

        {/* Formularios condicionales */}
        <div className="admin-content">
        {/* Crear empresa */}
        {activeTab === 'empresa' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Empresa</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-lg">
                  Razón Social
                  <input
                    value={adminForm.empresa.RazonSocial}
                    onChange={(e) => updateField('empresa', 'RazonSocial', e.target.value)}
                    placeholder="Ingresar Razón Social"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  CUIT
                  <input
                    data-admin-key="empresa.CUIT"
                    disabled={mode === 'edit'}
                    value={adminForm.empresa.CUIT}
                    onChange={(e) => updateField('empresa', 'CUIT', e.target.value)}
                    placeholder="Ingresar CUIT"
                  />
                </label>
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.empresa.Activo ?? '')}
                    onChange={(e) => updateField('empresa', 'Activo', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activa</option>
                    <option value="false">Inactiva</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear moneda */}
        {activeTab === 'moneda' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Moneda</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Nombre
                  <input
                    value={adminForm.moneda?.Nombre || ''}
                    onChange={(e) => updateField('moneda', 'Nombre', e.target.value)}
                    placeholder="Ingresar Nombre"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Código ISO 4217
                  <input
                    data-admin-key="moneda.CodigoISO"
                    disabled={mode === 'edit'}
                    value={adminForm.moneda?.CodigoISO || ''}
                    onChange={(e) => updateField('moneda', 'CodigoISO', e.target.value)}
                    placeholder="Ingresar Código ISO 4217"
                    maxLength="3"
                  />
                </label>
                <label className="field-sm">
                  Símbolo
                  <input
                    value={adminForm.moneda?.Simbolo || ''}
                    onChange={(e) => updateField('moneda', 'Simbolo', e.target.value)}
                    placeholder="Ingresar Símbolo"
                    maxLength="5"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.moneda?.Activa ?? '')}
                    onChange={(e) => updateField('moneda', 'Activa', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activa</option>
                    <option value="false">Inactiva</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear cotización */}
        {activeTab === 'cotizacion' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Cotización</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Moneda
                  <FkAutocompleteInput
                    lookup={getFkLookup('MonedaID')}
                    value={adminForm.cotizacion?.MonedaID || ''}
                    onSelect={(id) => updateField('cotizacion', 'MonedaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Cotización
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.cotizacion?.Cotizacion || ''}
                    onChange={(e) => updateField('cotizacion', 'Cotizacion', e.target.value)}
                    placeholder="Ingresar Cotización"
                  />
                </label>
                <label className="field-sm">
                  Fecha Cotización
                  <input
                    data-admin-key="cotizacion.FechaCotizacion"
                    disabled={mode === 'edit'}
                    type="date"
                    value={adminForm.cotizacion?.FechaCotizacion || ''}
                    onChange={(e) => updateField('cotizacion', 'FechaCotizacion', e.target.value)}
                  />
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear parámetro general */}
        {activeTab === 'parametro' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Parámetro General</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Empresa
                  <FkAutocompleteInput
                    lookup={getFkLookup('EmpresaID')}
                    value={adminForm.parametro?.EmpresaID || ''}
                    onSelect={(id) => updateField('parametro', 'EmpresaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-md">
                  Moneda Principal
                  <FkAutocompleteInput
                    lookup={getFkLookup('MonedaPrincipalID')}
                    value={adminForm.parametro?.MonedaPrincipalID || ''}
                    onSelect={(id) => updateField('parametro', 'MonedaPrincipalID', id)}
                  />
                </label>
                <label className="field-md">
                  Moneda Secundaria
                  <FkAutocompleteInput
                    lookup={getFkLookup('MonedaSecundariaID')}
                    value={adminForm.parametro?.MonedaSecundariaID || ''}
                    onSelect={(id) => updateField('parametro', 'MonedaSecundariaID', id)}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="checkbox-row">
                  <input
                    type="checkbox"
                    checked={Boolean(adminForm.parametro?.SubidaAutomaticaCatalogoML)}
                    onChange={(e) => updateField('parametro', 'SubidaAutomaticaCatalogoML', e.target.checked)}
                  />
                  Subir precio a ML automáticamente (solo publicaciones de catálogo; las que no son de catálogo siempre piden aprobación)
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear cuenta ML */}
        {activeTab === 'cuentaML' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Cuenta ML</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Empresa
                  <FkAutocompleteInput
                    lookup={getFkLookup('EmpresaID')}
                    value={adminForm.cuentaML?.EmpresaID || ''}
                    onSelect={(id) => updateField('cuentaML', 'EmpresaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-md">
                  Nickname ML
                  <input
                    data-admin-key="cuentaML.NicknameML"
                    disabled={mode === 'edit'}
                    value={adminForm.cuentaML?.NicknameML || ''}
                    onChange={(e) => updateField('cuentaML', 'NicknameML', e.target.value)}
                    placeholder="Ingresar Nickname ML"
                  />
                </label>
                <label className="field-sm">
                  User ID ML
                  <input
                    value={adminForm.cuentaML?.UserIDML || ''}
                    onChange={(e) => updateField('cuentaML', 'UserIDML', e.target.value)}
                    placeholder="Ingresar User ID ML"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Access Token
                  <input
                    type="password"
                    value={adminForm.cuentaML?.AccessToken || ''}
                    onChange={(e) => updateField('cuentaML', 'AccessToken', e.target.value)}
                    placeholder="Ingresar Access Token"
                  />
                </label>
                <label className="field-lg">
                  Refresh Token
                  <input
                    type="password"
                    value={adminForm.cuentaML?.RefreshToken || ''}
                    onChange={(e) => updateField('cuentaML', 'RefreshToken', e.target.value)}
                    placeholder="Ingresar Refresh Token"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-md">
                  Fecha Vencimiento Token
                  <input
                    type="datetime-local"
                    value={adminForm.cuentaML?.FechaVencimientoToken || ''}
                    onChange={(e) => updateField('cuentaML', 'FechaVencimientoToken', e.target.value)}
                  />
                </label>
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.cuentaML?.Activo ?? '')}
                    onChange={(e) => updateField('cuentaML', 'Activo', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activa</option>
                    <option value="false">Inactiva</option>
                  </select>
                </label>
              </div>
            </fieldset>
            {mode !== 'create' && getRecordId('cuentaML') != null && (
              <p className="erp-panel-subtitle">
                <a
                  className="secondary-button"
                  href={`${API_BASE_URL}/api/marketplace/ml/oauth/iniciar?cuentaMlId=${getRecordId('cuentaML')}`}
                >
                  Conectar con MercadoLibre
                </a>
                {' '}— te lleva al login de ML para autorizar esta cuenta; al volver, el Access/Refresh Token quedan
                cargados automáticamente.
              </p>
            )}
          </div>
        )}

        {/* Crear producto */}
        {activeTab === 'producto' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Producto</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Empresa
                  <FkAutocompleteInput
                    lookup={getFkLookup('EmpresaID')}
                    value={adminForm.producto?.EmpresaID || ''}
                    onSelect={(id) => updateField('producto', 'EmpresaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  SKU
                  <input
                    data-admin-key="producto.SKU"
                    disabled={mode === 'edit'}
                    value={adminForm.producto?.SKU || ''}
                    onChange={(e) => updateField('producto', 'SKU', e.target.value)}
                    placeholder="Ingresar SKU"
                  />
                </label>
                <label className="field-lg">
                  Título
                  <input
                    value={adminForm.producto?.Titulo || ''}
                    onChange={(e) => updateField('producto', 'Titulo', e.target.value)}
                    placeholder="Ingresar Título"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Categoría ID
                  <input
                    value={adminForm.producto?.CategoriaID || ''}
                    onChange={(e) => updateField('producto', 'CategoriaID', e.target.value)}
                    placeholder="Ingresar Categoría ID"
                  />
                </label>
                <label className="field-md">
                  Marca
                  <input
                    value={adminForm.producto?.Marca || ''}
                    onChange={(e) => updateField('producto', 'Marca', e.target.value)}
                    placeholder="Ingresar Marca"
                  />
                </label>
                <label className="field-md">
                  Modelo
                  <input
                    value={adminForm.producto?.Modelo || ''}
                    onChange={(e) => updateField('producto', 'Modelo', e.target.value)}
                    placeholder="Ingresar Modelo"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.producto?.Activo ?? '')}
                    onChange={(e) => updateField('producto', 'Activo', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activo</option>
                    <option value="false">Inactivo</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear costo producto */}
        {activeTab === 'costoProducto' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Costo Producto</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Producto
                  <FkAutocompleteInput
                    lookup={getFkLookup('ProductoID')}
                    value={adminForm.costoProducto?.ProductoID || ''}
                    onSelect={(id) => updateField('costoProducto', 'ProductoID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Costo Compra
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.CostoCompra || ''}
                    onChange={(e) => updateField('costoProducto', 'CostoCompra', e.target.value)}
                    placeholder="Ingresar Costo Compra"
                  />
                </label>
                <label className="field-sm">
                  % IVA
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.PorcentajeIVA || ''}
                    onChange={(e) => updateField('costoProducto', 'PorcentajeIVA', e.target.value)}
                    placeholder="Ingresar % IVA"
                  />
                </label>
                <label className="field-sm">
                  Impuestos Internos
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.ImpuestosInternos || ''}
                    onChange={(e) => updateField('costoProducto', 'ImpuestosInternos', e.target.value)}
                    placeholder="Ingresar Impuestos Internos"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Costo Envío Promedio
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.CostoEnvioPromedio || ''}
                    onChange={(e) => updateField('costoProducto', 'CostoEnvioPromedio', e.target.value)}
                    placeholder="Ingresar Costo Envío Promedio"
                  />
                </label>
                <label className="field-sm">
                  Costo Logístico Fijo
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.CostoLogisticoFijo || ''}
                    onChange={(e) => updateField('costoProducto', 'CostoLogisticoFijo', e.target.value)}
                    placeholder="Ingresar Costo Logístico Fijo"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  % Costo Financiero
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.CostoFinancieroPorc || ''}
                    onChange={(e) => updateField('costoProducto', 'CostoFinancieroPorc', e.target.value)}
                    placeholder="Ingresar % Costo Financiero"
                  />
                </label>
                <label className="field-sm">
                  % Costo Publicidad
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.CostoPublicidadPorc || ''}
                    onChange={(e) => updateField('costoProducto', 'CostoPublicidadPorc', e.target.value)}
                    placeholder="Ingresar % Costo Publicidad"
                  />
                </label>
                <label className="field-sm">
                  Otros Costos Fijos
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.costoProducto?.OtrosCostosFijos || ''}
                    onChange={(e) => updateField('costoProducto', 'OtrosCostosFijos', e.target.value)}
                    placeholder="Ingresar Otros Costos Fijos"
                  />
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear publicación ML */}
        {activeTab === 'publicacionML' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Publicación ML</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Cuenta ML
                  <FkAutocompleteInput
                    lookup={getFkLookup('CuentaMLID')}
                    value={adminForm.publicacionML?.CuentaMLID || ''}
                    onSelect={(id) => updateField('publicacionML', 'CuentaMLID', id)}
                  />
                </label>
                <label className="field-md">
                  Producto
                  <FkAutocompleteInput
                    lookup={getFkLookup('ProductoID')}
                    value={adminForm.publicacionML?.ProductoID || ''}
                    onSelect={(id) => updateField('publicacionML', 'ProductoID', id)}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Meli Item ID
                  <input
                    data-admin-key="publicacionML.MeliItemID"
                    disabled={mode === 'edit'}
                    value={adminForm.publicacionML?.MeliItemID || ''}
                    onChange={(e) => updateField('publicacionML', 'MeliItemID', e.target.value)}
                    placeholder="Ingresar Meli Item ID"
                  />
                </label>
                <label className="field-sm">
                  Tipo Publicación
                  <select
                    value={adminForm.publicacionML?.TipoPublicacion || ''}
                    onChange={(e) => updateField('publicacionML', 'TipoPublicacion', e.target.value)}
                  >
                    <option value="free">Free</option>
                    <option value="bronze">Bronze</option>
                    <option value="silver">Silver</option>
                    <option value="gold">Gold</option>
                    <option value="gold_premium">Gold Premium</option>
                    <option value="gold_pro">Gold Pro</option>
                    <option value="gold_special">Gold Special</option>
                  </select>
                </label>
                <label className="field-sm">
                  Estado
                  <select
                    value={adminForm.publicacionML?.Estado || ''}
                    onChange={(e) => updateField('publicacionML', 'Estado', e.target.value)}
                  >
                    <option value="active">Active</option>
                    <option value="paused">Paused</option>
                    <option value="closed">Closed</option>
                  </select>
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  % Comisión ML
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.publicacionML?.ComisionMLPorc || ''}
                    onChange={(e) => updateField('publicacionML', 'ComisionMLPorc', e.target.value)}
                    placeholder="Ingresar % Comisión ML"
                  />
                </label>
                <label className="field-sm">
                  Precio Actual
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.publicacionML?.PrecioActual || ''}
                    onChange={(e) => updateField('publicacionML', 'PrecioActual', e.target.value)}
                    placeholder="Ingresar Precio Actual"
                  />
                </label>
                <label className="field-sm">
                  Precio Objetivo
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.publicacionML?.PrecioObjetivo || ''}
                    onChange={(e) => updateField('publicacionML', 'PrecioObjetivo', e.target.value)}
                    placeholder="Ingresar Precio Objetivo"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Precio Mínimo Permitido
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.publicacionML?.PrecioMinimoPermitido || ''}
                    onChange={(e) => updateField('publicacionML', 'PrecioMinimoPermitido', e.target.value)}
                    placeholder="Ingresar Precio Mínimo Permitido"
                  />
                </label>
                <label className="field-sm">
                  Precio Máximo Permitido
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.publicacionML?.PrecioMaximoPermitido || ''}
                    onChange={(e) => updateField('publicacionML', 'PrecioMaximoPermitido', e.target.value)}
                    placeholder="Ingresar Precio Máximo Permitido"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="checkbox-row">
                  <input
                    type="checkbox"
                    checked={Boolean(adminForm.publicacionML?.EsCatalogo)}
                    onChange={(e) => updateField('publicacionML', 'EsCatalogo', e.target.checked)}
                  />
                  Es catálogo
                </label>
              </div>
            </fieldset>
            {mode !== 'create' && !adminForm.publicacionML?.EsCatalogo && getRecordId('publicacionML') != null && (
              <CompetidoresManualPanel publicacionId={getRecordId('publicacionML')} />
            )}
          </div>
        )}

        {/* Crear stock estado */}
        {activeTab === 'stockEstado' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Stock Estado</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Producto
                  <FkAutocompleteInput
                    lookup={getFkLookup('ProductoID')}
                    value={adminForm.stockEstado?.ProductoID || ''}
                    onSelect={(id) => updateField('stockEstado', 'ProductoID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Stock Actual
                  <input
                    type="number"
                    value={adminForm.stockEstado?.StockActual || ''}
                    onChange={(e) => updateField('stockEstado', 'StockActual', e.target.value)}
                    placeholder="Ingresar Stock Actual"
                  />
                </label>
                <label className="field-sm">
                  Stock Reservado
                  <input
                    type="number"
                    value={adminForm.stockEstado?.StockReservado || ''}
                    onChange={(e) => updateField('stockEstado', 'StockReservado', e.target.value)}
                    placeholder="Ingresar Stock Reservado"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Stock Mínimo
                  <input
                    type="number"
                    value={adminForm.stockEstado?.StockMinimo || ''}
                    onChange={(e) => updateField('stockEstado', 'StockMinimo', e.target.value)}
                    placeholder="Ingresar Stock Mínimo"
                  />
                </label>
                <label className="field-sm">
                  Stock Máximo
                  <input
                    type="number"
                    value={adminForm.stockEstado?.StockMaximo || ''}
                    onChange={(e) => updateField('stockEstado', 'StockMaximo', e.target.value)}
                    placeholder="Ingresar Stock Máximo"
                  />
                </label>
                <label className="field-sm">
                  Stock Objetivo
                  <input
                    type="number"
                    value={adminForm.stockEstado?.StockObjetivo || ''}
                    onChange={(e) => updateField('stockEstado', 'StockObjetivo', e.target.value)}
                    placeholder="Ingresar Stock Objetivo"
                  />
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear configuración parámetros */}
        {activeTab === 'configuracion' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Configuración Parámetros</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Empresa
                  <FkAutocompleteInput
                    lookup={getFkLookup('EmpresaID')}
                    value={adminForm.configuracion?.EmpresaID || ''}
                    onSelect={(id) => updateField('configuracion', 'EmpresaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Clave Parámetro
                  <select
                    data-admin-key="configuracion.ClaveParametro"
                    disabled={mode === 'edit'}
                    value={adminForm.configuracion?.ClaveParametro || ''}
                    onChange={(e) => updateField('configuracion', 'ClaveParametro', e.target.value)}
                  >
                    <option value="MARGEN_MINIMO_PERMITIDO">MARGEN_MINIMO_PERMITIDO</option>
                  </select>
                </label>
                <label className="field-sm">
                  Valor Parámetro
                  <input
                    value={adminForm.configuracion?.ValorParametro || ''}
                    onChange={(e) => updateField('configuracion', 'ValorParametro', e.target.value)}
                    placeholder="Ingresar Valor Parámetro"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Descripción
                  <textarea
                    value={adminForm.configuracion?.Descripcion || ''}
                    onChange={(e) => updateField('configuracion', 'Descripcion', e.target.value)}
                    placeholder="Ingresar Descripción"
                    rows="3"
                  />
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear estrategia */}
        {activeTab === 'estrategia' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Estrategia</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Empresa
                  <FkAutocompleteInput
                    lookup={getFkLookup('EmpresaID')}
                    value={adminForm.estrategia?.EmpresaID || ''}
                    onSelect={(id) => updateField('estrategia', 'EmpresaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-md">
                  Nombre
                  <input
                    data-admin-key="estrategia.NombreEstrategia"
                    disabled={mode === 'edit'}
                    value={adminForm.estrategia.NombreEstrategia}
                    onChange={(e) => updateField('estrategia', 'NombreEstrategia', e.target.value)}
                    placeholder="Ingresar Nombre"
                  />
                </label>
                <label className="field-lg">
                  Descripción
                  <input
                    value={adminForm.estrategia.Descripcion}
                    onChange={(e) => updateField('estrategia', 'Descripcion', e.target.value)}
                    placeholder="Ingresar Descripción"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.estrategia.Activa ?? '')}
                    onChange={(e) => updateField('estrategia', 'Activa', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activa</option>
                    <option value="false">Inactiva</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear regla */}
        {activeTab === 'regla' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Regla</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-lg">
                  Código de regla
                  <select
                    data-admin-key="regla.CodigoRegla"
                    disabled={mode === 'edit'}
                    value={adminForm.regla.CodigoRegla || ''}
                    onChange={(e) => updateField('regla', 'CodigoRegla', e.target.value)}
                  >
                    <option value="REGLA_STOCK_CRITICO">REGLA_STOCK_CRITICO</option>
                    <option value="REGLA_COMPETENCIA_ABAJO">REGLA_COMPETENCIA_ABAJO</option>
                    <option value="REGLA_OPORTUNIDAD">REGLA_OPORTUNIDAD</option>
                    <option value="REGLA_EXCESO_STOCK">REGLA_EXCESO_STOCK</option>
                  </select>
                </label>
              </div>
              <div className="field-row">
                <label className="field-md">
                  Nombre
                  <input
                    value={adminForm.regla.Nombre}
                    onChange={(e) => updateField('regla', 'Nombre', e.target.value)}
                    placeholder="Ingresar Nombre"
                  />
                </label>
                <label className="field-md">
                  Tipo de regla
                  <select
                    value={adminForm.regla.TipoRegla || ''}
                    onChange={(e) => updateField('regla', 'TipoRegla', e.target.value)}
                  >
                    {tiposRegla.map((tipo) => (
                      <option key={tipo} value={tipo}>
                        {tipo}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Descripción
                  <textarea
                    value={adminForm.regla.Descripcion || ''}
                    onChange={(e) => updateField('regla', 'Descripcion', e.target.value)}
                    rows="3"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Condición JSON
                  <textarea
                    value={adminForm.regla.CondicionJSON || ''}
                    onChange={(e) => updateField('regla', 'CondicionJSON', e.target.value)}
                    placeholder="Ingresar Condición JSON"
                    rows="3"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.regla.Activa ?? '')}
                    onChange={(e) => updateField('regla', 'Activa', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activa</option>
                    <option value="false">Inactiva</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Vincular regla a estrategia */}
        {activeTab === 'estrategiaRegla' && (
          <div className="panel admin-form">
            <h3>{mode === 'view' ? 'Ver' : mode === 'edit' ? 'Editar' : 'Vincular'} Regla a Estrategia</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Estrategia
                  <FkAutocompleteInput
                    lookup={getFkLookup('EstrategiaID')}
                    value={adminForm.estrategiaRegla.EstrategiaID}
                    onSelect={(id) => updateField('estrategiaRegla', 'EstrategiaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
                <label className="field-md">
                  Regla
                  <FkAutocompleteInput
                    lookup={getFkLookup('ReglaID')}
                    value={adminForm.estrategiaRegla.ReglaID}
                    onSelect={(id) => updateField('estrategiaRegla', 'ReglaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Prioridad
                  <input
                    type="number"
                    value={adminForm.estrategiaRegla.Prioridad}
                    onChange={(e) => updateField('estrategiaRegla', 'Prioridad', e.target.value)}
                    placeholder="Ingresar Prioridad"
                  />
                </label>
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.estrategiaRegla.Activa ?? '')}
                    onChange={(e) => updateField('estrategiaRegla', 'Activa', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activa</option>
                    <option value="false">Inactiva</option>
                  </select>
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Parámetros JSON
                  <textarea
                    value={adminForm.estrategiaRegla.ParametrosJSON}
                    onChange={(e) => updateField('estrategiaRegla', 'ParametrosJSON', e.target.value)}
                    placeholder="Ingresar Parámetros JSON"
                    rows="4"
                  />
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear parámetro de regla */}
        {activeTab === 'parametrosRegla' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Parámetro de Regla</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Estrategia-Regla
                  <FkAutocompleteInput
                    lookup={getFkLookup('EstrategiaReglaID')}
                    value={adminForm.parametrosRegla?.EstrategiaReglaID || ''}
                    onSelect={(id) => updateField('parametrosRegla', 'EstrategiaReglaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Clave
                  <select
                    data-admin-key="parametrosRegla.Clave"
                    disabled={mode === 'edit'}
                    value={adminForm.parametrosRegla?.Clave || ''}
                    onChange={(e) => updateField('parametrosRegla', 'Clave', e.target.value)}
                  >
                    <option value="PORCENTAJE_INCREMENTO_STOCK_CRITICO">PORCENTAJE_INCREMENTO_STOCK_CRITICO</option>
                    <option value="PORCENTAJE_INCREMENTO_OPORTUNIDAD">PORCENTAJE_INCREMENTO_OPORTUNIDAD</option>
                    <option value="PORCENTAJE_DECREMENTO_EXCESO_STOCK">PORCENTAJE_DECREMENTO_EXCESO_STOCK</option>
                    <option value="PORCENTAJE_DESCUENTO_COMPETENCIA">PORCENTAJE_DESCUENTO_COMPETENCIA</option>
                  </select>
                </label>
                <label className="field-sm">
                  Valor
                  <input
                    type="number"
                    step="0.01"
                    value={adminForm.parametrosRegla?.Valor || ''}
                    onChange={(e) => updateField('parametrosRegla', 'Valor', e.target.value)}
                    placeholder="Ingresar Valor"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Descripción
                  <input
                    value={adminForm.parametrosRegla?.Descripcion || ''}
                    onChange={(e) => updateField('parametrosRegla', 'Descripcion', e.target.value)}
                    placeholder="Ingresar Descripción"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.parametrosRegla?.Activo ?? '')}
                    onChange={(e) => updateField('parametrosRegla', 'Activo', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activo</option>
                    <option value="false">Inactivo</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}

        {/* Crear mensaje de regla */}
        {activeTab === 'mensajesRegla' && (
          <div className="panel admin-form">
            <h3>{modeLabel} Mensaje de Regla</h3>
            <fieldset className="mini-form abm-fields" disabled={mode === 'view'}>
              <div className="field-row">
                <label className="field-md">
                  Estrategia-Regla
                  <FkAutocompleteInput
                    lookup={getFkLookup('EstrategiaReglaID')}
                    value={adminForm.mensajesRegla?.EstrategiaReglaID || ''}
                    onSelect={(id) => updateField('mensajesRegla', 'EstrategiaReglaID', id)}
                    disabled={mode === 'edit'}
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Clave
                  <select
                    data-admin-key="mensajesRegla.Clave"
                    disabled={mode === 'edit'}
                    value={adminForm.mensajesRegla?.Clave || ''}
                    onChange={(e) => updateField('mensajesRegla', 'Clave', e.target.value)}
                  >
                    <option value="MENSAJE_STOCK_CRITICO">MENSAJE_STOCK_CRITICO</option>
                    <option value="MENSAJE_OPORTUNIDAD">MENSAJE_OPORTUNIDAD</option>
                    <option value="MENSAJE_EXCESO_STOCK">MENSAJE_EXCESO_STOCK</option>
                    <option value="MENSAJE_COMPETENCIA">MENSAJE_COMPETENCIA</option>
                  </select>
                </label>
                <label className="field-sm">
                  Idioma
                  <select
                    value={adminForm.mensajesRegla?.Idioma || 'ES'}
                    onChange={(e) => updateField('mensajesRegla', 'Idioma', e.target.value)}
                  >
                    <option value="ES">ES</option>
                    <option value="EN">EN</option>
                    <option value="PT">PT</option>
                  </select>
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Mensaje
                  <textarea
                    value={adminForm.mensajesRegla?.Valor || ''}
                    onChange={(e) => updateField('mensajesRegla', 'Valor', e.target.value)}
                    placeholder="Ingresar Mensaje (admite {PORCENTAJE}, {PRECIO_NUEVO}, {PRECIO_ANTERIOR}, {COMPETIDOR_PRECIO})"
                    rows="3"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-lg">
                  Descripción
                  <input
                    value={adminForm.mensajesRegla?.Descripcion || ''}
                    onChange={(e) => updateField('mensajesRegla', 'Descripcion', e.target.value)}
                    placeholder="Ingresar Descripción"
                  />
                </label>
              </div>
              <div className="field-row">
                <label className="field-sm">
                  Estado
                  <select
                    value={String(adminForm.mensajesRegla?.Activo ?? '')}
                    onChange={(e) => updateField('mensajesRegla', 'Activo', e.target.value === 'true' ? true : e.target.value === 'false' ? false : '')}
                  >
                    <option value="true">Activo</option>
                    <option value="false">Inactivo</option>
                  </select>
                </label>
              </div>
            </fieldset>
          </div>
        )}
        </div>
      </div>

      <ConfirmDialog
        open={!!deleteDialog}
        title="Eliminar registro"
        message={`¿Confirmás eliminar este registro de ${ADMIN_FORM_CONFIG[deleteDialog?.entity]?.label || ''}? Esta acción no se puede deshacer.`}
        loading={deleteLoading}
        onConfirm={handleDeleteConfirm}
        onCancel={handleDeleteCancel}
      />

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />
    </div>
  )
}

export default AdminPanel
