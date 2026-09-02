# Pricing Engine

Contexto de pricing para empresas, productos, configuraciones de negocio y el registro de sus decisiones operativas.

## Vista actual de la aplicación

La interfaz principal quedó organizada con una navegación lateral por secciones:

- Pricing
- Formularios
  - Empresa
  - Moneda
  - Cotización
  - Parámetro General
  - Cuenta ML
  - Producto
  - Costo Producto
  - Publicación ML
  - Stock Estado
  - Estrategia
  - Regla
  - Estrategia-Regla
  - Configuración Parámetros
- Reportes
- Documentación
  - Funcional
  - Apartado especial
  - Manual práctico
  - API docs
- API Check (entrada del árbol lateral; consulta `GET /health` automáticamente al ingresar)

La intención es que el usuario vea solo el contenido de la sección activa, con submenús desplegables y una estructura más clara que evitó la duplicación de botones superpuestos.

## Language

**Reporte de tabla**:
Consulta de solo lectura que presenta los registros de una tabla del dominio de pricing.
_Avoid_: dashboard, listado parcial

**Tabla de historial**:
Registro inmutable de eventos o mediciones pasadas del dominio de pricing.
_Avoid_: dato maestro, dato operativo editable

**Fuente histórica automática**:
Tabla de historial, snapshot o auditoría que se alimenta por procesos del sistema y se expone exclusivamente mediante un **Reporte de tabla** de solo lectura.
_Avoid_: formulario de carga manual, dato maestro editable

**Filtro de reporte**:
Criterio enviado por el usuario para restringir un **Reporte de tabla** por cualquier campo de la tabla.
_Avoid_: filtro predefinido, filtro fijo

**Operador de filtro**:
Comparación explícita aplicada al valor de un **Filtro de reporte**.
_Avoid_: operador implícito

**Orden de reporte**:
Secuencia determinista de campos que organiza los registros de un **Reporte de tabla**.
_Avoid_: orden implícito, orden no determinista

**Recurso de reporte**:
Nombre plural y canónico de una tabla expuesta para consulta bajo `/api/admin`.
_Avoid_: ruta alternativa, nombre singular

**Proyección de reporte**:
Representación completa en `camelCase` de un registro consultado por un **Reporte de tabla**.
_Avoid_: respuesta parcial, DTO de formulario

**Metadato de reporte**:
Configuración en frontend de una columna de reporte, incluyendo su tipo, etiqueta y reglas de filtrado, derivada del esquema de datos.
_Avoid_: inferencia de tipo desde los datos, endpoint de metadatos

**Rango de reporte**:
Filtro opcional de una columna que admite un límite desde, un límite hasta o ambos, según el orden natural del tipo de dato.
_Avoid_: obligación de completar ambos límites

**Búsqueda simple de texto**:
Filtro no-rango de una columna de texto o CUIT que encuentra coincidencias parciales.
_Avoid_: coincidencia exacta obligatoria

**Límite superior de fecha**:
Fin exclusivo del día posterior al seleccionado para incluir todos los registros del día elegido en un rango de fecha.
_Avoid_: medianoche inclusiva del mismo día

**Ejecución de filtros**:
Acción explícita del usuario que valida y aplica todos los filtros configurados en un reporte.
_Avoid_: consulta por cada pulsación

**Columna sensible**:
Dato que no se expone ni se filtra en un reporte, aunque exista en la tabla de origen.
_Avoid_: columna pública

**Catálogo de filtros**:
Conjunto de **Metadatos de reporte** para todas las fuentes de reportes públicas del sistema.
_Avoid_: configuración aislada por pantalla

**Filtro simple de valor**:
Filtro no-rango de número, importe o fecha que busca una coincidencia exacta; en fechas representa el día calendario completo.
_Avoid_: rango implícito

**Autocomplete de descripción para ID**:
Campo de texto para un ID que referencia otra entidad nombrable (Empresa, Moneda, Producto, Cuenta ML, Publicación ML, Estrategia o Regla) que busca por su descripción en vez de por el número técnico, proponiendo hasta 10 coincidencias a medida que se escribe (o los primeros 10 registros si todavía no se escribió nada). Es un único patrón compartido por dos contextos distintos: en un **Filtro de reporte**, lo elegido arma la condición `eq` por ID contra ese campo; en un campo ID de un ABM (**Vista maestro-detalle de ABM**), lo elegido es el valor que se guarda en el registro. En ambos casos el ID real nunca lo escribe el usuario a mano, y aplica por nombre de campo, no por tabla — el propio ID primario de una entidad (ej. Empresa ID en el reporte o el ABM de Empresa) también es buscable así.
_Avoid_: pedirle al usuario que sepa el ID técnico de memoria; ofrecerlo para un ID de fila propia sin una descripción natural (ColaID, DecisionID, SnapshotID, etc.); permitir el toggle Rango sobre estos campos en un **Filtro de reporte** (un "rango de nombres" no tiene sentido); un término separado por contexto (Reportes y ABM comparten el mismo mecanismo, `FkAutocompleteInput.jsx`); duplicar el campo de descripción de esa misma entidad como un **Filtro de reporte** aparte cuando el ID propio ya lo usa para buscar (ver ADR 0035) — el Autocomplete solo filtra por un registro puntual (ID exacto), así que esto sacrifica a propósito la búsqueda parcial multi-resultado sobre ese campo

**Vista maestro-detalle de ABM**:
Layout de cada pestaña de Formularios donde el listado de registros y el formulario conviven simultáneamente en la misma pantalla, sin modales.
_Avoid_: modal de búsqueda, pantalla separada de listado

**Clave de formulario**:
Identificador de negocio usado para recuperar un registro antes de editarlo; puede ser un campo único o una combinación de relaciones, fecha o código distintivo.
_Avoid_: identificador técnico que el usuario deba conocer

**Modo alta**:
Estado de un formulario de ABM sin registro abierto, con todos los campos —incluida la **Clave de formulario**— habilitados para crear un registro nuevo.
_Avoid_: alta con campos clave bloqueados

