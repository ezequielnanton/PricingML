# "Inicio" reemplaza al botón "Menú" como raíz del árbol

Se pidió sacar el botón "Menú" (el toggle que mostraba/ocultaba todo el
árbol de navegación) y que "Inicio" cumpla ese mismo rol, siendo el ítem
del que cuelgan todas las demás opciones. Además, API Check y Ejecución
automática pasan a ser hijos de "Configuración" (ver ADR 0029), en vez de
ítems sueltos al mismo nivel que Formularios/Reportes.

## Inicio hace dos cosas en un solo click

A diferencia de los demás grupos (Formularios, Reportes, Documentación,
Configuración), que solo despliegan sus hijos al clickearlos y nunca
navegan, "Inicio" sigue siendo también un destino real (`/`, el Resumen
de ventas). El pedido explícito fue que el click haga las dos cosas a la
vez: navega a Inicio y despliega el árbol, en el mismo gesto. Se
implementó como toggle (no como "siempre abrir"), para no perder la
posibilidad de volver a cerrar el árbol con el mismo botón — igual que
podía hacerse antes con "Menú".

## El botón se muestra aunque falte el permiso "pricing"

`hasSeccion('pricing')` sigue controlando si el Usuario puede ver la
pantalla de Inicio, pero el botón raíz ahora se renderiza siempre,
tenga o no ese permiso — si no lo tiene, el click solo despliega el
árbol sin navegar. La razón: como "Inicio" pasó a ser también el único
toggle de visibilidad de TODO el menú (heredó ese rol de "Menú", que
antes era incondicional), un Usuario sin el permiso "pricing" pero con
otros permisos (Formularios, Reportes, etc.) se habría quedado sin
ninguna forma de abrir el menú para llegar a esas otras pantallas que sí
tiene permitidas.

## Validado

- Entrando a `/`: "Inicio" aparece resaltado (única fila activa) y el
  árbol arranca colapsado, igual que antes arrancaba "Menú".
- Clickear "Inicio" despliega el árbol completo (Evaluar precio,
  Formularios, Reportes, Documentación, Configuración, Cola ML) en el
  mismo click que confirma la navegación a `/`.
- Dentro de "Configuración" ahora aparecen, en orden: API Check,
  Integración ERP, Integración MercadoLibre, Integración Email,
  Usuarios, Ejecución automática — cada uno con su ícono propio.
- En Usuarios, el catálogo de permisos sigue listando los seis hijos de
  Configuración por separado (`Configuración — API Check`, `—
  Ejecución automática`, etc.), sin perder ninguno en la reorganización.
- Clickear "API Check" navega a `/health`, resalta solo esa fila (ni
  Inicio ni Configuración quedan también marcados) y la pantalla
  responde `{"status":"ok"}`.
