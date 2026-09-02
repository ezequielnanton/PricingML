import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import Sidebar, { NAV_ITEMS } from './components/Sidebar'
import PricingForm from './components/PricingForm'
import ResultPanel from './components/ResultPanel'
import AdminPanel from './components/AdminPanel'
import DecisionDetail from './components/DecisionDetail'
import ReportsPanel from './components/ReportsPanel'
import IntegracionErpPanel from './components/IntegracionErpPanel'
import IntegracionMercadoLibrePanel from './components/IntegracionMercadoLibrePanel'
import EmailConfiguracionPanel from './components/EmailConfiguracionPanel'
import EjecucionAutomaticaPanel from './components/EjecucionAutomaticaPanel'
import ResumenVentasCard from './components/ResumenVentasCard'
import ColaMlAprobacionPanel from './components/ColaMlAprobacionPanel'
import UsuariosPanel from './components/UsuariosPanel'
import ResultToast from './components/ResultToast'
import SectionGuard from './components/SectionGuard'
import NotificationBell from './components/NotificationBell'
import DropdownMenu from './components/DropdownMenu'
import ScreenToolbar from './components/ScreenToolbar'
import TabBar from './components/TabBar'
import { ToolbarProvider } from './context/ToolbarContext'
import { TabsProvider, useTabs, INICIO_TAB } from './context/TabsContext'
import { SyncIcon } from './components/icons/HeaderIcons'
import './App.css'

// #configurarApiBase: URL del backend consumida por toda la aplicación.
import { API_BASE_URL } from './utils/apiBase'

const productTemplate = {
  empresaId: '',
  sku: '',
  titulo: '',
  precioPropuesto: '',
  precioMinimoPermitido: '',
  precioMaximoPermitido: '',
  stockDisponible: '',
  stockMinimo: '',
  stockMaximo: '',
  costoBase: '',
  iva: '',
  comisionMLPorc: '',
  costoEnvioPromedio: '',
  costoLogisticoFijo: '',
  costoFinancieroPorc: '',
  costoPublicidadPorc: '',
  estadoPublicacion: '',
  idioma: 'ES',
  origen: '',
  modoSimulacion: false,
  persistir: false,
}

// #plantillasAdminForm: valores por defecto de cada ABM; Activo/Activa arrancan en true
// para que coincida con el DEFAULT (1) real de la base y evitar mandar '' donde el backend espera un bool.
const ADMIN_FORM_TEMPLATES = {
  empresa: { RazonSocial: '', CUIT: '', Activo: true },
  moneda: { CodigoISO: '', Nombre: '', Simbolo: '', Activa: true },
  cotizacion: { MonedaID: '', Cotizacion: '', FechaCotizacion: '' },
  parametro: { EmpresaID: '', MonedaPrincipalID: '', MonedaSecundariaID: '' },
  cuentaML: { EmpresaID: '', UserIDML: '', NicknameML: '', AccessToken: '', RefreshToken: '', FechaVencimientoToken: '', Activo: true },
  producto: { EmpresaID: '', SKU: '', Titulo: '', CategoriaID: '', Marca: '', Modelo: '', Activo: true },
  costoProducto: { ProductoID: '', CostoCompra: '', PorcentajeIVA: '', ImpuestosInternos: '', CostoEnvioPromedio: '', CostoLogisticoFijo: '', CostoFinancieroPorc: '', CostoPublicidadPorc: '', OtrosCostosFijos: '' },
  publicacionML: { ProductoID: '', CuentaMLID: '', MeliItemID: '', TipoPublicacion: 'free', ComisionMLPorc: '', Estado: 'active', EsCatalogo: false, PrecioActual: '', PrecioMinimoPermitido: '', PrecioMaximoPermitido: '', PrecioObjetivo: '' },
  stockEstado: { ProductoID: '', StockActual: '', StockReservado: '', StockMinimo: '', StockMaximo: '', StockObjetivo: '' },
  estrategia: { EmpresaID: '', NombreEstrategia: '', Descripcion: '', Activa: true },
  regla: { CodigoRegla: 'REGLA_STOCK_CRITICO', Nombre: '', Descripcion: '', TipoRegla: 'MARGEN', CondicionJSON: '', Activa: true },
  estrategiaRegla: { EstrategiaID: '', ReglaID: '', Prioridad: '', ParametrosJSON: '', Activa: true },
  parametrosRegla: { EstrategiaReglaID: '', Clave: 'PORCENTAJE_INCREMENTO_STOCK_CRITICO', Valor: '', Descripcion: '', Activo: true },
  mensajesRegla: { EstrategiaReglaID: '', Clave: 'MENSAJE_STOCK_CRITICO', Idioma: 'ES', Valor: '', Descripcion: '', Activo: true },
  configuracion: { EmpresaID: '', ClaveParametro: 'MARGEN_MINIMO_PERMITIDO', ValorParametro: '', Descripcion: '' },
}

const cloneAdminFormTemplates = () =>
  Object.fromEntries(Object.entries(ADMIN_FORM_TEMPLATES).map(([entity, fields]) => [entity, { ...fields }]))

// #pantallasSueltas: pantallas que no son sub-tab de admin/reports/manual -- cada una es su
// propia pestaña con su propio SectionGuard (seccion + soloAdmin como antes en <Routes>).
const STANDALONE_SCREENS = {
  health: { seccion: 'health', soloAdmin: true },
  erp: { seccion: 'erp', soloAdmin: true },
  'ml-integracion': { seccion: 'ml-integracion', soloAdmin: true },
  'email-integracion': { seccion: 'email-integracion', soloAdmin: true },
  'cola-ml-aprobacion': { seccion: 'cola-ml-aprobacion', soloAdmin: false },
  'ejecucion-automatica': { seccion: 'ejecucion-automatica', soloAdmin: true },
  usuarios: { seccion: 'usuarios', soloAdmin: true },
}

