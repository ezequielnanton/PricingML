import { useEffect, useState } from 'react'
import { API_BASE_URL } from '../utils/apiBase'
import { getUsuario } from '../utils/auth'
import { NAV_ITEMS, PERMISSION_ALIAS } from './Sidebar'
import ResultToast from './ResultToast'
import ConfirmDialog from './ConfirmDialog'
import { useRegisterToolbar } from '../context/ToolbarContext'

// #permisosPorSeccion: reutiliza los ids/labels del menú (Sidebar.jsx) como catálogo de
// secciones tildables — es la misma lista que filtra qué ítems ve cada Usuario en el menú
// y qué rutas puede abrir (SectionGuard). Un grupo normal (Formularios, Reportes,
// Documentación) es un único permiso que cubre todos sus hijos, así que aporta solo su
// propia fila; un grupo con filterChildrenByPermission (Configuración, Test,
// Autorización) no tiene permiso propio -- cada hijo sigue siendo su propio permiso
// independiente, como ya lo era antes de agruparse en el menú, así que aporta una fila por
// hijo en vez de una por el grupo. Un hijo puede a su vez ser un subgrupo (ej. "Empresas",
// o "MercadoLibre" adentro de "Integraciones", un subgrupo dentro de otro subgrupo) -- en
// ese caso la fila la aporta cada HOJA final, no el subgrupo (que no es un permiso real,
// ver #filtroPorNietoNoPorSubgrupo en Sidebar.jsx); collectSeccionRows baja recursivo, sin
// asumir una profundidad fija, para no tener que volver a tocar esto cada vez que se agregue
// un nivel más de subgrupo. PERMISSION_ALIAS resuelve los casos que reusan el permiso de
// otra pantalla en vez de pedir uno nuevo (ej. "Evaluar precio" reusa "pricing"; "Empresa"
// reusa "admin"). Como más de una hoja puede resolver al mismo id (las 3 pestañas de
// "Empresas" reusan "admin", que además ya tiene su propia fila "Formularios"), se descarta
// cualquier fila cuyo id ya apareció antes -- si no, el checklist repite el mismo toggle
// varias veces con distinta etiqueta (confuso) y React tira warning de key duplicada al
// armar la lista.
function collectSeccionRows(children, pathLabels) {
  return children.flatMap((entry) => {
    const labels = [...pathLabels, entry.label]
    return entry.children
      ? collectSeccionRows(entry.children, labels)
      : [{ id: PERMISSION_ALIAS[entry.id] ?? entry.id, label: labels.join(' — ') }]
  })
}
const SECCIONES_CON_DUPLICADOS = NAV_ITEMS.flatMap((item) =>
  item.filterChildrenByPermission ? collectSeccionRows(item.children, [item.label]) : [{ id: item.id, label: item.label }],
)
const idsVistos = new Set()
const SECCIONES = SECCIONES_CON_DUPLICADOS.filter((s) => (idsVistos.has(s.id) ? false : idsVistos.add(s.id)))

const FORM_VACIO = { NombreCompleto: '', Usuario: '', Password: '', Rol: 'ADMIN', Email: '', Secciones: [] }

function toggleEnLista(lista, id) {
  return lista.includes(id) ? lista.filter((x) => x !== id) : [...lista, id]
}

