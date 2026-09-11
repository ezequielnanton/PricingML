# PricingML Chrome Extension

Extensión de Chrome que permite capturar competidores de MercadoLibre y sincronizar precios automáticamente en PricingML.

## Instalación para Desarrollo

1. **Clonar/descargar** esta carpeta a tu máquina
2. Abrir Chrome y navegar a `chrome://extensions/`
3. Activar **"Modo de desarrollador"** (esquina superior derecha)
4. Hacer clic en **"Cargar extensión sin empaquetar"**
5. Seleccionar la carpeta `PricingML-Extension/`

## Uso

1. **Navegar a MercadoLibre** (https://articulo.mercadolibre.com.ar/...)
2. **Abrir cualquier producto** que sea competencia
3. **Clic en el icono de la extensión** (esquina superior derecha del navegador)
4. **Verificar datos** pre-llenados automáticamente:
   - ID de MercadoLibre
   - Título
   - Precio
5. **Opcionalmente editar** vendedor u otros datos
6. **Clic "Guardar a PricingML"** → vincula automáticamente

## Configuración

La extensión requiere que **PricingML Motor esté corriendo** en tu máquina:
- Por defecto: `http://localhost:5000`
- Si Motor está en otra IP/puerto, la extensión lo detecta automáticamente

## Estructura

```
PricingML-Extension/
├── manifest.json          # Configuración de la extensión (Manifest V3)
├── README.md              # Este archivo
├── src/
│   ├── popup.html        # UI del popup (formulario)
│   ├── popup.js          # Lógica del popup (envía datos a API)
│   ├── content.js        # Inyectado en ML: extrae datos del DOM
│   └── background.js     # Service Worker: eventos globales
└── icons/                # Iconos de la extensión (16, 48, 128px)
```

## Flujo Técnico

```
Usuario en ML
    ↓
Clic en icono de extensión
    ↓
content.js extrae: ID, título, precio de ML
    ↓
popup.html muestra el formulario pre-llenado
    ↓
Usuario revisa/edita y clic "Guardar"
    ↓
popup.js envía POST a http://localhost:5000/api/competidores/capturado
    ↓
Motor API vincula automáticamente (búsqueda por GTIN)
    ↓
Motor inserta snapshot de precio
    ↓
Popup muestra "✓ Vinculado correctamente"
```

## Notas

- La extensión funciona **solo en Chrome/Edge** (Manifest V3)
- Requiere que **PricingML Motor esté corriendo** en http://localhost:5000
- Los datos capturados se envían SOLO al Motor (tu red privada, no a internet)
- El motor debe estar en la misma red para que funcione

## Troubleshooting

**"Error de conexión"** → Verificar que Motor esté corriendo en http://localhost:5000/swagger

**"No se encontró un producto propio"** → El título del competidor no coincide con ninguno de tus productos. Agregarlos primero en "Administración > Productos"

**"ID de ML vacío"** → Abrir una página de artículo válida de MercadoLibre
