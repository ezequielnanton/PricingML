# Captura Automática de Competidores - Extensión Chrome

**Problema**: MercadoLibre bloqueó acceso a APIs de búsqueda y lectura de ítems ajenos. Imposible automatizar captura de competidores de forma segura.

**Solución**: Extensión Chrome que permite al usuario capturar competidores **desde el navegador** (datos públicos visibles) mientras navega MercadoLibre, enviándolos automáticamente a PricingML para vincularlos y sincronizar precios.

---

## Instalación

### Paso 1: Descargar la Extensión

La extensión está en: `PricingML-Extension/`

```bash
# En tu carpeta de desarrollo
ls -la PricingML-Extension/
# manifest.json
# src/
# icons/
# README.md
```

### Paso 2: Generar Iconos (Opcional)

Los iconos PNG se generan automáticamente desde SVG:

```bash
cd PricingML-Extension/
bash GENERATE_ICONS.sh
```

Si no tienes ImageMagick, crea los iconos de forma manual:
- icon-16.png (16x16 píxeles)
- icon-48.png (48x48 píxeles)
- icon-128.png (128x128 píxeles)

O usa la versión SVG (Chrome la acepta).

### Paso 3: Cargar en Chrome

1. Abrir **Chrome** → Menú ≡ → **Configuración** → **Extensiones** (o ir a `chrome://extensions/`)
2. Activar **"Modo de Desarrollador"** (esquina superior derecha)
3. Clic en **"Cargar extensión sin empaquetar"**
4. Seleccionar la carpeta `PricingML-Extension/`
5. La extensión aparecerá en tu barra de herramientas

✓ **Instalada exitosamente**. El icono es azul con un gráfico de precios.

---

## Uso Diario

### Flujo Simple

```
1. Usuario navega MercadoLibre
   ↓
2. Ve un producto competidor (Nike Air Max 90 - $15999)
   ↓
3. Clic en icono de la extensión (azul, esquina superior derecha)
   ↓
4. Popup muestra datos pre-llenados:
   - ID de ML:     MLA123456789
   - Título:       Nike Air Max 90 Negro Talla 43
   - Precio:       15999
   - Moneda:       ARS
   - Vendedor:     otro_store (opcional)
   ↓
5. Usuario revisa/edita si es necesario
   ↓
6. Clic "Guardar a PricingML"
   ↓
7. Motor recibe datos y busca en la BD
   ↓
8. Si encuentra producto similar por GTIN/título:
   - Vincula automáticamente
   - Inserta snapshot de precio
   - Muestra: "✓ Competidor vinculado"
   ↓
9. Popup se cierra automáticamente
```

### Ejemplo Real

**Escenario**: Eres vendedor de zapatillas en MercadoLibre. Tu producto es "Nike Air Max 90 Negro Talla 43" ($16500). Ves que un competidor lo vende a $15999.

**Pasos**:
1. Abrir artículo del competidor en ML
2. Clic en icono azul de PricingML
3. El popup muestra:
   ```
   ID: MLA1234567890
   Título: Nike Air Max 90 Negro Talla 43
   Precio: 15999
   Moneda: ARS
   Vendedor: otro_store
   ```
4. Revisar que sea correcto (lo está)
5. Clic "Guardar a PricingML"
6. Motor busca "Nike Air Max 90" en tus productos
7. Encuentra tu publicación (`ProductoID=42`)
8. Vincula automáticamente
9. Inserta snapshot: `CompetidorItemID=MLA1234567890`, `Precio=15999`
10. Motor recalcula tu precio de venta

**Resultado**: Tu recomendación de precios ahora considera este competidor en $15999. Si tu margen lo permite, puede sugerir bajar a $15750.

---

## Requisitos Técnicos

### En tu PC

- **Chrome 90+** (o Edge)
- **PricingML Motor corriendo** en `http://localhost:5000`
  - Verificar en: http://localhost:5000/swagger
  - Si el Motor no responde, la extensión muestra error

### En MercadoLibre

- Extensión funciona en:
  - https://articulo.mercadolibre.com.ar/*
  - https://articulo.mercadolibre.com.mx/*
  - https://articulo.mercadolibre.com.br/*
  - (cualquier país con dominio .com.xx)

---

## Configuración Avanzada

### Motor en otra IP/Puerto

Si tu Motor corre en `192.168.1.50:5000` en lugar de `localhost:5000`:

1. Abrir consola de Chrome (F12)
2. Ir a **Application** → **Storage** → **Sync**
3. Buscar `apiUrl`
4. Editar a `http://192.168.1.50:5000`

O desde JavaScript (consola):
```javascript
chrome.storage.sync.set({ apiUrl: 'http://192.168.1.50:5000' });
```

---

## Estructura de Archivos

