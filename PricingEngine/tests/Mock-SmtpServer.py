"""Servidor SMTP mínimo para pruebas (sin auth, sin TLS): entiende lo justo del
protocolo (EHLO/HELO, MAIL FROM, RCPT TO, DATA, QUIT) para que System.Net.Mail.
SmtpClient complete un envío real por socket contra localhost. Cada mensaje recibido
se imprime completo por stdout -- Run-PruebasLogin.ps1 lo redirige a un archivo y
extrae el link de "olvidé mi contraseña" del cuerpo (base64, texto/html) para poder
seguir el flujo de reset de punta a punta sin un proveedor de email real.

Uso: python Mock-SmtpServer.py [puerto]  (default 1025)
"""
import socketserver
import sys


class SmtpHandler(socketserver.StreamRequestHandler):
    def sendline(self, text):
        self.wfile.write((text + "\r\n").encode("utf-8"))

    def handle(self):
        self.sendline("220 mock.local ESMTP mock")
        data_mode = False
        buffer = []
        while True:
            line = self.rfile.readline()
            if not line:
                break
            text = line.decode("utf-8", errors="replace").rstrip("\r\n")

            if data_mode:
                if text == ".":
                    data_mode = False
                    msg = "\n".join(buffer)
                    print("----- MENSAJE RECIBIDO -----")
                    print(msg)
                    print("----- FIN MENSAJE -----", flush=True)
                    buffer = []
                    self.sendline("250 OK: message queued")
                    continue
                buffer.append(text)
                continue

            upper = text.upper()
            if upper.startswith("EHLO") or upper.startswith("HELO"):
                self.sendline("250-mock.local greets you")
                self.sendline("250 OK")
            elif upper.startswith("MAIL FROM"):
                self.sendline("250 OK")
            elif upper.startswith("RCPT TO"):
                self.sendline("250 OK")
            elif upper.startswith("DATA"):
                data_mode = True
                self.sendline("354 Start mail input; end with <CRLF>.<CRLF>")
            elif upper.startswith("QUIT"):
                self.sendline("221 Bye")
                break
            elif upper.startswith("RSET"):
                self.sendline("250 OK")
            else:
                self.sendline("250 OK")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 1025
    server = socketserver.ThreadingTCPServer(("localhost", port), SmtpHandler)
    print(f"Mock SMTP listening on :{port}", flush=True)
    server.serve_forever()
