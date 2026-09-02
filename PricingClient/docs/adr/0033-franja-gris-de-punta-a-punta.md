# La franja gris de iconos cruza todo el ancho de la página

La franja gris con Sincronización/campanita/cuenta (ADR 0032) había
quedado angosta, confinada al ancho del sidebar (260px), debajo del
logo. Se pidió que cruce de punta a punta todo el ancho de la página,
siempre debajo del logo y arriba del título de la pantalla.

## Por qué hizo falta tocar el grid de `.app-shell`

Sidebar y el panel principal son columnas separadas de un mismo grid de
2 columnas (`.app-shell`). Para que la franja gris ocupe las dos columnas
a la vez sin dejar de tener el logo solo en la columna izquierda y el
título solo en la derecha, `.app-shell` pasó a definir 3 filas con
`grid-template-areas`:

```
"brand   brand-fill"
"toolbar toolbar"
"nav     main"
```

`toolbar` se repite en las dos columnas de su fila, así que ocupa el
ancho completo automáticamente. La celda `brand-fill` (arriba a la
derecha, junto al logo) queda vacía a propósito — ahí no va nada, es la
misma franja blanca que ya se ve en el header-bar antes de que el título
empiece más abajo.

Para que esto funcione, `.brand`, `.sidebar-toolbar`, `.sidebar-scroll`
(el árbol de navegación) y `.main-panel` tienen que ser hijos DIRECTOS
del grid de `.app-shell` — pero `Sidebar.jsx` sigue devolviendo un único
`<aside>` que los envuelve a los primeros tres. Se resolvió con
`.sidebar { display: contents; }`: el `<aside>` deja de tener caja
propia (sin fondo, sin tamaño) y sus hijos pasan a participar del grid
del padre como si fueran hijos directos, sin tocar la estructura de
componentes de React. El fondo oscuro degradado y el borde derecho que
antes tenía `.sidebar` se movieron a `.sidebar-scroll`, que es la única
pieza que sigue ocupando una sola columna (la franja del árbol de
navegación, no el logo ni el toolbar, que ya tienen sus propios fondos
opacos).

## Los paneles desplegables volvieron a anclarse a la derecha

Al mover los tres iconos de vuelta a una franja de ancho completo,
quedaron otra vez pegados al borde **derecho** de la página (con
`justify-content: flex-end` dentro de la franja) — el mismo lugar que
ocupaban antes de mudarse al sidebar angosto. El ADR 0032 los había
anclado con `left: 0` porque en ese momento vivían pegados al borde
izquierdo; con la franja de ancho completo eso volvió a producir el
mismo bug de desborde, ahora hacia la derecha. Se revirtieron los tres
paneles (`.notification-dropdown`, `.toolbar-dropdown-panel`) a
`right: 0`.

## Validado

- La franja gris cruza las dos columnas del grid, de punta a punta.
- El logo queda solo, arriba a la izquierda; el título "Inicio" queda
  solo, debajo de la franja, en la columna derecha.
- Los tres desplegables abren completos dentro del viewport
  (`scrollWidth` de la página no crece al abrirlos).
- El árbol de navegación (Formularios y sus hijos) sigue funcionando
  igual que antes dentro de su columna.