**Modo lectura**:
Estado de un formulario de ABM inmediatamente después de abrir un registro existente desde el listado, con todos los campos deshabilitados.
_Avoid_: modo edición por defecto al abrir, campos habilitados automáticamente

**Modo edición**:
Estado de un formulario de ABM en el que los campos no clave quedan habilitados para modificar el registro abierto; se activa explícitamente con el botón Editar.
_Avoid_: edición automática, edición sin paso de confirmación previo

**Eliminación confirmada**:
Acción de baja disponible únicamente sobre un registro recuperado y confirmada explícitamente por la persona usuaria.
_Avoid_: baja inmediata, botón habilitado en un alta nueva

**Diálogo de eliminación**:
Modal propio del diseño de la aplicación que solicita la confirmación de una **Eliminación confirmada**, mostrando un resumen del registro a borrar.
_Avoid_: window.confirm nativo del navegador

**Aviso de resultado**:
Mensaje breve, en lenguaje de negocio y con color de éxito o error, que informa el resultado de Guardar o Eliminar en un ABM.
_Avoid_: panel de JSON crudo, respuesta técnica sin interpretar

**Repositor**:
Persona operativa (sin ERP propio) que carga recuentos de stock desde la pantalla dedicada `/repositor`, identificada por Usuario y PIN numérico.
_Avoid_: usuario de Formularios, rol de administrador

**Recuento absoluto de stock**:
Carga de stock donde el Repositor escribe el total físico contado de un SKU, que reemplaza a `StockEstado.StockActual` vigente.
_Avoid_: ajuste incremental (+/-), delta de movimiento

**Carga de stock**:
Evento inmutable de auditoría que registra quién (Repositor), cuándo y de qué valor a qué valor cambió el stock de un producto mediante un Recuento absoluto de stock.
_Avoid_: edición silenciosa sin rastro, sobrescritura sin registro

**Conexión ERP**:
Configuración por Empresa que habilita el intercambio de datos con el ERP del cliente: una clave que el motor le entrega al ERP para recibir datos por POST, y opcionalmente una URL y clave propias del ERP para que el motor le pida datos por GET.
_Avoid_: credencial de usuario humano, login

**Sincronización ERP**:
Evento inmutable de auditoría de un intercambio de datos con el ERP de una Empresa, en sentido Entrante (el ERP nos hizo POST) o Saliente (el motor le hizo GET), con la cantidad de productos procesados y errores.
_Avoid_: log técnico sin traducir, reintento silencioso

**Mapeo de campos ERP**:
Configuración por Empresa que indica con qué campo del ERP (tal cual lo devuelve su GET) se llena cada campo canónico del motor (SKU, título, costo de compra, IVA, impuestos internos, stock actual/mínimo/máximo), armada desde la pantalla Integración ERP tras descubrir los campos disponibles.
_Avoid_: adaptador de código por ERP, transformación hardcodeada

**Procesamiento de cola ML**:
Acción manual que toma las filas `PENDIENTE` de Cola Ejecución ML, actualiza el precio real en MercadoLibre y marca cada fila como Procesado (con `PrecioActual` ya confirmado) o Error (con el motivo real de ML), renovando el token de la Cuenta ML si hace falta.
_Avoid_: actualización automática sin confirmación de ML, cambio de PrecioActual antes de que ML lo confirme

**Sincronización de publicaciones ML**:
Acción manual (botón "Sincronizar ML") que trae de MercadoLibre el precio y estado reales de cada Publicación ML, la competencia real del buy box para las de catálogo, y las ventas históricas de los últimos 90 días vía la API de Órdenes, actualizando Métricas Ventas en la misma acción.
_Avoid_: competencia para publicaciones que no son de catálogo (ML no expone un endpoint directo para eso)

**Historial de sincronización ML**:
Registro persistido de cada corrida de la parte de Publicaciones de la Sincronización de publicaciones ML (no de Ventas): una fila madre por corrida (`SincronizacionMLHistorial`, con fecha y los tres conteos agregados) y una fila hija por cada Publicación ML procesada en esa corrida (`SincronizacionMLDetalle`, con si esa publicación se actualizó bien o el motivo exacto del error de ML). Se expone como dos **Reporte de tabla** (`sincronizaciones-ml` / `sincronizaciones-ml-detalle`) por debajo, pero en la UI viven como un único **Reporte maestro-detalle** ("Sincronizaciones ML" en el menú). El ícono del toast que aparece al terminar "Sincronizar ML" resume el resultado de esa corrida con la misma paleta: tilde verde si ninguna publicación falló, cruz roja si ninguna se pudo procesar, triángulo de warning amarillo si fue una mezcla de OK y error (ver ADR 0037).
_Avoid_: persistir también el detalle por publicación de la parte de Ventas (esa sigue devolviendo solo un conteo agregado, sin fila por publicación, a propósito — no se pidió para esa parte); calcular el color del toast mezclando errores de Ventas con los de Publicaciones (el ícono resume específicamente el resultado de Publicaciones, que es el que tiene detalle por ítem)

**Reporte maestro-detalle**:
Uno o más **Reporte de tabla** hijos relacionados con un mismo **Reporte de tabla** madre por una clave foránea, mostrados en una sola pantalla de Reportes con las grillas apiladas (madre arriba, una o varias hijas abajo) en vez de pestañas separadas — clickear una fila de la madre refresca todas sus grillas hijas a la vez, cada una filtrada por el ID de esa fila (`ReportsPanel.jsx`, tabla `MASTER_DETAIL_REPORTS`; cada madre tiene un array `details`, no un único detalle fijo). Ninguna grilla hija tiene panel de filtros propio: antes de seleccionar una fila madre muestra un mensaje de espera, y su único filtro es el ID de la fila madre elegida, fijo. Casos armados así:
- **Sincronizaciones ML** (madre) + su detalle (una sola hija).
- **Decisiones** (madre) + **Detalle auditoría** (`DecisionID`, una sola hija) — existía además "Decisiones historial", un reporte duplicado que exponía la misma tabla `DecisionesHistorial` bajo otro nombre de recurso (`decisiones-historial`); se eliminó (menú, reporte, filtros, endpoint) por no aportar nada distinto de "Decisiones".
- **Publicaciones ML** (madre) + **Competencia** / **Métricas ventas** / **Cola ejecución ML** (`PublicacionID`, tres hijas a la vez) — las tres compartían la misma madre, así que en vez de tres pantallas repitiendo la grilla de Publicaciones ML se armó una sola con las tres grillas de detalle apiladas debajo; clickear una publicación las refresca a las tres juntas.
- **Productos** (madre) + **Costos Producto** / **Stock** (`ProductoID`, dos hijas a la vez).
- **Monedas** (madre) + **Cotizaciones** (`MonedaID`, una hija).
- **Estrategia-Reglas** (madre) + **Parámetros de regla: histórico** / **Mensajes de regla: histórico** (`EstrategiaReglaID`, dos hijas a la vez).
- **Estrategias** (madre) + **Parámetros de regla: vigentes** / **Mensajes de regla: vigentes** (`EstrategiaID`, dos hijas a la vez).

