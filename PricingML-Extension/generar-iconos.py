#!/usr/bin/env python3
"""Genera los PNG del icono de la extensión a partir del diseño de icons/icon.svg.

Se dibuja a mano en vez de rasterizar el SVG a propósito: así corre con Python pelado en
cualquier máquina (Windows incluido) y no hace falta ImageMagick ni ninguna librería de
imágenes. Los PNG resultantes están commiteados, así que esto solo hace falta si se cambia
el diseño.

    python generar-iconos.py
"""

import struct
import zlib
from pathlib import Path

AZUL = (0x00, 0x66, 0xCC)
BLANCO = (0xFF, 0xFF, 0xFF)

# Mismas coordenadas que icon.svg, en su viewBox de 128x128.
LADO_SVG = 128
RADIO_ESQUINA = 24
GROSOR_LINEA = 4
TENDENCIA = [(24, 80), (40, 60), (56, 70), (72, 40), (88, 50), (104, 30)]
PUNTOS = [(40, 60), (56, 70), (72, 40), (88, 50)]
RADIO_PUNTO = 3

# Cada píxel final se calcula promediando MUESTRAS x MUESTRAS puntos: es el antialiasing.
MUESTRAS = 4

TAMANOS = (16, 48, 128)


def dentro_del_fondo(x, y):
    """El rect redondeado del SVG, en coordenadas del viewBox."""
    if not (0 <= x <= LADO_SVG and 0 <= y <= LADO_SVG):
        return False
    r = RADIO_ESQUINA
    cx = min(max(x, r), LADO_SVG - r)
    cy = min(max(y, r), LADO_SVG - r)
    # Solo las cuatro esquinas quedan fuera del rectángulo interior; ahí manda el radio.
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def distancia_a_segmento(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    largo = dx * dx + dy * dy
    t = 0.0 if largo == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / largo))
    return ((px - (ax + t * dx)) ** 2 + (py - (ay + t * dy)) ** 2) ** 0.5


def en_la_tendencia(x, y):
    """La polilínea blanca, con puntas redondeadas (stroke-linecap='round')."""
    mitad = GROSOR_LINEA / 2
    for (ax, ay), (bx, by) in zip(TENDENCIA, TENDENCIA[1:]):
        if distancia_a_segmento(x, y, ax, ay, bx, by) <= mitad:
            return True
    return any((x - cx) ** 2 + (y - cy) ** 2 <= RADIO_PUNTO ** 2 for cx, cy in PUNTOS)


def color_en(x, y):
    if en_la_tendencia(x, y):
        return BLANCO + (255,)
    if dentro_del_fondo(x, y):
        return AZUL + (255,)
    return (0, 0, 0, 0)


def dibujar(lado):
    """Devuelve las filas RGBA del icono de `lado` píxeles."""
    escala = LADO_SVG / lado
    paso = escala / MUESTRAS
    filas = []
    for py in range(lado):
        fila = bytearray()
        for px in range(lado):
            r = g = b = a = 0
            for sy in range(MUESTRAS):
                for sx in range(MUESTRAS):
                    x = (px * escala) + (sx + 0.5) * paso
                    y = (py * escala) + (sy + 0.5) * paso
                    cr, cg, cb, ca = color_en(x, y)
                    # Premultiplicado, para que el borde transparente no tire negro al mezclar.
                    r += cr * ca
                    g += cg * ca
                    b += cb * ca
                    a += ca
            if a == 0:
                fila += bytes(4)
            else:
                fila += bytes((round(r / a), round(g / a), round(b / a), round(a / (MUESTRAS ** 2))))
        filas.append(bytes(fila))
    return filas


def escribir_png(destino, filas):
    """PNG RGBA mínimo (IHDR/IDAT/IEND), sin filtros por fila."""
    lado = len(filas)
    crudo = b"".join(b"\x00" + fila for fila in filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    destino.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + bloque(b"IHDR", struct.pack(">IIBBBBB", lado, lado, 8, 6, 0, 0, 0))
        + bloque(b"IDAT", zlib.compress(crudo, 9))
        + bloque(b"IEND", b""))


def main():
    carpeta = Path(__file__).resolve().parent / "icons"
    carpeta.mkdir(exist_ok=True)
    for lado in TAMANOS:
        destino = carpeta / f"icon-{lado}.png"
        escribir_png(destino, dibujar(lado))
        print(f"  {destino.name}: {destino.stat().st_size} bytes")


if __name__ == "__main__":
    main()
