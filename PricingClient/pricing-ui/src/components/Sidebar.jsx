import { useEffect, useState } from 'react'
import { hasSeccion, esAdmin } from '../utils/auth'
import {
  FolderIcon,
  BarChartIcon,
  SheetIcon,
  MonitorIcon,
  ShoppingBagIcon,
  EnvelopeIcon,
  PeopleIcon,
  GearIcon,
  HouseIcon,
  DollarIcon,
  CheckIcon,
  StackedBooksIcon,
  DoubleGearIcon,
  BookIcon,
  SheetCheckIcon,
  SheetPencilIcon,
  PanelToggleIcon,
  SheetLinesIcon,
  SheetChartArrowIcon,
  HamburgerIcon,
  FactoryIcon,
  MixerIcon,
  MixerCalculatorIcon,
  PlugIcon,
  CoinIcon,
  BoxIcon,
  MegaphoneIcon,
  TargetIcon,
} from './icons/NavIcons'

// #iconoPorItemDeNivelSuperior: ícono de cada fila de nivel superior -- para un grupo
// (con hijos) es el ícono que va junto al triángulo de expandir; para un item suelto (sin
// hijos) es el único ícono de la fila. Documentación y Configuración usan carpeta/tuerca;
// Formularios y Reportes pidieron cada uno un ícono propio (hoja con líneas, hoja con
// gráfico) en vez de la carpeta genérica.
const ITEM_ICON_BY_ID = {
  admin: SheetLinesIcon,
  reports: SheetChartArrowIcon,
  test: SheetPencilIcon,
  autorizacion: SheetCheckIcon,
  manual: FolderIcon,
  'configuracion-sistema': GearIcon,
}

// #iconoPorGrupo: qué ícono de línea le corresponde a los hijos de cada grupo del menú
// -- un gráfico de barras para cada Reporte, una hoja para cada formulario de ABM, un
// libro para cada página de Documentación.
const CHILD_ICON_BY_GROUP = {
  admin: SheetIcon,
  reports: BarChartIcon,
  manual: BookIcon,
}

// #iconoPorHijoDeConfiguracion: a diferencia de Formularios/Reportes (mismo ícono para
// todos los hijos del grupo), cada hijo de Configuración pidió un ícono propio y
// distinto -- se resuelve por id de hijo, no por grupo.
const CHILD_ICON_OVERRIDE = {
  // #iconosDeSubgruposFormularios: los 4 subgrupos de "Formularios" (ver NAV_ITEMS) pidieron
  // cada uno su propio ícono en vez del genérico de hoja que usan sus hijos sueltos.
  'monedas-grupo': CoinIcon,
  'productos-grupo': BoxIcon,
  'publicaciones-grupo': MegaphoneIcon,
  'estrategias-grupo': TargetIcon,
  erp: MonitorIcon,
  'ml-integracion': ShoppingBagIcon,
  'email-integracion': EnvelopeIcon,
  // #subgrupoIntegraciones: ERP/Email/MercadoLibre agrupados adentro de "Integraciones" --
  // cada uno conserva el ícono que ya tenía suelto, el subgrupo en sí pidió un enchufe.
  // "MercadoLibre" es a su vez un subgrupo (ver #cuartoNivelDeMenu), con el ícono de bolsa
  // que ya usaba.
  'integraciones-grupo': PlugIcon,
  'mercadolibre-grupo': ShoppingBagIcon,
  usuarios: PeopleIcon,
  health: CheckIcon,
  'ejecucion-automatica': DoubleGearIcon,
  'evaluar-precio': DollarIcon,
  'cola-ml-aprobacion': StackedBooksIcon,
  // #empresasDentroDeConfiguracion: Empresa/Parámetros Generales/Cuenta ML/Parámetros de
  // Cálculo se movieron de Formularios a un subgrupo adentro de Configuración (siguen
  // siendo las mismas pestañas de /admin, ver PERMISSION_ALIAS y el onSelect de App.jsx).
  // El subgrupo se renombró "Parámetros" y pasó a usar el ícono de mixer (el mismo que ya
  // tenía "Parámetros Generales", ahora "el ícono de parámetros" del grupo); "Empresa" pasó
  // a usar la fábrica que antes tenía el subgrupo.
  'empresas-grupo': MixerIcon,
  empresa: FactoryIcon,
  parametro: MixerIcon,
  // #mercadolibreDentroDeConfiguracion: "Cuenta ML" se sumó desde "Empresas" y pasó a
  // llamarse "Cuentas MercadoLibre" -- mismo ícono de Usuario que ya tenía.
  cuentaML: PeopleIcon,
  configuracion: MixerCalculatorIcon,
}

