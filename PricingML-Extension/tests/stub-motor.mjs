// Motor de mentira: responde lo mismo que PricingApi para los dos endpoints que usa el popup,
// con el camelCase que emite System.Text.Json en minimal APIs.
import http from 'node:http';

export const recibido = [];
let modo = { publicaciones: 'ok', post: 'alta' };
export function configurar(m) { Object.assign(modo, m); }

const PUBLICACIONES = [
  { publicacionID: 7, meliItemID: 'MLA111111111', titulo: 'Zapatillas Runner', sku: 'SKU-7', precioActual: 150000.0, monedaPrincipalID: 1 },
  { publicacionID: 9, meliItemID: 'MLA222222222', titulo: 'Mochila Urbana', sku: 'SKU-9', precioActual: 48000.0, monedaPrincipalID: null }
];

const APP_HTML = `<!doctype html><meta charset="utf-8"><title>PricingML (falso)</title>
<script>localStorage.setItem('pricingUiToken', 'TOKEN-NUEVO');
        localStorage.setItem('pricingUiUsuario', JSON.stringify({rol:'ADMIN'}));</script>
<h1>PricingML de mentira</h1>`;

function cors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin ?? '*');
  res.setHeader('Access-Control-Allow-Headers', '*');
  res.setHeader('Access-Control-Allow-Methods', '*');
}

export const server = http.createServer(async (req, res) => {
  cors(req, res);
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }

  const url = new URL(req.url, 'http://localhost');
  const token = (req.headers.authorization ?? '').replace('Bearer ', '');
  let cuerpo = '';
  for await (const trozo of req) cuerpo += trozo;
  recibido.push({ metodo: req.method, ruta: url.pathname, token, cuerpo: cuerpo ? JSON.parse(cuerpo) : null });

  const responder = (codigo, datos) => {
    res.writeHead(codigo, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(datos));
  };

  if (url.pathname === '/app') { res.writeHead(200, { 'Content-Type': 'text/html' }); return res.end(APP_HTML); }

  // El token viejo vence: es lo que dispara el camino de releer la sesión y reintentar.
  if (token !== 'TOKEN-NUEVO') return responder(401, { message: 'Sesión inválida' });

  if (url.pathname === '/api/marketplace/ml/publicaciones') {
    if (modo.publicaciones === 'vacio') return responder(200, []);
    if (modo.publicaciones === 'error') return responder(500, { message: 'Explotó el Motor' });
    return responder(200, PUBLICACIONES);
  }

  if (req.method === 'POST' && /\/api\/marketplace\/ml\/publicaciones\/\d+\/competidores$/.test(url.pathname)) {
    if (modo.post === 'lectura') return responder(403, { message: 'Solo lectura' });
    if (modo.post === 'invalido') return responder(400, { message: 'Ingresá un ID o un link de MercadoLibre.' });
    if (modo.post === 'actualizacion') return responder(200, { vinculoID: 42, esNuevo: false, precioAnterior: 189999.99 });
    return responder(201, { vinculoID: 42, esNuevo: true, precioAnterior: null });
  }

  responder(404, { message: 'no existe' });
});
