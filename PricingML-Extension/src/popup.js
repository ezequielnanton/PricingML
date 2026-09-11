document.addEventListener('DOMContentLoaded', async () => {
    const form = document.getElementById('competitorForm');
    const statusDiv = document.getElementById('status');
    const btnGuardar = document.getElementById('btnGuardar');

    // Cargar configuración guardada (URL de la API)
    const { apiUrl = 'http://localhost:5000' } = await chrome.storage.sync.get(['apiUrl']);

    // Pre-llenar datos detectados de MercadoLibre (si existen)
    const { detectedData } = await chrome.storage.session.get(['detectedData']);
    if (detectedData) {
        document.getElementById('meliItemId').value = detectedData.meliItemId || '';
        document.getElementById('titulo').value = detectedData.titulo || '';
        document.getElementById('precio').value = detectedData.precio || '';
        // Limpiar datos detectados después de usar
        await chrome.storage.session.remove(['detectedData']);
    }

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const meliItemId = document.getElementById('meliItemId').value.trim();
        const titulo = document.getElementById('titulo').value.trim();
        const precio = parseFloat(document.getElementById('precio').value);
        const monedaId = parseInt(document.getElementById('moneda').value);
        const vendedor = document.getElementById('vendedor').value.trim();

        // Validar
        if (!meliItemId || !titulo || !precio || precio <= 0) {
            mostrarEstado('Faltan datos requeridos', 'error');
            return;
        }

        btnGuardar.disabled = true;
        mostrarEstado('<span class="loading-spinner"></span> Guardando...', 'loading');

        try {
            const response = await fetch(`${apiUrl}/api/competidores/capturado`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    meliItemId,
                    titulo,
                    precio,
                    monedaId,
                    vendedor: vendedor || null,
                    link: null
                })
            });

            const data = await response.json();

            if (response.ok && data.vinculado) {
                const mensaje = `
                    <span class="success-icon">✓</span>
                    <strong>Competidor vinculado exitosamente</strong><br>
                    Producto: ${data.productoNombre}<br>
                    ${data.recomendacionNueva ? `Nueva recomendación: $${data.recomendacionNueva}` : ''}
                `;
                mostrarEstado(mensaje, 'success');
                form.reset();
                // Cerrar popup después de 2 segundos
                setTimeout(() => window.close(), 2000);
            } else {
                const mensaje = data.mensaje || 'No se pudo vincular el competidor';
                mostrarEstado(`<span class="error-icon">✗</span> ${mensaje}`, 'error');
            }
        } catch (error) {
            const msg = error.message === 'Failed to fetch'
                ? 'Error de conexión. Verifica que PricingML esté corriendo en ' + apiUrl
                : error.message;
            mostrarEstado(`<span class="error-icon">✗</span> ${msg}`, 'error');
        } finally {
            btnGuardar.disabled = false;
        }
    });

    function mostrarEstado(mensaje, tipo) {
        statusDiv.innerHTML = mensaje;
        statusDiv.className = `status show ${tipo}`;
    }

    // Abrir página de configuración con un clic (opcional)
    document.addEventListener('keydown', (e) => {
        if (e.ctrlKey && e.shiftKey && e.key === 'C') {
            chrome.runtime.openOptionsPage();
        }
    });
});