// #aliasDePermiso: un hijo de un grupo con filterChildrenByPermission normalmente se gatea
// con su propio id como Sección, pero estos casos reusan el permiso de otra pantalla en vez
// de pedir uno nuevo. "Evaluar precio" ya usaba "pricing" (la misma que "Inicio") antes de
// agruparse. Empresa/Parámetros Generales/Cuenta ML/Parámetros de Cálculo son pestañas de
// /admin, así que siguen detrás del permiso "Formularios" ('admin') pase lo que pase en qué
// subgrupo del menú vivan -- si tuvieran un permiso propio, un Usuario podría ver la entrada
// del menú sin poder realmente entrar a /admin (SectionGuard de esa ruta exige "admin").
// #filtroPorNietoNoPorSubgrupo: por eso el alias se define por CADA nieto individualmente
// (no uno solo para "empresas-grupo"): dentro de un mismo subgrupo puede haber nietos con
// permisos reales distintos (ver "MercadoLibre", que mezcla admin con ml-integracion), así
// que cada uno se filtra por el suyo -- el subgrupo entero se sigue mostrando si queda al
// menos un nieto visible (ver navItems más abajo).
// Exportado porque UsuariosPanel.jsx arma su lista de Secciones tildables a partir del
// mismo NAV_ITEMS -- necesita el mismo alias para no ofrecer un toggle que apunte a un id
// ("empresas-grupo", etc.) que nada verifica.
export const PERMISSION_ALIAS = {
  'evaluar-precio': 'pricing',
  empresa: 'admin',
  parametro: 'admin',
  cuentaML: 'admin',
  configuracion: 'admin',
}

