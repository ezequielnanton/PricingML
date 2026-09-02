import { hasSeccion, esAdmin } from '../utils/auth'

// #permisosPorSeccion: si el Usuario logueado no tiene tildada esta sección, muestra un
// aviso en vez del contenido real — cubre tanto entrar por el menú (que ya la oculta)
// como escribir la URL directamente.
// #soloAdminEnConfiguracion: todo lo que cuelga de "Configuración" además exige Rol=ADMIN
// (soloAdmin), sin importar si el Usuario tiene la Sección tildada -- un LECTURA con esa
// Sección ya no alcanza a ver estas pantallas.
function SectionGuard({ seccion, soloAdmin = false, children }) {
  if (!hasSeccion(seccion)) {
    return (
      <section className="panel">
        <h3>Sin acceso</h3>
        <p className="erp-panel-subtitle">
          Tu usuario no tiene permiso para ver esta sección. Pedile a un administrador que te lo habilite en
          "Usuarios".
        </p>
      </section>
    )
  }

  if (soloAdmin && !esAdmin()) {
    return (
      <section className="panel">
        <h3>Sin acceso</h3>
        <p className="erp-panel-subtitle">
          Esta sección es solo para usuarios con Rol ADMIN. Pedile a un administrador que la revise por vos.
        </p>
      </section>
    )
  }

  return children
}

export default SectionGuard
