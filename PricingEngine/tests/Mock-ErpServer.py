"""Servidor HTTP mínimo para simular el GET que expone el ERP de un cliente: sirve un
único endpoint con una lista de productos usando nombres de campo DISTINTOS a los
canónicos del motor (a propósito, para poder probar el descubrimiento de campos y el
mapeo configurable de punta a punta, no un mapeo identidad). Si se le pasa un token
esperado, exige `Authorization: Bearer <token>` y devuelve 401 si falta o no coincide
-- así Run-PruebasErp.ps1 puede probar tanto el camino feliz como una ApiKeySaliente
mal configurada.

Uso: python Mock-ErpServer.py <puerto> [token-esperado]
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PRODUCTOS = [
    {
        "codigo_sku": "QA-ERP-PULL",
        "nombre": "Producto QA ERP (saliente)",
        "precio_compra": 2500.75,
        "iva_pct": 21,
        "impuestos_int": 0,
        "existencias": 42,
        "stock_min": 5,
        "stock_max": 200,
    }
]


class ErpHandler(BaseHTTPRequestHandler):
    expected_token = None

    def do_GET(self):
        if self.expected_token:
            auth = self.headers.get("Authorization", "")
            if auth != f"Bearer {self.expected_token}":
                self.send_response(401)
                self.end_headers()
                self.wfile.write(b'{"message":"no autorizado"}')
                return

        body = json.dumps({"productos": PRODUCTOS}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8090
    if len(sys.argv) > 2:
        ErpHandler.expected_token = sys.argv[2]
    server = HTTPServer(("localhost", port), ErpHandler)
    print(f"Mock ERP listening on :{port}", flush=True)
    server.serve_forever()