// #agregarNavegacion: agregar aquí la entrada de menú para una nueva pantalla.
export const NAV_ITEMS = [
    { id: 'pricing', label: 'Inicio' },
    {
      id: 'admin',
      label: 'Formularios',
      children: [
        {
          id: 'monedas-grupo',
          label: 'Monedas',
          children: [
            { id: 'moneda', label: 'Moneda' },
            { id: 'cotizacion', label: 'Cotización' },
          ],
        },
        {
          id: 'productos-grupo',
          label: 'Productos',
          children: [
            { id: 'producto', label: 'Producto' },
            { id: 'costoProducto', label: 'Costo Producto' },
            { id: 'stockEstado', label: 'Stock Estado' },
          ],
        },
        {
          id: 'publicaciones-grupo',
          label: 'Publicaciones',
          children: [{ id: 'publicacionML', label: 'Publicación ML' }],
        },
        {
          id: 'estrategias-grupo',
          label: 'Estrategias',
          children: [
            { id: 'estrategia', label: 'Estrategia' },
            { id: 'regla', label: 'Regla' },
            { id: 'estrategiaRegla', label: 'Estrategia-Regla' },
            { id: 'parametrosRegla', label: 'Parámetros de Regla' },
            { id: 'mensajesRegla', label: 'Mensajes de Regla' },
          ],
        },
      ],
    },
    {
      id: 'reports',
      label: 'Reportes',
      children: [
        { id: 'empresas', label: 'Empresas' },
        { id: 'monedas', label: 'Monedas' },
        { id: 'cuentasMl', label: 'Cuentas ML' },
        { id: 'estrategias', label: 'Estrategias' },
        { id: 'reglas', label: 'Reglas' },
        { id: 'estrategiaReglas', label: 'Estrategia-Reglas' },
        { id: 'productos', label: 'Productos' },
        { id: 'publicacionesMl', label: 'Publicaciones ML' },
        { id: 'parametrosGenerales', label: 'Parámetros' },
        { id: 'configuracionParametros', label: 'Config. parámetros' },
        { id: 'decisiones', label: 'Decisiones' },
        { id: 'sincronizacionesMl', label: 'Sincronizaciones ML' },
      ],
    },
    {
      id: 'test',
      label: 'Test',
      // Ver nota de filterChildrenByPermission en "Configuración" más abajo -- mismo
      // patrón: Evaluar precio ya existía suelto, con su propio permiso ("pricing",
      // reutilizado, no uno propio), agruparlo acá no le crea un permiso nuevo.
      filterChildrenByPermission: true,
      children: [{ id: 'evaluar-precio', label: 'Evaluar precio' }],
    },
    {
      id: 'autorizacion',
      label: 'Autorización',
      // Mismo patrón que "Test": Cola ML (Aprobación) ya existía suelta con su propio
      // permiso ("cola-ml-aprobacion"), agruparla acá no le crea un permiso nuevo.
      filterChildrenByPermission: true,
      children: [{ id: 'cola-ml-aprobacion', label: 'Cola ML (Aprobación)' }],
    },
    {
      id: 'manual',
      label: 'Documentación',
      children: [
        { id: 'documentacion-funcional', label: 'Funcional' },
        { id: 'apartado-especial', label: 'Apartado especial' },
        { id: 'manual-practico', label: 'Manual práctico' },
        { id: 'api-docs', label: 'API docs' },
      ],
    },
    {
      id: 'configuracion-sistema',
      label: 'Configuración',
      // #soloAdminEnConfiguracion: todo el grupo (no solo las rutas de fondo, ver
      // SectionGuard/AdminPanel) pide Rol=ADMIN -- un LECTURA con la Sección tildada ya ni
      // ve la entrada en el menú, no solo se lo bloquea al entrar.
      soloAdmin: true,
      // #configuracionAgrupaPermisosSueltos: a diferencia de Formularios/Reportes/
      // Documentación (un único permiso "seccion" cubre todo el grupo), acá cada hijo
      // sigue siendo su propio permiso independiente -- ya existían como items sueltos
      // del menú, cada uno con su propio toggle en Usuarios. Agruparlos es solo un
      // cambio de menú, no de permisos: por eso el grupo se filtra hijo por hijo (ver
      // filterChildrenByPermission más abajo) en vez de por un permiso del grupo entero.
      filterChildrenByPermission: true,
      children: [
        { id: 'health', label: 'API Check' },
        { id: 'usuarios', label: 'Usuarios' },
        { id: 'ejecucion-automatica', label: 'Ejecución automática' },
        {
          id: 'empresas-grupo',
          label: 'Parámetros',
          // #empresasDentroDeConfiguracion: estas siguen siendo las mismas pestañas de
          // /admin (Formularios) que ya eran -- solo cambia dónde aparecen en el menú, no
          // el permiso que las protege (ver PERMISSION_ALIAS) ni la ruta a la que navegan
          // (ver el onSelect de App.jsx, que las manda a /admin#<id> igual que antes). El id
          // sigue siendo "empresas-grupo" (no afecta nada visible) aunque el label ya diga
          // "Parámetros".
          children: [
            { id: 'empresa', label: 'Empresa' },
            { id: 'parametro', label: 'Parámetros Generales' },
            { id: 'configuracion', label: 'Parámetros de Cálculo' },
          ],
        },
        {
          id: 'integraciones-grupo',
          label: 'Integraciones',
          // #subgrupoIntegraciones: agrupa las integraciones externas -- cada una sigue
          // detrás de su propio permiso, no uno del subgrupo (ver #filtroPorNietoNoPorSubgrupo).
          // "MercadoLibre" es a su vez un subgrupo adentro de este (4to nivel de menú, ver
          // #cuartoNivelDeMenu) -- junta "Integración MercadoLibre" y "Cuentas MercadoLibre"
          // (permiso "admin", ver PERMISSION_ALIAS) bajo un mismo encabezado.
          children: [
            { id: 'erp', label: 'Integración ERP' },
            { id: 'email-integracion', label: 'Integración Email' },
            {
              id: 'mercadolibre-grupo',
              label: 'MercadoLibre',
              children: [
                { id: 'ml-integracion', label: 'Integración MercadoLibre' },
                { id: 'cuentaML', label: 'Cuentas MercadoLibre' },
              ],
            },
          ],
        },
      ],
    },
]

