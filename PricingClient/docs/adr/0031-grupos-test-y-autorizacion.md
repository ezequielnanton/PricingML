# Grupos "Test" y "Autorización", nuevo orden del menú

Se pidieron dos carpetas nuevas en el menú, con el mismo patrón que
"Configuración" (ADR 0029): **Test** (ícono de hoja con lápiz), con
"Evaluar precio" adentro, y **Autorización** (ícono de hoja con check),
con "Cola ML (Aprobación)" adentro. Ambas reemplazan esas dos pantallas
como ítems sueltos de nivel superior. El orden final quedó: Inicio,
Formularios, Reportes, Test, Autorización, Documentación, Configuración.

## Caso nuevo: un hijo que no tiene permiso propio

Los grupos con `filterChildrenByPermission` que ya existían
(Configuración) agrupaban hijos que YA tenían cada uno su propio permiso
independiente en `Usuario.Secciones`. "Evaluar precio" es distinto: nunca
tuvo un permiso propio — desde antes de este cambio se gatea con el
mismo permiso `pricing` que ya usa "Inicio" (ver el término "Evaluar
precio" en CONTEXT.md), justamente para no obligar a un ADMIN a tildar
un permiso nuevo por una pantalla que ya podía ver.

Al mover "Evaluar precio" adentro de "Test", tanto el filtro de
visibilidad del menú (`Sidebar.jsx`) como el catálogo de permisos de la
pantalla Usuarios (`UsuariosPanel.jsx`) tuvieron que aprender este caso
especial: la fila "Test — Evaluar precio" apunta al mismo id `pricing`
que la fila "Inicio", no a un id `evaluar-precio` que nunca existió en
ningún Usuario guardado. Sin este cuidado, esa fila habría sido un
checkbox que no hacía nada (existía un bug igual, sin este cuidado, en el
código *anterior* a este cambio — cuando "Evaluar precio" todavía era un
ítem suelto de nivel superior; quedó corregido de paso).

## Validado

- Orden del árbol confirmado: Formularios, Reportes, Test, Autorización,
  Documentación, Configuración (más "Inicio" como raíz).
- "Test" despliega solo "Evaluar precio"; "Autorización" despliega solo
  "Cola ML (Aprobación)" — clickear cualquiera de los dos navega a su
  ruta real (`/evaluar-precio`, `/cola-ml-aprobacion`) sin hash, y
  resalta solo esa fila.
- En Usuarios, con el Administrador (que tiene todos los permisos), el
  panel "Editar permisos" muestra tildadas a la vez "Inicio" y "Test —
  Evaluar precio" — confirma que ambas filas reflejan el mismo permiso
  `pricing` compartido, sin duplicarlo.
