import { useToolbarConfig } from '../context/ToolbarContext'
import { SheetPlusIcon, OpenFolderIcon, SheetLinesPencilIcon, RedCrossIcon, SaveIcon } from './icons/NavIcons'

// #barraDePantalla: franja gris de punta a punta, siempre visible, entre el título y el
// contenido de cada pantalla (ver ADR 0036). Los 5 íconos son fijos; lo que cambia por
// pantalla es cuáles están habilitados (ver ToolbarContext.jsx / App.jsx). Editar/Eliminar
// solo se habilitan en los 13 ABMs de AdminPanel.jsx, con un registro abierto.
function ScreenToolbar() {
  const { newRecord, toggleFilters, edit, delete: deleteAction, save } = useToolbarConfig()

  return (
    <div className="screen-toolbar">
      <button
        type="button"
        className="screen-toolbar-button"
        disabled={!newRecord}
        onClick={newRecord?.onClick}
        title="Nuevo registro"
        aria-label="Nuevo registro"
      >
        <SheetPlusIcon />
      </button>
      <button
        type="button"
        className={toggleFilters?.active ? 'screen-toolbar-button active' : 'screen-toolbar-button'}
        disabled={!toggleFilters}
        onClick={toggleFilters?.onClick}
        title="Mostrar/ocultar filtros"
        aria-label="Mostrar/ocultar filtros"
      >
        <OpenFolderIcon />
      </button>
      <button
        type="button"
        className="screen-toolbar-button"
        disabled={!edit}
        onClick={edit?.onClick}
        title="Editar"
        aria-label="Editar"
      >
        <SheetLinesPencilIcon />
      </button>
      <button
        type="button"
        className="screen-toolbar-button"
        disabled={!deleteAction}
        onClick={deleteAction?.onClick}
        title="Eliminar"
        aria-label="Eliminar"
      >
        <RedCrossIcon />
      </button>
      <button
        type="button"
        className="screen-toolbar-button"
        disabled={!save}
        onClick={save?.onClick}
        title="Guardar"
        aria-label="Guardar"
      >
        <SaveIcon />
      </button>
    </div>
  )
}

export default ScreenToolbar
