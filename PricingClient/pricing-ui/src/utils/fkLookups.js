// #autocompleteFkReportes: para cada campo ID de Reportes que referencia otra entidad,
// qué endpoint consultar, qué campo es el ID real y cómo armar la descripción legible
// que se busca a medida que se escribe (ver ReportFilterField.jsx / FkAutocompleteInput.jsx).
// Solo se listan acá los ID con una entidad "nombrable" clara (Empresa, Moneda, Producto,
// Cuenta ML, Publicación ML, Estrategia, Regla) — un ID de fila propia sin nombre natural
// (ej. ColaID, SnapshotID, DecisionID) se deja como número simple, no tiene descripción
// razonable para buscar.
export const FK_LOOKUPS = {
  EmpresaID: {
    endpoint: '/api/admin/empresas',
    idField: 'empresaID',
    searchField: 'razonSocial',
    label: (item) => item.razonSocial ?? `Empresa ${item.empresaID}`,
  },
  MonedaID: {
    endpoint: '/api/admin/monedas',
    idField: 'monedaID',
    searchField: 'nombre',
    label: (item) => (item.codigoISO ? `${item.codigoISO} — ${item.nombre}` : item.nombre ?? `Moneda ${item.monedaID}`),
  },
  ProductoID: {
    endpoint: '/api/admin/productos',
    idField: 'productoID',
    searchField: 'titulo',
    label: (item) => (item.sku ? `${item.sku} — ${item.titulo}` : item.titulo ?? `Producto ${item.productoID}`),
  },
  CuentaMLID: {
    endpoint: '/api/admin/cuentas-ml',
    idField: 'cuentaMLID',
    searchField: 'nicknameML',
    label: (item) => item.nicknameML || item.userIDML || `Cuenta ML ${item.cuentaMLID}`,
  },
  PublicacionID: {
    endpoint: '/api/admin/publicaciones-ml',
    idField: 'publicacionID',
    searchField: 'meliItemID',
    label: (item) => item.meliItemID ?? `Publicación ${item.publicacionID}`,
  },
  EstrategiaID: {
    endpoint: '/api/admin/estrategias',
    idField: 'estrategiaID',
    searchField: 'nombreEstrategia',
    label: (item) => item.nombreEstrategia ?? `Estrategia ${item.estrategiaID}`,
  },
  ReglaID: {
    endpoint: '/api/admin/reglas',
    idField: 'reglaID',
    searchField: 'nombre',
    label: (item) => item.nombre ?? `Regla ${item.reglaID}`,
  },
  // #sinNombrePropio: Estrategia-Regla es una tabla de vínculo (Estrategia + Regla +
  // Prioridad), sin ningún campo de texto propio para buscar por "contains" como el resto
  // de arriba -- por eso searchType:'number' (ver FkAutocompleteInput.jsx), que busca por
  // ID exacto en vez de coincidencia parcial. La lupa igual muestra los primeros resultados
  // apenas se hace foco, sin necesidad de escribir nada.
  EstrategiaReglaID: {
    endpoint: '/api/admin/estrategia-reglas',
    idField: 'estrategiaReglaID',
    searchField: 'estrategiaReglaID',
    searchType: 'number',
    label: (item) => `Estrategia ${item.estrategiaID} · Regla ${item.reglaID} (Prioridad ${item.prioridad})`,
  },
}

// Alias que apuntan a la misma entidad que otro campo ya definido arriba, para no
// duplicar endpoint/searchField/label a mano.
const ALIAS_TARGET = { MonedaPrincipalID: 'MonedaID', MonedaSecundariaID: 'MonedaID', ReglaGanadoraID: 'ReglaID' }

export const getFkLookup = (fieldName) => {
  const target = ALIAS_TARGET[fieldName] || fieldName
  return FK_LOOKUPS[target] || null
}