Estos dos últimos casos usan hijas cuyo backend es un Controller de ASP.NET con el ID en la URL (`/estrategia-regla/{id}` o `/estrategia/{id}/vigentes`), no el mecanismo genérico `?filter[campo][eq]=` de `AdminReportsService` — `loadDetail` en `ReportsPanel.jsx` detecta un `{id}` literal en `detailEndpoint` y lo sustituye directo en la URL en vez de armar un filtro. Ese Controller tampoco pagina ni ordena server-side (siempre devuelve todas las filas), así que esas dos hijas se cargan enteras y se ordenan del lado del cliente, sin controles de paginación. Los endpoints "vigentes" además devuelven HTTP 404 (no 200 + arreglo vacío) cuando no hay filas para esa estrategia — se trata como "sin datos todavía", no como un error.
_Avoid_: una pestaña separada por cada hija cuando el patrón de uso es "elegir una fila de la madre y ver su detalle" (obliga a copiar el ID a mano de una pestaña a otra); repetir la grilla madre en una pantalla nueva por cada hija cuando varias hijas comparten la misma madre (en vez de una sola pantalla con todas las hijas apiladas); agregarle a una grilla de detalle un panel de filtros propio además del ID de la fila madre (no se pidió, mantiene la pantalla simple); tratar el 404 de los endpoints "vigentes" como un error real en vez de "sin datos"

**Aprobación de cola ML**:
Decisión humana (Aprobado o Rechazado) sobre una fila puntual de Cola Ejecución ML, obligatoria para toda publicación que no es de catálogo y opcional (según `SubidaAutomaticaCatalogoML` de Parámetro General) para las de catálogo.
_Avoid_: subida automática sin revisión para publicaciones sin competencia confiable

**Competidor vinculado manualmente**:
Vínculo explícito entre una Publicación ML que no es de catálogo y un item de MercadoLibre que el usuario eligió como competidor. MercadoLibre bloquea tanto la búsqueda pública por texto (`GET /sites/{site}/search`) como leer una publicación ajena por ID (`GET /items/{id}` de un ítem que no pertenece a la cuenta conectada) — ambos devuelven 403 para apps de terceros, con o sin token, confirmado contra la API real; es una restricción de plataforma, no un límite temporal, y no hay scope ni nivel de partner que la levante. Como la app no puede traer el precio del competidor por ningún medio (tampoco por HTML: un pedido de servidor a la página del ítem es redirigido de inmediato a un desafío anti-bot de MercadoLibre), el usuario carga a mano el ID/link, título, moneda y precio que ve en su propio navegador al vincular, y los puede reescribir cuando quiera con "Actualizar precio" — cada vínculo muestra hace cuánto se actualizó. La moneda sugiere por defecto la Moneda Principal de la Empresa dueña de la publicación, pero se puede cambiar. La pantalla es una grilla (mismo estilo `.data-table` que Reportes): Publicación (el ID como link que abre la publicación real de MercadoLibre), Título, Moneda, Precio, con una fila fija al final para cargar un competidor nuevo. Nada se vincula sin esa confirmación explícita.
_Avoid_: competencia inferida automáticamente para publicaciones no-catálogo; vínculo creado sin revisión humana; reintentar la búsqueda o la lectura por ID asumiendo que el bloqueo de ML es temporal o un scope faltante; construir un scraper (HTTP o navegador headless) para esquivar el anti-bot de MercadoLibre; que "Sincronizar ML" intente refrescar el precio de estos vínculos (ya se probó, fallaba en silencio para cualquier competidor real)

**Conexión OAuth de Cuenta ML**:
Flujo real de autorización (Authorization Code de OAuth 2.0) por el que el vendedor se loguea en MercadoLibre y autoriza la app, tras lo cual el `AccessToken`, `RefreshToken` y `UserIDML` de su Cuenta ML se completan automáticamente — reemplaza pegar esos valores a mano por SQL o por el formulario.
_Avoid_: dominio de login de ML fijo a un país; el `SiteId` (configurable en "Integración MercadoLibre") decide a qué dominio de auth se redirige

**Usuario**:
Cuenta con Usuario+contraseña y Rol (`ADMIN` o `LECTURA`) que da acceso a toda la superficie de la app que antes era libre (AdminPanel, Cola ML, Integraciones, Reportes, Pricing) — alcance global, no por Empresa. Un `ADMIN` puede aprobar/vincular/guardar; un `LECTURA` solo puede consultar.
_Avoid_: una sola contraseña compartida sin usuarios nombrados; login scopeado por Empresa como Repositor (esas pantallas no filtran por Empresa hoy)

**Sección permitida**:
Cada una de las pantallas del menú (Pricing, Formularios, Reportes, Documentación, API Check, Integración ERP, Integración MercadoLibre, Integración Email, Cola ML, Usuarios) que un Usuario puede ver — se tildan al darlo de alta o después desde "Editar permisos". Es control de visibilidad en el menú y las rutas de la UI; el límite real de qué se puede escribir sigue siendo el Rol, no la Sección. Integración ERP/MercadoLibre/Email y Usuarios viven agrupadas bajo la carpeta "Configuración" en el menú, pero cada una sigue siendo su propia Sección permitida independiente — la carpeta en sí no tiene permiso propio, es solo agrupación visual (ver ADR 0029).
_Avoid_: tratar la Sección permitida como un límite de seguridad de API — Formularios y Reportes comparten las mismas rutas `/api/admin/*` del backend, así que no están separadas ahí; asumir que agrupar pantallas bajo una carpeta del menú (como Configuración) las une en un solo permiso — no es así salvo que la carpeta lo diga explícitamente (Formularios/Reportes/Documentación sí son un único permiso por grupo, Configuración no)

