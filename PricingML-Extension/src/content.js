// content.js - Inyectado en páginas de MercadoLibre
// Detecta datos del artículo cuando el usuario abre el popup

function extraerDatosDelArticulo() {
    // Detectar si estamos en una página de artículo de ML
    const urlMatch = window.location.href.match(/articulo\.mercadolibre\.com[^/]*\/([A-Z]{3}-?\d+)/);
    if (!urlMatch) return null;

    const meliItemId = urlMatch[1].replace('-', '');

    // Extraer datos del DOM (estructura típica de ML)
    const titulo = document.querySelector('h1, [data-testid="title"]')?.textContent?.trim() || '';

    const precioTexto = document.querySelector('[data-testid="price"]')?.textContent ||
                       document.querySelector('.price-tag')?.textContent ||
                       '';
    const precio = extraerNumero(precioTexto);

    const vendedorElem = document.querySelector('[data-testid="seller-name"]') ||
                        document.querySelector('.ui-seller');
    const vendedor = vendedorElem?.textContent?.trim() || '';

    if (!meliItemId || !titulo || !precio) {
        return null;
    }

    return {
        meliItemId,
        titulo,
        precio,
        vendedor
    };
}

function extraerNumero(texto) {
    const num = texto.match(/[\d.,]+/);
    if (!num) return 0;
    // Convertir punto o coma a separador decimal
    return parseFloat(num[0].replace(/\./g, '').replace(',', '.'));
}

// Cuando se abre el popup, enviar los datos detectados
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'getPageData') {
        const datos = extraerDatosDelArticulo();
        sendResponse({ datos });
    }
});

// Intentar detectar datos del artículo cuando se carga la página
window.addEventListener('load', () => {
    const datos = extraerDatosDelArticulo();
    if (datos) {
        // Guardar en sesión para que el popup lo encuentre
        chrome.storage.session.set({ detectedData: datos });
    }
});
