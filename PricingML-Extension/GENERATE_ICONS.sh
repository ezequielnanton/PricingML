#!/bin/bash
# Generar iconos PNG desde SVG
# Requiere ImageMagick (apt-get install imagemagick)

if ! command -v convert &> /dev/null; then
    echo "ImageMagick no está instalado. Instalalo con:"
    echo "  Ubuntu/Debian: sudo apt-get install imagemagick"
    echo "  macOS: brew install imagemagick"
    exit 1
fi

cd "$(dirname "$0")/icons" || exit

# Generar PNGs desde SVG
convert -density 300 -resize 16x16 icon.svg -background none icon-16.png
convert -density 300 -resize 48x48 icon.svg -background none icon-48.png
convert -density 300 -resize 128x128 icon.svg -background none icon-128.png

echo "✓ Iconos generados exitosamente"
ls -lh icon-*.png