**Recuperación de contraseña**:
Flujo de "olvidé mi contraseña" por email real: un Usuario con Email cargado pide un link desde el login, recibe un token de un solo uso (vale 1 hora) por SMTP, y elige una contraseña nueva en una pantalla que funciona sin sesión iniciada. La respuesta de la solicitud es siempre el mismo mensaje genérico, exista o no el Usuario, para no revelar cuentas por enumeración.
_Avoid_: que un ADMIN resetee la contraseña de otro a mano (se evaluó y se descartó a favor del email real); revelar en la respuesta si el usuario/email existen

**Sesión de Usuario**:
Token de acceso persistido en la tabla `UsuarioSesiones` (no en memoria) — un reinicio de la API ya no desloguea a nadie. Es un snapshot fijo desde el login (NombreCompleto, Rol, Secciones); un cambio posterior de esos datos solo se ve en el próximo login.
_Avoid_: guardar la Sesión solo en memoria (se perdía en cada reinicio); releer Rol/Secciones en cada request en vez de usar el snapshot del login

**Ejecución automática**:
Ciclo completo sin intervención manual: Actualizar desde ERP, evaluar todos los productos activos con publicación ML abierta (persistiendo la decisión — antes solo existía producto por producto, a mano), Procesar cola ML y Sincronizar ML. Se configura con un simple on/off y cada cuántos minutos corre; un `BackgroundService` revisa cada un minuto si ya toca. El resultado de la última corrida (a favor o con errores, con un resumen de cada etapa) queda visible en la pantalla.
_Avoid_: horarios específicos tipo cron (se evaluó y se descartó a favor de "cada N minutos"); guardar la marca de tiempo de la última corrida en hora local en vez de UTC (rompe la comparación contra el reloj interno)

**Resumen de ventas**:
Venta Bruta Total, Costo Total y Rentabilidad de los últimos 30 días, mostrados al entrar a Pricing (única pantalla que muestra la ruta `/`). Es una aproximación: unidades vendidas en la ventana × precio/costo ACTUAL de cada publicación, no el precio real al que se vendió cada unidad en su momento — el sistema no guarda un historial de órdenes, solo cantidades por ventana rodante. El Costo Total usa los mismos componentes que ya usa el motor para calcular margen (compra + comisión ML + envío + logística + financiero + publicidad), sin la fórmula de IVA neteado que sí usa el motor para decidir precios, para que Rentabilidad sea literalmente Venta Bruta Total − Costo Total. Incluye dos gráficos: un gráfico de barras de unidades vendidas por ventana rodante (7D/15D/30D/60D/90D — no hay ventas por día real, así que no hay gráfico de tendencia diaria) y una torta (donut) de Costo Total vs. Rentabilidad, que no se dibuja si la Rentabilidad es negativa.
_Avoid_: presentarlo como venta histórica real (no lo es); usar una fórmula de costo distinta a la del motor (`MargenActualPorc` dejaría de ser comparable); simular un gráfico de ventas por día con datos que el sistema no tiene

**Barra de pantalla**:
Franja gris de punta a punta (mismo ancho que `.header-bar`, adentro de `.main-panel`), siempre visible, entre el título y el contenido de cada pantalla, con 5 íconos fijos en este orden: hoja+ = Nuevo registro, carpeta abierta = mostrar/ocultar filtros, hoja con líneas y lápiz amarillo = Editar, cruz roja = Eliminar, disquete = Guardar. El alto de cada ícono iguala al de la franja de sincronización/notificaciones bajo el logo (`.sidebar-toolbar-collapse`). Es global (`ScreenToolbar.jsx`, vive una sola vez en `App.jsx`); cada pantalla le registra qué acciones le corresponden vía `ToolbarContext.jsx`, y lo que no aplica queda deshabilitado, no oculto. Reemplaza los botones de texto que antes tenía cada pantalla por separado ("+Nuevo registro", la flecha de colapsar búsqueda, "Guardar"/"Crear usuario"/"Persistir y evaluar"/etc.) y, en los 13 ABMs, también reemplaza los botones "Editar"/"Eliminar" que antes vivían dentro del formulario (`AdminActions`, ya eliminado) — ver ADR 0036.
_Avoid_: un botón de texto propio de "Nuevo"/"Guardar"/"Editar"/"Eliminar" en una pantalla que ya tiene Barra de pantalla (la única excepción deliberada es Integración ERP, que tiene dos guardados distintos y secuenciales — "Guardar conexión" y "Guardar mapeo" — que no se pueden colapsar en un solo ícono); ocultar un ícono que no aplica en vez de dejarlo deshabilitado (rompe la consistencia visual entre pantallas); llamar `useRegisterToolbar` con un array de deps que no incluya todos los campos de estado que lee el handler registrado — la barra global guarda el `onClick` que estaba vigente quando el efecto corrió por última vez, así que un handler de `save` que cierre sobre campos de un formulario (ej. `clientId`, `adminForm`) sin esos campos en los deps termina mandando valores viejos, no lo último tipeado (bug real encontrado y corregido en `IntegracionMercadoLibrePanel.jsx`, `AdminPanel.jsx`, `EmailConfiguracionPanel.jsx`, `EjecucionAutomaticaPanel.jsx` y `UsuariosPanel.jsx` — ver ADR 0036). Los modales de Parámetro/Mensaje evitan esto con un patrón distinto: un `ref` que el formulario hijo reasigna en cada render propio, no un closure capturado por deps.

