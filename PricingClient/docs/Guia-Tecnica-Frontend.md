# Guía técnica del frontend

Esta guía refleja la versión actual del proyecto y la navegación que quedó implementada en la interfaz.

## 1. Tecnologías

| Tecnología | Uso en el proyecto | Referencia |
| --- | --- | --- |
| React 19 | Componentes, estado y renderizado de la interfaz. | `pricing-ui/src/` |
| Vite 8 | Servidor de desarrollo y empaquetado de producción. | `pricing-ui/vite.config.js` |
| React Router DOM 6 | Navegación por URL entre Pricing, Formularios, Reportes, Documentación y API Check. | `App.jsx`, `Sidebar.jsx` |
| JavaScript JSX | Componentes principales del sistema. | `pricing-ui/src/**/*.jsx` |
| CSS nativo | Layout, formularios, tablas, menús desplegables y estilos visuales. | `App.css` |
| Fetch API | Llamadas HTTP al backend. | `App.jsx`, `AdminPanel.jsx`, `ReportsPanel.jsx` |
| npm | Ejecutar el proyecto y construir producción. | `pricing-ui/package.json` |

## 2. Estructura del frontend

```text
pricing-ui/
├── src/
│   ├── main.jsx                 ← arranque React y router
│   ├── App.jsx                  ← estado global, rutas y requests POST
│   ├── App.css                  ← estilos de componentes y layout
│   ├── index.css                ← estilos globales
│   └── components/
│       ├── Sidebar.jsx          ← navegación lateral
│       ├── PricingForm.jsx      ← formulario de evaluación
│       ├── AdminPanel.jsx       ← formularios administrativos
│       ├── ReportsPanel.jsx     ← reportes GET, filtros y paginación
│       ├── ResultPanel.jsx      ← JSON de respuesta
│       └── DecisionDetail.jsx   ← detalle de decisión
├── package.json                 ← dependencias y comandos
└── vite.config.js               ← configuración de Vite
```

Flujo principal:

```text
Usuario → componente → estado/handler en App.jsx → fetch → API backend → respuesta → componente
```

En reportes el flujo se concentra dentro de `ReportsPanel.jsx`: la UI construye `page`, `pageSize`, `filter` y `sort`, hace un `GET` y muestra `items`.

## 3. Ejecutar y validar

Desde `pricing-ui`:

```powershell
npm.cmd install
npm.cmd run dev
npm.cmd run lint
npm.cmd run build
```

Se usa `npm.cmd` porque en este equipo PowerShell puede bloquear `npm.ps1`. Vite muestra la URL local al iniciar; por defecto el frontend espera backend en `http://localhost:5000`.

Para cambiarla, buscar `#configurarApiBase` en `src/App.jsx`. Reportes tiene su propia constante equivalente en `src/components/ReportsPanel.jsx`; actualizar ambas o, idealmente, centralizarlas en una futura variable de entorno.

## 4. Crear un nuevo reporte

Buscar `#crearReporte` en `src/components/ReportsPanel.jsx`. Allí está el arreglo `reports`.

Agregar una entrada con:

```js
['proveedores', 'Proveedores', 'proveedores']
```

El código la transforma en:

```http
GET /api/admin/proveedores?page=1&pageSize=50
```

Ejemplo completo:

```js
['alertasPrecio', 'Alertas de precio', 'alertas-precio']
```

Antes de hacerlo, pedir al backend que implemente el endpoint con el contrato de [Reportes-API-Pendientes.md](./Reportes-API-Pendientes.md):

```json
{
  "items": [],
  "page": 1,
  "pageSize": 50,
  "totalCount": 0
}
```

El selector, tabla, filtros y paginación se generan automáticamente. No hace falta crear un componente nuevo.

Para modificar cómo se envía o procesa la consulta, buscar `#cargarReporte`. Para modificar los filtros, buscar `#filtrosReporte`. Los estilos de esta pantalla se encuentran mediante `#estilosReportes`.

### Reportes especializados y solo lectura

