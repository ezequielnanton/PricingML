# 📦 PricingML - Empaquetamiento e Instalación

## Resumen Ejecutivo

Se ha preparado un **paquete Docker completo** que permite instalar el Motor y Cliente de PricingML en otra PC Windows con **un solo comando**:

```bash
docker-compose up
```

---

## ¿Qué se proporciona?

### 1. **Dockerfiles Optimizados**
- `PricingEngine/Dockerfile` → Motor .NET 10.0 compilado en multi-stage (imagen ligera)
- `PricingClient/pricing-ui/Dockerfile` → Cliente React compilado + nginx

### 2. **Docker Compose**
- `docker-compose.yml` → Orquesta Motor, Cliente y SQL Server
- Variables de entorno centralizadas
- Volúmenes para persistencia de datos
- Health checks integrados

### 3. **Scripts de Instalación**
- `setup.ps1` → Para Windows (PowerShell)
- `setup.sh` → Para Linux/Mac
- Verifican requisitos, construyen imágenes y validan inicio

### 4. **Configuración**
- `.env.example` → Template con todas las variables
- `nginx.conf` → Configuración del cliente con proxy a API
- `PricingEngine/SQL/init-docker.sql` → Script de inicialización BD

### 5. **Documentación**
- `INSTALACION.md` → Guía paso a paso detallada
- Troubleshooting incluido
- Comandos útiles de Docker

---

## Instalación Rápida (3 pasos)

### Opción 1: Windows (Recomendado con Docker Desktop)

```powershell
# 1. Descargar/clonar el código
git clone https://github.com/tu-usuario/PricingML.git
cd PricingML

# 2. Ejecutar script de setup (crea .env y verifica Docker)
.\setup.ps1

# 3. Listo - acceder a:
#    - Cliente: http://localhost:3000
#    - Motor API: http://localhost:5000/swagger
```

### Opción 2: Linux/Mac

```bash
# 1. Descargar/clonar el código
git clone https://github.com/tu-usuario/PricingML.git
cd PricingML

# 2. Ejecutar script de setup
bash setup.sh

# 3. Listo - acceder a:
#    - Cliente: http://localhost:3000
#    - Motor API: http://localhost:5000/swagger
```

### Opción 3: Manual (cualquier plataforma)

```bash
# 1. Copiar configuración
cp .env.example .env

# 2. Editar .env (cambiar SQL_SA_PASSWORD por tu contraseña)
# (Usar editor de texto: Notepad, VS Code, etc)

# 3. Construir e iniciar
docker-compose build
docker-compose up -d

# 4. Ver estado
docker-compose ps

# 5. Ver logs (opcional)
docker-compose logs -f
```

---

## Requisitos

- ✅ **Docker Desktop** (versión 4.0+) - https://www.docker.com/products/docker-desktop
- ✅ **Windows 10/11** (u otro sistema operativo con Docker)
- ✅ **1 GB de RAM** disponible (SQL Server: 2GB, Motor: 256MB, Cliente: 128MB)
- ✅ **Puertos disponibles**: 3000 (cliente), 5000 (motor), 1433 (SQL)

---

## Arquitectura del Paquete

```
PricingML/
├── docker-compose.yml          ← Orquestación
├── .env.example                ← Configuración template
├── .gitignore                  ← Git ignores
├── INSTALACION.md              ← Guía detallada
├── setup.ps1                   ← Script Windows
├── setup.sh                    ← Script Linux/Mac
│
├── PricingEngine/
│   ├── Dockerfile              ← Imagen del motor
│   ├── SQL/
│   │   └── init-docker.sql    ← Init script BD
│   ├── src/
│   │   ├── PricingApi/
│   │   ├── PricingAdapter/
│   │   └── ...
│
└── PricingClient/
    └── pricing-ui/
        ├── Dockerfile          ← Imagen del cliente
        ├── nginx.conf          ← Config nginx
        ├── package.json
        └── src/
            └── ...
```

---

## Flujo de Instalación