**Placeholder de campo**:
Texto de ejemplo "Ingresar {Nombre del campo}" que aparece vacío en todo campo de texto de un formulario, salvo el de un **Autocomplete de descripción para ID** o una búsqueda por texto libre, que usan "Buscar…" en su lugar porque ese campo no guarda un valor final sino que dispara una búsqueda.
_Avoid_: un placeholder distinto por pantalla para el mismo tipo de campo; "Buscar…" en un campo que no busca nada; forzar este patrón en un campo cuyo placeholder depende de un estado guardado (ej. "Contraseña SMTP" o "Client Secret" de Integración MercadoLibre, que muestran si ya hay un valor configurado en vez de un texto fijo)

**Evaluar precio**:
Pantalla (`/evaluar-precio`) con el formulario de Evaluación de precio y su panel de Resultado — separada de Pricing (`/`, que ahora solo muestra el Resumen de ventas) desde que ambas convivían en la misma ruta y se dividieron en dos entradas de menú. Vive en el menú dentro de la carpeta "Test" (ver ADR 0031). No es una Sección permitida propia: se gatea con el mismo permiso `pricing` que ya existía, porque es la misma pantalla de antes partida en dos rutas, no una funcionalidad nueva.
_Avoid_: crear una Sección permitida nueva para esta ruta (obligaría a un ADMIN a re-tildar el permiso a Usuarios que ya podían evaluar precios); asumir que la fila "Test — Evaluar precio" del catálogo de permisos de Usuarios controla un permiso propio — apunta al mismo `pricing` que la fila "Inicio"

## Relationships

- Cada **Reporte de tabla** representa una sola tabla del dominio.
- Cada formulario recupera un registro por su **Clave de formulario**, seleccionándolo desde el listado de la **Vista maestro-detalle de ABM**; ya no se recupera automáticamente al perder foco (blur) de esos campos.
- Una **Eliminación confirmada** solo puede realizarse sobre un registro recuperado de forma unívoca.
- Un formulario de ABM tiene tres estados posibles: **Modo alta**, **Modo lectura** y **Modo edición**.
- Al abrir un registro desde el listado, el formulario entra en **Modo lectura**.
- El botón Editar transiciona el formulario de **Modo lectura** a **Modo edición**, habilitando todos los campos salvo la **Clave de formulario** (ver ADR 0001).
- Un botón "Nuevo registro" limpia el formulario y lo pone en **Modo alta**.
- El botón Eliminar solo está disponible cuando el formulario está en **Modo lectura** o **Modo edición** (hay un registro abierto).
- Cada ABM usa una **Vista maestro-detalle de ABM** que combina su listado de registros y su formulario en una sola pantalla.
- El listado de la **Vista maestro-detalle de ABM** es liviano: busca por los campos ya definidos como búsqueda en cada entidad y pagina, sin filtros por columna ni orden configurable como los de **Reporte de tabla**.
- La búsqueda del listado aplica **Búsqueda simple de texto** (coincidencia parcial) sobre los campos de texto y CUIT, y **Filtro simple de valor** (coincidencia exacta) sobre los campos numéricos, de importe y de fecha, según la definición ya establecida para cada tipo.
- Toda **Eliminación confirmada** se solicita mediante un **Diálogo de eliminación** propio de la aplicación, no `window.confirm` nativo.
- Cada acción de Guardar o Eliminar en un ABM produce un **Aviso de resultado**, que reemplaza el panel de JSON crudo.
- Al guardar exitosamente desde **Modo edición**, el formulario vuelve a **Modo lectura** mostrando los datos ya actualizados, sin limpiarse.
- Al guardar exitosamente desde **Modo alta**, el formulario pasa a **Modo lectura** del registro recién creado, y el listado se actualiza para incluirlo.
- Tras una **Eliminación confirmada**, el formulario vuelve a **Modo alta** y el listado se actualiza quitando el registro borrado.
- **Decisiones** se pueden crear y actualizar, pero no eliminar desde la UI porque deben conservarse para auditoría.
- Una **Tabla de historial** también debe disponer de un **Reporte de tabla**.
- Una **Fuente histórica automática** no habilita formularios de alta, edición ni baja en la UI.
- Cada **Reporte de tabla** puede aplicar cero o más **Filtros de reporte**.
- Cada **Filtro de reporte** tiene un **Operador de filtro** compatible con el tipo del campo.
- Cada **Reporte de tabla** tiene un **Orden de reporte** explícito o un orden predeterminado determinista.
- Cada **Reporte de tabla** se expone mediante un único **Recurso de reporte**.
- Cada **Reporte de tabla** devuelve una **Proyección de reporte**, excepto los campos sensibles excluidos explícitamente.
- Cada **Reporte de tabla** tiene **Metadatos de reporte** en frontend para que la UI genere filtros adecuados.
- Un **Rango de reporte** se aplica a números, importes, fechas, texto y CUIT; los booleanos no admiten rango.
- Una **Búsqueda simple de texto** usa coincidencia parcial; al activar **Rango de reporte** usa límites lexicográficos.
- Todo **Límite superior de fecha** de un **Rango de reporte** incluye el día de calendario seleccionado.
- Los **Filtros de reporte** se aplican únicamente mediante una **Ejecución de filtros**.
- Una **Columna sensible** no forma parte de los **Metadatos de reporte** ni de la **Proyección de reporte**.
- El **Catálogo de filtros** cubre todas las fuentes de reportes públicas.
- Un **Filtro simple de valor** se convierte en igualdad exacta, excepto que la fecha incluye el día completo.

## Example dialogue

> **Dev:** "¿El reporte de DecisionesHistorial se trata distinto por ser histórico?"
> **Domain expert:** "No; se consulta como cualquier reporte de tabla, pero no habilita modificaciones."

> **Dev:** "¿La descripción admite solamente coincidencia exacta?"
> **Domain expert:** "No; todos los campos se pueden filtrar y el texto admite coincidencia parcial."

> **Dev:** "¿Cómo expresa la UI un filtro de texto?"
> **Domain expert:** "Con la forma `filter[campo][contains]=valor`; el operador es explícito y backend lo valida."

> **Dev:** "¿Puede cambiar el orden de los datos entre páginas?"
> **Domain expert:** "No; el reporte usa `sort=campo:dirección` y siempre aplica un orden predeterminado estable."