const GROUP_IDS = NAV_ITEMS.filter((item) => item.children).map((item) => item.id)
const ALL_COLLAPSED = Object.fromEntries(GROUP_IDS.map((id) => [id, false]))

// #tercerNivelDeMenu: un hijo de un grupo (ej. "Productos" adentro de Formularios) puede a
// su vez tener sus propios hijos -- un subgrupo dentro del grupo, no una pantalla propia. Se
// navega igual que un hijo suelto (onSelect(grupo, nietoId), el mismo hash que usaba antes de
// agruparlo), el subgrupo en sí no es una ruta -- solo controla si sus nietos se muestran o
// no. Un subgrupo puede a su vez contener otro subgrupo (ej. "MercadoLibre" adentro de
// "Integraciones", ver #cuartoNivelDeMenu) -- por eso collectSubgroupIds recorre recursivo,
// sin asumir una profundidad fija. SUBGROUP_IDS junta los ids de TODOS los subgrupos, a
// cualquier profundidad, para poder arrancar el estado de expandido/colapsado de cada uno
// igual que se hace con los grupos de nivel superior.
function collectSubgroupIds(children) {
  return children.flatMap((child) => (child.children ? [child.id, ...collectSubgroupIds(child.children)] : []))
}
const SUBGROUP_IDS = NAV_ITEMS.flatMap((item) => collectSubgroupIds(item.children ?? []))
const ALL_SUBGROUPS_COLLAPSED = Object.fromEntries(SUBGROUP_IDS.map((id) => [id, false]))

// #cuartoNivelDeMenu: filtra un árbol de hijos por permiso, recursivamente -- una hoja se
// muestra si hasSeccion la deja pasar; un subgrupo se muestra si le queda al menos un
// descendiente visible después de filtrar sus propios hijos, sin importar cuántos niveles
// de subgrupo-dentro-de-subgrupo haya (usado tanto para el árbol de 2 niveles de
// Formularios/Reportes como para el de 4 niveles de Configuración > Integraciones >
// MercadoLibre > hoja).
function filterVisibleNavChildren(children) {
  return children
    .map((child) => {
      if (child.children) {
        const visibleGrandchildren = filterVisibleNavChildren(child.children)
        return visibleGrandchildren.length > 0 ? { ...child, children: visibleGrandchildren } : null
      }
      return hasSeccion(PERMISSION_ALIAS[child.id] ?? child.id) ? child : null
    })
    .filter(Boolean)
}

// #buscarEnCualquierProfundidad: true si algún nodo del árbol (a cualquier profundidad)
// tiene ese id -- usado para encontrar el grupo de nivel superior que hay que expandir para
// que un descendiente activo quede visible, sin importar cuántos subgrupos haya en el medio.
function subtreeContainsId(children, targetId) {
  return children.some((child) => child.id === targetId || (child.children && subtreeContainsId(child.children, targetId)))
}

// #caminoDeSubgrupos: devuelve, en orden de afuera hacia adentro, los ids de todos los
// subgrupos que hay que expandir para llegar a targetId -- null si targetId no está en este
// árbol. Con un solo subgrupo en el medio devuelve un array de un elemento (comportamiento
// de antes); con "MercadoLibre" adentro de "Integraciones" devuelve los dos.
function findSubgroupPath(children, targetId) {
  for (const child of children) {
    if (!child.children) continue
    if (child.children.some((c) => c.id === targetId)) return [child.id]
    const deeper = findSubgroupPath(child.children, targetId)
    if (deeper) return [child.id, ...deeper]
  }
  return null
}

