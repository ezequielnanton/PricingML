# Integración Frontend para Pricing Engine

Este documento está pensado para que el equipo de UI pueda consumir las APIs del Pricing Engine sin tener que conocer la lógica interna del motor ni la base SQL.

## 1. Arquitectura que debe entender la UI

La UI no debe hablar directo con SQL ni con el motor. Debe enviar un payload normalizado a la API y recibir una decisión de pricing.

La navegación actual de la frontend quedó organizada en:

- Pricing
- Formularios
- Reportes
- Documentación
- API Check

Esto reemplaza la estructura legacy de Admin, Health y API docs como pantallas independientes.

```text
UI
  ↓
API /api/input/ui/product
  ↓
UiAdapter
  ↓
ProductoInput
  ↓
Persistencia core
  ↓
SQL Server / spCalcularDecision
```

La capa de pricing está desacoplada del origen. La UI solo necesita enviar un payload válido en el formato esperado.

## 2. Base URL

Actualmente la API corre en la aplicación ASP.NET Core localmente, por ejemplo:

```text
http://localhost:5000
```

Si la configuración del entorno cambia, ajustar la URL de la API del frontend.

## 3. Autenticación

En esta etapa no hay autenticación implementada en la API. Los endpoints son abiertos.

Importante: esto es solo para entornos internos o seguros. En producción se recomienda JWT o API Key.

## 4. Modelo de entrada principal para UI

La UI debe enviar el siguiente JSON a la API de ingreso principal:

```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "titulo": "Auriculares Bluetooth",
  "precioPropuesto": 46000,
  "precioMinimoPermitido": 41400,
  "precioMaximoPermitido": 55200,
  "stockDisponible": 8,
  "stockMinimo": 5,
  "stockMaximo": 20,
  "costoBase": 31000,
  "iva": 21,
  "comisionMLPorc": 9,
  "costoEnvioPromedio": 0,
  "costoLogisticoFijo": 0,
  "costoFinancieroPorc": 0,
  "costoPublicidadPorc": 0,
  "estadoPublicacion": "active",
  "origen": "UI",
  "modoSimulacion": true,
  "persistir": true
}
```

Este payload corresponde al contrato [src/PricingApi/Models/UiPricingRequest.cs](C:/PricingEngine/src/PricingApi/Models/UiPricingRequest.cs).

### Campos principales

- empresaId: int, obligatorio
- sku: string, obligatorio, se normaliza a uppercase y trim
- titulo: string, opcional pero recomendado
- precioPropuesto: decimal, obligatorio y mayor a 0
- precioMinimoPermitido: decimal, opcional
- precioMaximoPermitido: decimal, opcional
- stockDisponible: int, obligatorio
- stockMinimo: int, opcional
- stockMaximo: int, opcional
- costoBase: decimal, obligatorio y mayor a 0
- iva: decimal, opcional (por defecto 21)
- comisionMLPorc: decimal, opcional
- costoEnvioPromedio: decimal, opcional
- costoLogisticoFijo: decimal, opcional
- costoFinancieroPorc: decimal, opcional
- costoPublicidadPorc: decimal, opcional
- estadoPublicacion: string, opcional, ejemplo "active"
- origen: string, por defecto "UI"
- modoSimulacion: bool, por defecto true
- persistir: bool, por defecto false

## 5. Endpoint recomendado para la UI

### POST /api/input/ui/product

Este es el endpoint principal que la interfaz debe usar para cargar un producto y obtener una recomendación de pricing.

#### Descripción

- Recibe el payload de la UI
- Lo transforma con UiAdapter
- Genera un ProductoInput canónico
- Valida campos mínimos
- Persiste en tablas core (Productos, CostosProducto, StockEstado)
- Ejecuta el motor si corresponde

#### Request example

```http
POST /api/input/ui/product
Content-Type: application/json

{
  "empresaId": 1,
  "sku": "SKU-001",
  "titulo": "Auriculares Bluetooth",
  "precioPropuesto": 46000,
  "precioMinimoPermitido": 41400,
  "precioMaximoPermitido": 55200,
  "stockDisponible": 8,
  "stockMinimo": 5,
  "stockMaximo": 20,
  "costoBase": 31000,
  "iva": 21,
  "comisionMLPorc": 9,
  "costoEnvioPromedio": 0,
  "costoLogisticoFijo": 0,
  "costoFinancieroPorc": 0,
  "costoPublicidadPorc": 0,
  "estadoPublicacion": "active",
  "origen": "UI",
  "modoSimulacion": true,
  "persistir": true
}
```

#### Response example (201 Created)

```json
{
  "productoId": 123,
  "decision": {
    "empresaId": 1,
    "sku": "SKU-001",
    "precioActual": 46000,
    "precioSugerido": 45500,
    "accion": "MANTENER",
    "motivo": "Margen dentro de límites",
    "margenActualPorc": 22.5,
    "scoreConfianza": 87.3,
    "modoSimulacion": true,
    "fuenteOrigen": "UI"
  }
}
```

#### HTTP status

- 201 Created: ingreso correcto
- 400 Bad Request: payload inválido
- 404 Not Found: empresa inexistente
- 500 Internal Server Error: error de SQL o algún problema de persistencia

#### Validaciones del frontend recomendadas

Antes de hacer la llamada, la UI debería validar lo siguiente:

- empresaId > 0
- sku no vacío
- titulo no vacío o al menos no nulo
- precioPropuesto > 0
- costoBase > 0
- precioMinimoPermitido <= precioActual <= precioMaximoPermitido cuando se envían todos
- stockDisponible >= 0
- stockMinimo <= stockMaximo

La API también aplica validaciones de backend, pero conviene mostrar feedback al usuario antes de enviar.

## 6. Endpoint alternativo de cálculo sin persistir

### POST /pricing/evaluate

Se usa cuando la UI solo quiere obtener una recomendación de pricing, sin guardarla en el core.

#### Request example

```http
POST /pricing/evaluate
Content-Type: application/json

{
  "empresaId": 1,
  "sku": "SKU-001",
  "titulo": "Auriculares Bluetooth",
  "precioPropuesto": 46000,
  "stockDisponible": 8,
  "stockMinimo": 5,
  "stockMaximo": 20,
  "costoBase": 31000,
  "iva": 21,
  "comisionMLPorc": 9,
  "estadoPublicacion": "active",
  "origen": "UI",
  "modoSimulacion": true,
  "persistir": false
}
```

#### Response example (200 OK)

```json
{
  "empresaId": 1,
  "sku": "SKU-001",
  "precioActual": 46000,
  "precioSugerido": 45500,
  "accion": "MANTENER",
  "motivo": "Margen dentro de límites",
  "margenActualPorc": 22.5,
  "scoreConfianza": 87.3,
  "modoSimulacion": true,
  "fuenteOrigen": "UI"
}
```

#### Cuándo usarlo

- cuando la UI quiere solo simular una recomendación
- cuando no se desea guardar aún los datos en la base

## 7. Endpoint de salud

### GET /health

```http
GET /health
```

#### Response

```json
{ "status": "ok" }
```

Se usa para chequeo de disponibilidad del servicio API. La UI lo expone únicamente como `API Check` en el árbol lateral y ejecuta esta consulta automáticamente al entrar; no hay un botón adicional en la pantalla.

## 8. Endpoints administrativos (solo si la UI necesita administrar configuración)

La UI puede necesitar editar datos maestros o configuración. Eso se expone en la sección admin.

La UI usa un flujo común para los formularios administrativos:

- Al salir de los campos de la clave de formulario, consulta `GET /api/admin/{recurso}` con filtros `filter[campo][eq]`.
- Si recibe exactamente un registro, carga sus campos y conserva el ID técnico.
- `Aceptar` usa `POST` para altas y `PUT /api/admin/{recurso}/{id}` para registros recuperados.
- `Eliminar` usa `DELETE /api/admin/{recurso}/{id}` solo después de confirmación y solo para registros recuperados.
- Decisiones no admite `DELETE` porque debe conservarse para auditoría.

Los formularios cubiertos son Empresas, Monedas, Cotizaciones, Parámetros generales, Cuentas ML, Productos, Costos producto, Publicaciones ML, Stock estado, Estrategias, Reglas, Estrategia-Regla, Configuración parámetros, Decisiones y Cola ejecución ML.

Documentación ampliada: [docs/API-Admin-Endpoints.md](C:/PricingEngine/docs/API-Admin-Endpoints.md)

## 9. Reglas de negocio que la UI debe respetar

- No llamar al motor SQL directamente desde la UI.
- No construir JSON con campos extra no soportados.
- Sumar y mantener el payload con los campos esperados por [src/PricingApi/Models/UiPricingRequest.cs](C:/PricingEngine/src/PricingApi/Models/UiPricingRequest.cs).
- Si una validación falla en frontend, no debe enviarse el request.
- Si el backend responde 400/404/409/500, mostrar mensaje amigable para el usuario.

## 10. Casos de uso comunes para UI

### Caso A: el usuario quiere simular una recomendación

- Llamar a POST /pricing/evaluate
- Mostrar precio sugerido y decisión
- No persistir aún

### Caso B: el usuario quiere guardar el producto y calcular

- Llamar a POST /api/input/ui/product
- Mostrar la respuesta con productoId y decision

### Caso C: el usuario quiere crear configuración de empresa/estrategia

- Usar endpoints /api/admin/*
- Ejemplo: crear empresa, crear estrategia, asociar regla a estrategia

## 11. Recomendación de implementación frontend

Se recomienda armare la capa de servicio frontend así:

```ts
async function evaluarProducto(payload: UiPricingRequest) {
  const response = await fetch('/api/input/ui/product', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    throw new Error('Error de validación o persistencia');
  }

  return response.json();
}
```

## 12. Documentación complementaria

- [docs/API-Endpoints.md](C:/PricingEngine/docs/API-Endpoints.md)
- [docs/API-Admin-Endpoints.md](C:/PricingEngine/docs/API-Admin-Endpoints.md)
- [src/PricingApi/Program.cs](C:/PricingEngine/src/PricingApi/Program.cs)
- [src/PricingAdapter/Program.cs](C:/PricingEngine/src/PricingAdapter/Program.cs)

## 13. Conclusión

Para la UI, la API principal que debe consumir es:

- POST /api/input/ui/product

Y la API de cálculo rápido es:

- POST /pricing/evaluate

Con esto ya está en condiciones de integrar el frontend de forma segura y consistente con la arquitectura documentada.
