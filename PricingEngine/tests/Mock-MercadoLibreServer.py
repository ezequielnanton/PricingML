"""Servidor HTTP mínimo que simula lo justo de la API real de MercadoLibre para que
Run-PruebasMercadoLibre.ps1 pueda probar de punta a punta: OAuth (POST /oauth/token,
ambos grant_type), precio/estado/detalle de un item (GET/PUT /items/{id}, usado tanto
para sincronizar como para resolver un competidor vinculado a mano por ID/link),
competencia de catálogo (GET /items/{id}/price_to_win) y ventas históricas
(GET /orders/search). Los datos son fijos y deterministas para los SKUs de prueba
`MLA-QA-*` -- no intenta imitar el resto de la API real de ML, solo lo que
MercadoLibreSyncService.cs realmente llama. No simula GET /sites/{site}/search porque
la API real ya no lo permite para apps de terceros (devuelve 403 "forbidden").

Uso: python Mock-MercadoLibreServer.py <puerto>
"""
import json
import sys
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs, parse_qsl

ITEMS = {
    "MLA-QA-ML-CATALOGO": {"price": 10500, "status": "active", "title": "Catálogo QA", "seller_id": 111111},
    "MLA-QA-ML-NOCAT": {"price": 5200, "status": "active", "title": "No Catálogo QA", "seller_id": 111111},
    "MLA-QA-ML-COMPETIDOR-MANUAL": {"price": 4800, "status": "active", "title": "Competidor Manual QA", "seller_id": 123456},
    "MLA-QA-ML-RECHAZA": {"price": 999, "status": "active", "title": "Rechaza QA", "seller_id": 111111},
}

PRICE_TO_WIN = {
    "MLA-QA-ML-CATALOGO": {
        "price_to_win": 9800,
        "winner": {"item_id": "MLA-QA-ML-COMPETIDOR-CATALOGO"},
        "current_status": "losing",
    }
}


def _json(handler, status, payload):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


class MlHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path.endswith("/price_to_win"):
            item_id = path.split("/items/")[1].split("/")[0]
            data = PRICE_TO_WIN.get(item_id)
            if data is None:
                _json(self, 404, {"message": "sin price_to_win para este item"})
            else:
                _json(self, 200, data)
            return

        if path.startswith("/items/"):
            item_id = path[len("/items/"):]
            data = dict(ITEMS.get(item_id, {"price": 1000, "status": "active"}))
            data.setdefault("id", item_id)
            _json(self, 200, data)
            return

        if path == "/orders/search":
            now = datetime.now()

            def orden(dias_atras, cantidad, item_id="MLA-QA-ML-CATALOGO"):
                fecha = (now - timedelta(days=dias_atras)).strftime("%Y-%m-%dT%H:%M:%S.000")
                return {
                    "date_created": fecha,
                    "order_items": [{"item": {"id": item_id}, "quantity": cantidad}],
                }


            # #ventanasDeterministas: distribución elegida para que las sumas de
            # 7D/15D/30D/60D/90D den valores exactos y verificables:
            # 7D=5, 15D=10, 30D=12, 60D=16, 90D=22 (ver QA-MercadoLibre.md).
            resultados = [
                orden(0, 1), orden(0, 1),   # hoy: 2
                orden(5, 3),                # 5 días: +3 (7D)
                orden(10, 5),               # 10 días: +5 (15D)
                orden(20, 2),               # 20 días: +2 (30D)
                orden(40, 4),               # 40 días: +4 (60D)
                orden(70, 6),               # 70 días: +6 (90D)
            ]
            _json(self, 200, {"results": resultados, "paging": {"total": len(resultados)}})
            return

        _json(self, 404, {"message": "ruta no simulada"})

    def do_PUT(self):
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw)
        except Exception:
            body = {}

        if path.startswith("/items/"):
            item_id = path[len("/items/"):]
            if item_id == "MLA-QA-ML-RECHAZA":
                _json(self, 400, {"message": "precio rechazado por ML (mock)"})
                return
            _json(self, 200, {"id": item_id, "price": body.get("price")})
            return

        _json(self, 404, {"message": "ruta no simulada"})

    def do_POST(self):
        if self.path != "/oauth/token":
            _json(self, 404, {"message": "ruta no simulada"})
            return

        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length).decode("utf-8") if length else ""
        form = dict(parse_qsl(raw))
        grant_type = form.get("grant_type")

        if grant_type == "authorization_code":
            code = form.get("code", "")
            if code == "codigo-invalido-mock":
                _json(self, 400, {"message": "código de autorización inválido (mock)"})
                return
            _json(self, 200, {
                "access_token": "MOCK-ACCESS-OAUTH",
                "refresh_token": "MOCK-REFRESH-OAUTH",
                "expires_in": 21600,
                "user_id": 999888777,
            })
            return

        if grant_type == "refresh_token":
            _json(self, 200, {
                "access_token": "MOCK-ACCESS-REFRESHED",
                "refresh_token": "MOCK-REFRESH-REFRESHED",
                "expires_in": 21600,
            })
            return

        _json(self, 400, {"message": "grant_type no soportado (mock)"})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8091
    server = HTTPServer(("localhost", port), MlHandler)
    print(f"Mock MercadoLibre listening on :{port}", flush=True)
    server.serve_forever()