> **Dev:** "¿Por qué Decisiones no usa una ruta del módulo pricing?"
> **Domain expert:** "Porque es un reporte de tabla y todas esas consultas pertenecen a `/api/admin`."

> **Dev:** "¿El reporte devuelve solamente columnas elegidas por la UI?"
> **Domain expert:** "No; devuelve la proyección completa de la tabla en `camelCase`, salvo secretos declarados como excluidos."

> **Dev:** "¿Cómo conoce la UI el tipo y las reglas de cada filtro?"
> **Domain expert:** "Los obtiene de metadatos configurados en frontend a partir del esquema de datos."

> **Dev:** "¿Un rango de texto entre A y Y tiene sentido?"
> **Domain expert:** "Sí; busca valores en ese intervalo alfabético."

> **Dev:** "¿Cómo se comporta Razón social cuando no se activa Rango?"
> **Domain expert:** "Busca coincidencias parciales; Rango solo cambia esa búsqueda por límites alfabéticos."

> **Dev:** "¿Un límite Hasta de 31/01 incluye registros de esa tarde?"
> **Domain expert:** "Sí; se consulta antes de la medianoche del día siguiente."

> **Dev:** "¿La búsqueda se actualiza en cada tecla?"
> **Domain expert:** "No; el usuario presiona Ejecutar después de completar y validar los filtros."

> **Dev:** "¿La UI puede mostrar o filtrar tokens de Mercado Libre?"
> **Domain expert:** "No; son columnas sensibles y quedan excluidas del reporte."

> **Dev:** "¿La solución se entrega solo para Empresas?"
> **Domain expert:** "No; Empresas es el ejemplo, pero el catálogo cubre todos los reportes."

> **Dev:** "¿Un valor numérico simple equivale a un rango invisible?"
> **Domain expert:** "No; equivale a igualdad exacta."

## Flagged ambiguities

- Las rutas de reportes usan únicamente `GET /api/admin/{recurso-en-plural}`; `/api/pricing/decisiones` queda sustituida por `/api/admin/decisiones`.
- Cada respuesta devuelve los campos disponibles de la tabla en `camelCase`, incluidas claves, estados, fechas y JSON; los campos sensibles son la única excepción permitida y deben documentarse.
- La configuración de tipos, etiquetas y reglas de filtro vive en frontend como **Metadatos de reporte** y se deriva del esquema de datos.
- El rango es individual por columna y permite solo desde, solo hasta o ambos; se admite también para texto y CUIT con comparación lexicográfica. Los booleanos usan únicamente Todos/Sí/No.
- Texto y CUIT usan `contains` en modo simple y límites `gte`/`lte` en modo rango.
- Para `datetime`, el límite Hasta se convierte al inicio exclusivo del día siguiente, de modo que el día seleccionado queda incluido completamente.
- Los filtros se validan y envían solo al presionar el botón Ejecutar; Limpiar elimina todos los criterios y restaura la primera página.
- Las columnas sensibles nunca se muestran ni filtran. `AccessToken` y `RefreshToken` de CuentasML son explícitamente sensibles y backend también debe excluirlos.
- El mecanismo genérico se configura para todas las fuentes de reportes públicas del esquema SQL, no solo para Empresas.
- Números e importes usan `eq` en filtro simple; una fecha simple consulta el día completo y el modo Rango usa límites explícitos.
- La sintaxis canónica de ordenamiento es `sort=campo:asc|desc[,campo:asc|desc]`; si falta, se usa una clave primaria ascendente en tablas maestras u operativas y fecha/ID descendente en historial, auditoría y cola.

- La **Vista maestro-detalle de ABM** (listado, **Modo alta**/**Modo lectura**/**Modo edición**, **Diálogo de eliminación**, **Aviso de resultado**) aplica a los 13 ABMs de `AdminPanel.jsx` (Empresa, Moneda, Cotización, Parámetro General, Cuenta ML, Producto, Costo Producto, Publicación ML, Stock Estado, Estrategia, Regla, Estrategia-Regla, Configuración Parámetros). Parámetros y Mensajes de Estrategia-Regla quedan fuera por ser versionados (sin **Eliminación confirmada**, cada edición crea una versión histórica nueva). Decisión y Cola Ejecución ML quedaron fuera de Formularios por completo: las puebla exclusivamente `spCalcularDecision` (ver ADR 0002); solo se consultan desde Reportes.
- Los campos de los formularios de Parámetro General, Cuenta ML, Producto, Costo Producto, Publicación ML, Stock Estado y Configuración Parámetros se corrigieron para coincidir exactamente con las columnas reales de `PRICES_DB` (antes tenían nombres o estructuras inventadas que la API descartaba silenciosamente al guardar).

- La pantalla `/repositor` es independiente de Formularios/Reportes (no comparte el layout de sidebar): solo permite Login de **Repositor** y **Carga de stock** por **Recuento absoluto de stock**, sin tocar costos, publicaciones ni estrategias. Existe para clientes sin ERP propio; si el cliente tiene ERP, ese conector alimenta `StockEstado` en su lugar y esta pantalla queda como herramienta de soporte (ver ADR 0003 sobre la decisión de login con token en memoria).

- La integración con el ERP del cliente soporta los dos sentidos posibles (el motor recibe un POST del ERP, o el motor le hace GET al ERP) sobre el mismo contrato canónico de productos/costos/stock. Cada instalación conecta a un solo ERP; en vez de un adaptador de código por vendor, la pantalla "Integración ERP" deja armar un **Mapeo de campos ERP** desde la UI (descubrir campos del GET del cliente + asignar cuál llena cada campo canónico), así cualquier instalación se conecta a su ERP sin escribir código nuevo (ver ADR 0004). El botón "Actualizar desde ERP" del header dispara el sentido saliente contra todas las **Conexiones ERP** activas de una vez, sin selector de empresa.

- El botón "Procesar cola ML" del header dispara el **Procesamiento de cola ML**: consume `ColaEjecucionML` y confirma cada cambio de precio contra la API real de MercadoLibre (renovando el token de la Cuenta ML si venció). Antes de esta pieza la cola se llenaba pero nadie la procesaba, y `PublicacionesML.PrecioActual` no reflejaba el precio realmente confirmado en ML (ver ADR 0005). Probado contra un mock de la API de ML, no contra la API real (todavía no hay credenciales de una app de MercadoLibre configuradas).

