// Prueba la lectura de la página de ML contra varios armados de PDP. Usa la función real de
// popup.js, no una copia.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

const AQUI = path.dirname(url.fileURLToPath(import.meta.url));
const EXT = path.join(AQUI, '..');

const fuente = fs.readFileSync(path.join(EXT, 'src/popup.js'), 'utf8');
const funcion = fuente.slice(fuente.indexOf('function extraerDatosDelArticulo'),
                             fuente.indexOf('document.addEventListener')).trim();

const CUOTAS = `<div class="ui-pdp-price__subtitles">
  <span class="andes-money-amount"><span class="andes-money-amount__fraction">15.833</span>
  <span class="andes-money-amount__cents">25</span></span> en 12 cuotas</div>`;

const casos = [
  {
    nombre: 'con descuento: precio tachado primero en el DOM',
    url: 'https://articulo.mercadolibre.com.ar/MLA-1234567890-zapatillas-_JM',
    html: `<h1 class="ui-pdp-title">Zapatillas Nike</h1>
      <s class="andes-money-amount andes-money-amount--previous">
        <span class="andes-money-amount__fraction">299.999</span></s>
      <div class="ui-pdp-price__second-line"><span class="andes-money-amount" data-testid="price-part">
        <span class="andes-money-amount__fraction">189.999</span>
        <span class="andes-money-amount__cents">99</span></span></div>${CUOTAS}`,
    espera: { meliItemId: 'MLA1234567890', titulo: 'Zapatillas Nike', precio: 189999.99 }
  },
  {
    nombre: 'sin descuento, sin centavos',
    url: 'https://articulo.mercadolibre.com.ar/MLA-987654321-mochila-_JM',
    html: `<h1>Mochila Urbana</h1><div class="ui-pdp-price__second-line">
      <span class="andes-money-amount"><span class="andes-money-amount__fraction">150.000</span>
      </span></div>${CUOTAS}`,
    espera: { meliItemId: 'MLA987654321', titulo: 'Mochila Urbana', precio: 150000 }
  },
  {
    nombre: 'las cuotas no pueden ganarle al precio',
    url: 'https://articulo.mercadolibre.com.ar/MLA-555000111-auricular-_JM',
    html: `<h1>Auriculares</h1>${CUOTAS}<div class="ui-pdp-price__second-line">
      <span class="andes-money-amount"><span class="andes-money-amount__fraction">190.000</span>
      </span></div>`,
    espera: { precio: 190000 }
  },
  {
    nombre: 'JSON-LD le gana a lo que se ve en pantalla',
    url: 'https://articulo.mercadolibre.com.ar/MLA-444333222-tv-_JM',
    html: `<script type="application/ld+json">
      {"@type":"Product","name":"TV","offers":{"@type":"Offer","price":"88999.50","priceCurrency":"ARS"}}
      </script><h1>Smart TV 50</h1><span class="andes-money-amount">
      <span class="andes-money-amount__fraction">99.999</span></span>`,
    espera: { precio: 88999.5 }
  },
  {
    nombre: 'meta itemprop cuando no hay JSON-LD',
    url: 'https://articulo.mercadolibre.com.ar/MLA-111222333-teclado-_JM',
    html: `<meta itemprop="price" content="34500.00"><h1>Teclado</h1>`,
    espera: { precio: 34500 }
  },
  {
    nombre: 'markup viejo: solo la fracción suelta',
    url: 'https://articulo.mercadolibre.com.ar/MLA-777888999-cafetera-_JM',
    html: `<h1>Cafetera</h1><span class="price-tag"><span class="andes-money-amount__fraction">72.500</span></span>`,
    espera: { precio: 72500 }
  },
  {
    nombre: 'el texto para lectores de pantalla no ensucia el precio',
    url: 'https://articulo.mercadolibre.com.ar/MLA-121212121-heladera-_JM',
    html: `<h1>Heladera</h1><div class="ui-pdp-price__second-line"><span class="andes-money-amount">
      <span class="andes-visually-hidden">1299999 pesos con 90 centavos</span>
      <span class="andes-money-amount__fraction">1.299.999</span>
      <span class="andes-money-amount__cents">90</span></span></div>`,
    espera: { precio: 1299999.9 }
  },
  {
    nombre: 'ID sin guión en la URL',
    url: 'https://articulo.mercadolibre.com.ar/MLA1234500000-monitor-_JM',
    html: `<h1>Monitor</h1><span class="andes-money-amount__fraction">210.000</span>`,
    espera: { meliItemId: 'MLA1234500000', precio: 210000 }
  },
  {
    nombre: 'otro sitio de ML (México)',
    url: 'https://articulo.mercadolibre.com.mx/MLM-909090909-licuadora-_JM',
    html: `<h1>Licuadora</h1><span class="andes-money-amount__fraction">1.299</span>`,
    espera: { meliItemId: 'MLM909090909', precio: 1299 }
  },
  {
    nombre: 'una página que no es un artículo devuelve null',
    url: 'https://listado.mercadolibre.com.ar/zapatillas',
    html: `<h1>Zapatillas</h1><span class="andes-money-amount__fraction">1.000</span>`,
    espera: null
  },
  {
    nombre: 'artículo sin precio visible: precio null, no 0 ni basura',
    url: 'https://articulo.mercadolibre.com.ar/MLA-333333333-usado-_JM',
    html: `<h1>Producto pausado</h1><p>Publicación pausada</p>`,
    espera: { meliItemId: 'MLA333333333', precio: null }
  }
];

const navegador = await chromium.launch();
const ctx = await navegador.newContext();
await ctx.route('**://*.mercadolibre.com*/**', (ruta, pedido) => {
  const caso = casos.find((c) => c.url === pedido.url());
  ruta.fulfill({ contentType: 'text/html; charset=utf-8', body: `<!doctype html><meta charset="utf-8">${caso.html}` });
});

const pagina = await ctx.newPage();
let fallas = 0;
for (const caso of casos) {
  await pagina.goto(caso.url);
  const obtenido = await pagina.evaluate(`(${funcion})()`);
  const esperado = caso.espera;
  const mal = esperado === null
    ? obtenido !== null
    : Object.entries(esperado).some(([k, v]) => obtenido?.[k] !== v);
  if (mal) { fallas++; console.log(`  FALLA ${caso.nombre}\n        esperaba ${JSON.stringify(esperado)}\n        obtuvo   ${JSON.stringify(obtenido)}`); }
  else console.log(`  PASA  ${caso.nombre}${esperado?.precio !== undefined ? ` — precio ${obtenido?.precio}` : ''}`);
}
await navegador.close();
console.log(`\n${casos.length - fallas}/${casos.length} pasaron`);
process.exit(fallas ? 1 : 0);
