# Autocomplete por descripción para filtros de ID en Reportes

Los filtros de campos ID en Reportes (`EmpresaID`, `ProductoID`, etc.) eran
inputs numéricos simples: para filtrar "productos de la empresa X" había
que saber de memoria el ID técnico de esa empresa. El usuario pidió que,
para todo campo ID que referencia otra entidad, se pueda buscar por
descripción en vez de por número — escribiendo, se proponen hasta 10
coincidencias; sin escribir nada, se proponen los primeros 10 registros.

## Alcance: solo IDs que referencian una entidad "nombrable"

No todos los campos que terminan en `ID` se convirtieron en buscador. Se
armó un mapa explícito (`fkLookups.js`) solo para los que apuntan a una
entidad con un nombre/descripción natural para buscar:
**Empresa** (`EmpresaID`), **Moneda** (`MonedaID`,
`MonedaPrincipalID`/`MonedaSecundariaID` como alias), **Producto**
(`ProductoID`), **Cuenta ML** (`CuentaMLID`), **Publicación ML**
(`PublicacionID`), **Estrategia** (`EstrategiaID`) y **Regla** (`ReglaID`,
`ReglaGanadoraID` como alias). IDs de fila propia sin un nombre natural
(`ColaID`, `SnapshotID`, `DecisionID`, `AuditoriaID`, etc.) se dejaron
como número simple — no hay ninguna descripción razonable que buscar ahí,
y esos registros ya se identifican por otras columnas visibles en la
tabla del reporte.

El mapeo aplica por **nombre de campo**, no por tabla: si un reporte tiene
su propio `EmpresaID` como clave primaria (el reporte "Empresas"), ese
campo también se convierte en buscador por Razón Social — poder tipear
"Softland" para encontrar su propio ID es tan útil ahí como en cualquier
FK que apunte a Empresas.

## Cómo funciona (sin cambios de backend)

`FkAutocompleteInput.jsx` reusa los mismos endpoints genéricos de
Reportes que ya existían (`GET /api/admin/{recurso}?filter[campo][contains]=...&pageSize=10`),
sin agregar ningún endpoint nuevo:

- Al enfocar el campo vacío: pide los primeros 10 registros sin filtro.
- Al escribir (con debounce de 250ms): pide hasta 10 coincidencias por
  `contains` sobre un único campo de búsqueda por entidad (por ejemplo,
  `razonSocial` para Empresa, `nombre` para Moneda/Regla, `titulo` para
  Producto). El sistema de filtros de Reportes no soporta `OR` entre
  campos distintos en una sola consulta, así que para entidades con
  etiqueta compuesta (Producto muestra "SKU — Título") se busca por el
  campo más útil (`titulo`) y se muestran ambos en la sugerencia.
- Al elegir una sugerencia, el filtro real que se manda a la API sigue
  siendo `eq` sobre el ID (sin cambios en `reportFilters.js` más allá de
  desactivar el toggle "Rango" en estos campos — un "rango de nombres" no
  tiene sentido).
- Si el filtro ya tiene un valor (ej. al reabrir la pantalla, o si se
  cargó por otro medio), el campo resuelve su descripción con una consulta
  `filter[{idField}][eq]={valor}` para mostrarla en vez del número crudo.

## Validado

- Probado en el reporte "Productos": el campo Empresa ID muestra las
  empresas existentes al enfocarlo vacío, filtra en vivo escribiendo
  "Soft", y al elegir "Softland" y ejecutar, el filtro real aplicado fue
  `EmpresaID = 2` (verificado contra los 9 productos QA de "Empresa QA
  Motor" al elegir esa empresa en su lugar).
- Probado el caso reflexivo: en el reporte "Empresas", el propio `Empresa
  ID` (su clave primaria) también quedó como buscador por Razón Social.
- El toggle "Rango" ya no aparece en ninguno de estos campos.

## Fuera de alcance (no pedido, no implementado)

Enriquecer las **columnas de la tabla de resultados** de Reportes para
mostrar la descripción en vez del ID crudo en cada fila no se tocó — el
pedido, tal como se elaboró, fue específicamente sobre la experiencia de
tipeo/sugerencias al armar el filtro. Eso requeriría cambios de backend
(joins por reporte) y quedaría como un pedido aparte si se necesita.