Además de los reportes de tabla, `ReportsPanel.jsx` registra cuatro recursos especializados:

- Parámetros de regla: histórico por `EstrategiaReglaID` y vigentes por `EstrategiaID`.
- Mensajes de regla: histórico por `EstrategiaReglaID` y vigentes por `EstrategiaID`.

Cada uno se declara en `scopedReports` con una ruta que contiene `{id}`. La interfaz pide y valida ese identificador antes de ejecutar el `GET`. Los recursos que provienen de métricas, snapshots, historial de decisiones y auditoría son solamente reportes de lectura: no se les deben crear formularios de alta, edición o baja.

Los metadatos de filtros para los reportes de tabla viven en `src/utils/reportFilters.js`. Agregar un recurso de tabla requiere registrar allí sus campos públicos, tipo y etiqueta.

## 5. Crear un POST

La aplicación tiene dos patrones.

### POST de pricing

El formulario está en `src/components/PricingForm.jsx`, pero el estado, las validaciones y el request viven en `src/App.jsx`.

1. Agregar el estado inicial al objeto `productTemplate`.
2. Agregar el input controlado en `PricingForm.jsx`:

```jsx
<input value={productForm.miCampo} onChange={(e) => updateField('miCampo', e.target.value)} />
```

3. Si corresponde, agregar una regla en `#validarFormulario`.
4. Convertir el tipo (por ejemplo, con `Number`) dentro de `buildPayload`.
5. Crear un handler que llame a `executeRequest('/ruta', payload)`. Buscar `#crearPost`.
6. Asociar el handler a un botón del formulario.

### Formularios administrativos (CRUD)

Los 15 formularios de `AdminPanel.jsx` usan una configuración CRUD común. Cada entidad declara su endpoint, sus campos de **Clave de formulario** y su ID técnico de respuesta.

Al salir de los campos de clave, `AdminPanel.jsx` consulta `GET /api/admin/{recurso}` con filtros `eq`. Si obtiene una única coincidencia, carga sus valores y conserva el ID técnico. `Aceptar` ejecuta `POST` cuando no hay registro o `PUT /{id}` cuando lo hay. `Eliminar` pide confirmación y solo se habilita para registros recuperados; Decisiones no admite eliminación.

Para agregar una entidad:

1. Crear el estado inicial y el payload en `App.jsx`.
2. Agregar el formulario y su entrada a `operations` en `AdminPanel.jsx`.
3. Registrar endpoint, ID técnico y campos de búsqueda en `ADMIN_FORM_CONFIG`.
4. Marcar los campos clave con `data-admin-key="entidad.campo"`.
5. Mantener la escritura en `handleAdminCreate`; no duplicar fetch ni botones CRUD.

Ejemplo de handler mínimo:

```js
const handleCrearProveedor = async () => {
  const payload = { nombre: 'Proveedor SA', activo: true }
  const data = await executeRequest('/api/admin/proveedores', payload)
  setAdminResult({ entity: 'proveedor', response: data })
}
```

No llamar a SQL desde la UI ni duplicar `fetch` si `executeRequest` cubre el caso.

### Parámetros y mensajes por Estrategia-Regla

Los flujos con vigencia, historial y desactivación usan componentes dedicados:

- `ParametersAdminPanel.jsx` y `ParameterForm.jsx` consumen `/api/admin/estrategias-reglas-parametros`.
- `MessagesAdminPanel.jsx` y `MessageForm.jsx` consumen `/api/admin/estrategias-reglas-parametros-mensajes`.

`App.jsx` los muestra en `/admin#parametrosRegla` y `/admin#mensajesRegla`. Las claves permitidas se mantienen en los arreglos `parameterKeys` y `messageKeys` de sus formularios. Las cotizaciones usan una sola `MonedaID`, `Cotizacion` y `FechaCotizacion`; no tienen moneda destino.

Claves numéricas canónicas:

