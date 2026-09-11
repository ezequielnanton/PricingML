const API_URL_DEFAULT = 'http://localhost:5000';

// Corre dentro de la pestaña de MercadoLibre vía chrome.scripting, así que tiene que ser
// autocontenida: no puede referenciar nada de este archivo.
function extraerDatosDelArticulo() {
    const enUrl = window.location.href.match(/articulo\.mercadolibre\.com[^/]*\/([A-Z]{3})-?(\d+)/);
    if (!enUrl) return null;

    const textoPrecio = document.querySelector('[data-testid="price"], .price-tag, .andes-money-amount__fraction')
        ?.textContent ?? '';
    const soloNumero = textoPrecio.match(/[\d.,]+/);

    return {
        meliItemId: `${enUrl[1]}${enUrl[2]}`,
        titulo: document.querySelector('h1, [data-testid="title"]')?.textContent?.trim() ?? '',
        // ML usa punto para los miles y coma para los decimales.
        precio: soloNumero ? Number.parseFloat(soloNumero[0].replace(/\./g, '').replace(',', '.')) : null
    };
}

document.addEventListener('DOMContentLoaded', async () => {
    const form = document.getElementById('competitorForm');
    const statusDiv = document.getElementById('status');
    const btnGuardar = document.getElementById('btnGuardar');
    const configPanel = document.getElementById('configPanel');
    const selectPublicacion = document.getElementById('publicacion');
    const publicacionHint = document.getElementById('publicacionHint');
    const inputApiUrl = document.getElementById('apiUrl');
    const inputToken = document.getElementById('authToken');

    let config = await leerConfig();
    let publicaciones = [];

    inputApiUrl.value = config.apiUrl;
    inputToken.value = config.authToken;

    document.getElementById('btnConfig').addEventListener('click', () => {
        configPanel.hidden = !configPanel.hidden;
    });

    document.getElementById('btnGuardarConfig').addEventListener('click', async () => {
        config = {
            apiUrl: (inputApiUrl.value.trim() || API_URL_DEFAULT).replace(/\/+$/, ''),
            authToken: inputToken.value.trim()
        };
        await chrome.storage.local.set(config);
        configPanel.hidden = true;
        await cargarPublicaciones();
    });

    await precargarDatosDetectados();
    await cargarPublicaciones();

    selectPublicacion.addEventListener('change', mostrarHintPublicacion);

    form.addEventListener('submit', async (event) => {
        event.preventDefault();

        const publicacionId = Number(selectPublicacion.value);
        const competidorItemID = document.getElementById('competidorItemId').value.trim();
        const competidorTitulo = document.getElementById('titulo').value.trim();
        const precio = Number.parseFloat(document.getElementById('precio').value);

        if (!publicacionId) {
            mostrarEstado('Elegí a qué publicación tuya le compite.', 'error');
            return;
        }
        if (!competidorItemID) {
            mostrarEstado('Falta el ID o el link del competidor.', 'error');
            return;
        }
        if (!Number.isFinite(precio) || precio <= 0) {
            mostrarEstado('El precio tiene que ser mayor a 0.', 'error');
            return;
        }

        const publicacion = publicaciones.find((p) => p.publicacionID === publicacionId);
        if (!publicacion?.monedaPrincipalID) {
            mostrarEstado(
                'Esa publicación no tiene Moneda Principal configurada. Configurala en PricingML antes de capturar competidores.',
                'error');
            return;
        }

        btnGuardar.disabled = true;
        mostrarEstado('Guardando...', 'loading');

        try {
            const respuesta = await pedir(
                `/api/marketplace/ml/publicaciones/${publicacionId}/competidores`,
                {
                    method: 'POST',
                    body: JSON.stringify({
                        competidorItemID,
                        competidorTitulo: competidorTitulo || null,
                        monedaID: publicacion.monedaPrincipalID,
                        precio
                    })
                });

            const datos = await respuesta.json().catch(() => ({}));

            if (!respuesta.ok) {
                mostrarEstado(mensajeDeError(respuesta.status, datos), 'error');
                return;
            }

            if (datos.esNuevo) {
                mostrarEstado(`Competidor vinculado a "${publicacion.titulo}".`, 'success');
            } else if (datos.precioAnterior != null) {
                mostrarEstado(
                    `Precio actualizado en "${publicacion.titulo}": antes ${datos.precioAnterior}, ahora ${precio}.`,
                    'success');
            } else {
                mostrarEstado(`Precio actualizado en "${publicacion.titulo}".`, 'success');
            }
        } catch (error) {
            mostrarEstado(mensajeDeFalloDeRed(error), 'error');
        } finally {
            btnGuardar.disabled = false;
        }
    });

    async function leerConfig() {
        const guardado = await chrome.storage.local.get(['apiUrl', 'authToken']);
        return {
            apiUrl: (guardado.apiUrl || API_URL_DEFAULT).replace(/\/+$/, ''),
            authToken: guardado.authToken || ''
        };
    }

    function pedir(ruta, opciones = {}) {
        return fetch(`${config.apiUrl}${ruta}`, {
            ...opciones,
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${config.authToken}`
            }
        });
    }

    // Se lee la pestaña en el momento de abrir el popup, en vez de que un content script deje
    // los datos guardados: chrome.storage.session no es escribible desde un content script sin
    // bajarle el nivel de acceso, y el dato guardado envejece si el usuario cambia de artículo.
    async function precargarDatosDetectados() {
        const [pestaña] = await chrome.tabs.query({ active: true, currentWindow: true });
        if (!pestaña?.id) return;

        let detectado = null;
        try {
            const [resultado] = await chrome.scripting.executeScript({
                target: { tabId: pestaña.id },
                func: extraerDatosDelArticulo
            });
            detectado = resultado?.result;
        } catch {
            // No es una pestaña donde se pueda inyectar (chrome://, otra web): se carga a mano.
            return;
        }

        if (!detectado) {
            document.getElementById('infoSection').textContent =
                'Abrí la página del competidor en MercadoLibre para que se completen los datos solos, o cargalos a mano.';
            return;
        }

        document.getElementById('competidorItemId').value = detectado.meliItemId ?? '';
        document.getElementById('titulo').value = detectado.titulo ?? '';
        document.getElementById('precio').value = detectado.precio ?? '';
    }

    async function cargarPublicaciones() {
        selectPublicacion.replaceChildren(opcion('', 'Cargando...'));
        publicacionHint.textContent = '';

        if (!config.authToken) {
            selectPublicacion.replaceChildren(opcion('', 'Sin token configurado'));
            mostrarEstado('Configurá la URL del Motor y tu token de sesión para empezar.', 'error');
            configPanel.hidden = false;
            return;
        }

        try {
            const respuesta = await pedir('/api/marketplace/ml/publicaciones');
            if (!respuesta.ok) {
                const datos = await respuesta.json().catch(() => ({}));
                selectPublicacion.replaceChildren(opcion('', 'No se pudieron cargar'));
                mostrarEstado(mensajeDeError(respuesta.status, datos), 'error');
                if (respuesta.status === 401) configPanel.hidden = false;
                return;
            }

            publicaciones = await respuesta.json();
            if (publicaciones.length === 0) {
                selectPublicacion.replaceChildren(opcion('', 'No tenés publicaciones activas'));
                mostrarEstado('No hay publicaciones activas en PricingML para vincular.', 'error');
                return;
            }

            selectPublicacion.replaceChildren(
                opcion('', 'Elegí una publicación'),
                ...publicaciones.map((p) => opcion(
                    String(p.publicacionID),
                    p.sku ? `${p.titulo} (${p.sku})` : p.titulo)));
            ocultarEstado();
        } catch (error) {
            selectPublicacion.replaceChildren(opcion('', 'No se pudieron cargar'));
            mostrarEstado(mensajeDeFalloDeRed(error), 'error');
        }
    }

    function mostrarHintPublicacion() {
        const publicacion = publicaciones.find((p) => p.publicacionID === Number(selectPublicacion.value));
        publicacionHint.textContent = publicacion
            ? `${publicacion.meliItemID} — tu precio actual: ${publicacion.precioActual}`
            : '';
    }

    function opcion(valor, texto) {
        const elemento = document.createElement('option');
        elemento.value = valor;
        elemento.textContent = texto;
        return elemento;
    }

    function mensajeDeError(status, datos) {
        if (status === 401) return 'Token inválido o vencido. Volvé a copiarlo desde PricingML en Configuración.';
        if (status === 403) return 'Tu usuario es de solo lectura: necesitás un usuario ADMIN para guardar competidores.';
        return datos?.message || `El Motor respondió con un error (${status}).`;
    }

    function mensajeDeFalloDeRed(error) {
        return error instanceof TypeError
            ? `No se pudo conectar con el Motor en ${config.apiUrl}. Verificá que esté corriendo.`
            : error.message;
    }

    // textContent y no innerHTML: el título y el precio vienen del DOM de MercadoLibre y los
    // mensajes del Motor, así que tratarlos como HTML sería inyectable desde una página ajena.
    function mostrarEstado(mensaje, tipo) {
        statusDiv.textContent = mensaje;
        statusDiv.className = `status show ${tipo}`;
    }

    function ocultarEstado() {
        statusDiv.textContent = '';
        statusDiv.className = 'status';
    }
});
