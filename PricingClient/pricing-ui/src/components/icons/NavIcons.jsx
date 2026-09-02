// #iconosDeLineaMenu: iconos del menú lateral dibujados solo con trazos (stroke), sin
// relleno -- heredan el color del texto (currentColor) en vez de tener un color propio,
// para que se vean "transparentes" (como el ícono de carpeta de la imagen de referencia)
// y respeten el color activo/inactivo de cada fila sin necesidad de una clase aparte.
const commonProps = {
  width: 14,
  height: 14,
  viewBox: '0 0 16 16',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.3,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  className: 'nav-icon',
  'aria-hidden': true,
}

export function FolderIcon() {
  return (
    <svg {...commonProps}>
      <path d="M1.5 3.6a1 1 0 0 1 1-1h3.1l1.3 1.5h6.6a1 1 0 0 1 1 1v6.8a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1z" />
    </svg>
  )
}

export function BarChartIcon() {
  return (
    <svg {...commonProps}>
      <path d="M2 1.5v12.7h12.2" />
      <path d="M4.6 13.8V9.4M8 13.8V6M11.4 13.8V3.3" />
    </svg>
  )
}

export function SheetIcon() {
  return (
    <svg {...commonProps}>
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" />
      <path d="M9.3 1.5v3.2h3.2" />
    </svg>
  )
}

export function MonitorIcon() {
  return (
    <svg {...commonProps}>
      <rect x="1.6" y="2.2" width="12.8" height="8.4" rx="1" />
      <path d="M5.6 13.8h4.8M8 10.6v3.2" />
    </svg>
  )
}

// #logoMercadoLibreNoReproducible: no se recrea el isologo real de MercadoLibre (marca
// registrada) -- este es un ícono genérico de "bolsa de compras" en el mismo estilo de
// trazos, como equivalente visual para la sección de integración.
export function ShoppingBagIcon() {
  return (
    <svg {...commonProps}>
      <path d="M3.8 5.3h8.4l-.8 8.2H4.6z" />
      <path d="M6.1 5.3V3.9a1.9 1.9 0 0 1 3.8 0v1.4" />
    </svg>
  )
}

export function EnvelopeIcon() {
  return (
    <svg {...commonProps}>
      <rect x="1.6" y="3.4" width="12.8" height="9.2" rx="1" />
      <path d="M1.9 3.9 8 8.6l6.1-4.7" />
    </svg>
  )
}

export function PeopleIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="10.1" cy="5.3" r="1.9" />
      <path d="M6.7 12.9c.4-2.9 1.9-4.2 3.4-4.2s3 1.3 3.4 4.2" />
      <circle cx="5.7" cy="6" r="2.1" />
      <path d="M1.7 13.6c.4-3.3 2.1-4.7 4-4.7s3.6 1.4 4 4.7" />
    </svg>
  )
}

export function GearIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="8" cy="8" r="3.6" />
      <circle cx="8" cy="8" r="1.3" />
      <path d="M8 2.6v1.9M8 11.5v1.9M13.4 8h-1.9M4.5 8H2.6M11.7 4.3l-1.35 1.35M5.65 10.35 4.3 11.7M11.7 11.7l-1.35-1.35M5.65 5.65 4.3 4.3" />
    </svg>
  )
}

export function HouseIcon() {
  return (
    <svg {...commonProps}>
      <path d="M2 8.2 8 2.6l6 5.6" />
      <path d="M3.6 6.9v6.5h8.8V6.9" />
      <path d="M6.6 13.4V9.6h2.8v3.8" />
    </svg>
  )
}

export function DollarIcon() {
  return (
    <svg {...commonProps}>
      <path d="M8 1.8v12.4" />
      <path d="M10.8 4.6c0-1.2-1.3-2-2.8-2-1.7 0-3.1.9-3.1 2.3 0 3 6.2 1.5 6.2 4.4 0 1.4-1.4 2.3-3.1 2.3-1.5 0-2.8-.8-2.8-2" />
    </svg>
  )
}

