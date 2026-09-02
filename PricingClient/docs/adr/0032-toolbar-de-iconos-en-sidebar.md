# Sincronización/campanita/cuenta se mudan al sidebar

Se pidió replicar el layout de una imagen de referencia (un sistema con
logo chico arriba a la izquierda y una franja gris debajo con iconos) en
la parte de arriba del sidebar. El pedido se acotó explícitamente a
"solo el sidebar" — el árbol de navegación (Inicio, Formularios,
Reportes, etc.) sigue siendo la columna izquierda de siempre, sin
convertirse en una barra horizontal arriba de toda la app.

## Qué cambió

- **Logo**: `.brand` pasó de centrado/grande a chico y alineado a la
  izquierda (100×52, contra los 150×78 centrados de antes), en una
  franja blanca fina — igual que el logo de la imagen de referencia. El
  logo de la pantalla de login (`.login-gate-logo`) no se tocó, sigue
  centrado y grande porque es un contexto distinto (tarjeta de login, no
  el sidebar).
- **Franja gris nueva** (`.sidebar-toolbar`): justo debajo del logo, con
  los tres iconos alineados a la derecha (Sincronización, campanita,
  cuenta) — antes vivían en el `header-bar` del panel principal, a la
  derecha del título de la pantalla.
- **Título**: sigue en el `header-bar` de arriba del contenido, ahora
  solo con el `<h1>` — sin los iconos al lado, tal como pidió la
  restricción ("los títulos van debajo", es decir, no comparten fila con
  el logo/los iconos del sidebar).

## Por qué hubo que mover App.jsx a props en vez de JSX fijo

Sidebar y el panel principal son hermanos en el árbol de componentes
(`<div className="app-shell"><Sidebar/><main>...</main></div>`), no uno
dentro del otro. El contenido de Sincronización (los tres botones de
ERP/Cola ML, con su propio loading state) y el `accountMenu` (que viene
de `LoginGate` como render-prop) seguían viviendo en `App.jsx`, que es
quien tiene esos handlers y ese estado — así que en vez de duplicar esa
lógica dentro de `Sidebar.jsx`, `App.jsx` arma el JSX ya armado
(`toolbarIcons`) y se lo pasa a `<Sidebar toolbarIcons={...} />` como
prop, que solo lo ubica en el lugar correcto del layout.

## Bug de posicionamiento encontrado y corregido

Los tres paneles desplegables (`.notification-dropdown`,
`.toolbar-dropdown-panel`) estaban anclados con `right: 0` — correcto
cuando los botones vivían pegados al borde derecho de una pantalla
ancha, pero al mudarse a un sidebar angosto (260px) pegado al borde
**izquierdo**, ese mismo anclaje hacía que el panel (320px+ de ancho) se
abriera hacia la izquierda y quedara cortado fuera del viewport, sin
poder verse ni scrollear hasta él. Se cambiaron los tres a `left: 0`
para que se desplieguen hacia la derecha, hacia el espacio del panel
principal donde sí hay lugar.

## Validado

- Los tres iconos aparecen en la franja gris, alineados a la derecha,
  debajo del logo chico.
- Los tres desplegables (Sincronización, campanita, cuenta) abren
  completos hacia la derecha, sin cortarse ni generar scroll.
- El título "Inicio" quedó solo en su propia fila, sin iconos al lado.
