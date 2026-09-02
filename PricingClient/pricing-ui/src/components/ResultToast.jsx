import { GreenCheckIcon, RedCrossCircleIcon, WarningTriangleIcon } from './icons/NavIcons'

const ICON_BY_TYPE = {
  success: GreenCheckIcon,
  error: RedCrossCircleIcon,
  warning: WarningTriangleIcon,
}

function ResultToast({ toast, onDismiss }) {
  if (!toast) return null

  const Icon = ICON_BY_TYPE[toast.type]

  return (
    <div className={`toast toast-${toast.type}`} role="status">
      {Icon && <Icon />}
      <span>{toast.message}</span>
      <button type="button" className="toast-close" onClick={onDismiss} aria-label="Cerrar aviso">
        ×
      </button>
    </div>
  )
}

export default ResultToast