export function CheckIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="8" cy="8" r="6.2" />
      <path d="M5 8.3l2.1 2.1 3.9-4.4" />
    </svg>
  )
}

export function StackedBooksIcon() {
  return (
    <svg {...commonProps}>
      <rect x="2.4" y="10.3" width="11.2" height="2.5" rx="0.5" />
      <rect x="3.2" y="7.4" width="9.6" height="2.5" rx="0.5" />
      <rect x="4" y="4.5" width="8" height="2.5" rx="0.5" />
    </svg>
  )
}

export function DoubleGearIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="6" cy="6" r="2.6" />
      <circle cx="6" cy="6" r="1" />
      <path d="M6 3.4V2.1M6 8.6v1.3M8.6 6h1.3M3.4 6H2.1" />
      <circle cx="10.6" cy="10.4" r="2" />
      <circle cx="10.6" cy="10.4" r="0.7" />
      <path d="M10.6 8.4V7.3M10.6 12.4v1.1M12.6 10.4h1.1M8.6 10.4H7.5" />
    </svg>
  )
}

export function BookIcon() {
  return (
    <svg {...commonProps}>
      <path d="M8 3.6c-1.3-1-3.4-1.4-5.2-1v8.6c1.8-.4 3.9 0 5.2 1 1.3-1 3.4-1.4 5.2-1V2.6c-1.8-.4-3.9 0-5.2 1z" />
      <path d="M8 3.6v8.6" />
    </svg>
  )
}

export function SheetCheckIcon() {
  return (
    <svg {...commonProps}>
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" />
      <path d="M9.3 1.5v3.2h3.2" />
      <path d="M5.7 9.6 7.3 11.1 10.4 7.4" />
    </svg>
  )
}

export function SheetPencilIcon() {
  return (
    <svg {...commonProps}>
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" />
      <path d="M9.3 1.5v3.2h3.2" />
      <path d="M5.9 12.2 10.5 7.6" />
      <path d="M5.9 12.2 5.1 13.3 6.3 12.7Z" />
      <path d="M9.5 6.6 10.5 7.6 11.5 6.6" />
    </svg>
  )
}

// #iconoOcultarMenu: panel dividido en dos -- el clásico ícono de "mostrar/ocultar
// barra lateral", como el de la imagen de referencia (el cuadrito antes del buscador).
export function PanelToggleIcon() {
  return (
    <svg {...commonProps}>
      <rect x="1.5" y="2.5" width="13" height="11" rx="1.5" />
      <path d="M6 2.5v11" />
    </svg>
  )
}

// #iconoOcultarMenuMobile: tres líneas horizontales (hamburguesa) -- en mobile, colapsar
// el menú lo convierte en una fila horizontal de íconos (no en un riel angosto vertical
// como en desktop), así que el ícono de panel con línea vertical no representa la acción;
// se usa solo en mobile, ver .toggle-icon-mobile / .toggle-icon-desktop en App.css.
export function HamburgerIcon() {
  return (
    <svg {...commonProps}>
      <path d="M2 4.5h12M2 8h12M2 11.5h12" />
    </svg>
  )
}

// #iconoFormularios: hoja con tres líneas horizontales adentro -- un formulario/lista.
export function SheetLinesIcon() {
  return (
    <svg {...commonProps}>
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" />
      <path d="M9.3 1.5v3.2h3.2" />
      <path d="M5.8 7.2h4.4M5.8 9.4h4.4M5.8 11.6h4.4" />
    </svg>
  )
}

// #iconoReportes: hoja con un gráfico de líneas subiendo y una flecha hacia arriba
// adentro -- reportes/tendencia.
export function SheetChartArrowIcon() {
  return (
    <svg {...commonProps}>
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" />
      <path d="M9.3 1.5v3.2h3.2" />
      <path d="M5.6 11.8 7.4 9.4 8.6 10.6 10.6 7.6" />
      <path d="M9.2 7.6h1.4v1.4" />
    </svg>
  )
}