const endpoints = [
  { name: 'GET /health', group: 'Health', method: 'GET' },
  { name: 'POST /pricing/evaluate', group: 'Pricing', method: 'POST' },
  { name: 'POST /api/input/ui/product', group: 'Pricing', method: 'POST' },
  // Admin - Empresas
  { name: 'GET /api/admin/empresas', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/empresas', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/empresas/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/empresas/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Monedas
  { name: 'GET /api/admin/monedas', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/monedas', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/monedas/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/monedas/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Cotizaciones
  { name: 'GET /api/admin/cotizaciones', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/cotizaciones', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/cotizaciones/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/cotizaciones/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Parámetros Generales
  { name: 'GET /api/admin/parametros-generales', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/parametros-generales', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/parametros-generales/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/parametros-generales/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Cuentas ML
  { name: 'GET /api/admin/cuentas-ml', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/cuentas-ml', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/cuentas-ml/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/cuentas-ml/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Productos
  { name: 'GET /api/admin/productos', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/productos', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/productos/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/productos/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Costos Producto
  { name: 'GET /api/admin/costos-producto', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/costos-producto', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/costos-producto/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/costos-producto/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Publicaciones ML
  { name: 'GET /api/admin/publicaciones-ml', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/publicaciones-ml', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/publicaciones-ml/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/publicaciones-ml/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Stock Estado
  { name: 'GET /api/admin/stock-estado', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/stock-estado', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/stock-estado/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/stock-estado/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Estrategias
  { name: 'GET /api/admin/estrategias', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/estrategias', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/estrategias/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/estrategias/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Reglas
  { name: 'GET /api/admin/reglas', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/reglas', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/reglas/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/reglas/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Estrategia-Reglas
  { name: 'POST /api/admin/estrategia/{estrategiaId}/reglas', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/estrategia/{estrategiaId}/reglas/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/estrategia/{estrategiaId}/reglas/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Configuración Parámetros
  { name: 'GET /api/admin/configuracion-parametros', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/configuracion-parametros', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/configuracion-parametros/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/configuracion-parametros/{id}', group: 'Admin', method: 'DELETE' },
  // Admin - Decisiones (generadas por spCalcularDecision; sin edición manual desde la UI)
  { name: 'GET /api/admin/decisiones', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/decisiones', group: 'Admin', method: 'POST' },
  // Admin - Decisiones Detalle Auditoría
  { name: 'GET /api/admin/decisiones-detalle-auditoria', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/decisiones-detalle-auditoria', group: 'Admin', method: 'POST' },
  // Admin - Métricas Ventas
  { name: 'GET /api/admin/metricas-ventas-hist', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/metricas-ventas-hist', group: 'Admin', method: 'POST' },
  // Admin - Competencia Snapshot
  { name: 'GET /api/admin/competencia-snapshot', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/competencia-snapshot', group: 'Admin', method: 'POST' },
  // Admin - Cola Ejecución ML (generada por spCalcularDecision; sin edición manual desde la UI)
  { name: 'GET /api/admin/cola-ejecucion-ml', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/cola-ejecucion-ml', group: 'Admin', method: 'POST' },
  // Admin - Parámetros y mensajes por estrategia-regla
  { name: 'GET /api/admin/estrategias-reglas-parametros/estrategia-regla/{id}', group: 'Admin', method: 'GET' },
  { name: 'GET /api/admin/estrategias-reglas-parametros/estrategia/{id}/vigentes', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/estrategias-reglas-parametros', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/estrategias-reglas-parametros/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/estrategias-reglas-parametros/{id}', group: 'Admin', method: 'DELETE' },
  { name: 'GET /api/admin/estrategias-reglas-parametros-mensajes/estrategia-regla/{id}', group: 'Admin', method: 'GET' },
  { name: 'GET /api/admin/estrategias-reglas-parametros-mensajes/estrategia/{id}/vigentes', group: 'Admin', method: 'GET' },
  { name: 'POST /api/admin/estrategias-reglas-parametros-mensajes', group: 'Admin', method: 'POST' },
  { name: 'PUT /api/admin/estrategias-reglas-parametros-mensajes/{id}', group: 'Admin', method: 'PUT' },
  { name: 'DELETE /api/admin/estrategias-reglas-parametros-mensajes/{id}', group: 'Admin', method: 'DELETE' },
]

const functionalGuide = [
  {
    title: '¿Qué es este sistema?',
    content:
      'Pricing Engine es una herramienta que ayuda a decidir el precio más adecuado para un producto en Mercado Libre. Analiza datos del producto, stock, costos, competencia y reglas de negocio para recomendar si conviene subir, bajar o mantener el precio.',
  },
  {
    title: '¿Para quién sirve?',
    content:
      'Está pensado para usuarios de negocio, administradores, analistas y personas que gestionan precios sin necesidad de conocer programación. La intención es que cualquier persona pueda completar los datos del producto y obtener una recomendación clara.',
  },
  {
    title: '¿Cómo funciona en la práctica?',
    content:
      'Primero se completa la información del producto y del contexto comercial. Luego se ejecuta la evaluación. El sistema revisa el margen, el stock, la competencia y las reglas establecidas para devolver una recomendación con explicación.',
  },
  {
    title: 'Secciones principales del sistema',
    list: [
      'Pricing: permite evaluar un producto y obtener una recomendación de precio.',
      'Formularios: permite administrar datos maestros, configuraciones, parámetros y mensajes de una Estrategia-Regla.',
      'Reportes: permite consultar tablas por filtros, rangos, orden y paginación; las fuentes históricas son solo lectura.',
      'Health: verifica si la API está disponible.',
      'API docs: muestra los endpoints del sistema para desarrolladores y soporte técnico.',
    ],
  },
  {
    title: 'Flujo recomendado para un usuario final',
    list: [
      'Ingresá a la sección Pricing.',
      'Completa los datos obligatorios: Empresa ID, SKU, Título, Precio propuesto, Stock disponible, Costo base y rangos de precio.',
      'Si el producto tiene costos adicionales, completá también IVA, comisión, logística y publicidad.',
      'Hacé clic en Evalúa.',
      'Leé la recomendación y la explicación del resultado.',
      'Si corresponde, usá Persistir y evaluar para guardar la decisión y dejarla lista para ejecución.',
    ],
  },
  {
    title: 'Qué significa cada campo',
    list: [
      'Empresa ID: identifica a la empresa a la que pertenece el producto.',
      'SKU: código interno del producto.',
      'Título: nombre visible del producto.',
      'Precio propuesto: precio que se quiere analizar o recomendar.',
      'Precios mínimo y máximo: rango permitido para evitar decisiones imposibles o poco competitivas.',
      'Stock disponible: cantidad de unidades actuales disponibles.',
      'Stock mínimo y máximo: niveles de inventario deseados.',
      'Costo base: costo de compra o producción del producto.',
      'IVA y comisiones: variables que afectan el margen real.',
      'Estado de publicación: indica si el producto está activo, pausado o en otra condición.',
      'Idioma: selecciona el idioma del motivo de la decisión. Se admiten ES, EN y PT; si no existe una traducción, se usa ES.',
      'Modo simulación: permite probar una decisión sin provocar cambios reales.',
      'Persistir: guarda la decisión en el sistema para continuar el flujo.',
    ],
  },
  {
    title: 'Cómo interpretar la recomendación',
    content:
      'El sistema no solo devuelve un número: también explica por qué. El resultado puede indicar que conviene mantener, subir o bajar el precio según el margen, el stock, la demanda y la estrategia definida. Si aparece una validación o una alerta, significa que algún dato necesario está incompleto o que hay una regla de negocio que no se puede cumplir. Un requisito previo: la Empresa del producto necesita tener al menos una Estrategia activa (Formularios → Estrategias) — sin eso, el sistema no tiene con qué calcular y lo avisa con un mensaje claro en vez de calcular cualquier cosa.',
  },
  {
    title: 'Sección de administración',
    content:
      'En Formularios se gestionan los datos maestros que alimentan el motor: empresas, monedas, productos, estrategias, reglas y configuraciones. También se administran parámetros y mensajes asociados a una Estrategia-Regla. Los campos con relación a otras tablas aparecen como listas desplegables con una etiqueta del tipo “Descripción (ID)”. Esto ayuda a elegir un valor correcto sin memorizar números.',
  },
  {
    title: 'Cómo usar los selects con FK',
    content:
      'Cuando un campo pertenece a otra entidad, por ejemplo una empresa o un producto, el sistema muestra un listado. Cada opción se ve como “Nombre o descripción (ID: número)”. Eso permite identificar fácilmente la entidad correcta sin tener que recordar su ID exacto.',
  },
  {
    title: 'Reportes',
    content:
      'La sección de reportes sirve para consultar información histórica o segmentada. Elegí una vista, completá filtros simples o rangos y presioná Ejecutar; la consulta no se lanza al cambiar de pantalla ni al escribir. Podés ordenar con campo:asc o campo:desc y recorrer los resultados paginados.',
  },
  {
    title: 'Parámetros y mensajes por Estrategia-Regla',
    content:
      'Los parámetros definen valores numéricos de una regla dentro de una estrategia, por ejemplo un porcentaje de ajuste. Los mensajes definen plantillas explicativas por idioma y admiten los tokens {PORCENTAJE}, {PRECIO_NUEVO}, {PRECIO_ANTERIOR} y {COMPETIDOR_PRECIO}. En ambos formularios ingresá el ID de Estrategia-Regla, cargá la clave, definí la vigencia y guardá. Las actualizaciones crean una nueva versión histórica y los períodos superpuestos se rechazan.',
  },
  {
    title: 'Historiales y auditoría',
    content:
      'Métricas de ventas, snapshots de competencia, decisiones históricas y auditorías son fuentes automáticas e inmutables. Se consultan únicamente desde Reportes: no tienen formularios de alta, edición ni baja. Los reportes especializados de parámetros y mensajes solicitan Estrategia ID o Estrategia-Regla ID según corresponda.',
  },
  {
    title: 'Consejos prácticos',
    list: [
      'No dejes campos vacíos cuando sean obligatorios.',
      'Usá valores realistas de stock y costos para que la recomendación sea útil.',
      'Si no estás seguro de un dato, revisá primero la sección de administración.',
      'Al usar Admin, elegí siempre una opción del desplegable antes de guardar.',
      'Si la validación marca un error, corregí el dato indicado antes de volver a evaluar.',
    ],
  },
  {
    title: 'Reglas generales del sistema',
    list: [
      'El sistema trabaja con información de empresa, producto, costo y stock.',
      'Las decisiones se basan en reglas de negocio y objetivos de rentabilidad.',
      'La simulación es útil para probar escenarios sin afectar producción.',
      'La persistencia guarda la decisión para que pueda ser procesada o ejecutada luego.',
      'La auditoría ayuda a entender por qué se tomó una decisión.',
    ],
  },
]

const decisionFlowGuide = [
  {
    title: '¿Qué hace el motor de decisión?',
    content:
      'El procedimiento spCalcularDecision es la lógica central que decide si conviene mantener, subir o bajar el precio de un producto. En términos funcionales, toma el contexto del producto y aplica reglas comerciales para producir una recomendación útil, segura y explicable.',
  },
  {
    title: 'Flujo funcional del motor',
    list: [
      'Recibe la información del producto, la empresa, el stock, los costos y la publicación asociada.',
      'Valida que el producto tenga contexto suficiente para tomar una decisión: precio, costo, stock y datos de negocio.',
      'Revisa el margen actual y proyectado para saber si el precio es rentable o si está dejando dinero sobre la mesa.',
      'Compara el precio con referencias de competencia y con los límites definidos por la empresa.',
      'Consulta la estrategia activa y aplica las reglas de negocio en orden de prioridad — si la empresa no tiene ninguna estrategia activa configurada, el motor no puede seguir y devuelve un mensaje claro pidiendo que se configure una antes de reintentar.',
      'Evalúa si el cambio propuesto puede generar riesgo: margen insuficiente, stock crítico, límite de publicación o aumento excesivo.',
      'Genera una decisión final con una acción concreta: mantener, subir, bajar o bloquear.',
      'Guarda la decisión en historial para poder auditar por qué se tomó esa acción.',
      'Si el modo es producción, la decisión puede pasar a cola de ejecución para que se aplique en Mercado Libre.',
    ],
  },
  {
    title: 'Cómo se interpreta la decisión',
    content:
      'El motor no busca “poner el precio más alto” ni “el más bajo” como criterio único. Busca un equilibrio entre rentabilidad, competitividad y disponibilidad. Por eso, una recomendación puede ser “mantener” aunque el precio actual no sea el máximo posible, porque la estrategia prioriza estabilidad o margen real.',
  },
  {
    title: 'Qué considera para decidir',
    list: [
      'Margen neto del producto.',
      'Stock disponible y niveles mínimos/máximos.',
      'Precio actual y precio propuesto.',
      'Competencia directa y precios relevantes.',
      'Reglas del negocio y estrategia vigente.',
      'Bloqueos de seguridad para evitar decisiones perjudiciales.',
      'Historial para evitar movimientos bruscos o inconsistentes.',
    ],
  },
  {
    title: 'Ejemplo funcional simple',
    content:
      'Si un producto tiene buen margen, stock suficiente y la competencia está más alta, el motor puede recomendar subir el precio. Si el producto tiene margen bajo, stock limitado y la competencia está más baja, puede decidir bajar el precio para sostener competitividad. Si la regla de negocio indica que no se puede bajar más de cierto porcentaje, el motor bloquea la acción y recomienda mantener el precio.',
  },
  {
    title: '¿Contra qué compara el precio, exactamente?',
    list: [
      'Margen mínimo permitido: un porcentaje configurado por empresa (parámetro MARGEN_MINIMO_PERMITIDO, 15% si no se configuró otro). Si una baja de precio dejaría el margen por debajo de ese piso, el motor la bloquea y mantiene el precio actual, con el motivo "BLOQUEO SEGURIDAD: la baja sugerida viola el margen mínimo permitido".',
      'Precio mínimo y máximo permitido de la publicación: si el precio calculado por cualquier regla queda fuera de ese rango, se recorta al límite más cercano ("Ajustado al Límite Mínimo/Máximo Permitido por Publicación").',
      'Nivel de stock: se clasifica en CRÍTICO, BAJO, NORMAL, ALTO o EXCESO comparando el stock disponible contra el Stock mínimo y máximo configurados del producto (por ejemplo, CRÍTICO es stock disponible ≤ stock mínimo).',
      'El precio de la competencia (ver el punto siguiente).',
      'Cooldown y variación mínima: si el precio de esa publicación cambió hace menos de 12 horas, o el cambio propuesto es menor al 1,50%, el motor no lo aplica y lo marca "BLOQUEO COOLDOWN/HISTÉRESIS" — esto evita que el precio esté subiendo y bajando todo el tiempo por variaciones insignificantes.',
    ],
  },
  {
    title: '¿Contra quién compara: de dónde sale el precio de la competencia?',
    content:
      'Acá hay una diferencia importante según el tipo de publicación, porque Mercado Libre no deja consultar el precio de cualquier vendedor por API — solo el propio.',
    list: [
      'Publicaciones de catálogo (EsCatalogo = Sí): Mercado Libre tiene un mecanismo propio, el "buy box" de catálogo — varios vendedores compiten por la misma ficha de producto, y ML define quién "gana" la oferta. El sistema le pregunta a Mercado Libre, publicación por publicación, "¿estoy ganando la oferta o no, y a qué precio la ganaría?" (endpoint price_to_win de ML). Si NO estamos ganando, se guarda automáticamente un registro de competencia con el precio necesario para ganar — no hace falta que nadie cargue nada a mano.',
      'Publicaciones que no son de catálogo: acá Mercado Libre bloquea (403) cualquier intento de leer el precio o buscar productos de otro vendedor por API. No hay forma automática de saber el precio de la competencia. La solución es manual: en la pantalla de "Competidores" de cada publicación, una persona pega el link o el ID del aviso competidor y su precio a mano. Cada vez que se actualiza ese precio manualmente, queda igual guardado como un registro de competencia — el motor no distingue después si ese dato vino de Mercado Libre o de una persona.',
      'Los registros de competencia tienen una fecha de captura y el motor solo usa los de las últimas 48 horas — uno más viejo que eso se ignora, como si no existiera.',
      'Con esos registros calcula dos cosas: el precio mínimo de cualquier competidor visto, y la "posición competitiva" (cuántos competidores nos ganan en precio, más uno).',
    ],
  },
  {
    title: 'De dónde entran los datos del producto: la integración con el ERP',
    content:
      'El SKU, el título, el costo de compra, el IVA y el stock de un producto no tienen por qué cargarse a mano en Formularios — se pueden traer automáticamente del sistema de gestión (ERP) del cliente, de dos maneras que pueden convivir:',
    list: [
      'El ERP empuja los datos: el propio ERP del cliente le avisa al sistema cuando algo cambió, mandándole la información por su cuenta (con una clave de acceso propia). No depende de que nadie haga clic en nada acá.',
      'El sistema va a buscar los datos al ERP: con el botón "Actualizar desde ERP" (en el desplegable de Sincronización de la barra superior), o automáticamente si la Ejecución automática está activada (ver más abajo), el sistema le pide al ERP su información más reciente.',
      'Antes de que cualquiera de las dos formas funcione, hay que configurar la conexión una sola vez en Configuración → Integración ERP: se indica la URL del ERP, se usa "Descubrir campos del ERP" para que el sistema detecte solo qué nombres de campo usa ese ERP en particular, y se hace corresponder cada uno con el campo que necesita el sistema (SKU, Título, Costo de compra, IVA, Stock, etc.).',
      'El ERP es dueño de un conjunto acotado de datos: SKU, Título, Costo de compra, IVA, Impuestos internos, Stock actual y Stock mínimo/máximo. Otros costos que también afectan el margen (envío, logística, financiero, publicidad) el ERP no los toca nunca — esos se cargan y mantienen a mano en Formularios, porque son decisiones del área de precios, no del ERP.',
    ],
  },
  {
    title: 'Qué hace exactamente en Mercado Libre',
    list: [
      'Leer: cada vez que se sincroniza (a mano o automático), el sistema le pregunta a Mercado Libre el precio y el estado actuales de cada publicación abierta, y los actualiza en el sistema — así, si alguien cambió el precio directamente desde Mercado Libre, el sistema se entera igual. También trae el historial de ventas (pedidos pagados) para calcular cuánto se está vendiendo por día en distintas ventanas (7/15/30/60/90 días).',
      'Escribir (cambiar el precio de verdad): esto pasa en un momento bien puntual y separado — cuando una recomendación del motor queda aprobada y lista, el sistema le pide a Mercado Libre que actualice el precio de esa publicación puntual. Es la ÚNICA acción de todo el sistema que efectivamente cambia un precio real y visible en Mercado Libre — todo lo anterior (evaluar, guardar la decisión, ponerla en cola) todavía no tocó nada en Mercado Libre.',
      'Antes de escribir, casi siempre hay una aprobación humana de por medio: una publicación que no es de catálogo, o una de catálogo si la empresa no habilitó la subida automática, queda esperando en la pantalla "Cola ML (Aprobación)" hasta que alguien apruebe o rechace el cambio. Solo las publicaciones de catálogo con la subida automática habilitada (una configuración por empresa) se aplican sin pedir aprobación. Aprobar en esa pantalla todavía no cambia el precio en Mercado Libre — solo lo autoriza; el envío real ocurre en la siguiente sincronización (a mano con "Procesar cola ML", o en el próximo ciclo automático).',
    ],
  },
  {
    title: 'Cuándo se actualiza todo esto automáticamente',
    content:
      'Todo lo anterior (traer del ERP, evaluar, aprobar cuando corresponde, escribir en Mercado Libre, leer de vuelta) se puede disparar a mano, pantalla por pantalla — o dejarse en piloto automático desde Formularios → Ejecución automática.',
    list: [
      'Se activa con un simple check "Activar ejecución automática" y se define cada cuántos minutos correr (30 minutos por defecto, nunca menos de 1).',
      'Cuando está activa, cada vez que se cumple ese intervalo el sistema hace, en orden, las 4 cosas de este apartado: 1) trae novedades del ERP, 2) vuelve a evaluar todos los productos con una publicación de Mercado Libre abierta, 3) sube a Mercado Libre lo que ya esté aprobado (o no necesite aprobación), 4) lee de vuelta precios, estados y ventas desde Mercado Libre.',
      'Un producto sin ninguna publicación abierta en Mercado Libre, o marcado como inactivo, se salta en este proceso automático — no tiene sentido evaluarlo si no hay dónde aplicar el resultado.',
      'La misma pantalla de Ejecución automática muestra cuándo corrió por última vez y un resumen en palabras simples de lo que hizo (por ejemplo, "12 productos sincronizados · 40 evaluados, 6 cambios de precio · 5 subidos a Mercado Libre"), y tiene un botón "Ejecutar ahora" para correr el ciclo completo en el momento, sin esperar al intervalo.',
    ],
  },
  {
    title: 'El recorrido completo, de punta a punta',
    content:
      'Uniendo todo: el costo y el stock de un producto entran por el ERP (empujados por el ERP mismo, o traídos por el sistema); el precio de la competencia entra automático para publicaciones de catálogo (Mercado Libre dice si estamos ganando o no) o a mano para el resto (alguien carga el precio del competidor); con esos datos, el motor de decisión calcula si conviene mantener, subir o bajar el precio, respetando el margen mínimo, los límites de la publicación y el freno anti-vaivén; si la decisión implica un cambio de precio, queda en una cola esperando aprobación humana (salvo catálogo con subida automática); una vez aprobada, el sistema recién ahí le pide a Mercado Libre que aplique el precio nuevo — y en la próxima sincronización confirma que quedó bien leyendo el precio actualizado de vuelta. Todo este circuito puede correr solo, a intervalos regulares, si se activa la Ejecución automática — o pantalla por pantalla, a mano, si se prefiere tener control manual en cada paso.',
  },
  {
    title: 'Importancia para el usuario final',
    content:
      'Aunque el nombre técnico sea spCalcularDecision, funcionalmente es el “motor de recomendación” del sistema. Lo importante para el usuario no es la parte técnica, sino entender que esta lógica toma decisiones comerciales apoyadas en datos reales y reglas definidas por la empresa.',
  },
]

const userManualGuide = [
  {
    title: '¿Por dónde empiezo?',
    content:
      'Esta guía está pensada para alguien que abre el sistema por primera vez y no tiene por qué saber nada de programación ni de bases de datos. Vamos a recorrer, paso a paso y con capturas de pantalla reales, las tres cosas que más se usan: evaluar el precio de un producto, cargar o modificar datos, y consultar información. No hace falta leerla de punta a punta: cada bloque funciona solo, así que podés ir directo al que necesites.',
    image: {
      src: '/docs/manual-inicio.jpg',
      alt: 'Pantalla de Inicio del sistema, con el menú a la izquierda y el resumen de ventas',
      caption: 'Así se ve la pantalla de Inicio apenas entrás. A la izquierda está el menú con todas las secciones (Formularios, Reportes, etc.); arriba, las pestañas de lo que tenés abierto.',
    },
  },
  {
    title: 'Los tres elementos que vas a ver siempre',
    list: [
      'El menú de la izquierda: para moverte entre las distintas pantallas del sistema. Un triangulito al lado de un nombre significa que tiene más opciones adentro — hacé clic para desplegarlas.',
      'Las pestañas de arriba: cada pantalla que abrís queda como una pestaña, igual que en un navegador de internet. Podés tener varias abiertas a la vez y saltar entre ellas sin perder lo que estabas haciendo. La "X" de cada pestaña la cierra.',
      'La franja de herramientas: debajo de las pestañas hay unos íconos (hoja en blanco, carpeta, lápiz, tacho de basura, disquete) que sirven para Nuevo registro, Mostrar/ocultar filtros, Editar, Eliminar y Guardar. Cambian según qué pantalla tengas abierta.',
    ],
  },
  {
    title: 'Paso a paso: evaluar el precio de un producto',
    list: [
      'En el menú de la izquierda, buscá "Test" y adentro hacé clic en "Evaluar precio".',
      'Elegí la Empresa escribiendo su nombre en el campo "Empresa ID" y clickeando la opción correcta de la lista que aparece (no hace falta saber el número, alcanza con el nombre).',
      'Completá el SKU (el código interno del producto) y el Título.',
      'Cargá el Precio propuesto (el precio que querés analizar) y, si los tenés, el Precio mínimo y el Precio máximo permitidos.',
      'Completá el Stock disponible y, si querés, los niveles de Stock mínimo y máximo.',
      'Cargá el Costo base del producto y, si corresponden, el IVA, la Comisión de Mercado Libre y los demás costos (envío, logística, financiero, publicidad).',
      'Si solo querés probar sin que quede nada guardado, dejá tildado "Modo simulación".',
      'Hacé clic en el botón "Evaluar".',
    ],
    image: {
      src: '/docs/manual-evaluar-formulario.jpg',
      alt: 'Formulario de Evaluación de precio completo con datos de ejemplo de un producto',
      caption: 'El formulario completo, listo para evaluar. Los datos de este ejemplo son ficticios, para que veas cómo se completa cada campo.',
    },
  },
  {
    title: 'Qué hacer con el resultado',
    content:
      'Después de hacer clic en "Evaluar", a la derecha del formulario aparece el "Resultado" con la respuesta del sistema. A primera vista se ve como un bloque de texto técnico (lo que se llama formato JSON) — no hace falta entenderlo, es solo el detalle interno. Fijate que arriba de ese bloque hay un enlace "Ver detalle": hacé clic ahí para ver la misma información, pero traducida a tarjetas fáciles de leer.',
    image: {
      src: '/docs/manual-evaluar-resultado.jpg',
      alt: 'Panel de Resultado mostrando la respuesta técnica de la evaluación en formato JSON',
      caption: 'El "Resultado" que aparece apenas evaluás. Es el detalle técnico completo — arriba a la derecha está el enlace "Ver detalle" para verlo en un formato más simple.',
    },
  },
  {
    title: 'La pantalla de Detalle de decisión, explicada campo por campo',
    list: [
      'Precio actual: el precio que tenía el producto antes de evaluar.',
      'Precio sugerido: el precio que el sistema recomienda, según el margen, el stock, la competencia y las reglas del negocio.',
      'Acción: qué conviene hacer — AUMENTAR_PRECIO, DISMINUIR_PRECIO o MANTENER_PRECIO.',
      'Margen: qué porcentaje de ganancia deja el producto con el precio actual.',
      'Score: qué tan confiable es la recomendación, de 0 a 1 (cuanto más cerca de 1, más segura es la sugerencia).',
      'Motivo: la explicación en palabras simples de por qué el sistema decidió lo que decidió — este es el campo más importante para entender la recomendación de un vistazo.',
    ],
    image: {
      src: '/docs/manual-evaluar-detalle.jpg',
      alt: 'Pantalla de Detalle de decisión con tarjetas legibles: precio actual, precio sugerido, acción, margen, score y motivo',
      caption: 'La pantalla de "Detalle de decisión" — mucho más fácil de leer que el JSON. Acá se ve clarito que para este producto el sistema recomienda subir el precio ("AUMENTAR_PRECIO") y por qué.',
    },
  },
  {
    title: 'Si aparece un mensaje de error al evaluar',
    content:
      'Cuando algo no está bien para poder evaluar, el sistema lo avisa con un cartel rojo arriba del formulario, con una frase en español que explica exactamente qué falta — no hace falta entender de sistemas para leerlo. Los más comunes:',
    list: [
      '"No existe una estrategia activa configurada para la empresa": la Empresa que elegiste todavía no tiene ninguna Estrategia de precios cargada y activa. Solución: andá a Formularios → Estrategias, creá una para esa empresa (o activá una que ya exista cambiando su Estado a "Activa") y volvé a evaluar.',
      'Mensajes sobre un campo puntual (por ejemplo, que el Precio propuesto no puede estar vacío o ser menor al Precio mínimo): revisá ese campo en particular, corregilo y volvé a hacer clic en "Evaluar".',
    ],
  },
  {
    title: 'Paso a paso: cargar o modificar datos (Formularios)',
    list: [
      'En el menú de la izquierda, entrá a "Formularios" y elegí qué querés cargar (por ejemplo, "Producto", dentro de "Productos").',
      'A la izquierda de la pantalla vas a ver dos bloques: arriba "Filtros" (para buscar algo que ya existe) y abajo "Registros" (la lista de lo que ya está cargado). Podés arrastrar la línea que los separa para agrandar uno u otro.',
      'Para cargar algo nuevo, hacé clic en el ícono de la hoja en blanco (arriba a la izquierda, "Nuevo registro") y completá el formulario de la derecha.',
      'Los campos que dependen de otra información (por ejemplo, a qué Empresa pertenece un Producto) se completan escribiendo el nombre y eligiendo la opción de la lista que aparece — igual que hicimos con "Empresa ID" en Evaluar precio.',
      'Cuando termines de completar, hacé clic en el ícono del disquete ("Guardar") en la franja de herramientas.',
      'Para modificar algo que ya existe, hacé clic en esa fila dentro de "Registros", después en el ícono del lápiz ("Editar"), cambiá lo que haga falta y volvé a Guardar.',
    ],
    image: {
      src: '/docs/manual-formularios-producto.jpg',
      alt: 'Pantalla de Formularios mostrando el listado de Productos y el formulario para crear uno nuevo',
      caption: 'La pantalla de Producto dentro de Formularios: a la izquierda, Filtros y el listado de Registros; a la derecha, el formulario para crear uno nuevo.',
    },
  },
  {
    title: 'Cómo ver el detalle de algo que ya está cargado',
    content:
      'Simplemente hacé clic en cualquier fila del listado de "Registros" (a la izquierda). El formulario de la derecha se llena solo con los datos de ese registro, en modo "Ver" (los campos aparecen deshabilitados, para que no se modifiquen sin querer). Si necesitás cambiar algo, usá el ícono del lápiz ("Editar") de la franja de herramientas.',
    image: {
      src: '/docs/manual-formularios-ver.jpg',
      alt: 'Formulario en modo Ver Producto, con los datos de un producto ya cargado y los campos deshabilitados',
      caption: 'Al hacer clic en una fila del listado, el formulario se abre en modo "Ver Producto" con los datos ya cargados.',
    },
  },
  {
    title: 'Paso a paso: consultar información sin modificar nada (Reportes)',
    list: [
      'En el menú de la izquierda, entrá a "Reportes" y elegí qué querés consultar (por ejemplo, "Productos").',
      'Completá los filtros que necesites en el panel de la izquierda (podés dejarlos todos vacíos para traer todo).',
      'Hacé clic en "Buscar".',
      'El resultado aparece como una tabla a la derecha, con paginación abajo para recorrer todos los resultados.',
      'Esta sección es solo de consulta: no tiene botones de Nuevo, Editar ni Guardar, porque su función es mostrar información, no modificarla.',
    ],
    image: {
      src: '/docs/manual-reportes-productos.jpg',
      alt: 'Pantalla de Reportes mostrando una tabla con el listado completo de Productos',
      caption: 'El Reporte de Productos, con todos los productos cargados en una tabla que se puede recorrer y filtrar.',
    },
  },
  {
    title: 'Caso práctico 1: producto con margen bajo',
    content:
      'Si el costo base es alto y el precio propuesto está muy cerca del umbral mínimo, el sistema puede recomendar subir el precio o ajustar la estrategia. Si el negocio no permite ese aumento, el motor puede bloquear la decisión porque sería inviable.'
  },
  {
    title: 'Caso práctico 2: producto con stock crítico',
    content:
      'Cuando el stock disponible es bajo, el motor puede recomendar precios más altos o mantener la recomendación actual para evitar faltantes. El objetivo es equilibrar ventas y disponibilidad.'
  },
  {
    title: 'Caso práctico 3: producto muy competitivo',
    content:
      'Si el precio del competidor es más bajo y el producto tiene margen suficiente, el sistema puede sugerir reducir el precio para mantener competitividad y seguir vendiendo.'
  },
  {
    title: 'Caso práctico 4: producto con estrategia estable',
    content:
      'Si la estrategia de la empresa prioriza estabilidad, el motor puede mantener el precio incluso cuando el margen podría aumentar un poco. Eso evita cambios bruscos y mejora consistencia comercial.'
  },
  {
    title: 'Cómo descargar esta guía',
    content:
      'Arriba a la derecha de esta página hay un botón "Descargar en PDF". Al hacer clic se abre el cuadro de impresión normal del navegador: elegí como destino "Guardar como PDF" (o "Microsoft Print to PDF") en vez de una impresora física, y confirmá. Así te queda un archivo con toda esta guía para leer sin conexión o compartir con otra persona.',
  },
]

// #validarFormulario: reglas de validación previas a cualquier POST de pricing.
const getValidationErrors = (payload) => {
  const issues = []

  if (!Number(payload.empresaId) || Number(payload.empresaId) <= 0) {
    issues.push('empresaId debe ser mayor a 0.')
  }

  if (!String(payload.sku || '').trim()) {
    issues.push('sku no puede estar vacío.')
  }

  if (!String(payload.titulo || '').trim()) {
    issues.push('titulo no puede estar vacío.')
  }

  if (!Number(payload.precioPropuesto) || Number(payload.precioPropuesto) <= 0) {
    issues.push('precioPropuesto debe ser mayor a 0.')
  }

  if (!Number(payload.costoBase) || Number(payload.costoBase) <= 0) {
    issues.push('costoBase debe ser mayor a 0.')
  }

  if (Number(payload.stockDisponible) < 0) {
    issues.push('stockDisponible no puede ser negativo.')
  }

  if (Number(payload.stockMinimo) > Number(payload.stockMaximo)) {
    issues.push('stockMinimo no puede ser mayor que stockMaximo.')
  }

  const min = Number(payload.precioMinimoPermitido)
  const max = Number(payload.precioMaximoPermitido)
  const actual = Number(payload.precioPropuesto)

  if (min && max && min > max) {
    issues.push('precioMinimoPermitido no puede ser mayor que precioMaximoPermitido.')
  }

  if (min && actual && actual < min) {
    issues.push('precioPropuesto no puede ser menor que precioMinimoPermitido.')
  }

  if (max && actual && actual > max) {
    issues.push('precioPropuesto no puede ser mayor que precioMaximoPermitido.')
  }

  return issues
}

// #proveedorDePestañas: TabsProvider tiene que envolver a AppContent desde afuera para que
// éste pueda llamar useTabs() -- separado en dos componentes por eso, no por otra razón.
function App({ accountMenu }) {
  return (
    <TabsProvider>
      <AppContent accountMenu={accountMenu} />
    </TabsProvider>
  )
}

function AppContent({ accountMenu }) {
  const navigate = useNavigate()
  const location = useLocation()
  const { openTabs, activeTabKey, openTab } = useTabs()
  // #rielDeIconos: colapsa el sidebar a una columna angosta con solo íconos (sin texto,
  // sin árbol) -- ver Sidebar.jsx, botón .sidebar-toolbar-collapse.
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  // #sidebarRedimensionable: ancho elegido a mano arrastrando .sidebar-resize-handle (ver
  // más abajo) -- no aplica con el sidebar colapsado, que ya tiene su propio ancho fijo de
  // riel angosto (72px, ver .app-shell.collapsed en App.css).
  const [sidebarWidth, setSidebarWidth] = useState(260)
  const sidebarResizeRef = useRef(null)

  useEffect(() => {
    if (!sidebarResizeRef.current) return undefined
    const SIDEBAR_MIN_WIDTH = 200
    const SIDEBAR_MAX_WIDTH = 440
    const alMover = (event) => {
      const nuevoAncho = Math.min(SIDEBAR_MAX_WIDTH, Math.max(SIDEBAR_MIN_WIDTH, event.clientX))
      setSidebarWidth(nuevoAncho)
    }
    const alSoltar = () => {
      document.removeEventListener('mousemove', alMover)
      document.removeEventListener('mouseup', alSoltar)
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
    }
    const alBajarElMouse = () => {
      document.addEventListener('mousemove', alMover)
      document.addEventListener('mouseup', alSoltar)
      // #cursorYSeleccionMientrasArrastra: sin esto, arrastrar rápido selecciona texto de la
      // página (comportamiento normal del navegador al mover el mouse con el botón apretado)
      // y el cursor col-resize solo se ve sobre la propia manija, parpadeando feo al arrastrar.
      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
    }
    const handle = sidebarResizeRef.current
    handle.addEventListener('mousedown', alBajarElMouse)
    return () => {
      handle.removeEventListener('mousedown', alBajarElMouse)
      document.removeEventListener('mousemove', alMover)
      document.removeEventListener('mouseup', alSoltar)
    }
  }, [sidebarCollapsed])

  // #altoRealDeMainPanel: .abm-list-column (la franja de Filtros de Formularios/Reportes,
  // ver App.css #panelDeFiltrosFueraDeLaTarjeta) necesita el alto real y actual de
  // .main-panel para ocupar la pantalla restante de punta a punta -- un height:100% vía la
  // cadena de grids no se resolvía como "definido" en la práctica, y un cálculo fijo tipo
  // calc(100vh - Npx) se desactualiza apenas cambia el alto de la barra de herramientas o
  // del título arriba (ya pasó una vez, ver el commit que sacó el título de .main-panel).
  // Mismo criterio que --sidebar-width: se mide con ResizeObserver y se expone como
  // variable CSS en el propio elemento, así cualquier descendiente (sin importar en qué
  // pestaña/componente esté) la puede leer con var(--main-panel-height).
  const mainPanelRef = useRef(null)
  useEffect(() => {
    const el = mainPanelRef.current
    if (!el) return undefined
    const actualizarAlto = () => {
      el.style.setProperty('--main-panel-height', `${el.getBoundingClientRect().height}px`)
    }
    actualizarAlto()
    const observer = new ResizeObserver(actualizarAlto)
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  const [productForm, setProductForm] = useState(productTemplate)
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState(null)
  const [error, setError] = useState('')
  const [healthStatus, setHealthStatus] = useState(null)
  const [productValidation, setProductValidation] = useState([])
  const [adminForm, setAdminForm] = useState(() => cloneAdminFormTemplates())
  const [erpPullLoading, setErpPullLoading] = useState(false)
  const [erpToast, setErpToast] = useState(null)
  const [mlColaLoading, setMlColaLoading] = useState(false)
  const [mlToast, setMlToast] = useState(null)
  const [mlSyncLoading, setMlSyncLoading] = useState(false)
  const [mlSyncToast, setMlSyncToast] = useState(null)
  // #tituloBuscaEnTodoElArbol: un hijo puede tener sus propios hijos (subgrupo, ver
  // #tercerNivelDeMenu en Sidebar.jsx), y un subgrupo puede a su vez contener otro subgrupo
  // (ej. "MercadoLibre" adentro de "Integraciones", ver #cuartoNivelDeMenu en Sidebar.jsx) --
  // por eso el aplanado es recursivo, sin asumir una profundidad fija. Además, desde
  // #empresasDentroDeConfiguracion un nieto puede vivir en un grupo del menú distinto al de
  // su propia ruta (Empresa cuelga de Configuración en el menú, pero sigue siendo
  // /admin#empresa) -- por eso busca en TODO NAV_ITEMS, no solo adentro de un grupo puntual.
  const flatNavEntries = useMemo(() => {
    const flatten = (items) => items.flatMap((item) => [item, ...(item.children ? flatten(item.children) : [])])
    return flatten(NAV_ITEMS)
  }, [])
  const findLabel = (id) => flatNavEntries.find((entry) => entry.id === id)?.label || id

  const activeTab = openTabs.find((tab) => tab.key === activeTabKey) || null

  // #seccionActivaDesdeLaPestaña: Sidebar resalta el ítem del menú según activeSection /
  // activeSubSection -- antes salían de la URL, ahora de la pestaña activa (puede haber
  // varias pestañas montadas a la vez, la URL sola ya no alcanza para saber cuál se ve).
  const activeSection = !activeTab
    ? 'pricing'
    : activeTab.kind === 'admin'
      ? 'admin'
      : activeTab.kind === 'reports'
        ? 'reports'
        : activeTab.kind === 'manual'
          ? 'manual'
          : activeTab.kind === 'pricing-home'
            ? 'pricing'
            : activeTab.kind === 'evaluar-precio'
              ? 'evaluar-precio'
              : activeTab.screenId
  const activeSubSection = !activeTab
    ? ''
    : activeTab.kind === 'admin'
      ? activeTab.entity
      : activeTab.kind === 'reports'
        ? activeTab.report
        : activeTab.kind === 'manual'
          ? activeTab.section
          : ''

  // #tituloDinamico: refleja en el header la pestaña actualmente activa. /detail no es una
  // pestaña (ver más abajo), por eso es el único caso con título fijo.
  const currentTitle = location.pathname === '/detail' ? 'Detalle de decisión' : activeTab?.label || 'Inicio'

  // #pestañaInicialSegúnUrl: al cargar la app (o refrescar) se abre la pestaña que
  // corresponde a la URL actual, para no arrancar en blanco -- después de este montaje
  // inicial la URL la maneja el efecto de sincronización de abajo, en el sentido pestaña ->
  // URL, no al revés (si no, cambiar de pestaña y navegar competirían entre sí).
  useEffect(() => {
    const path = location.pathname
    if (path === '/detail') return
    const seccion = path.replace('/', '').split('/')[0] || 'pricing'
    const hash = location.hash.replace('#', '')
    let tab
    if (seccion === 'pricing' || seccion === '') {
      tab = INICIO_TAB
    } else if (seccion === 'manual') {
      const target = hash || 'documentacion-funcional'
      tab = { key: `manual:${target}`, kind: 'manual', section: target, label: findLabel(target), path: `/manual#${target}` }
    } else if (seccion === 'admin') {
      const target = hash || 'moneda'
      tab = { key: `admin:${target}`, kind: 'admin', entity: target, label: findLabel(target), path: `/admin#${target}` }
    } else if (seccion === 'reports') {
      const target = hash || 'empresas'
      tab = { key: `reports:${target}`, kind: 'reports', report: target, label: findLabel(target), path: `/reports#${target}` }
    } else if (seccion === 'evaluar-precio') {
      tab = { key: 'evaluar-precio', kind: 'evaluar-precio', label: findLabel('evaluar-precio'), path: '/evaluar-precio' }
    } else {
      tab = { key: seccion, kind: 'standalone', screenId: seccion, label: findLabel(seccion), path: `/${seccion}` }
    }
    openTab(tab)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // #pestañaActivaControlaLaUrl: cada vez que cambia la pestaña activa (por click en el
  // menú, en el TabBar, o al cerrar la pestaña que estaba activa), la URL se actualiza para
  // reflejarla -- así el botón atrás/adelante del navegador y compartir el link siguen
  // teniendo sentido, sin que la navegación misma dispare un desmontaje (nada depende del
  // match de ruta para decidir qué pestaña se ve, ver el bloque de render más abajo).
  useEffect(() => {
    if (!activeTab || !activeTab.path) return
    navigate(activeTab.path, { replace: true })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTabKey])

  useEffect(() => {
    if (!location.hash) return
    const target = document.getElementById(location.hash.replace('#', ''))
    if (target) {
      target.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [location.pathname, location.hash])

  // #errorFantasma: `error` es un cartel global (renderizado una sola vez, arriba de
  // <Routes>), pero antes solo se limpiaba en puntos puntuales de código -- si el error
  // pasaba en una pantalla, quedaba pegado en cualquier otra pantalla a la que navegaras
  // después, aunque ya no aplicara. Cambiar de pantalla (ruta o hash) es la señal correcta
  // de que ese error ya no es relevante.
  useEffect(() => {
    setError('')
  }, [location.pathname, location.hash])

  const updateProductField = (field, value) => {
    setProductForm((prev) => ({
      ...prev,
      [field]: value,
    }))
    setProductValidation([])
  }

  const updateAdminField = (entity, field, value) => {
    setAdminForm((prev) => ({
      ...prev,
      [entity]: {
        ...prev[entity],
        [field]: value,
      },
    }))
  }

  const buildPayload = (persistOverride) => ({
    ...productForm,
    empresaId: Number(productForm.empresaId),
    precioPropuesto: Number(productForm.precioPropuesto),
    precioMinimoPermitido: Number(productForm.precioMinimoPermitido),
    precioMaximoPermitido: Number(productForm.precioMaximoPermitido),
    stockDisponible: Number(productForm.stockDisponible),
    stockMinimo: Number(productForm.stockMinimo),
    stockMaximo: Number(productForm.stockMaximo),
    costoBase: Number(productForm.costoBase),
    iva: Number(productForm.iva),
    comisionMLPorc: Number(productForm.comisionMLPorc),
    costoEnvioPromedio: Number(productForm.costoEnvioPromedio),
    costoLogisticoFijo: Number(productForm.costoLogisticoFijo),
    costoFinancieroPorc: Number(productForm.costoFinancieroPorc),
    costoPublicidadPorc: Number(productForm.costoPublicidadPorc),
    modoSimulacion: Boolean(productForm.modoSimulacion),
    persistir: persistOverride ?? Boolean(productForm.persistir),
  })

  // #crearPost: helper reutilizable para requests JSON; usarlo al agregar un POST.
  const executeRequest = async (endpoint, payload, method = 'POST') => {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
        body: method === 'GET' || method === 'DELETE' ? undefined : JSON.stringify(payload),
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        throw new Error(data?.message || `Request failed with status ${response.status}`)
      }

      return data
    } catch (requestError) {
      if (requestError.message.includes('Failed to fetch')) {
        throw new Error(`❌ No se pudo conectar a la API en ${API_BASE_URL}. Verifica que:
1. El backend esté corriendo en http://localhost:5000
2. CORS esté habilitado en la API (permite requests desde http://localhost:5173)
3. El endpoint ${endpoint} exista en el backend`)
      }

      throw requestError
    }
  }

  const handleEvaluate = async () => {
    const payload = buildPayload(false)
    const issues = getValidationErrors(payload)

    if (issues.length > 0) {
      setProductValidation(issues)
      setError(issues.join(' '))
      setResult(null)
      return
    }

    setProductValidation([])
    setLoading(true)
    setError('')
    try {
      const data = await executeRequest('/pricing/evaluate', payload)
      setResult(data)
    } catch (requestError) {
      setError(requestError.message)
      setResult(null)
    } finally {
      setLoading(false)
    }
  }

  const handleIngest = async () => {
    const payload = buildPayload(true)
    const issues = getValidationErrors(payload)

    if (issues.length > 0) {
      setProductValidation(issues)
      setError(issues.join(' '))
      setResult(null)
      return
    }

    setProductValidation([])
    setLoading(true)
    setError('')
    try {
      const data = await executeRequest('/api/input/ui/product', payload)
      setResult(data)
    } catch (requestError) {
      setError(requestError.message)
      setResult(null)
    } finally {
      setLoading(false)
    }
  }

  const handleHealthCheck = async () => {
    setLoading(true)
    setError('')
    try {
      const response = await fetch(`${API_BASE_URL}/health`)
      const data = await response.json().catch(() => ({ status: 'unknown' }))

      if (!response.ok) {
        throw new Error(data?.message || `Health check failed with status ${response.status}`)
      }

      setHealthStatus(data)
    } catch (requestError) {
      setError(requestError.message)
      setHealthStatus(null)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (activeSection === 'health') {
      handleHealthCheck()
    }
  }, [activeSection])

  useEffect(() => {
    if (!erpToast) return
    const timer = setTimeout(() => setErpToast(null), 5000)
    return () => clearTimeout(timer)
  }, [erpToast])

  useEffect(() => {
    if (!mlToast) return
    const timer = setTimeout(() => setMlToast(null), 5000)
    return () => clearTimeout(timer)
  }, [mlToast])

  useEffect(() => {
    if (!mlSyncToast) return
    const timer = setTimeout(() => setMlSyncToast(null), 5000)
    return () => clearTimeout(timer)
  }, [mlSyncToast])


  // #integracionErp: botón "Actualizar desde ERP" del header — dispara el pull saliente
  // contra todas las conexiones ERP activas con UrlSalida configurada.
  const handleErpPull = async () => {
    setErpPullLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/erp/pull`, { method: 'POST' })
      if (!res.ok) {
        setErpToast({ type: 'error', message: 'No se pudo actualizar desde el ERP.' })
        return
      }
      const summaries = await res.json()
      if (summaries.length === 0) {
        setErpToast({ type: 'error', message: 'No hay conexiones ERP configuradas con URL de lectura.' })
        return
      }
      const fallidas = summaries.filter((s) => !s.ok)
      const procesados = summaries.reduce((sum, s) => sum + (s.resultado?.procesados || 0), 0)
      const errores = summaries.reduce((sum, s) => sum + (s.resultado?.errores || 0), 0)
      const empresasOk = summaries.length - fallidas.length

      if (fallidas.length === 0) {
        setErpToast({
          type: 'success',
          message: `${empresasOk} empresa(s) actualizadas: ${procesados} productos sincronizados${errores > 0 ? `, ${errores} con error` : ''}.`,
        })
      } else {
        setErpToast({
          type: 'error',
          message: `${fallidas.length} conexión(es) ERP fallaron (${fallidas.map((f) => f.razonSocial).join(', ')}). ${empresasOk} empresa(s) OK.`,
        })
      }
    } catch {
      setErpToast({ type: 'error', message: 'No se pudo conectar con el servidor.' })
    } finally {
      setErpPullLoading(false)
    }
  }

  // #idaYVueltaMercadoLibre: botón "Procesar cola ML" del header — consume
  // ColaEjecucionML y empuja cada precio pendiente a la API de MercadoLibre.
  const handleMlProcesarCola = async () => {
    setMlColaLoading(true)
    try {
      const res = await fetch(`${API_BASE_URL}/api/marketplace/ml/procesar-cola`, { method: 'POST' })
      if (!res.ok) {
        setMlToast({ type: 'error', message: 'No se pudo procesar la cola de MercadoLibre.' })
        return
      }
      const result = await res.json()
      if (result.procesados === 0 && result.errores === 0) {
        setMlToast({ type: 'success', message: 'No hay cambios de precio pendientes para MercadoLibre.' })
        return
      }
      setMlToast({
        type: result.errores > 0 ? 'error' : 'success',
        message: `${result.procesados} precio(s) actualizados en MercadoLibre${result.errores > 0 ? `, ${result.errores} con error` : ''}.`,
      })
    } catch {
      setMlToast({ type: 'error', message: 'No se pudo conectar con el servidor.' })
    } finally {
      setMlColaLoading(false)
    }
  }

  // #idaYVueltaMercadoLibre: botón "Sincronizar ML" del header — sentido de entrada
  // completo. Trae precio/estado + competencia de catálogo, y además ventas
  // históricas (API de Órdenes -> MetricasVentasHist) en la misma acción.
  const handleMlSincronizar = async () => {
    setMlSyncLoading(true)
    try {
      const [resPub, resVentas] = await Promise.all([
        fetch(`${API_BASE_URL}/api/marketplace/ml/sincronizar-publicaciones`, { method: 'POST' }),
        fetch(`${API_BASE_URL}/api/marketplace/ml/sincronizar-ventas`, { method: 'POST' }),
      ])

      if (!resPub.ok || !resVentas.ok) {
        setMlSyncToast({ type: 'error', message: 'No se pudo sincronizar con MercadoLibre.' })
        return
      }

      const pub = await resPub.json()
      const ventas = await resVentas.json()
      const errores = pub.errores + ventas.errores

      // #resultadoMixtoSincronizacion: el ícono/color del toast resume el resultado de
      // Publicaciones puntualmente (no de Ventas, que no tiene detalle por ítem) -- tilde
      // verde si no hubo ningún error, cruz roja si nada se pudo procesar, warning amarillo
      // si fue una mezcla de OK y error. Detalle completo (qué ítem falló y por qué) queda
      // en el historial persistido, ver Reportes > Sincronizaciones ML.
      const tipoResultadoPub = pub.errores === 0 ? 'success' : pub.procesados === 0 ? 'error' : 'warning'

      setMlSyncToast({
        type: errores > 0 && tipoResultadoPub === 'success' ? 'warning' : tipoResultadoPub,
        message: `${pub.procesados} publicación(es) actualizadas${pub.conCompetenciaActualizada > 0 ? `, ${pub.conCompetenciaActualizada} con competencia nueva` : ''}; ${ventas.publicacionesActualizadas} con métricas de venta${errores > 0 ? `; ${errores} con error` : ''}.`,
      })
    } catch {
      setMlSyncToast({ type: 'error', message: 'No se pudo conectar con el servidor.' })
    } finally {
      setMlSyncLoading(false)
    }
  }

  // #crearPostAdmin: asigna endpoint y payload del formulario administrativo.
  const handleAdminCreate = async (entity, options = {}) => {
    setLoading(true)
    setError('')

    try {
      let endpoint = ''
      let payload = {}

      switch (entity) {
        case 'empresa':
          endpoint = '/api/admin/empresas'
          payload = adminForm.empresa
          break
        case 'moneda':
          endpoint = '/api/admin/monedas'
          payload = {
            ...adminForm.moneda,
            CodigoISO: String(adminForm.moneda?.CodigoISO || '').trim().toUpperCase(),
            Nombre: String(adminForm.moneda?.Nombre || '').trim(),
          }
          if (payload.CodigoISO.length !== 3) throw new Error('CodigoISO debe tener exactamente 3 caracteres.')
          if (!payload.Nombre) throw new Error('Nombre de moneda es obligatorio.')
          break
        case 'cotizacion':
          endpoint = '/api/admin/cotizaciones'
          payload = {
            MonedaID: Number(adminForm.cotizacion?.MonedaID),
            Cotizacion: Number(adminForm.cotizacion?.Cotizacion),
            FechaCotizacion: adminForm.cotizacion?.FechaCotizacion
              ? `${adminForm.cotizacion.FechaCotizacion}T00:00:00`
              : null,
          }
              if (payload.MonedaID <= 0) throw new Error('Seleccioná una moneda válida.')
              if (payload.Cotizacion <= 0) throw new Error('La cotización debe ser mayor que cero.')
              if (!payload.FechaCotizacion) throw new Error('La fecha de cotización es obligatoria.')
          break
        case 'parametro':
          endpoint = '/api/admin/parametros-generales'
          payload = {
            EmpresaID: Number(adminForm.parametro?.EmpresaID),
            MonedaPrincipalID: Number(adminForm.parametro?.MonedaPrincipalID),
            MonedaSecundariaID: Number(adminForm.parametro?.MonedaSecundariaID),
          }
          if (payload.MonedaPrincipalID === payload.MonedaSecundariaID) throw new Error('La moneda principal y la secundaria deben ser distintas.')
          break
        case 'cuentaML':
          endpoint = '/api/admin/cuentas-ml'
          payload = {
            ...adminForm.cuentaML,
            EmpresaID: Number(adminForm.cuentaML?.EmpresaID),
            FechaVencimientoToken: adminForm.cuentaML?.FechaVencimientoToken
              ? `${adminForm.cuentaML.FechaVencimientoToken}:00`
              : null,
          }
          break
        case 'producto':
          endpoint = '/api/admin/productos'
          payload = {
            ...adminForm.producto,
            EmpresaID: Number(adminForm.producto?.EmpresaID),
          }
          break
        case 'costoProducto':
          endpoint = '/api/admin/costos-producto'
          payload = {
            ProductoID: Number(adminForm.costoProducto?.ProductoID),
            CostoCompra: Number(adminForm.costoProducto?.CostoCompra),
            PorcentajeIVA: Number(adminForm.costoProducto?.PorcentajeIVA),
            ImpuestosInternos: Number(adminForm.costoProducto?.ImpuestosInternos),
            CostoEnvioPromedio: Number(adminForm.costoProducto?.CostoEnvioPromedio),
            CostoLogisticoFijo: Number(adminForm.costoProducto?.CostoLogisticoFijo),
            CostoFinancieroPorc: Number(adminForm.costoProducto?.CostoFinancieroPorc),
            CostoPublicidadPorc: Number(adminForm.costoProducto?.CostoPublicidadPorc),
            OtrosCostosFijos: Number(adminForm.costoProducto?.OtrosCostosFijos),
          }
          break
        case 'publicacionML':
          endpoint = '/api/admin/publicaciones-ml'
          payload = {
            ...adminForm.publicacionML,
            ProductoID: Number(adminForm.publicacionML?.ProductoID),
            CuentaMLID: Number(adminForm.publicacionML?.CuentaMLID),
            ComisionMLPorc: Number(adminForm.publicacionML?.ComisionMLPorc),
            PrecioActual: Number(adminForm.publicacionML?.PrecioActual),
            PrecioMinimoPermitido: Number(adminForm.publicacionML?.PrecioMinimoPermitido),
            PrecioMaximoPermitido: Number(adminForm.publicacionML?.PrecioMaximoPermitido),
            PrecioObjetivo: adminForm.publicacionML?.PrecioObjetivo ? Number(adminForm.publicacionML.PrecioObjetivo) : null,
            EsCatalogo: Boolean(adminForm.publicacionML?.EsCatalogo),
          }
          break
        case 'stockEstado':
          endpoint = '/api/admin/stock-estado'
          payload = {
            ProductoID: Number(adminForm.stockEstado?.ProductoID),
            StockActual: Number(adminForm.stockEstado?.StockActual),
            StockReservado: Number(adminForm.stockEstado?.StockReservado),
            StockMinimo: Number(adminForm.stockEstado?.StockMinimo),
            StockMaximo: Number(adminForm.stockEstado?.StockMaximo),
            StockObjetivo: Number(adminForm.stockEstado?.StockObjetivo),
          }
          break
        case 'estrategia':
          endpoint = '/api/admin/estrategias'
          payload = {
            ...adminForm.estrategia,
            EmpresaID: Number(adminForm.estrategia?.EmpresaID),
          }
          break
        case 'regla':
          endpoint = '/api/admin/reglas'
          payload = adminForm.regla
          break
        case 'estrategiaRegla':
          endpoint = `/api/admin/estrategia/${adminForm.estrategiaRegla.EstrategiaID}/reglas`
          payload = {
            ...adminForm.estrategiaRegla,
            Prioridad: Number(adminForm.estrategiaRegla.Prioridad),
            EstrategiaID: Number(adminForm.estrategiaRegla.EstrategiaID),
            ReglaID: Number(adminForm.estrategiaRegla.ReglaID),
          }
          break
        case 'parametrosRegla':
          endpoint = '/api/admin/estrategias-reglas-parametros'
          payload = {
            ...adminForm.parametrosRegla,
            EstrategiaReglaID: Number(adminForm.parametrosRegla?.EstrategiaReglaID),
            Valor: Number(adminForm.parametrosRegla?.Valor),
          }
          break
        case 'mensajesRegla':
          endpoint = '/api/admin/estrategias-reglas-parametros-mensajes'
          payload = {
            ...adminForm.mensajesRegla,
            EstrategiaReglaID: Number(adminForm.mensajesRegla?.EstrategiaReglaID),
          }
          break
        case 'configuracion':
          endpoint = '/api/admin/configuracion-parametros'
          payload = {
            ...adminForm.configuracion,
            EmpresaID: Number(adminForm.configuracion?.EmpresaID),
          }
          break
        default:
          throw new Error(`Tipo de entidad desconocida: ${entity}`)
      }

      const method = options.method || 'POST'
      if (method !== 'POST') {
        if (options.id === null || options.id === undefined) throw new Error('No hay un ID técnico recuperado para modificar el registro')
        endpoint = `${endpoint}/${options.id}`
      }
      const data = await executeRequest(endpoint, payload, method)
      return { ok: true, data }
    } catch (requestError) {
      setError(requestError.message)
      return { ok: false, error: requestError.message }
    } finally {
      setLoading(false)
    }
  }

  const clearAdminFormFields = (entity) => {
    setAdminForm((previous) => ({
      ...previous,
      [entity]: { ...ADMIN_FORM_TEMPLATES[entity] },
    }))
  }

  // #contenidoDeUnaPestañaDeManual: switchea entre las 4 sub-secciones estáticas de
  // /manual -- se llama una vez por cada pestaña "manual:*" abierta, con la sección fija de
  // esa pestaña (no con un estado global compartido, para no pisarse entre pestañas).
  // #imagenEnGuia: además de content/list, una sección de guía puede traer una captura de
  // pantalla real de la app ({ src, alt, caption }) -- útil para alguien que nunca usó un
  // sistema, ver texto solo no siempre alcanza para saber "dónde toco". Las imágenes viven
  // en /public/docs (servidas tal cual por Vite, sin pasar por el bundle de JS) para no
  // inflar App.jsx con strings base64 gigantes.
  const renderDocSection = (section) => (
    <section className="doc-section" key={section.title}>
      <h4>{section.title}</h4>
      {section.content && <p>{section.content}</p>}
      {section.list && (
        <ul>
          {section.list.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      )}
      {section.image && (
        <figure className="doc-section-image">
          <img src={section.image.src} alt={section.image.alt} loading="lazy" />
          {section.image.caption && <figcaption>{section.image.caption}</figcaption>}
        </figure>
      )}
    </section>
  )

  // #descargarComoPdf: no hay backend generador de PDF -- window.print() abre el diálogo
  // nativo del navegador, donde "Guardar como PDF" es un destino de impresión estándar en
  // Chrome/Edge/Firefox. Los estilos @media print (App.css) esconden el menú, las pestañas y
  // las barras de herramientas para que lo que se guarda sea solo el contenido de la guía.
  const renderDescargarPdfButton = () => (
    <button type="button" className="secondary-button doc-download-pdf" onClick={() => window.print()}>
      Descargar en PDF
    </button>
  )

  const renderManualSection = (sectionId) => (
    <section className="docs-layout">
      {sectionId === 'documentacion-funcional' && (
        <div id="documentacion-funcional" className="panel functional-docs">
          <div className="functional-docs-header">
            <div>
              <p className="eyebrow">Documentación funcional</p>
              <h3>Cómo funciona Pricing Engine</h3>
            </div>
            {renderDescargarPdfButton()}
          </div>

          <article className="doc-article">
            {functionalGuide.map(renderDocSection)}
          </article>
        </div>
      )}

      {sectionId === 'apartado-especial' && (
        <div id="apartado-especial" className="panel decision-flow-docs">
          <div className="functional-docs-header">
            <div>
              <p className="eyebrow">Apartado especial</p>
              <h3>Cómo funciona el motor de decisión</h3>
            </div>
            {renderDescargarPdfButton()}
          </div>

          <article className="doc-article">
            {decisionFlowGuide.map(renderDocSection)}
          </article>
        </div>
      )}

      {sectionId === 'manual-practico' && (
        <div id="manual-practico" className="panel user-manual-docs">
          <div className="functional-docs-header">
            <div>
              <p className="eyebrow">Manual práctico</p>
              <h3>Guía paso a paso para alguien que nunca usó el sistema</h3>
            </div>
            {renderDescargarPdfButton()}
          </div>

          <article className="doc-article">
            {userManualGuide.map(renderDocSection)}
          </article>
        </div>
      )}

      {sectionId === 'api-docs' && (
        <div id="api-docs" className="panel">
          <div className="functional-docs-header">
            <div>
              <p className="eyebrow">API docs</p>
              <h3>Endpoints del sistema</h3>
            </div>
          </div>

          <div className="docs-grid">
            {endpoints.map((endpoint) => (
              <div className="panel endpoint-card" key={endpoint.name}>
                <span className={`badge ${endpoint.group.toLowerCase()}`}>{endpoint.method}</span>
                <h4>{endpoint.name}</h4>
                <small>{endpoint.group}</small>
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  )

  // #contenidoDeUnaPestañaSuelta: pantallas de /erp, /usuarios, etc. -- IntegracionErpPanel
  // y ColaMlAprobacionPanel no usan useRegisterToolbar, por eso no reciben isActiveTab.
  const renderStandaloneScreen = (screenId, isActiveTab) => {
    switch (screenId) {
      case 'health':
        return (
          <section className="panel">
            <h3>Estado del servicio</h3>
            <div className="status-box">
              <pre>{healthStatus ? JSON.stringify(healthStatus, null, 2) : 'Consultando el estado de la API...'}</pre>
            </div>
          </section>
        )
      case 'erp':
        return <IntegracionErpPanel />
      case 'ml-integracion':
        return <IntegracionMercadoLibrePanel isActiveTab={isActiveTab} />
      case 'email-integracion':
        return <EmailConfiguracionPanel isActiveTab={isActiveTab} />
      case 'cola-ml-aprobacion':
        return <ColaMlAprobacionPanel />
      case 'ejecucion-automatica':
        return <EjecucionAutomaticaPanel isActiveTab={isActiveTab} />
      case 'usuarios':
        return <UsuariosPanel isActiveTab={isActiveTab} />
      default:
        return null
    }
  }

  // #contenidoDeUnaPestaña: arma el árbol de la pantalla que le corresponde a una pestaña
  // abierta -- se llama para CADA pestaña abierta en cada render (no solo la activa, ver
  // #pestañasSiempreMontadas más abajo), por eso isActiveTab decide si esta instancia
  // puntual registra su barra de pantalla (ver useRegisterToolbar) o no.
  const renderTabContent = (tab, isActiveTab) => {
    switch (tab.kind) {
      case 'pricing-home':
        return (
          <SectionGuard seccion="pricing">
            <ResumenVentasCard />
          </SectionGuard>
        )
      case 'evaluar-precio':
        return (
          <SectionGuard seccion="pricing">
            <section className="content-grid">
              <PricingForm
                productForm={productForm}
                onChange={updateProductField}
                onEvaluate={handleEvaluate}
                onIngest={handleIngest}
                loading={loading}
                validationErrors={productValidation}
                isActiveTab={isActiveTab}
              />
              <ResultPanel
                title="Resultado"
                data={result}
                placeholder="Realiza una evaluación para ver la respuesta JSON."
                onViewDetail={() => {
                  if (result) {
                    navigate('/detail', { state: { decision: result } })
                  }
                }}
              />
            </section>
          </SectionGuard>
        )
      case 'admin':
        return (
          <SectionGuard seccion="admin">
            <AdminPanel
              adminForm={adminForm}
              onChange={updateAdminField}
              onCreate={handleAdminCreate}
              onClearFields={clearAdminFormFields}
              loading={loading}
              fixedEntity={tab.entity}
              isActiveTab={isActiveTab}
            />
          </SectionGuard>
        )
      case 'reports':
        return (
          <SectionGuard seccion="reports">
            <ReportsPanel fixedReport={tab.report} isActiveTab={isActiveTab} />
          </SectionGuard>
        )
      case 'manual':
        return <SectionGuard seccion="manual">{renderManualSection(tab.section)}</SectionGuard>
      case 'standalone': {
        const config = STANDALONE_SCREENS[tab.screenId]
        if (!config) return null
        const guardProps = config.soloAdmin ? { seccion: config.seccion, soloAdmin: true } : { seccion: config.seccion }
        return <SectionGuard {...guardProps}>{renderStandaloneScreen(tab.screenId, isActiveTab)}</SectionGuard>
      }
      default:
        return null
    }
  }

  // #iconosEnSidebar: Sincronización/campanita/cuenta viven en la franja gris del
  // sidebar (debajo del logo), no en el header-bar del contenido -- el header-bar
  // solo muestra el título de la pantalla actual (ver Sidebar.jsx, prop toolbarIcons).
  const toolbarIcons = (
    <>
      <DropdownMenu label="Sincronización" icon={<SyncIcon />} iconOnly>
        <button
          type="button"
          className="toolbar-dropdown-item erp-refresh-button"
          onClick={handleErpPull}
          disabled={erpPullLoading}
        >
          {erpPullLoading ? 'Actualizando…' : 'Actualizar desde ERP'}
        </button>
        <button
          type="button"
          className="toolbar-dropdown-item ml-procesar-cola-button"
          onClick={handleMlProcesarCola}
          disabled={mlColaLoading}
        >
          {mlColaLoading ? 'Procesando…' : 'Procesar cola ML'}
        </button>
        <button
          type="button"
          className="toolbar-dropdown-item ml-sincronizar-button"
          onClick={handleMlSincronizar}
          disabled={mlSyncLoading}
        >
          {mlSyncLoading ? 'Sincronizando…' : 'Sincronizar ML'}
        </button>
      </DropdownMenu>
      <NotificationBell />
      {accountMenu}
    </>
  )

  return (
    <ToolbarProvider>
    <div
      className={sidebarCollapsed ? 'app-shell collapsed' : 'app-shell'}
      style={sidebarCollapsed ? undefined : { '--sidebar-width': `${sidebarWidth}px` }}
    >
      {!sidebarCollapsed && (
        <div
          ref={sidebarResizeRef}
          className="sidebar-resize-handle"
          title="Arrastrá para achicar o agrandar el menú"
        />
      )}
      <Sidebar
        activeSection={activeSection}
        activeSubSection={activeSubSection}
        toolbarIcons={toolbarIcons}
        collapsed={sidebarCollapsed}
        onToggleCollapsed={() => setSidebarCollapsed((current) => !current)}
        onSelect={(section, subSection) => {
          setError('')

          // #clickAbrePestaña: clickear cualquier ítem hoja del menú abre-o-activa su
          // propia pestaña (ver TabsContext.jsx) -- nunca navega "por encima" de una
          // pestaña existente, siempre abre/reusa la suya.
          if (section === 'manual') {
            const target = subSection || 'documentacion-funcional'
            openTab({ key: `manual:${target}`, kind: 'manual', section: target, label: findLabel(target), path: `/manual#${target}` })
            return
          }

          if (section === 'pricing') {
            openTab(INICIO_TAB)
            return
          }

          if (section === 'admin') {
            // #defaultNoAdminOnly: "empresa" es admin-only (ver ADMIN_ONLY_TABS en
            // AdminPanel.jsx) -- no puede ser el destino por defecto de "Formularios".
            const target = subSection || 'moneda'
            openTab({ key: `admin:${target}`, kind: 'admin', entity: target, label: findLabel(target), path: `/admin#${target}` })
            return
          }

          if (section === 'reports') {
            const target = subSection || 'empresas'
            openTab({ key: `reports:${target}`, kind: 'reports', report: target, label: findLabel(target), path: `/reports#${target}` })
            return
          }

          // #empresasDentroDeConfiguracion: estos 4 aparecen en el menú adentro de
          // Configuración (subgrupo "Empresas"), pero siguen siendo pestañas de /admin, no
          // rutas propias -- si no, se intentaría abrir una pestaña "empresa" (no existe) en
          // vez de admin#empresa. Ver PERMISSION_ALIAS en Sidebar.jsx: siguen detrás del
          // permiso "admin", no de uno propio.
          if (section === 'configuracion-sistema' && ['empresa', 'parametro', 'cuentaML', 'configuracion'].includes(subSection)) {
            openTab({ key: `admin:${subSection}`, kind: 'admin', entity: subSection, label: findLabel(subSection), path: `/admin#${subSection}` })
            return
          }

          // #configuracionAgrupaPermisosSueltos: los hijos de estos grupos son pantallas
          // propias que ya existían sueltas (/erp, /evaluar-precio, /cola-ml-aprobacion,
          // etc.), no sub-tabs de una sola pantalla -- cada una es su propia pestaña.
          if (['configuracion-sistema', 'test', 'autorizacion'].includes(section)) {
            const kind = subSection === 'evaluar-precio' ? 'evaluar-precio' : 'standalone'
            openTab({ key: subSection, kind, screenId: subSection, label: findLabel(subSection), path: `/${subSection}` })
            return
          }

          openTab({ key: section, kind: 'standalone', screenId: section, label: findLabel(section), path: `/${section}` })
        }}
      />

      {location.pathname !== '/detail' && <TabBar />}

      <ScreenToolbar />

      <header className="header-bar">
        <div>
          <h1>{currentTitle}</h1>
        </div>
      </header>

      <main className="main-panel" ref={mainPanelRef}>
        {error && <div className="alert error">{error}</div>}

        {location.pathname === '/detail' ? (
          <SectionGuard seccion="pricing">
            <DecisionDetail />
          </SectionGuard>
        ) : (
          <>
            {/* #pestañasSiempreMontadas: TODAS las pestañas abiertas se renderizan en cada
                render (no solo la activa), ocultando con CSS las que no se ven -- por eso
                cambiar de pestaña nunca desmonta ni pierde lo que se estaba tipeando en las
                demás, a diferencia de <Routes>. */}
            {openTabs.map((tab) => (
              <div key={tab.key} style={{ display: tab.key === activeTabKey ? undefined : 'none' }}>
                {renderTabContent(tab, tab.key === activeTabKey)}
              </div>
            ))}
          </>
        )}
      </main>

      <ResultToast toast={erpToast} onDismiss={() => setErpToast(null)} />
      <ResultToast toast={mlToast} onDismiss={() => setMlToast(null)} />
      <ResultToast toast={mlSyncToast} onDismiss={() => setMlSyncToast(null)} />
    </div>
    </ToolbarProvider>
  )
}

export default App