```
PricingML-Extension/
│
├── manifest.json              ← Configuración de la extensión
│                                (versión 3, Chrome moderno)
│
├── src/
│   ├── popup.html             ← Interfaz del popup (formulario)
│   ├── popup.js               ← Lógica: envía datos a API
│   ├── content.js             ← Extrae datos del DOM de ML
│   └── background.js          ← Service Worker de eventos globales
│
├── icons/
│   ├── icon.svg               ← Icono en formato vector
│   ├── icon-16.png            ← Pequeño (barra de herramientas)
│   ├── icon-48.png            ← Mediano
│   └── icon-128.png           ← Grande (tienda de Chrome)
│
├── README.md                  ← Para desarrolladores
├── GENERATE_ICONS.sh          ← Script para generar PNGs desde SVG
│
└── (carpeta raíz)
    └── COMPETIDORES-EXTENSION.md  ← Este archivo (guía de usuario)
```

---

## Cómo Funciona Internamente

### 1. Inyección en MercadoLibre

Cuando navegas a `articulo.mercadolibre.com.ar/MLA-123456-...`, Chrome inyecta automáticamente `content.js` que:

```javascript
// Extrae del DOM:
- URL → ID de ML (MLA123456)
- <h1> o [data-testid="title"] → Título
- [data-testid="price"] → Precio
- [data-testid="seller-name"] → Vendedor

// Guarda en sesión del navegador para que popup lo encuentre
chrome.storage.session.set({ detectedData: {...} });
```

### 2. Popup Muestra Datos

Cuando clic en el icono:
1. `popup.html` carga
2. `popup.js` busca datos en sesión
3. Si existen, pre-llena los campos
4. Usuario edita si es necesario

### 3. Envío a API

```javascript
POST http://localhost:5000/api/competidores/capturado
{
  "meliItemId": "MLA123456789",
  "titulo": "Nike Air Max 90 Negro",
  "precio": 15999,
  "monedaId": 1,
  "vendedor": "otro_store"
}
```

### 4. Procesamiento en Motor

Motor recibe datos en `CompetidorCapturaService.CapturarCompetidorAsync()`:

```csharp
// 1. Valida datos
// 2. Busca GTIN en título
// 3. Si no hay GTIN, búsqueda fuzzy por título
// 4. Si encuentra producto propio:
//    - Vincula en PublicacionCompetidoresManual
//    - Inserta snapshot en CompetenciaSnapshot
//    - Retorna confirmación

Response:
{
  "vinculado": true,
  "publicacionId": 42,
  "productoId": 5,
  "productoNombre": "Nike Air Max 90",
  "mensaje": "✓ Competidor vinculado correctamente"
}
```

### 5. Confirmación en Popup

Popup muestra:
```
✓ Competidor vinculado exitosamente
Producto: Nike Air Max 90
```

Popup se cierra automáticamente después de 2 segundos.

---

## Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| "Error de conexión" | Motor no está corriendo | Verificar http://localhost:5000/swagger |
| "Faltan datos requeridos" | Página no es de artículo de ML | Abrir un artículo válido de ML |
| "No se encontró un producto propio" | Título no coincide con ninguno tuyo | Crear el producto en PricingML primero |
| Datos vacíos en popup | content.js no inyectó | Recargar página de ML (F5) |
| Extensión no aparece | Archivo manifest.json corrupto | Verificar formato JSON, recargar en chrome://extensions |

---

## Seguridad

✅ **Datos públicos**: Solo captura lo que ves en el navegador (título, precio público)

✅ **Sin credenciales**: La extensión NUNCA requiere login en ML

✅ **Red privada**: Datos se envían al Motor (tu red local), no a servidores externos

✅ **Manifest V3**: Cumple estándares de seguridad de Chrome modernos

⚠️ **Nota**: La extensión depende de que **PricingML Motor esté en http/no https** para desarrollo. En producción, cambiar a HTTPS con certificado válido.

---

## Próximos Pasos

1. **Instalar extensión** (pasos arriba)
2. **Navegar a MercadoLibre**
3. **Capturar 1-2 competidores** para probar
4. **Verificar en PricingML**:
   - Ir a "Administración" → "Publicaciones"
   - Abrir un producto
   - Ver sección "Competidores Manuales"
   - Debe mostrar los que capturaste

5. **Motor recalcula precios** (cada sync)

---

## Limitaciones y Notas

- ❌ Extensión NO scraptea automáticamente (requiere clic manual del usuario)
- ❌ No funciona sin Motor corriendo
- ✓ Legal y seguro (datos públicos, navegador legítimo)
- ✓ Sincronización manual pero rápida (clic y listo)
- ✓ Escalable a múltiples competidores (1 o 100, mismo flujo)

---

## Contacto / Soporte

Si la extensión no funciona:

1. Verificar que Motor esté corriendo: http://localhost:5000/swagger
2. Abrir F12 → Console y buscar errores
3. Verificar manifest.json está bien formado
4. Recargar extensión en chrome://extensions

¿Preguntas? Revisar código en `PricingML-Extension/` con comentarios.
