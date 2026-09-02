# Sin filtro de reporte duplicado para el campo que ya busca el Autocomplete de descripción para ID

En 7 Reportes de tabla, el ID propio de la entidad usa el **Autocomplete de descripción para ID** (ver ADR 0027) buscando por un campo de texto de esa misma entidad — y ese mismo campo de texto también existía como un **Filtro de reporte** aparte: Empresas (Empresa ID busca por Razón Social, y Razón Social era un filtro propio), Monedas (Moneda ID / Nombre), Productos (Producto ID / Título), Cuentas ML (Cuenta ML ID / Nickname ML), Publicaciones ML (Publicación ID / Meli item ID), Estrategias (Estrategia ID / Nombre estrategia) y Reglas (Regla ID / Nombre).

Se decidió sacar el filtro de texto duplicado en los 7 casos: desde que el ID tiene autocomplete por esa descripción, tenerla también como filtro aparte se veía redundante en la UI.

Esto es un trade-off real, no solo estético: el Autocomplete solo sirve para encontrar y filtrar por **un** registro puntual (una vez elegida la sugerencia, arma un filtro `eq` por ID exacto); el filtro de texto aparte permitía además una búsqueda parcial (`contains`) que puede traer **varios** registros a la vez (ej. "todas las empresas que tengan 'tech' en la razón social"). Sacar el filtro duplicado elimina esa segunda posibilidad — se aceptó conscientemente esa pérdida a cambio de un catálogo de filtros más limpio.

Si en el futuro hace falta volver a filtrar por texto parcial contra varios registros en alguno de estos 7 campos, hay que reintroducir ese `Filtro de reporte` explícitamente (no es un default que vaya a reaparecer solo).