```
Usuario descarga repo
         ↓
Ejecuta setup.ps1 (o setup.sh)
         ↓
Script verifica Docker
         ↓
Crea archivo .env (usuario edita credenciales)
         ↓
docker-compose build (construye imágenes)
         ↓
docker-compose up -d (inicia servicios)
         ↓
Docker inicia:
  - sqlserver (BD)
  - motor (API .NET)
  - cliente (React + nginx)
         ↓
Health checks validan que todo funciona
         ↓
Usuario accede a http://localhost:3000
```

---

## Comparación de Soluciones

| Característica | Docker Compose | EXE/NSIS | ZIP Manual |
|---|---|---|---|
| **Facilidad** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Aislamiento** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐ |
| **Reproducibilidad** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Dependencias** | Docker | .NET, Node | .NET, Node |
| **Requisitos RAM** | 2-3 GB | 1-2 GB | 1-2 GB |
| **Plataformas** | Windows, Linux, Mac | Windows | Todas |
| **Setup Time** | ~5-10 min | ~10-15 min | ~15-20 min |
| **Mantenimiento** | 🟢 Bajo | 🟡 Medio | 🟠 Alto |

**Elegimos Docker Compose porque:**
- Instalación simple: `docker-compose up`
- Reproducible: mismo código = mismo resultado en cualquier PC
- Aislado: no contamina dependencias del sistema
- Escalable: fácil agregar services (Redis, Elasticsearch, etc)
- Estándar: Docker es la norma en DevOps

---

## Principales Cambios en el Código

### Dockerfiles
- **PricingEngine/Dockerfile**: Multi-stage build optimizado
  - Etapa 1: SDK .NET compila código
  - Etapa 2: Runtime .NET ejecuta binarios (imagen final ~300MB)
  - Health check automático

- **PricingClient/pricing-ui/Dockerfile**: Node → Nginx
  - Etapa 1: Node 22 compila React/Vite
  - Etapa 2: Nginx sirve archivos estáticos (imagen final ~50MB)

### Nginx Config (PricingClient/pricing-ui/nginx.conf)
- Routing SPA: redirige requests a index.html
- Proxy a API: `/api/` → `http://motor:5000/api/`
- Cache busting: archivos estáticos con hash
- Security headers: X-Frame-Options, X-Content-Type-Options, etc

### Docker Compose (docker-compose.yml)
- `services.motor`: API .NET
  - Puerto 5000 (HTTP), 5001 (HTTPS dev)
  - Espera a SQL Server antes de iniciar
  - Variables de entorno para conexión BD
  
- `services.cliente`: React + Nginx
  - Puerto 3000
  - Proxy interno a `motor:5000`
  
- `services.sqlserver`: SQL Server Developer Edition
  - Puerto 1433
  - Volumen `sqlserver-data` para persistencia
  - Script init automático

---

## Próximos Pasos (Futuro)

### Corto Plazo ✅ (Hecho)
- [x] Docker Compose setup
- [x] Dockerfiles optimizados
- [x] Scripts de instalación
- [x] Documentación detallada

### Mediano Plazo 🔄
- [ ] GitHub Actions CI/CD para construir imágenes
- [ ] Publicar releases en GitHub con docker-compose.yml
- [ ] CI/CD que pushea imágenes a Docker Hub

### Largo Plazo 🎯
- [ ] NSIS Installer para Windows (opcional)
- [ ] Helm charts para Kubernetes
- [ ] Multi-stage deployment (staging, prod)
- [ ] Backup/restore automation

---

## Solución de Problemas

Si algo no funciona, ver `INSTALACION.md` sección "Troubleshooting".

Comandos útiles de debugging:

```bash
# Ver estado
docker-compose ps

# Ver logs
docker-compose logs motor        # Motor
docker-compose logs cliente      # Cliente
docker-compose logs sqlserver    # BD
docker-compose logs -f           # Tiempo real, todos

# Ejecutar SQL en BD
docker-compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourPassword -Q "SELECT @@VERSION"

# Reiniciar un servicio
docker-compose restart motor

# Detener todo (data se preserva)
docker-compose down

# Limpiar todo (elimina todo, incluyendo BD)
docker-compose down -v

# Reconstruir imágenes
docker-compose build --no-cache
```

---

## Contacto y Soporte

- 📖 Documentación: `INSTALACION.md`
- 🐛 Issues: GitHub Issues
- 💬 Preguntas: GitHub Discussions