// #renderRecursivoDeSubnav: pinta un nivel de hijos del árbol -- una hoja navega (onSelect),
// un subgrupo se pinta como encabezado plegable y se llama a sí mismo para sus propios
// hijos. Antes esto estaba escrito a mano dos veces (hijo directo / nieto, un solo nivel de
// subgrupo) -- recursivo soporta cualquier cantidad de subgrupo-adentro-de-subgrupo (ver
// #cuartoNivelDeMenu) sin volver a duplicar el JSX por cada nivel nuevo que se agregue.
// `topGroupId` es siempre el id del grupo de nivel superior (ej. "configuracion-sistema"):
// onSelect(topGroupId, hojaId) no cambia aunque la hoja esté varios subgrupos más adentro.
// `nested` solo decide la clase CSS (el primer nivel es "subnav", el resto "subnav subnav-nested" --
// el sangrado en sí lo da el padding-left de .subnav, que se compone solo al anidar divs).
function NavSubItems({ items, topGroupId, nested, activeSection, activeSubSection, expandedSubgroups, toggleSubgroup, onSelect }) {
  return (
    <div className={nested ? 'subnav subnav-nested' : 'subnav'}>
      {items.map((entry) => {
        const EntryIcon = CHILD_ICON_OVERRIDE[entry.id] ?? CHILD_ICON_BY_GROUP[topGroupId]
        if (entry.children) {
          const isSubExpanded = expandedSubgroups[entry.id] ?? false
          return (
            <div key={entry.id} className="subnav-group">
              <button
                type="button"
                className="subnav-item subnav-item-group"
                onClick={() => toggleSubgroup(entry.id)}
              >
                <span className="nav-item-label">
                  <span className={`nav-chevron ${isSubExpanded ? 'open' : ''}`} aria-hidden="true">▸</span>
                  {EntryIcon && <EntryIcon />}
                  <span className="nav-item-text">{entry.label}</span>
                </span>
              </button>
              {isSubExpanded && (
                <NavSubItems
                  items={entry.children}
                  topGroupId={topGroupId}
                  nested
                  activeSection={activeSection}
                  activeSubSection={activeSubSection}
                  expandedSubgroups={expandedSubgroups}
                  toggleSubgroup={toggleSubgroup}
                  onSelect={onSelect}
                />
              )}
            </div>
          )
        }
        // #resaltadoDeHojaACualquierProfundidad: una hoja "standalone" (ruta propia, ej.
        // "erp") deja su propio id en activeSection, no en activeSubSection (ver
        // #tituloDinamico en App.jsx) -- por eso se comprueban los dos, sin importar a
        // cuántos subgrupos de profundidad esté la hoja.
        return (
          <button
            key={entry.id}
            type="button"
            className={
              activeSubSection === entry.id || activeSection === entry.id
                ? 'subnav-item active'
                : 'subnav-item'
            }
            onClick={() => onSelect(topGroupId, entry.id)}
          >
            <span className="nav-item-label">
              {EntryIcon && <EntryIcon />}
              <span className="nav-item-text">{entry.label}</span>
            </span>
          </button>
        )
      })}
    </div>
  )
}

