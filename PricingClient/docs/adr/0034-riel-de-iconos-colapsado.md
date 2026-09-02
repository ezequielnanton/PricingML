# El botón de "ocultar menú" colapsa a un riel de íconos, no oculta todo

La primera implementación del ícono `PanelToggleIcon` (agregado sobre la
ADR 0032/0033) reusaba el estado `menuOpen` que "Inicio" ya tenía como
toggle de todo el árbol — al clickearlo, el menú entero desaparecía,
dejando solo la fila "Inicio" visible. Eso no era lo pedido: el botón
tiene que **colapsar** el sidebar a una columna angosta con **solo
íconos** (sin texto, sin árbol desplegable), no ocultar las opciones.

## Se sacó el concepto de "ocultar todo" y se reemplazó por "colapsar"

Se eliminó `menuOpen` (y el `isMobile` que solo existía para cerrarlo en
mobile) de `Sidebar.jsx`. En su lugar, `collapsed` vive en `App.jsx`
(`sidebarCollapsed`) porque tiene que controlar el ancho de la columna
del sidebar en `.app-shell`, que es un elemento fuera de `Sidebar.jsx` —
se pasa para abajo como prop (`collapsed` / `onToggleCollapsed`), igual
que `toolbarIcons` viaja para arriba.

Con `collapsed`:
- `.app-shell.collapsed` angosta `grid-template-columns` de `260px` a
  `72px` (el logo y los ítems del árbol se adaptan a esa columna nueva
  con CSS, ocultando `.nav-item-text` y `.nav-chevron` y centrando cada
  ícono).
- La franja gris de iconos (`.sidebar-toolbar`) no se ve afectada:
  sigue ocupando el ancho completo de la página siempre (ver ADR 0033),
  independiente de si el riel está colapsado o no.
- "Inicio" dejó de ser un toggle — ahora es un ítem de navegación normal
  como cualquier otro (ya no tiene sentido que también controle el
  colapso, porque ese rol ahora es exclusivo del ícono dedicado).

## Clickear un grupo con el riel colapsado

Un riel de 72px no tiene lugar para desplegar hijos ahí mismo, y
mostrarlos sería ilegible sin texto. Se agregó `handleCollapsedClick`:
clickear un ítem sin hijos navega directo (igual que siempre); clickear
un grupo (Formularios, Reportes, etc.) expande el sidebar completo
(`onToggleCollapsed()`) **y** abre ese grupo en el mismo click
(`setExpandedSections` con ese id en `true`), para no dejar al usuario
con un grupo colapsado que no sabe cómo abrir.

## Validado

- Clickear el ícono de colapsar angosta el sidebar a un riel de solo
  íconos (Inicio, Formularios, Reportes, Test, Autorización,
  Documentación, Configuración) — sin texto, sin flechas de expandir.
- Clickear "Formularios" en el riel colapsado expande el sidebar
  completo y abre ese grupo con sus 15 hijos visibles, en el mismo
  click.
- Clickear el ícono de nuevo vuelve a colapsar todo a el riel de
  íconos.
