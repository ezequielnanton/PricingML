# Filtros dinámicos reutilizables para reportes

## Estado

Aceptado.

## Contexto

Los reportes de tabla se exponen bajo una API administrativa uniforme y comparten la misma necesidad: cada columna debe poder filtrarse sin duplicar lógica por pantalla o por tipo de dato. El backend ya soporta requisitos de filtrado por operador (`eq`, `contains`, `gte`, `lte`, etc.), pero la UI anterior tenía un mecanismo manual, no reutilizable y acoplado a un único caso de uso.

La solución debía cumplir una serie de requisitos de negocio:

- un filtro por cada columna configurada;
- rango opcional por columna;
- validación según tipo de dato;
- comportamiento distinto para texto, número, fecha y booleano;
- no obligar a completar ambos lados del rango;
- mantener la lógica en un componente reutilizable y parametrizable;
- evitar SQL injection usando parámetros de consulta y no concatenando strings del usuario.

## Decisión

Se implementó un mecanismo basado en metadatos de columnas y lógica centralizada para construir los parámetros de consulta.

### Metadatos del filtro

Cada columna puede definirse con:

- `field`: nombre del campo de la tabla;
- `label`: texto visible para el usuario;
- `type`: `text`, `number`, `date`, `boolean`, `cuit`;
- `allowRange`: si admite modo rango;
- `component`: control visual (`text`, `number`, `date`, `select`);
- `options`: opciones para booleanos o selectores enumerados;
- `value`, `from`, `to`: estado del filtro en la UI.

### Lógica reutilizable

La lógica está separada en tres capas:

1. Configuración de campos: `REPORT_FIELD_DEFINITIONS` y `normalizeFiltersForReport`.
2. Render del control: `ReportFilterField.jsx`.
3. Validación y construcción de query params: `reportFilters.js`.

Esto permite que cualquier reporte pueda reutilizar el mismo mecanismo con una definición de columnas distinta.

## Comportamiento

### Filtro simple

Cuando el rango está desactivado:

- número: compara con `eq`;
- texto y CUIT: usa `contains` como operación base;
- fecha: busca el día completo;
- booleano: muestra opciones `Todos / Sí / No`.

### Rango

Cuando el rango está activado:

- solo `Desde`: `>=`;
- solo `Hasta`: `<=`;
- ambos: `>=` y `<=`;
- ninguno: no aplica el filtro.

### Fechas

Para `date` y `datetime`, el límite superior del día se ajusta para incluir el día completo, por ejemplo:

- `2026-01-31` se transforma a `2026-01-31T23:59:59.999Z` para que no se excluyan registros del final del día.

### Validaciones

- números deben ser válidos;
- fechas deben ser válidas;
- si ambos límites existen, `Desde <= Hasta`;
- booleanos solo aceptan valores permitidos;
- un error claro bloquea la ejecución de la consulta.

## Consecuencias

### Positivas

- la UI queda genérica y reutilizable para cualquier reporte;
- el rango es independiente por columna;
- se evita duplicación de reglas por cada reporte;
- se centraliza la validación y la construcción de filtros.

### Negativas

- la configuración inicial de metadatos requiere mantener una definición explícita por reporte;
- el backend sigue siendo responsable de aceptar los operadores y parámetros validados en la API.

## Implementación actual

Las piezas principales están en:

- [pricing-ui/src/utils/reportFilters.js](../pricing-ui/src/utils/reportFilters.js)
- [pricing-ui/src/components/ReportFilterField.jsx](../pricing-ui/src/components/ReportFilterField.jsx)
- [pricing-ui/src/components/ReportsPanel.jsx](../pricing-ui/src/components/ReportsPanel.jsx)

Esto deja el patrón listo para extenderlo a clientes, productos, proveedores, historial y cualquier otra tabla del sistema.
