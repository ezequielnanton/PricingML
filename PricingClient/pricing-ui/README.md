# Pricing UI

Aplicación frontend del Pricing Engine para evaluar precios, administrar datos maestros y consultar reportes.

## Objetivo del sistema

La interfaz permite:

- evaluar un producto y obtener una recomendación comercial;
- ingresar y mantener formularios de negocio y configuración;
- consultar reportes tabulares con filtros y paginación;
- revisar documentación funcional y técnica del sistema;
- consultar el estado de la API.

## Menú actual

La navegación principal quedó organizada así:

- Pricing
- Formularios
  - Empresa
  - Moneda
  - Cotización
  - Parámetro General
  - Cuenta ML
  - Producto
  - Costo Producto
  - Publicación ML
  - Stock Estado
  - Estrategia
  - Regla
  - Estrategia-Regla
  - Configuración Parámetros
  - Decisión
  - Cola Ejecución ML
- Reportes
  - Empresas
  - Monedas
  - Cuentas ML
  - Estrategias
  - Reglas
  - etc.
- Documentación
  - Funcional
  - Apartado especial
  - Manual práctico
  - API docs
- API Check

## Stack

- React 19
- Vite 8
- React Router DOM
- Fetch API para HTTP
- CSS nativo

## Ejecutar localmente

Desde la carpeta del frontend:

```powershell
cd C:\PricingClient\pricing-ui
$env:VITE_API_BASE_URL = "http://192.168.1.83:5000"
cmd /c "npm run dev -- --host 0.0.0.0"
```

También puede ejecutarse con:

```powershell
cmd /c "npm run build"
```

## Conexión con la API

La app usa la variable de entorno `VITE_API_BASE_URL` y tiene un fallback a `http://localhost:5000`.

Para acceso desde celular o desde otra máquina en la misma red local, conviene usar la IP de la PC donde corre el backend:

```env
VITE_API_BASE_URL=http://192.168.1.83:5000
```

## Estructura principal

```text
src/
├── App.jsx
├── App.css
├── components/
│   ├── Sidebar.jsx
│   ├── PricingForm.jsx
│   ├── AdminPanel.jsx
│   ├── ReportsPanel.jsx
│   ├── ResultPanel.jsx
│   ├── DecisionDetail.jsx
│   └── ReportFilterField.jsx
└── utils/
    └── reportFilters.js
```

## Nota importante

La navegación lateral es la fuente principal de interacción. Los botones superiores quedaron eliminados para evitar duplicación y mantener una interfaz más clara.
