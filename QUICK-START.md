# ⚡ PricingML - Quick Start (60 segundos)

## Para Windows

```powershell
# 1. Abrir PowerShell en la carpeta del proyecto
# 2. Ejecutar:
.\setup.ps1

# 3. Cuando termine, abrir navegador:
# http://localhost:3000
```

## Para Linux / Mac

```bash
# 1. Abrir terminal en la carpeta del proyecto
# 2. Ejecutar:
bash setup.sh

# 3. Cuando termine, abrir navegador:
# http://localhost:3000
```

## Requisitos Previos
- ✅ [Docker Desktop](https://www.docker.com/products/docker-desktop) instalado
- ✅ Docker corriendo (mínimo 2 GB RAM libre)
- ✅ Puertos disponibles: 3000, 5000, 1433

## URLs de Acceso
- 🌐 **Cliente**: http://localhost:3000
- 🔌 **API Swagger**: http://localhost:5000/swagger
- 🗄️ **SQL Server**: localhost:1433

## Comandos Básicos

```bash
# Ver estado
docker-compose ps

# Ver logs
docker-compose logs -f

# Detener
docker-compose down

# Reiniciar todo
docker-compose restart

# Limpiar (elimina datos)
docker-compose down -v
```

## ¿Problemas?

1. **Puerto ocupado**: Cambiar en `docker-compose.yml`
2. **Docker no inicia**: `docker-compose logs`
3. **SQL no conecta**: Esperar 30 segundos más
4. **API retorna error**: Ver `docker-compose logs motor`

## Documentación Completa

- 📖 Ver `INSTALACION.md` para guía detallada
- 📦 Ver `README-EMPAQUETAMIENTO.md` para arquitectura

---

**¡Listo en menos de 5 minutos!** 🚀