// #loginGeneralApp: alta y baja/reactivación de Usuarios de la app, y qué secciones
// puede ver cada uno. Solo un ADMIN puede crear, desactivar o cambiar permisos (el
// backend lo exige igual con el gate por Rol; acá además se oculta para LECTURA).
function UsuariosPanel({ isActiveTab = true }) {
  const usuarioActual = getUsuario()
  const esAdmin = usuarioActual?.rol === 'ADMIN'

  const [usuarios, setUsuarios] = useState([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(FORM_VACIO)
  const [guardando, setGuardando] = useState(false)
  const [editandoId, setEditandoId] = useState(null)
  const [seccionesEdicion, setSeccionesEdicion] = useState([])
  const [editandoEmailId, setEditandoEmailId] = useState(null)
  const [emailEdicion, setEmailEdicion] = useState('')
  const [toast, setToast] = useState(null)
  const [usuarioAEliminar, setUsuarioAEliminar] = useState(null)
  const [eliminando, setEliminando] = useState(false)

  const notify = (type, message) => {
    setToast({ type, message })
    setTimeout(() => setToast(null), 5000)
  }

  const cargar = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/usuarios`)
      const data = await res.json()
      setUsuarios(Array.isArray(data) ? data : [])
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  const handleCrear = async () => {
    setGuardando(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/usuarios`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        notify('error', data?.message || 'No se pudo crear el usuario.')
        return
      }
      notify('success', 'Usuario creado.')
      setForm(FORM_VACIO)
      await cargar()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setGuardando(false)
    }
  }

  const toggleActivo = async (usuario) => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/usuarios/${usuario.usuarioID}/activo`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Activo: !usuario.activo }),
      })
      if (!res.ok) {
        notify('error', 'No se pudo actualizar el usuario.')
        return
      }
      await cargar()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    }
  }

  const confirmarEliminar = async () => {
    if (!usuarioAEliminar) return
    setEliminando(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/usuarios/${usuarioAEliminar.usuarioID}`, { method: 'DELETE' })
      if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        notify('error', data?.message || 'No se pudo eliminar el usuario.')
        return
      }
      notify('success', 'Usuario eliminado.')
      setUsuarioAEliminar(null)
      await cargar()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    } finally {
      setEliminando(false)
    }
  }

  const empezarEdicionEmail = (usuario) => {
    setEditandoEmailId(usuario.usuarioID)
    setEmailEdicion(usuario.email || '')
  }

  const guardarEmail = async (usuarioId) => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/usuarios/${usuarioId}/email`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Email: emailEdicion || null }),
      })
      if (!res.ok) {
        notify('error', 'No se pudo guardar el email.')
        return
      }
      notify('success', 'Email actualizado.')
      setEditandoEmailId(null)
      await cargar()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    }
  }

  const empezarEdicionPermisos = (usuario) => {
    setEditandoId(usuario.usuarioID)
    setSeccionesEdicion(usuario.secciones || [])
  }

  const guardarPermisos = async (usuarioId) => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/usuarios/${usuarioId}/secciones`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ Secciones: seccionesEdicion }),
      })
      if (!res.ok) {
        notify('error', 'No se pudieron guardar los permisos.')
        return
      }
      notify('success', 'Permisos actualizados.')
      setEditandoId(null)
      await cargar()
    } catch {
      notify('error', 'No se pudo conectar con el servidor.')
    }
  }

  // #barraDePantalla: reemplaza el botón "Crear usuario" -- ver ScreenToolbar.jsx /
  // ToolbarContext.jsx. Usuarios no tiene "Nuevo registro" ni panel de filtros propio,
  // así que solo habilita el disquete (y solo si hay sesión ADMIN, como el form de abajo).
  // #closureObsoletaBarraDePantalla: form tiene que estar en los deps -- handleCrear lo lee
  // completo. Ver misma nota en IntegracionMercadoLibrePanel.jsx / AdminPanel.jsx.
  useRegisterToolbar({
    save: esAdmin && !guardando ? { onClick: handleCrear } : null,
  }, [esAdmin, guardando, form], isActiveTab)

  return (
    <section className="panel usuarios-panel">
      <h3>Usuarios</h3>
      <p className="erp-panel-subtitle">
        Acceso a la app. Un usuario ADMIN puede aprobar, vincular y guardar en toda pantalla; uno de LECTURA solo
        puede consultar. Las secciones tildadas son las que ve cada usuario en el menú — el límite real de qué
        puede modificar sigue siendo el Rol.
      </p>

      {loading ? (
        <p className="erp-panel-subtitle">Cargando…</p>
      ) : (
        <table className="usuarios-tabla">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Usuario</th>
              <th>Rol</th>
              <th>Email</th>
              <th>Estado</th>
              <th>Secciones</th>
              {esAdmin && <th></th>}
            </tr>
          </thead>
          <tbody>
            {usuarios.map((u) => (
              <tr key={u.usuarioID}>
                <td>{u.nombreCompleto}</td>
                <td>{u.usuario}</td>
                <td>{u.rol}</td>
                <td>
                  {editandoEmailId === u.usuarioID ? (
                    <div className="usuarios-email-edicion">
                      <input
                        type="email"
                        value={emailEdicion}
                        onChange={(e) => setEmailEdicion(e.target.value)}
                        placeholder="usuario@email.com"
                      />
                      <button type="button" className="primary-button" onClick={() => guardarEmail(u.usuarioID)}>
                        Guardar
                      </button>
                      <button type="button" className="secondary-button" onClick={() => setEditandoEmailId(null)}>
                        Cancelar
                      </button>
                    </div>
                  ) : (
                    <>
                      {u.email || '—'}
                      {esAdmin && (
                        <button type="button" className="ghost-button small-button" onClick={() => empezarEdicionEmail(u)}>
                          Editar
                        </button>
                      )}
                    </>
                  )}
                </td>
                <td>{u.activo ? 'Activo' : 'Inactivo'}</td>
                <td>
                  {editandoId === u.usuarioID ? (
                    <div className="usuarios-secciones-checkboxes">
                      {SECCIONES.map((s) => (
                        <label key={s.id} className="checkbox-row">
                          <input
                            type="checkbox"
                            checked={seccionesEdicion.includes(s.id)}
                            onChange={() => setSeccionesEdicion((prev) => toggleEnLista(prev, s.id))}
                          />
                          {s.label}
                        </label>
                      ))}
                      <div className="usuarios-secciones-acciones">
                        <button type="button" className="primary-button" onClick={() => guardarPermisos(u.usuarioID)}>
                          Guardar
                        </button>
                        <button type="button" className="secondary-button" onClick={() => setEditandoId(null)}>
                          Cancelar
                        </button>
                      </div>
                    </div>
                  ) : (
                    (u.secciones || []).map((id) => SECCIONES.find((s) => s.id === id)?.label || id).join(', ') || '—'
                  )}
                </td>
                {esAdmin && (
                  <td className="usuarios-tabla-acciones">
                    <button type="button" className="secondary-button" onClick={() => toggleActivo(u)}>
                      {u.activo ? 'Desactivar' : 'Reactivar'}
                    </button>
                    {editandoId !== u.usuarioID && (
                      <button type="button" className="secondary-button" onClick={() => empezarEdicionPermisos(u)}>
                        Editar permisos
                      </button>
                    )}
                    {u.usuarioID !== usuarioActual?.usuarioID && (
                      <button type="button" className="danger-button" onClick={() => setUsuarioAEliminar(u)}>
                        Eliminar
                      </button>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {esAdmin && (
        <form onSubmit={(event) => { event.preventDefault(); handleCrear() }} className="mini-form">
          <h4>Nuevo usuario</h4>
          <label>
            Nombre completo
            <input
              value={form.NombreCompleto}
              onChange={(e) => setForm((f) => ({ ...f, NombreCompleto: e.target.value }))}
              required
            />
          </label>
          <label>
            Usuario
            <input
              value={form.Usuario}
              onChange={(e) => setForm((f) => ({ ...f, Usuario: e.target.value }))}
              required
            />
          </label>
          <label>
            Contraseña
            <input
              type="password"
              value={form.Password}
              onChange={(e) => setForm((f) => ({ ...f, Password: e.target.value }))}
              placeholder="Ingresar Contraseña"
              required
            />
          </label>
          <label>
            Email
            <input
              type="email"
              value={form.Email}
              onChange={(e) => setForm((f) => ({ ...f, Email: e.target.value }))}
              placeholder="Ingresar Email"
            />
            <span className="erp-panel-subtitle">Necesario para que el usuario pueda usar "Olvidé mi contraseña".</span>
          </label>
          <label>
            Rol
            <select value={form.Rol} onChange={(e) => setForm((f) => ({ ...f, Rol: e.target.value }))}>
              <option value="ADMIN">ADMIN</option>
              <option value="LECTURA">LECTURA</option>
            </select>
          </label>
          <div className="usuarios-secciones-checkboxes">
            <span>Secciones que puede ver</span>
            {SECCIONES.map((s) => (
              <label key={s.id} className="checkbox-row">
                <input
                  type="checkbox"
                  checked={form.Secciones.includes(s.id)}
                  onChange={() => setForm((f) => ({ ...f, Secciones: toggleEnLista(f.Secciones, s.id) }))}
                />
                {s.label}
              </label>
            ))}
          </div>
        </form>
      )}

      <ResultToast toast={toast} onDismiss={() => setToast(null)} />

      <ConfirmDialog
        open={usuarioAEliminar !== null}
        title="Eliminar usuario"
        message={
          usuarioAEliminar
            ? `¿Eliminar definitivamente a "${usuarioAEliminar.nombreCompleto}" (${usuarioAEliminar.usuario})? Esta acción no se puede deshacer. Si tiene aprobaciones o vínculos en su historial, no va a poder eliminarse — usá "Desactivar" en ese caso.`
            : ''
        }
        loading={eliminando}
        onConfirm={confirmarEliminar}
        onCancel={() => setUsuarioAEliminar(null)}
      />
    </section>
  )
}

export default UsuariosPanel