- El botón "Sincronizar ML" del header dispara la **Sincronización de publicaciones ML** completa (sentido de entrada): precio/estado real por publicación (`GET /items/{id}`), competencia real del buy box para las de catálogo (`GET /items/{id}/price_to_win`, ver ADR 0006) y ventas históricas de los últimos 90 días vía la API de Órdenes (`GET /orders/search`, ver ADR 0007) que actualizan `MetricasVentasHist`. No hay competencia para publicaciones que no son de catálogo (ML no expone un endpoint directo para eso). Todo probado contra mock, no contra la API real de MercadoLibre.

- Antes de que "Procesar cola ML" suba un cambio de precio, toda publicación que no es de catálogo pasa por **Aprobación de cola ML** en la pantalla "Cola ML (Aprobación)", que muestra el precio actual/sugerido, el motivo y un link real a la publicación del competidor contra la que se comparó. Las de catálogo solo piden aprobación si `SubidaAutomaticaCatalogoML` está apagado para la Empresa (ver ADR 0009).

- Para publicaciones que no son de catálogo, la competencia se resuelve con un **Competidor vinculado manualmente**: dentro de "Publicación ML" el usuario carga a mano el ID/link, título y precio de la publicación competidora (ML bloquea tanto la búsqueda como la lectura por ID de una publicación ajena) y los puede reescribir cuando quiera con "Actualizar precio" — "Sincronizar ML" no toca estos vínculos, solo refresca catálogo vía `price_to_win` (ver ADR 0010).

- Una **Conexión OAuth de Cuenta ML** se inicia con el link "Conectar con MercadoLibre" del formulario "Cuenta ML" (solo visible para un registro ya guardado) y depende de que "Integración MercadoLibre" tenga cargados `ClientId`, `SiteId` y `RedirectUri` (ver ADR 0011).

- Un **Usuario** con Rol `ADMIN` es el único que puede aprobar/rechazar una **Aprobación de cola ML** o confirmar un **Competidor vinculado manualmente**; ambas acciones quedan registradas contra ese Usuario. La **Conexión OAuth de Cuenta ML** es la única excepción que no requiere sesión de Usuario, porque la inicia y la completa el navegador con una navegación común, no un fetch con Authorization (ver ADR 0012).

- Cada **Usuario** tiene cero o más **Sección permitida**: el primer ADMIN (bootstrap) las recibe todas automáticamente, cualquier otro Usuario arranca sin ninguna hasta que un ADMIN se las tilda al crearlo o después desde "Editar permisos" en la pantalla Usuarios (ver ADR 0013).

- Cualquier **Usuario** logueado puede cambiar su propia contraseña (conociendo la actual) desde la barra superior, sin necesitar que un ADMIN se la recree (ver ADR 0014).

- La campanita del header avisa cuántas filas de **Aprobación de cola ML** están pendientes y, al clickear una, navega a "Cola ML (Aprobación)"; no se muestra si el Usuario no tiene esa **Sección permitida** (ver ADR 0015).

- Un **Usuario** solo puede eliminarse definitivamente si nunca aprobó/rechazó una **Aprobación de cola ML** ni confirmó un **Competidor vinculado manualmente** — si tiene esa historia, hay que **Desactivar** en su lugar; tampoco puede eliminar su propia cuenta mientras está logueado con ella (ver ADR 0016).

- Una **Recuperación de contraseña** solo es posible para un **Usuario** con Email cargado; el envío depende de que "Integración Email" tenga el servidor SMTP configurado (ver ADR 0017).

- Cada **Sesión de Usuario** queda ligada a un **Usuario** con una copia de su Rol y sus **Sección permitida** al momento del login; guardarla en `UsuarioSesiones` en vez de en memoria es lo que le permite sobrevivir a un reinicio de la API (ver ADR 0018).

- La **Ejecución automática** genera, en el paso de evaluar todos los productos, exactamente las mismas filas de **Aprobación de cola ML** que generaría evaluar manualmente desde Pricing — mismo `spCalcularDecision`, misma cola, mismas reglas de aprobación por catálogo/no-catálogo (ver ADR 0019).

- El **Resumen de ventas** usa `PrecioActual` de cada **Publicación ML** activa y su **Costo Total** asociado — un cambio de precio (por la **Ejecución automática**, "Procesar cola ML" o edición manual) cambia la Venta Bruta Total mostrada en el siguiente refresco de la pantalla, aunque las unidades vendidas de la ventana no hayan cambiado (ver ADR 0020).

- Los filtros de ID de Reportes que referencian una entidad nombrable usan el **Autocomplete de descripción para ID** (`FkAutocompleteInput.jsx`) contra los mismos endpoints genéricos que ya existían (`filter[campo][contains]`), sin backend nuevo — ver ADR 0027.
- Los campos ID de un ABM que referencian una entidad nombrable usan el mismo **Autocomplete de descripción para ID** que Reportes, reemplazando el `<select>` que antes precargaba todas las opciones de esa entidad de una vez — ver ADR 0028. Esto cubre tanto los campos del formulario de alta/edición como los campos de búsqueda del listado de registros (`AbmRecordList.jsx`) cuando ese campo de búsqueda es un ID referenciable (ej. buscar Estrategia-Regla por Estrategia o por Regla).

- Los campos de búsqueda del listado de un ABM que NO son un ID referenciable (ej. CUIT, SKU, Nickname ML) también proponen hasta 10 sugerencias al escribir o los primeros 10 registros al enfocar vacíos, con `SearchSuggestInput.jsx` — mismo patrón visual y de interacción que el Autocomplete de descripción para ID, pero la sugerencia sale del propio valor del campo en los registros existentes, no de una entidad referenciada (ver ADR 0028).

