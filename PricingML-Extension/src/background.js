// background.js - Service Worker para la extensión
// Maneja eventos globales y comunicación entre popup y content scripts

chrome.runtime.onInstalled.addListener(() => {
    // Configuración inicial
    chrome.storage.sync.get(['apiUrl'], (result) => {
        if (!result.apiUrl) {
            chrome.storage.sync.set({
                apiUrl: 'http://localhost:5000'
            });
        }
    });
});

// Inyectar content.js en páginas de MercadoLibre
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    if (changeInfo.status === 'complete' &&
        /articulo\.mercadolibre\.com/.test(tab.url)) {
        chrome.scripting.executeScript({
            target: { tabId },
            files: ['src/content.js']
        });
    }
});