function Sidebar({ activeSection, activeSubSection, onSelect, toolbarIcons, collapsed, onToggleCollapsed }) {
  // #permisosPorSeccion: solo se listan en el menú las secciones que el Usuario
  // logueado tiene tildadas — la carga real de la pantalla igual queda cubierta por
  // SectionGuard, esto es solo para no mostrar ítems a los que no puede entrar.
  // "Evaluar precio" no es una Sección propia: es la misma pantalla de Pricing partida
  // en dos rutas, así que se gatea con el mismo permiso "pricing" en vez de pedir que un
  // ADMIN tenga que tildar un permiso nuevo para algo que ya podía ver. Un grupo con
  // filterChildrenByPermission (ver "Configuración" en NAV_ITEMS) no tiene permiso propio
  // -- se filtra hijo por hijo, y solo se muestra si queda al menos uno visible.
  const navItems = NAV_ITEMS.flatMap((item) => {
    if (item.soloAdmin && !esAdmin()) return []
    if (item.filterChildrenByPermission) {
      // #filtroPorNietoNoPorSubgrupo: un hijo con sus propios hijos (subgrupo) se filtra
      // nieto por nieto, no como un bloque -- ver PERMISSION_ALIAS. Recursivo (no una sola
      // pasada child->nieto) porque un subgrupo puede contener otro subgrupo (ver
      // #cuartoNivelDeMenu) -- un subgrupo se muestra si le queda al menos un descendiente
      // visible, a cualquier profundidad.
      const visibleChildren = filterVisibleNavChildren(item.children)
      return visibleChildren.length > 0 ? [{ ...item, children: visibleChildren }] : []
    }
    return hasSeccion(item.id) ? [item] : []
  })
  // #inicioEsLaRaiz: "Inicio" es un destino real (navega a "/") como cualquier otro ítem
  // -- el botón se muestra siempre, aunque el Usuario no tenga la Sección "pricing"
  // tildada, para que el resto del árbol (que sí puede tener permitido) no dependa de ese
  // permiso puntual.
  const canSeePricing = hasSeccion('pricing')
  const treeItems = navItems.filter((item) => item.id !== 'pricing')

  const [expandedSections, setExpandedSections] = useState(ALL_COLLAPSED)
  const [expandedSubgroups, setExpandedSubgroups] = useState(ALL_SUBGROUPS_COLLAPSED)

  // #acordeonSoloEnMobile: en desktop, abrir un grupo de nivel 1 (Formularios, Reportes...)
  // ya no cierra los demás que estuvieran abiertos -- pueden quedar varios expandidos a la
  // vez. En mobile se mantiene el comportamiento de acordeón de siempre (uno a la vez),
  // porque ahí el árbol entero compite por poco alto de pantalla. Mismo breakpoint que ya
  // usa el resto del layout para mobile (@media max-width: 980px en App.css).
  const [esMobile, setEsMobile] = useState(false)
  useEffect(() => {
    const mq = window.matchMedia('(max-width: 980px)')
    const actualizarEsMobile = () => setEsMobile(mq.matches)
    actualizarEsMobile()
    mq.addEventListener('change', actualizarEsMobile)
    return () => mq.removeEventListener('change', actualizarEsMobile)
  }, [])

  useEffect(() => {
    if (!activeSection && !activeSubSection) return
    // #autoexpandirGrupoDeHijoSuelto: para Formularios/Reportes/Documentación el activo
    // coincide con el propio id del grupo (son sub-tabs de una sola pantalla); para
    // Configuración, cada hijo navega a su propia ruta, así que lo que coincide con
    // activeSection es el id del HIJO, no el del grupo -- por eso también se busca por
    // hijo, no solo por el id del grupo. Y desde #empresasDentroDeConfiguracion, un
    // descendiente (ej. "empresa", o "cuentaML" a 3 niveles de profundidad adentro de
    // Integraciones > MercadoLibre, ver #cuartoNivelDeMenu) puede vivir en un grupo del
    // menú distinto al que coincide con activeSection (que sigue siendo "admin", porque la
    // ruta de fondo no cambió) -- por eso ese caso se busca primero (más específico, y a
    // cualquier profundidad vía subtreeContainsId) y solo si no aparece se cae al match por
    // activeSection, que si no fuera al revés siempre le "ganaría" a Formularios antes de
    // llegar a mirar los descendientes de Configuración.
    const parent =
      (activeSubSection && navItems.find((item) => item.children && subtreeContainsId(item.children, activeSubSection))) ||
      navItems.find(
        (item) => item.children && (item.id === activeSection || subtreeContainsId(item.children, activeSection)),
      )
    if (parent) {
      // #evitarLoopSidebar: navItems se recalcula (nueva referencia) en cada render porque
      // sale de un .filter() sobre NAV_ITEMS -- si el efecto siempre escribiera un objeto
      // nuevo acá, cada render dispararía el efecto, que dispararía otro render, sin parar.
      // El chequeo evita el setState (y por lo tanto el loop) cuando ya estaba expandido.
      setExpandedSections((current) => (current[parent.id] ? current : { ...current, [parent.id]: true }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSection, activeSubSection])

  useEffect(() => {
    // #autoexpandirSubgrupo: si la pantalla activa es un descendiente (ej. "producto"
    // adentro de "Productos", o "cuentaML" adentro de MercadoLibre > Integraciones, ver
    // #cuartoNivelDeMenu), hay que abrir TODOS los subgrupos en el camino hasta ella -- si
    // no, el ítem resaltado queda escondido dentro de un acordeón cerrado y no se ve por qué
    // está marcado el grupo padre. Para una pantalla "standalone" (ej. "erp") activeSubSection
    // queda vacío -- por eso también se busca por activeSection.
    const targetId = activeSubSection || activeSection
    if (!targetId) return
    const path = navItems.flatMap((item) => findSubgroupPath(item.children ?? [], targetId) ?? [])
    if (path.length === 0) return
    setExpandedSubgroups((current) => {
      const faltantes = path.filter((id) => !current[id])
      if (faltantes.length === 0) return current
      const next = { ...current }
      faltantes.forEach((id) => { next[id] = true })
      return next
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSection, activeSubSection])

  const toggleSubgroup = (subgroupId) => {
    setExpandedSubgroups((current) => ({ ...current, [subgroupId]: !(current[subgroupId] ?? false) }))
  }

  const toggleSection = (sectionId) => {
    const item = navItems.find((entry) => entry.id === sectionId)
    if (!item || !item.children) {
      if (esMobile) setExpandedSections(ALL_COLLAPSED)
      onSelect(sectionId)
      return
    }

    const isExpanded = expandedSections[sectionId] ?? false
    if (esMobile) {
      setExpandedSections({ ...ALL_COLLAPSED, [sectionId]: !isExpanded })
    } else {
      setExpandedSections((current) => ({ ...current, [sectionId]: !isExpanded }))
    }
  }

  // #clickEnRielColapsado: con el sidebar colapsado (solo íconos, sin texto ni árbol) no
  // hay lugar para desplegar hijos ahí mismo -- clickear un grupo expande el sidebar
  // completo Y abre ese grupo, en vez de intentar mostrar el árbol en un riel angosto.
  const handleCollapsedClick = (item) => {
    if (!item.children) {
      onSelect(item.id)
      return
    }
    onToggleCollapsed?.()
    setExpandedSections({ ...ALL_COLLAPSED, [item.id]: true })
  }

  return (
    <aside className={collapsed ? 'sidebar collapsed' : 'sidebar'}>
      <div className="brand">
        <div className="brand-mark" role="img" aria-label="Pricing Engine" />
      </div>

      <div className="sidebar-toolbar">
        <button
          type="button"
          className="sidebar-toolbar-collapse"
          onClick={onToggleCollapsed}
          aria-label={collapsed ? 'Expandir menú' : 'Colapsar menú'}
          title={collapsed ? 'Expandir menú' : 'Colapsar menú'}
        >
          <span className="toggle-icon-desktop"><PanelToggleIcon /></span>
          <span className="toggle-icon-mobile"><HamburgerIcon /></span>
        </button>
        {toolbarIcons && <div className="sidebar-toolbar-icons">{toolbarIcons}</div>}
      </div>

      <div className="sidebar-scroll">
      <button
        type="button"
        className={activeSection === 'pricing' ? 'nav-item menu-root active' : 'nav-item menu-root'}
        onClick={() => {
          if (canSeePricing) onSelect('pricing')
        }}
      >
        <span className="nav-item-label">
          <HouseIcon />
          <span className="nav-item-text">Inicio</span>
        </span>
      </button>

      <nav className="nav">
          {treeItems.map((item) => {
            const isExpanded = !!item.children && (expandedSections[item.id] ?? false)
            // #arbolMenuConCarpetas: un item con hijos nunca queda "seleccionado" él mismo
            // -- lo que está seleccionado es siempre el hijo puntual (o, si no tiene hijos,
            // el propio item). Así el resaltado del árbol nunca marca dos filas a la vez.
            const isActive = activeSection === item.id && !item.children
            const ItemIcon = ITEM_ICON_BY_ID[item.id]

            return (
              <div key={item.id} className="nav-group">
                <button
                  type="button"
                  className={isActive ? 'nav-item active' : 'nav-item'}
                  onClick={() => (collapsed ? handleCollapsedClick(item) : toggleSection(item.id))}
                >
                  <span className="nav-item-label">
                    {item.children && !collapsed && (
                      <span className={`nav-chevron ${isExpanded ? 'open' : ''}`} aria-hidden="true">
                        ▸
                      </span>
                    )}
                    {ItemIcon && <ItemIcon />}
                    <span className="nav-item-text">{item.label}</span>
                  </span>
                </button>

                {item.children && isExpanded && !collapsed && (
                  <NavSubItems
                    items={item.children}
                    topGroupId={item.id}
                    nested={false}
                    activeSection={activeSection}
                    activeSubSection={activeSubSection}
                    expandedSubgroups={expandedSubgroups}
                    toggleSubgroup={toggleSubgroup}
                    onSelect={onSelect}
                  />
                )}
              </div>
            )
          })}
      </nav>
      </div>
    </aside>
  )
}

export default Sidebar
