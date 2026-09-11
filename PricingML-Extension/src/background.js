// Service Worker de la extensión. Solo deja la URL del Motor por defecto en la primera
// instalación; el token lo pega el usuario desde Configuración en el popup.
//
// La lectura de la página de MercadoLibre la hace el popup con chrome.scripting cuando se
// abre (ver popup.js), así que acá no hace falta inyectar nada por cada pestaña.

chrome.runtime.onInstalled.addListener(async () => {
    const { apiUrl } = await chrome.storage.local.get(['apiUrl']);
    if (!apiUrl) {
        await chrome.storage.local.set({ apiUrl: 'http://localhost:5000' });
    }
});