- En Reportes, cuando el ID propio de una entidad usa el Autocomplete de descripción para ID contra un campo de texto de esa misma entidad, ese campo de texto ya NO se repite como un Filtro de reporte aparte — se sacó en 7 reportes (Empresas/Razón Social, Monedas/Nombre, Productos/Título, Cuentas ML/Nickname ML, Publicaciones ML/Meli item ID, Estrategias/Nombre estrategia, Reglas/Nombre) porque se veía redundante con el ID. Es una simplificación deliberada, no gratuita: el Autocomplete solo arma un filtro `eq` contra un registro puntual, así que sacar el filtro de texto también saca la posibilidad de una búsqueda `contains` que traiga varios registros a la vez sobre ese campo (ver ADR 0035).

- La fila de cada registro en el listado de un ABM (`AbmRecordList.jsx`) resuelve la descripción de sus campos FK en vez de mostrar el ID crudo (ej. "Estrategia QA Motor · Stock crítico" en vez de "1 · 1") — se resuelve por ID único en la página actual, cacheado para no repetir la consulta si el mismo ID vuelve a aparecer (ver ADR 0028).

- La carpeta "Configuración" del menú agrupa seis **Sección permitida** que ya existían sueltas (API Check, Integración ERP, Integración MercadoLibre, Integración Email, Usuarios, Ejecución automática) sin fusionarlas en un permiso nuevo — el catálogo de checkboxes de la pantalla Usuarios (`UsuariosPanel.jsx`) sale del mismo `NAV_ITEMS` que arma el menú, así que agrupar sin este cuidado le habría hecho perder a un ADMIN la posibilidad de tildar cada una por separado (ver ADR 0029).

- "Inicio" es a la vez el destino `/` y el único toggle que despliega/colapsa todo el árbol del menú (heredó ese rol del viejo botón "Menú"). El botón se muestra siempre, aunque el Usuario no tenga la **Sección permitida** "pricing" tildada, para no dejarlo sin forma de abrir el menú y llegar a otras secciones que sí tiene permitidas (ver ADR 0030).

- `Run-PruebasLogin.ps1` (mismo estilo y ubicación que `Run-PruebasMotor.ps1`, en `PricingEngine/tests`) es la suite de regresión de punta a punta del flujo de **Usuario**: bootstrap, login/logout, **Sesión de Usuario**, **Sección permitida**, cambio de contraseña y **Recuperación de contraseña** (contra un SMTP simulado), eliminación de **Usuario**. Corre contra una API real ya levantada (nunca la arranca ni la reinicia) y deja siempre la base como la encontró, usuarios `qa_login_*` incluidos (ver ADR 0021).
- `Run-PruebasErp.ps1`, `Run-PruebasRepositor.ps1`, `Run-PruebasMercadoLibre.ps1` y `Run-PruebasEmail.ps1` (mismo estilo, mismo directorio) completan la tanda de suites de regresión: **Integración ERP** (Conexión, Mapeo de campos, entrante y saliente; ver ADR 0023), **Repositor** (login por PIN, Recuento absoluto de stock, aislamiento multi-empresa; ver ADR 0024 — encontró y corrigió un `tx.RollbackAsync()` con un `SqlDataReader` todavía abierto, el mismo defecto que ADR 0017), **MercadoLibre** (OAuth, Procesar cola con gate de aprobación, Sincronizar publicaciones/ventas, Competidor vinculado manualmente; ver ADR 0025 — encontró y corrigió una respuesta HTML sin `charset=utf-8` declarado) y **Email** más allá de la recuperación de contraseña (Configuración, botón "Probar conexión"; ver ADR 0026). Cada una levanta su propio mock (`Mock-ErpServer.py`, `Mock-MercadoLibreServer.py`, o reusa `Mock-SmtpServer.py`) y deja la base exactamente como la encontró, incluidas las configuraciones globales (`ConfiguracionMercadoLibre`, `ConfiguracionEmail`) que restaura por SQL directo porque la API nunca expone sus secretos de vuelta.

- **Pricing** (`/`) y **Evaluar precio** (`/evaluar-precio`) son dos rutas separadas que comparten el mismo permiso `pricing`: la primera muestra únicamente el **Resumen de ventas** (con sus dos gráficos), la segunda el formulario de Evaluación de precio y su Resultado. Antes de esta separación convivían en la misma pantalla (ver ADR 0022).

- La **Barra de pantalla** habilita sus 5 íconos según el tipo de pantalla: los 5 en cada **Vista maestro-detalle de ABM** (Formulario), pero Editar/Eliminar solo se activan con un registro abierto (Editar además exige **Modo lectura**, no **Modo edición**); solo la carpeta en un **Reporte de tabla**; ninguno en Documentación; solo el disquete en Usuarios, Ejecución automática, Integración Email, Integración MercadoLibre, Evaluar precio y los modales de Parámetro/Mensaje de Estrategia-Regla. Integración ERP es la única pantalla con botón Guardar que quedó afuera por completo (ver ADR 0036) — mantiene sus dos botones de texto propios ("Guardar conexión", "Guardar mapeo") porque son dos guardados secuenciales distintos, no uno solo.

- El **Placeholder de campo** ("Ingresar {campo}" / "Buscar…") aplica a todos los formularios de la app, no solo a los 13 ABMs. En cambio, los íconos Editar/Eliminar de la **Barra de pantalla** solo se habilitan en los 13 ABMs de `AdminPanel.jsx` (reemplazaron los botones de texto que antes vivían dentro del formulario, en un componente `AdminActions` ya eliminado) — "Editar permisos"/"Desactivar" de Usuario y "Editar"/"Desactivar" de Parámetro de Regla y Mensaje de Estrategia-Regla siguen con botón de texto propio, porque esas pantallas no forman parte de la Vista maestro-detalle de ABM.

- "Reportes" se resolvió como reportes de tabla: cubren todas las tablas, incluidas historial, auditoría y cola de ejecución, y son de solo lectura.
- Los filtros no se limitan a Empresa, Producto o fecha: cualquier campo es filtrable; los campos de texto usan coincidencia parcial tipo `LIKE`.
- La sintaxis canónica de filtro es `filter[campo][operador]=valor`; los operadores son `eq`, `contains`, `startsWith`, `endsWith`, `gt`, `gte`, `lt`, `lte`, `in` e `isNull`.
