# Autocomplete por descripción para campos ID en los ABM

Los mismos criterios de búsqueda que ADR 0027 le dio a los filtros de
Reportes se pidieron también para los ABM (`AdminPanel.jsx`): todo campo
ID de un formulario que referencia una entidad nombrable (Empresa,
Moneda, Producto, Cuenta ML, Publicación ML, Estrategia, Regla) pasa de
ser un `<select>` que precargaba todas las opciones de esa entidad de una
sola vez, a ser el mismo `FkAutocompleteInput.jsx` que ya usa Reportes:
busca por descripción con hasta 10 coincidencias mientras se escribe, o
los primeros 10 registros si el campo está vacío. Es el mismo componente,
el mismo mapeo (`fkLookups.js`) y los mismos endpoints genéricos — cero
backend nuevo, igual que en Reportes.

Quedaron reemplazados 14 campos en 10 de los 13 formularios (cotización,
parámetro general, cuenta ML, producto, costo producto, publicación ML,
stock estado, configuración, estrategia y estrategia-regla). Empresa,
Moneda y Regla no tienen un campo FK propio para reemplazar — son el
origen de la búsqueda, no el destino. Junto con el reemplazo se pudo
borrar todo el precargado que ya no hacía falta: los `useState` con las
listas completas de cada entidad, el `useEffect` que las traía enteras al
montar el panel, y las funciones `getXxxLabel` que armaban a mano el
texto "Descripción (ID)" de cada `<option>`.

El mismo reemplazo se hizo también en los campos de **búsqueda del
listado** de cada ABM (`AbmRecordList.jsx`, la columna "Registros" a la
izquierda del formulario): cuando uno de los `searchFields` configurados
para una entidad es un ID con lookup (por ejemplo, buscar
Estrategia-Regla por `EstrategiaID` o `ReglaID`, o Producto por
`EmpresaID`), ese input también pasa a ser `FkAutocompleteInput` en vez
de un número/texto plano. Elegir una sugerencia completa el campo de
búsqueda con el ID real; el botón "Buscar" sigue aplicando el filtro
`eq` sobre ese ID exactamente igual que antes.

## Sugerencias también en los campos de búsqueda que no son ID

Después de este primer pase, el pedido se amplió: los campos de búsqueda
del listado que NO son un ID referenciable (`CUIT`, `SKU`, `NicknameML`,
`CodigoISO`, `MeliItemID`, `NombreEstrategia`, `CodigoRegla`,
`ClaveParametro`) tampoco proponían nada — eran inputs de texto planos.
Se armó `SearchSuggestInput.jsx`, un componente hermano de
`FkAutocompleteInput.jsx` con la misma interacción (sugerencias al
enfocar vacío, filtro en vivo con debounce al escribir, hasta 10
resultados), pero sin resolución de ID: como acá no hay una entidad
referenciada, la sugerencia es directamente el valor de ese campo tal
como aparece en los registros existentes (`filter[campo][contains]`
sobre el mismo endpoint del listado), y elegirla escribe ese texto en el
campo de búsqueda — el mismo texto que ya se mandaba con `contains` al
tocar Buscar, sin cambiar la semántica del filtro.

Al armar esto apareció un caso borde: `CUIT` no tiene `type: 'text'` en
`reportFilters.js` sino un tipo propio, `'cuit'` (para poder aplicarle
una validación de formato distinta en Reportes). La primera versión de
este cambio comparaba explícitamente contra `'text'` para decidir si
mostrar sugerencias, así que `CUIT` quedaba afuera y cayó al `<input
type="number">` por default. Se corrigió invirtiendo la condición: se
muestran sugerencias para cualquier tipo que no sea `'number'` ni
`'date'` (la misma regla que ya usaba el `else` original para decidir
entre `eq` y `contains`), en vez de listar explícitamente los tipos que
sí las tienen.

## Bug preexistente encontrado y corregido de paso

En el formulario "Vincular Regla a Estrategia", los `<select>` de
Estrategia y Regla tenían la prop `disabled` puesta dos veces: una vez
con `mode === 'edit'` (para respetar el bloqueo de Clave de formulario en
edición) y otra vez, más abajo, con `dataLoading || estrategias.length
=== 0` — en JSX, la segunda gana y pisa a la primera en silencio. El
resultado era que esos dos campos quedaban editables en Modo edición
aunque debieran quedar bloqueados. Se corrigió al reemplazar los
`<select>`, dejando un único `disabled={mode === 'edit'}`.

## Dos bugs de loop infinito de render encontrados en el camino

Verificar el reemplazo en el navegador destapó dos bugs de "Maximum
update depth exceeded" que no tenían relación directa con el trabajo de
autocomplete, pero bloqueaban poder probarlo:

