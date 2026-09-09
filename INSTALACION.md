# 📦 Guía de Instalación - PricingML Motor + Cliente

## Requisitos Previos

### Sistema Operativo
- **Windows 10/11** (Pro, Enterprise o Home con WSL2)
- Linux o macOS (también soportado)

### Software Requerido
1. **Docker Desktop** (versión 4.0+)
   - Descargar: https://www.docker.com/products/docker-desktop
   - Instalar e iniciar
   - Verificar: `docker --version`

2. **Git** (opcional, para clonar repositorio)
   - Descargar: https://git-scm.com/download/win

3. **SQL Server 2022+** (si planeas usar servidor externo, de lo contrario Docker lo proporciona)

---

## Opción 1: Instalación Rápida con Docker (Recomendado)

### Paso 1: Obtener el código

**Opción A - Clonar desde GitHub:**
```bash
git clone https://github.com/tu-usuario/PricingML.git
cd PricingML
```

**Opción B - Descargar ZIP:**
1. Descargar ZIP del repositorio
2. Extraer en carpeta destino
3. Abrir terminal en esa carpeta

### Paso 2: Configurar variables de entorno

```bash
# Copiar archivo de ejemplo
copy .env.example .env

# Editar .env (abrir con Notepad o tu editor preferido)
# Cambiar:
# - SQL_SA_PASSWORD: contraseña para SQL Server (mínimo 8 caracteres, incluir mayúscula, número y símbolo)
# - CONNECTION_STRING: actualizar la contraseña que pusiste arriba
# - Otros valores según tu setup
```

**Ejemplo de .env configurado:**
```
SQL_SA_PASSWORD=MySecurePass123!
CONNECTION_STRING=Server=sqlserver;Database=PRICES_DB;User Id=sa;Password=MySecurePass123!;TrustServerCertificate=True;
API_BASE_URL=http://localhost:5000
```

### Paso 3: Iniciar los servicios

```bash
# Construir imágenes Docker (primera vez, ~5-10 minutos)
docker-compose build

# Iniciar los servicios (en segundo plano)
docker-compose up -d

# Ver logs (opcional, para verificar que todo está bien)
docker-compose logs -f

# Esperar ~30 segundos a que se inicialice SQL Server y la API
```

### Paso 4: Verificar que todo funciona

**Motor (API):**
- Abrir en navegador: http://localhost:5000/swagger
- Deberías ver Swagger UI con endpoints disponibles

**Cliente (Frontend):**
- Abrir en navegador: http://localhost:3000
- Deberías ver la aplicación de PricingML cargada

**Base de Datos:**
- Verificar conexión: `docker-compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT @@VERSION"`

### Paso 5: Usar la Aplicación

1. Acceder a http://localhost:3000
2. Login (si está habilitado, ver credenciales en base de datos)
3. Comenzar a usar el sistema

---

## Opción 2: Instalación con SQL Server Existente

Si ya tienes SQL Server instalado en tu máquina, puedes usarlo en lugar de Docker:

### Configuración

1. **Editar .env:**
```
# Usa tu servidor SQL Server local
CONNECTION_STRING=Server=localhost\\SQLEXPRESS;Database=PRICES_DB;User Id=sa;Password=TuPassword;TrustServerCertificate=True;
```

2. **Comentar el servicio sqlserver en docker-compose.yml:**
```yaml
# sqlserver:
#   image: mcr.microsoft.com/mssql/server:2022-latest
#   ...
```

3. **Iniciar solo motor y cliente:**
```bash
docker-compose up -d motor cliente
```

---

## Comandos Útiles

### Ver estado de servicios
```bash
docker-compose ps
```

### Ver logs de un servicio
```bash
# Motor
docker-compose logs motor

# Cliente  
docker-compose logs cliente

# SQL Server
docker-compose logs sqlserver

# Tiempo real (añade -f)
docker-compose logs -f motor
```

### Detener servicios
```bash
# Parar sin eliminar volúmenes (data se preserva)
docker-compose down

# Parar y eliminar todo (incluyendo BD)
docker-compose down -v
```

### Reiniciar un servicio
```bash
docker-compose restart motor
docker-compose restart cliente
```

### Conectar a SQL Server desde otra herramienta

**SQL Server Management Studio (SSMS):**
- Server: `localhost,1433`
- Authentication: SQL Server Authentication
- Login: `sa`
- Password: La que pusiste en SQL_SA_PASSWORD
- Database: `PRICES_DB`

**SQL Server Data Tools:**
- Connection String: La de tu .env

---

## Acceso Remoto desde otra PC en la Red

Si quieres acceder a la aplicación desde otra máquina en la misma red:

### 1. Obtener IP de tu máquina
```bash
# Windows - en PowerShell
ipconfig

# Linux/Mac
ifconfig
```
Busca la dirección IPv4 de tu red local (ej: 192.168.1.100)

### 2. Actualizar .env
```
API_BASE_URL=http://192.168.1.100:5000
```

### 3. Reiniciar cliente
```bash
docker-compose restart cliente
```

### 4. Acceder desde otra PC
```
http://192.168.1.100:3000
```

---

## Troubleshooting

### Error: "Port 3000/5000 is already in use"
```bash
# Solución: cambiar puertos en docker-compose.yml
# Busca "ports:" y cambia:
#  - "3000:3000" a "3001:3000"
#  - "5000:5000" a "5100:5000"

docker-compose up -d
```

### Error: "Cannot find SQL Server"
```bash
# Verificar que SQL Server está corriendo
docker-compose ps

# Reiniciar SQL Server
docker-compose restart sqlserver

# Esperar 30 segundos y reintentar
```

### Error: "Connection refused"
```bash
# Esperar a que SQL Server se inicie (~30 segundos)
# Ver logs
docker-compose logs sqlserver

# Si sigue fallando, reiniciar todo
docker-compose down -v
docker-compose up -d
```

### Motor muestra "Unhealthy" en docker ps
```bash
# Ver qué está fallando
docker-compose logs motor

# Verificar que la conexión a BD es correcta en .env
# Reiniciar motor
docker-compose restart motor
```

### Cliente carga pero no conecta con API
```bash
# Verificar que API_BASE_URL es correcto en .env
# Debe ser http://motor:5000 si está en Docker
# O http://localhost:5000 si está en tu máquina

# Reiniciar cliente
docker-compose restart cliente
```

---

## Mantenimiento

### Actualizar código

```bash
# Si tienes cambios en GitHub
git pull origin main

# Reconstruir imágenes Docker
docker-compose build

# Reiniciar servicios
docker-compose down
docker-compose up -d
```

### Backup de Base de Datos

```bash
# Hacer backup
docker-compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "BACKUP DATABASE PRICES_DB TO DISK='/var/opt/mssql/backup/PRICES_DB.bak'"

# Copiar archivo local
docker cp pricing-sqlserver:/var/opt/mssql/backup/PRICES_DB.bak ./backup/
```

---

## Soporte

Si tienes problemas:

1. **Revisar logs:** `docker-compose logs`
2. **Verificar .env:** Asegúrate de que todos los valores sean correctos
3. **Reiniciar:** `docker-compose down && docker-compose up -d`
4. **Limpiar:** `docker system prune -a` (limpia imágenes y contenedores no usados)

---

## Recursos Útiles

- 📖 Docker Compose: https://docs.docker.com/compose/
- 🗄️ SQL Server en Docker: https://hub.docker.com/_/microsoft-mssql-server
- 🔗 Motor API Docs: http://localhost:5000/swagger
- 🎨 Cliente: http://localhost:3000
