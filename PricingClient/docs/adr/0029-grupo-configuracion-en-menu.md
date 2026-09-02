# Grupo "Configuración" en el menú, sin crear un permiso nuevo

Se pidió agrupar en el menú, bajo una carpeta "Configuración", cuatro
pantallas que hasta ahora vivían sueltas al mismo nivel que Formularios y
Reportes: Integración ERP, Integración MercadoLibre, Integración Email y
Usuarios.

## Por qué no es un grupo igual a Formularios/Reportes/Documentación

Esos tres grupos existentes son, en términos de permisos, un único
interruptor: `hasSeccion('admin')` tapa o muestra las 15 pantallas de
Formularios de una vez, sin que cada una tenga su propio permiso en
`Usuario.Secciones`. "Configuración" es distinto: sus cuatro hijos ya
eran Secciones permitidas independientes (`erp`, `ml-integracion`,
`email-integracion`, `usuarios`) mucho antes de este cambio, con su
propio tilde por separado en la pantalla Usuarios. Agruparlos visualmente
no debía convertir esos cuatro permisos en uno solo — eso le sacaría a un
ADMIN la posibilidad de, por ejemplo, dar acceso a Integración Email sin
dar también acceso a Usuarios.

Por eso el nuevo grupo en `Sidebar.jsx` lleva un flag propio,
`filterChildrenByPermission: true`, que le dice al Sidebar que no busque
un permiso `configuracion-sistema` para el grupo entero: en su lugar,
filtra cada hijo por su propio `hasSeccion(child.id)` (igual que antes de
agruparlos) y solo muestra la carpeta si queda al menos un hijo visible.

## El catálogo de permisos de la pantalla Usuarios sale del mismo NAV_ITEMS

`UsuariosPanel.jsx` arma la lista de checkboxes "Secciones que puede ver"
leyendo directo `NAV_ITEMS` de `Sidebar.jsx` (para no mantener dos listas
sincronizadas a mano). Antes de este cambio eso significaba: una fila por
cada item de nivel superior. Si "Configuración" se hubiera agregado como
un item de nivel superior más, sin el flag, esa lista habría perdido las
cuatro filas de `erp`/`ml-integracion`/`email-integracion`/`usuarios`
—reemplazadas por una sola fila "Configuración" que no correspondería a
ningún permiso real ya guardado en la base— rompiendo silenciosamente la
posibilidad de tildar/destildar esos cuatro permisos por separado para
usuarios nuevos o existentes.

Se corrigió armando `SECCIONES` con el mismo criterio
`filterChildrenByPermission`: un grupo normal aporta una fila (su propio
id), un grupo con ese flag aporta una fila por hijo, etiquetada
`"{grupo} — {hijo}"` (ej. "Configuración — Integración ERP") para que
siga siendo identificable en la lista plana de checkboxes.

## Navegación

A diferencia de Formularios/Reportes (una sola pantalla con pestañas por
hash, `/admin#empresa`), cada hijo de Configuración ya era su propia
ruta completa (`/erp`, `/ml-integracion`, `/email-integracion`,
`/usuarios`) — eso no cambió. El único ajuste fue en el `onSelect` de
`App.jsx`: al clickear un hijo de este grupo, navega directo a
`/{subSection}` en vez de armar un hash.

## Validado

- Entrando directo a `/erp`: el menú abre con "Configuración" expandida
  automáticamente y "Integración ERP" como única fila resaltada.
- Clickear "Integración MercadoLibre" navega a `/ml-integracion` y mueve
  el resaltado a esa fila únicamente.
- En Usuarios, la fila del Administrador sigue listando los cuatro
  permisos por separado ("Configuración — Integración ERP", "—
  Integración MercadoLibre", etc.), y el formulario de alta muestra los
  cuatro como checkboxes independientes.
