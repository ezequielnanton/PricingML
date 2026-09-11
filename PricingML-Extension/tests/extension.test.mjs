import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

const AQUI = path.dirname(url.fileURLToPath(import.meta.url));
const EXT = path.join(AQUI, '..');
import os from 'node:os';
import { server, recibido, configurar } from './stub-motor.mjs';

const URL_ML = 'https://articulo.mercadolibre.com.ar/MLA-1234567890-zapatillas-nike-air-max-90-_JM';

const resultados = [];
const ok = (n, d = '') => { resultados.push(['PASA', n, d]); console.log(`  PASA  ${n}${d ? ' — ' + d : ''}`); };
const falla = (n, d = '') => { resultados.push(['FALLA', n, d]); console.log(`  FALLA ${n}${d ? ' — ' + d : ''}`); };
const chequear = (cond, n, d = '') => (cond ? ok(n, d) : falla(n, d));

const esperarEstado = async (popup, contiene, ms = 8000) => {
  await popup.waitForFunction(
    (t) => document.getElementById('status').textContent.includes(t), contiene, { timeout: ms }
  ).catch(() => {});
  return popup.locator('#status').textContent();
};

await new Promise((r) => server.listen(0, '127.0.0.1', r));
const PUERTO = server.address().port;
const API = `http://localhost:${PUERTO}`;
console.log(`Motor de mentira en ${API}`);

const perfil = fs.mkdtempSync(path.join(os.tmpdir(), 'perfil-'));
const ctx = await chromium.launchPersistentContext(perfil, {
  channel: 'chromium',
  headless: true,
  args: [`--disable-extensions-except=${EXT}`, `--load-extension=${EXT}`]
});

// ---------------------------------------------------------------- carga
let sw = ctx.serviceWorkers()[0] ?? await ctx.waitForEvent('serviceworker', { timeout: 15000 });
const extId = new URL(sw.url()).host;
chequear(!!extId, 'T0 la extensión carga en Chrome', `id ${extId}`);

const manifiesto = await sw.evaluate(() => chrome.runtime.getManifest());
chequear(manifiesto.name === 'PricingML Competitor Capture' && manifiesto.manifest_version === 3,
  'T0b el manifest se lee desde el navegador', `${manifiesto.name} v${manifiesto.version}`);

// El service worker instala la URL por defecto: se verifica que haya corrido de verdad.
await new Promise((r) => setTimeout(r, 500));
const guardadoInicial = await sw.evaluate(() => chrome.storage.local.get('apiUrl'));
chequear(guardadoInicial.apiUrl === 'http://localhost:5000',
  'T0c background.js deja la URL del Motor al instalar', JSON.stringify(guardadoInicial));
// El Motor de mentira escucha en un puerto libre cualquiera, así que no pisa al de verdad.
await sw.evaluate((api) => chrome.storage.local.set({ apiUrl: api }), API);

// ------------------------------------------------- T1: lectura de la página de ML
await ctx.route('**://*.mercadolibre.com.ar/**', (ruta) =>
  ruta.fulfill({ contentType: 'text/html; charset=utf-8', body: fs.readFileSync(path.join(AQUI, 'ml-fixture.html'), 'utf8') }));

const paginaMl = await ctx.newPage();
await paginaMl.goto(URL_ML);

const fuente = fs.readFileSync(path.join(EXT, 'src/popup.js'), 'utf8');
const funcion = fuente.slice(fuente.indexOf('function extraerDatosDelArticulo'),
                             fuente.indexOf('document.addEventListener')).trim();
const leido = await paginaMl.evaluate(`(${funcion})()`);
console.log('   leído de la página:', JSON.stringify(leido));

chequear(leido?.meliItemId === 'MLA1234567890', 'T1a saca el ID del item de la URL', leido?.meliItemId);
chequear(leido?.titulo === 'Zapatillas Nike Air Max 90 Hombre Original', 'T1b saca el título', leido?.titulo);
chequear(leido?.precio === 189999.99, 'T1c saca el precio VIGENTE (no el tachado)', String(leido?.precio));

// ------------------------------------------- T2: permisos de host + inyección real
const idPestanaMl = await sw.evaluate(async () => {
  const [t] = await chrome.tabs.query({ url: 'https://articulo.mercadolibre.com.ar/*' });
  return t?.id ?? null;
});
const inyectado = await sw.evaluate(async (tabId) => {
  try {
    const [r] = await chrome.scripting.executeScript({ target: { tabId }, func: () => document.title });
    return r.result;
  } catch (e) { return 'ERROR: ' + e.message; }
}, idPestanaMl);
chequear(typeof inyectado === 'string' && inyectado.includes('Nike'),
  'T2 host_permissions permiten inyectar en articulo.mercadolibre.com.ar', inyectado);