- `PORCENTAJE_INCREMENTO_STOCK_CRITICO`
- `PORCENTAJE_INCREMENTO_OPORTUNIDAD`
- `PORCENTAJE_DECREMENTO_EXCESO_STOCK`
- `PORCENTAJE_DESCUENTO_COMPETENCIA`

Los mensajes envían `idioma` (`ES`, `EN` o `PT`) y usan `mensajeID` como identificador. El backend usa `ES` como fallback y rechaza tokens desconocidos o períodos de vigencia superpuestos. Un `PUT` crea una nueva versión histórica; no se debe asumir que conserva el mismo ID.

## 6. Crear una pantalla o ruta

1. Crear `src/components/MiPantalla.jsx`.
2. Importarla en `App.jsx`.
3. Buscar `#agregarRuta` y agregar una ruta, por ejemplo:

```jsx
<Route path="/proveedores" element={<MiPantalla />} />
```

4. Buscar `#agregarNavegacion` en `Sidebar.jsx` y agregar:

```js
{ id: 'proveedores', label: 'Proveedores' }
```

La navegación ya convierte ese `id` en la URL `/proveedores`.

## 7. Colores, formatos y responsive

### Colores globales

Buscar `#coloresGlobales` en `src/index.css`. Ahí se definen la fuente, color de texto y fondo base. Cambiar ese bloque altera toda la aplicación.

### Componentes y layout

Buscar `#coloresYFormatos` en `src/App.css`. Referencias principales:

- `.app-shell`: ancho de sidebar y layout general.
- `.panel`: tarjetas oscuras, bordes y sombras.
- `.primary-button`: degradado celeste/violeta de la acción principal.
- `.secondary-button` y `.ghost-button`: acciones secundarias.
- `.alert.error`: mensajes de error.
- `.form-grid`: grilla de campos de formularios.
- `.content-grid`, `.admin-grid`, `.docs-grid`: distribución de paneles.
- `@media (max-width: 980px)`: adaptación a móvil/tablet.

Ejemplo: cambiar el color principal del botón requiere modificar:

```css
.primary-button {
  background: linear-gradient(135deg, #38bdf8, #8b5cf6);
}
```

### Estilo de reportes

Buscar `#estilosReportes` en `src/App.css`.

- `.report-tab`: pestañas de cada tabla.
- `.report-filters`: formulario de filtros.
- `.filter-chip`: filtros activos.
- `.data-table`: tabla de resultados.
- `.report-pagination`: controles de página.

## 8. Mapa de etiquetas para buscar

| Buscar | Qué se encuentra |
| --- | --- |
| `#arranqueApp` | Punto de entrada de React y `BrowserRouter`. |
| `#configurarApiBase` | URL del backend en flujos de pricing/admin. |
| `#validarFormulario` | Validaciones previas al POST de pricing. |
| `#crearPost` | Helper de fetch para POST JSON y manejo de errores. |
| `#crearPostAdmin` | Mapeo de operaciones admin a endpoint y payload. |
| `#agregarRuta` | Lugar donde se registra una pantalla nueva. |
| `#agregarNavegacion` | Lugar donde se agrega una opción al menú. |
| `#crearReporte` | Catálogo de reportes y rutas GET. |
| `#cargarReporte` | Fetch de reportes con página, filtro y sort. |
| `#filtrosReporte` | Creación de filtros dinámicos. |
| `#coloresGlobales` | Tema base, fuente y fondo. |
| `#coloresYFormatos` | Layout, paneles, botones y estilos generales. |
| `#estilosReportes` | Estilos específicos de reportes. |

## 9. Documentación relacionada

- [API-Endpoints.md](./API-Endpoints.md): contratos de evaluación e ingreso de producto.
- [API-Admin-Endpoints.md](./API-Admin-Endpoints.md): operaciones administrativas existentes.
- [Reportes-API-Pendientes.md](./Reportes-API-Pendientes.md): contrato que debe implementar backend para reportes.
- [CONTEXT.md](../CONTEXT.md): vocabulario y decisiones de dominio.
