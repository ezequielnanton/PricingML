# Instalación PricingML

## Opción 1: Descargar Release (MÁS FÁCIL)

1. Ve a: https://github.com/ezequielnanton/PricingML/releases
2. Descarga `PricingML-v1.0.0.zip`
3. Extrae el ZIP
4. Lee `README.md` dentro de la carpeta

## Opción 2: Compilar Localmente

### Requisitos
- Windows 10/11
- .NET 10.0 SDK
- Node.js 18+

### Pasos

1. Clonar repositorio
```bash
git clone https://github.com/ezequielnanton/PricingML.git
cd PricingML
```

2. Compilar
```powershell
.\build-release.ps1
```

Esto genera: `dist/PricingML-v1.0.0.zip`

3. Extraer y usar
```bash
Expand-Archive dist/PricingML-v1.0.0.zip -DestinationPath release
cd release/pricingml-release
```

## Opción 3: Docker (Recomendado - Sin instalación)

```bash
docker-compose up
```

Accede a:
- Cliente: http://localhost:3000
- Motor: http://localhost:5000/swagger

---

Documentación en: README.md