// ------------------------------------- T3: toma la sesión de la app y puebla el desplegable
const paginaApp = await ctx.newPage();
await paginaApp.goto(`${API}/app`);
// Token vencido guardado de una sesión anterior: obliga a pasar por el 401 y el reintento.
await sw.evaluate(() => chrome.storage.local.set({ authToken: 'TOKEN-VIEJO' }));
recibido.length = 0;

const popup = await ctx.newPage();
await popup.goto(`chrome-extension://${extId}/src/popup.html`);
await popup.waitForFunction(() => document.getElementById('publicacion').options.length > 1, null, { timeout: 10000 })
  .catch(() => {});

const opciones = await popup.locator('#publicacion option').allTextContents();
chequear(opciones.some((o) => o.includes('Zapatillas Runner (SKU-7)')),
  'T3a el desplegable trae las publicaciones propias', JSON.stringify(opciones));

const con401 = recibido.filter((r) => r.ruta === '/api/marketplace/ml/publicaciones');
chequear(con401.length === 2 && con401[0].token === 'TOKEN-VIEJO' && con401[1].token === 'TOKEN-NUEVO',
  'T3b ante un 401 relee la sesión de la app y reintenta sola',
  con401.map((r) => r.token).join(' → '));

await popup.selectOption('#publicacion', '7');
const pista = await popup.locator('#publicacionHint').textContent();
chequear(pista.includes('MLA111111111') && pista.includes('150000'), 'T3c muestra tu precio actual', pista);

// ------------------------------------------------------------- T4: alta
await popup.fill('#competidorItemId', 'MLA1234567890');
await popup.fill('#titulo', 'Zapatillas Nike Air Max 90 Hombre Original');
await popup.fill('#precio', '189999.99');
recibido.length = 0;
await popup.click('#btnGuardar');
let estado = await esperarEstado(popup, 'vinculado');
chequear(estado.includes('Competidor vinculado a "Zapatillas Runner"'), 'T4a avisa que dio de alta', estado);

const post = recibido.find((r) => r.metodo === 'POST');
chequear(post?.cuerpo?.competidorItemID === 'MLA1234567890' && post?.cuerpo?.precio === 189999.99
         && post?.cuerpo?.monedaID === 1,
  'T4b postea ID, precio con centavos y la moneda principal de esa publicación', JSON.stringify(post?.cuerpo));

// ------------------------------------------------------ T5: recaptura = actualización
configurar({ post: 'actualizacion' });
await popup.fill('#precio', '145000');
await popup.click('#btnGuardar');
estado = await esperarEstado(popup, 'actualizado');
chequear(estado.includes('antes 189999.99') && estado.includes('ahora 145000'),
  'T5 recapturar avisa que actualizó, con el precio anterior', estado);

// ------------------------------------------------------------- T6: 403 solo lectura
configurar({ post: 'lectura' });
await popup.click('#btnGuardar');
estado = await esperarEstado(popup, 'solo lectura');
chequear(estado.includes('rol ADMIN'), 'T6 un usuario de solo lectura recibe un mensaje claro', estado);

// ------------------------------------------- T7: publicación sin moneda principal
configurar({ post: 'alta' });
await popup.selectOption('#publicacion', '9');
recibido.length = 0;
await popup.click('#btnGuardar');
estado = await esperarEstado(popup, 'Moneda Principal');
chequear(estado.includes('Moneda Principal') && !recibido.some((r) => r.metodo === 'POST'),
  'T7 sin Moneda Principal avisa y no postea nada', estado);

// ------------------------------------------------------------- T8: validaciones
await popup.selectOption('#publicacion', '');
recibido.length = 0;
await popup.click('#btnGuardar');
await new Promise((r) => setTimeout(r, 300));
const bloqueado = await popup.evaluate(() => document.getElementById('publicacion').checkValidity());
chequear(bloqueado === false && !recibido.some((r) => r.metodo === 'POST'),
  'T8a sin publicación elegida el navegador frena el submit y no se postea nada',
  `checkValidity=${bloqueado}`);

await popup.selectOption('#publicacion', '7');
await popup.fill('#precio', '0');
await popup.click('#btnGuardar');
estado = await esperarEstado(popup, 'mayor a 0');
chequear(estado.includes('mayor a 0'), 'T8b rechaza precio 0', estado);

// --------------------------------------------------------- T9: Motor apagado
await popup.fill('#precio', '145000');
await new Promise((r) => server.close(r));
await popup.click('#btnGuardar');
estado = await esperarEstado(popup, 'No se pudo conectar');
chequear(estado.includes('No se pudo conectar con el Motor'), 'T9 Motor apagado: mensaje entendible', estado);

// ------------------------------------------------------------------ resumen
await ctx.close();
const fallas = resultados.filter(([e]) => e === 'FALLA');
console.log(`\n${resultados.length - fallas.length}/${resultados.length} pasaron`);
if (fallas.length) {
  console.log('FALLARON:');
  for (const [, n, d] of fallas) console.log(`  - ${n}: ${d}`);
}
process.exit(fallas.length ? 1 : 0);