**1. `LoginGate.jsx` se autodisparaba en cada re-chequeo de sesión.**
`verificarSesion` (la función que revisa `/api/auth/me` al montar la app
y en cada `SESSION_CHANGED_EVENT`) llamaba `setSession()` en su propio
camino de éxito — pero `setSession()` es la misma función que dispara
`SESSION_CHANGED_EVENT`, y `verificarSesion` está suscripta a ese evento.
Cada re-chequeo exitoso volvía a dispararse a sí mismo, sin parar, al
ritmo de la latencia de red del fetch a `/api/auth/me`. Se agregó
`refreshStoredUsuario()` en `auth.js` — actualiza `localStorage` igual
que `setSession()` pero sin volver a disparar el evento — y
`verificarSesion` la usa en su lugar.

**2. `Sidebar.jsx` recalculaba `navItems` en cada render y lo usaba como
dependencia de un efecto que escribía estado.** `navItems` sale de un
`.filter()` sobre `NAV_ITEMS`, así que es una referencia nueva en cada
render aunque el contenido no cambie. Estaba en el arreglo de
dependencias de un `useEffect` que expande automáticamente la sección del
menú activa (`setExpandedSections`). Al tener `navItems` como dependencia
inestable, el efecto se disparaba en cada render, escribía un objeto
nuevo en el estado, eso disparaba otro render, que volvía a recrear
`navItems`, sin parar — un loop sincrónico, sin ningún fetch de por
medio, reproducible en **cualquier** pantalla de Formularios (no solo en
las que tienen `FkAutocompleteInput`, que fue lo primero que se sospechó).
Se sacó `navItems` de las dependencias y se agregó un chequeo de
idempotencia (`current[activeSection] ? current : {...}`) para que el
efecto no escriba estado cuando ya estaba expandido, cortando el loop de
raíz sin importar qué referencia traiga `navItems`.

## La fila del listado también resolvía la descripción de sus FK

Un tercer ajuste, en la misma línea: en "Parámetro General", "Costo
Producto", "Stock Estado" y "Vincular Regla a Estrategia" (formularios
donde `searchFields` es puro FK, sin ningún campo de texto propio como
SKU o NombreEstrategia), la fila del listado mostraba directamente el ID
crudo de cada campo (`"1 · 1"`) porque `getRowLabel` arma la etiqueta con
`config.searchFields`, y el registro que devuelve el propio endpoint del
ABM no trae la descripción de la entidad referenciada — no hay join.

Se agregó una resolución por ID: al llegar una página de resultados,
`AbmRecordList` junta los IDs únicos de cada campo FK que aparece en esa
página (como mucho 8 filas) y los resuelve uno por uno contra el
`lookup.endpoint` correspondiente (la misma consulta `filter[idField][eq]`
que ya usa `FkAutocompleteInput` para resolver un valor ya cargado),
cacheando el resultado en `fkLabels` para no repetir la consulta si el
mismo ID vuelve a aparecer en otra página. Mientras la resolución está en
vuelo, la fila muestra el ID crudo como antes — nunca queda en blanco.

## Validado

- En "Vincular Regla a Estrategia": las sugerencias de Estrategia y Regla
  cargan al enfocar (primeros registros) y filtran en vivo al escribir;
  elegir una completa el campo con el ID real y habilita Guardar (antes
  quedaba en "Guardando..." con los campos vacíos, comportamiento
  preexistente y no relacionado, sin tocar). El bloqueo de Modo edición
  ahora sí aplica sobre ambos campos.
- En "Producto": al abrir un registro existente, Empresa resuelve y
  muestra su descripción ("Softland") en vez del ID crudo. En Modo
  edición, Empresa y SKU quedan deshabilitados; el resto de los campos
  queda editable.
- Cero errores de "Maximum update depth exceeded" en consola tras una
  recarga completa (servidor y pestaña limpios) en `/admin#moneda` y
  `/admin#estrategiaRegla`, ni al enfocar los campos de autocomplete.
- En el buscador del listado de "Estrategia-Regla": el campo de búsqueda
  por Estrategia propone sugerencias al enfocarlo, elegir "Estrategia QA
  Motor" completa el campo y, al presionar Buscar, la request real fue
  `filter[estrategiaID][eq]=1` (verificado contra Network).
- En "Producto": combinando el filtro FK (Empresa) con el de texto (SKU)
  a la vez, Buscar devolvió los 8 productos de esa empresa cuyo SKU
  contiene el texto elegido — confirma que ambos tipos de filtro se
  combinan con AND, igual que antes del cambio.
- En "Empresa": el campo CUIT (antes texto plano, con el tipo especial
  `'cuit'`) ahora propone los CUIT existentes al enfocarlo vacío;
  elegir uno y tocar Buscar filtra correctamente al registro exacto.
- En "Regla": el campo Código de regla propone los 4 códigos existentes
  en la base al enfocarlo vacío.
- En "Vincular Regla a Estrategia", "Parámetro General", "Costo
  Producto" y "Stock Estado": las filas del listado ahora muestran la
  descripción resuelta (ej. "Estrategia QA Motor · Stock crítico",
  "Empresa QA Motor", "QA-TC01 — QA Stock Crítico") en vez del ID crudo.