// #barraDePantalla: los 3 íconos de la .screen-toolbar (ver App.jsx / ScreenToolbar.jsx).
// A diferencia del resto de NavIcons.jsx, van con color propio fijo -- así lo pidió el
// usuario explícitamente (hoja blanca con el + verde, carpeta amarilla, disco negro), no
// heredan currentColor ni son parte de la paleta de la app (mismo criterio que
// HeaderIcons.jsx). El verde reutiliza el mismo verde de SyncIcon (#25a55a).

// Hoja blanca (con borde para que se distinga sobre el fondo gris) con un "+" verde
// adentro -- crear un registro nuevo.
export function SheetPlusIcon() {
  return (
    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" fill="#ffffff" stroke="#2d3f4e" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M9.3 1.5v3.2h3.2" fill="none" stroke="#2d3f4e" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M8 7v4.4M5.8 9.2h4.4" fill="none" stroke="#25a55a" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

// Carpeta amarilla, abierta -- mostrar/ocultar el panel de filtros o búsqueda.
export function OpenFolderIcon() {
  return (
    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M1.6 3.4h4.4l1.3 1.5h6.1a1 1 0 0 1 1 1v.6H1.6z" fill="#f2b705" stroke="#b8860b" strokeWidth="0.6" strokeLinejoin="round" />
      <path d="M1.1 6.5h11.8a1 1 0 0 1 .96 1.27l-1.1 4a1 1 0 0 1-.96.73H2.2a1 1 0 0 1-.96-.73l-1.1-4A1 1 0 0 1 1.1 6.5Z" fill="#ffcc33" stroke="#b8860b" strokeWidth="0.6" strokeLinejoin="round" />
    </svg>
  )
}

// Disquete negro -- guardar.
export function SaveIcon() {
  return (
    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2.3 1.6h9.6l2.1 2.1v9a1 1 0 0 1-1 1H2.3a1 1 0 0 1-1-1V2.6a1 1 0 0 1 1-1Z" fill="none" stroke="#000000" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M4.3 1.6v3.6h6V1.6" fill="none" stroke="#000000" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M4.3 14.4V9.4h7.4v5" fill="none" stroke="#000000" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

// #accionesAbm: íconos de "Editar"/"Eliminar" de la .screen-toolbar, habilitados solo en
// los 13 ABMs de AdminPanel.jsx cuando hay un registro abierto (ver ToolbarContext.jsx).
// Mismo criterio de color fijo que los íconos de arriba -- así lo pidió el usuario
// explícitamente (cruz roja, hoja con líneas negras y lápiz amarillo).

// Cruz roja -- eliminar un registro.
export function RedCrossIcon() {
  return (
    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M3.4 3.4 12.6 12.6M12.6 3.4 3.4 12.6" fill="none" stroke="#d32f2f" strokeWidth="2.2" strokeLinecap="round" />
    </svg>
  )
}

// Hoja con tres líneas negras y un lápiz amarillo encima -- editar un registro.
export function SheetLinesPencilIcon() {
  return (
    <svg width={14} height={14} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M4 1.5h5.3l3.2 3.2v9.8H4z" fill="#ffffff" stroke="#000000" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M9.3 1.5v3.2h3.2" fill="none" stroke="#000000" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M5.8 7h4.4M5.8 9.1h4.4M5.8 11.2h2.6" fill="none" stroke="#000000" strokeWidth="1" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M5.9 12.2 10.5 7.6" fill="none" stroke="#f2b705" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M5.9 12.2 5.1 13.3 6.3 12.7Z" fill="#f2b705" stroke="#f2b705" strokeLinejoin="round" />
      <path d="M9.5 6.6 10.5 7.6 11.5 6.6" fill="none" stroke="#f2b705" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

// #iconosDeResultadoToast: tilde verde / cruz roja / triángulo de warning amarillo para
// ResultToast.jsx -- el color de cada uno resume el resultado (todo OK / todo con error /
// mezcla), así que van con color fijo igual que los otros íconos de esta sección.

// Tilde verde en círculo -- resultado totalmente exitoso.
export function GreenCheckIcon() {
  return (
    <svg width={18} height={18} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.8" fill="none" stroke="#0a6b3f" strokeWidth="1.3" />
      <path d="M4.8 8.2 6.9 10.3 11.2 5.7" fill="none" stroke="#0a6b3f" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

// Cruz roja en círculo -- resultado totalmente fallido.
export function RedCrossCircleIcon() {
  return (
    <svg width={18} height={18} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.8" fill="none" stroke="#9c1c1c" strokeWidth="1.3" />
      <path d="M5.4 5.4 10.6 10.6M10.6 5.4 5.4 10.6" fill="none" stroke="#9c1c1c" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  )
}

// Triángulo amarillo con "!" -- resultado mixto (algunos OK, algunos con error).
export function WarningTriangleIcon() {
  return (
    <svg width={18} height={18} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1.6 14.6 13.4H1.4Z" fill="#fff6d9" stroke="#b8860b" strokeWidth="1.2" strokeLinejoin="round" />
      <path d="M8 6v3.4" stroke="#8a5a10" strokeWidth="1.4" strokeLinecap="round" />
      <circle cx="8" cy="11.2" r="0.9" fill="#8a5a10" />
    </svg>
  )
}

// #iconoEmpresas: silueta de fábrica -- techo en dientes de sierra sobre la pared, chimenea
// a la izquierda con un rulo de humo arriba. Pedido para el subgrupo "Empresas".
export function FactoryIcon() {
  return (
    <svg {...commonProps}>
      <path d="M2.3 13.6h11.4" />
      <path d="M3.2 13.6V8.2l3-2v2l3-2v2l3-2v5.4" />
      <path d="M4.2 8.2V4h1.8v2.6" />
      <path d="M4.5 3.1c.5-.6 1.1-.6 1.6 0" />
    </svg>
  )
}

// #iconoParametrosGenerales: consola mixer -- tres canales verticales, cada uno con su
// perilla (el puntito relleno) a una altura distinta.
export function MixerIcon() {
  return (
    <svg {...commonProps}>
      <path d="M3.5 2v12M8 2v12M12.5 2v12" />
      <circle cx="3.5" cy="10.4" r="1.3" fill="currentColor" stroke="none" />
      <circle cx="8" cy="5.4" r="1.3" fill="currentColor" stroke="none" />
      <circle cx="12.5" cy="8.6" r="1.3" fill="currentColor" stroke="none" />
    </svg>
  )
}

// #iconoParametrosDeCalculo: el mismo mixer de arriba, sin tocarle una sola coordenada (las
// tres líneas y sus tres perillas son idénticas a MixerIcon -- antes las había achicado para
// hacerle lugar a la calculadora, y por eso la consola se veía distinta a la de Parámetros
// Generales), con una calculadora (pantalla + grilla de botones) superpuesta como una
// medallita arriba a la derecha, cruzando por encima del tercer canal.
export function MixerCalculatorIcon() {
  return (
    <svg {...commonProps}>
      <path d="M3.5 2v12M8 2v12M12.5 2v12" />
      <circle cx="3.5" cy="10.4" r="1.3" fill="currentColor" stroke="none" />
      <circle cx="8" cy="5.4" r="1.3" fill="currentColor" stroke="none" />
      <circle cx="12.5" cy="8.6" r="1.3" fill="currentColor" stroke="none" />
      <rect x="9.4" y="0.6" width="5.4" height="6.6" rx="0.9" />
      <path d="M10.2 2.1h3.8" />
      <circle cx="10.6" cy="4" r="0.35" fill="currentColor" stroke="none" />
      <circle cx="12.1" cy="4" r="0.35" fill="currentColor" stroke="none" />
      <circle cx="13.6" cy="4" r="0.35" fill="currentColor" stroke="none" />
      <circle cx="10.6" cy="5.6" r="0.35" fill="currentColor" stroke="none" />
      <circle cx="12.1" cy="5.6" r="0.35" fill="currentColor" stroke="none" />
      <circle cx="13.6" cy="5.6" r="0.35" fill="currentColor" stroke="none" />
    </svg>
  )
}

// #iconoIntegraciones: enchufe -- dos clavijas arriba entrando a un cuerpo redondeado, con
// el cable saliendo curvo por abajo. Para el subgrupo "Integraciones" (ERP/Email/ML).
export function PlugIcon() {
  return (
    <svg {...commonProps}>
      <path d="M5.6 1v4.2M10.4 1v4.2" />
      <rect x="4" y="5.2" width="8" height="4.2" rx="1.6" />
      <path d="M8 9.4v1.4" />
      <path d="M8 10.8c0 1.7-1.6 1.9-1.6 3.6" />
    </svg>
  )
}

// #iconoMonedas: dos monedas superpuestas, cada una con su marca de moneda adentro --
// para el subgrupo "Monedas" (Moneda/Cotización).
export function CoinIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="6.2" cy="9.6" r="4.6" />
      <circle cx="9.8" cy="6.2" r="4.6" />
      <path d="M9.8 4.1v4.2M8.1 6.2h3.4" />
    </svg>
  )
}

// #iconoProductos: caja isométrica (cubo con las 3 costuras de las caras a la vista) --
// para el subgrupo "Productos" (Producto/Costo Producto/Stock Estado).
export function BoxIcon() {
  return (
    <svg {...commonProps}>
      <path d="M8 1.6 14 5v6l-6 3.4-6-3.4V5z" />
      <path d="M2 5l6 3.4 6-3.4M8 8.4v6" />
    </svg>
  )
}

// #iconoPublicaciones: megáfono -- boquilla a la izquierda, bocina en trompeta hacia la
// derecha con una línea curva de sonido en la punta. Para el subgrupo "Publicaciones"
// (Publicación ML).
export function MegaphoneIcon() {
  return (
    <svg {...commonProps}>
      <path d="M1.8 6.3h2.3l7.7-3.7v10.8L4.1 9.7H1.8z" />
      <path d="M4.1 9.7v2.9a1 1 0 0 0 1 1h.5a1 1 0 0 0 1-1v-1.5" />
      <path d="M13 6.5c.65.55.65 2.3 0 2.9" />
    </svg>
  )
}

// #iconoEstrategias: diana con una flecha clavada en el centro -- para el subgrupo
// "Estrategias" (Estrategia/Regla/Estrategia-Regla/Parámetros de Regla/Mensajes de Regla).
export function TargetIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="6.8" cy="9.2" r="5.2" />
      <circle cx="6.8" cy="9.2" r="2.9" />
      <circle cx="6.8" cy="9.2" r="0.7" fill="currentColor" stroke="none" />
      <path d="M10.4 5.6 14.2 1.8M14.2 1.8h-2.6M14.2 1.8v2.6" />
    </svg>
  )
}

// #iconosModoOscuro: sol/luna del toggle de tema en la toolbar (ver LoginGate.jsx) -- se
// muestra el sol en modo oscuro (clickear pasa a claro) y la luna en modo claro (clickear
// pasa a oscuro), como cualquier toggle día/noche.
export function SunIcon() {
  return (
    <svg {...commonProps}>
      <circle cx="8" cy="8" r="3" />
      <path d="M8 1.4v2M8 12.6v2M1.4 8h2M12.6 8h2M3.3 3.3l1.4 1.4M11.3 11.3l1.4 1.4M12.7 3.3l-1.4 1.4M4.7 11.3l-1.4 1.4" />
    </svg>
  )
}

export function MoonIcon() {
  return (
    <svg {...commonProps}>
      <path d="M13.3 9.9A6 6 0 0 1 6.1 2.7a6 6 0 1 0 7.2 7.2z" />
    </svg>
  )
}
