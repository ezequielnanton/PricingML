# Pruebas de la extensión

Dos suites, las dos contra el código real de `src/popup.js` — ninguna copia pegada.

| Archivo | Qué prueba |
|---------|------------|
| `extraccion.test.mjs` | `extraerDatosDelArticulo` contra 11 armados distintos de página de ML |
| `extension.test.mjs` | El flujo completo: se carga la extensión en Chrome y se maneja el popup |

## Correrlas

```bash
cd PricingML-Extension/tests
npm install
npx playwright install chromium     # solo la primera vez
npm test
```

No hace falta el Motor ni SQL Server: `stub-motor.mjs` levanta un Motor de mentira en un puerto
libre que responde lo mismo que `PricingApi` (mismo camelCase, mismos códigos HTTP) y registra
lo que recibe, así que las pruebas pueden afirmar qué se posteó y con qué token.

## Qué cubre `extension.test.mjs`

Chrome carga la extensión de verdad (`--load-extension`), así que se prueban cosas que un test
de unidad no puede: que el `manifest.json` sea aceptado, que `host_permissions` alcance para
inyectar en `articulo.mercadolibre.com.ar`, y que el service worker corra.

- **T0** carga, manifest y URL por defecto del Motor
- **T1** lectura de ID, título y precio de la página de ML
- **T2** permisos de host + inyección real con `chrome.scripting`
- **T3** toma la sesión de la app, y ante un 401 la relee y reintenta sola
- **T4** alta de competidor: qué postea y qué avisa
- **T5** recaptura: avisa que actualizó y con qué precio anterior
- **T6** usuario de solo lectura (403)
- **T7** publicación sin Moneda Principal: avisa y no postea
- **T8** validaciones del formulario
- **T9** Motor apagado

## Límite conocido

Las páginas de ML son fixtures (`ml-fixture.html` y las de `extraccion.test.mjs`), armadas con
el markup de Andes que usa el PDP: `.ui-pdp-price__second-line`, `.andes-money-amount__fraction`,
`.andes-money-amount__cents`, `.andes-money-amount--previous`. Si ML rediseña el PDP, estas
pruebas siguen pasando y la captura real puede romperse igual. El chequeo final es abrir una
publicación de verdad y mirar que el precio que completa el popup sea el que se ve en pantalla.
