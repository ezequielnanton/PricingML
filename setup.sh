#!/bin/bash

# Script de Instalación para Linux/Mac - PricingML
# Uso: bash setup.sh

echo "════════════════════════════════════════════════"
echo "  🚀 PricingML - Setup Installation Script"
echo "════════════════════════════════════════════════"

# Verificar si Docker está instalado
echo ""
echo "📋 Verificando requisitos..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado"
    echo "   Descargar desde: https://www.docker.com/products/docker-desktop"
    exit 1
fi

DOCKER_VERSION=$(docker --version)
echo "✅ Docker encontrado: $DOCKER_VERSION"

# Verificar Docker daemon
echo ""
echo "🔍 Verificando Docker daemon..."
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon no está corriendo"
    echo "   Inicia el daemon de Docker e intenta de nuevo"
    exit 1
fi
echo "✅ Docker daemon está activo"

# Copiar .env si no existe
if [ ! -f ".env" ]; then
    echo ""
    echo "📝 Creando archivo .env..."
    cp ".env.example" ".env"
    echo "✅ Archivo .env creado"
    echo "   ⚠️  Edita .env con tus credenciales de SQL Server antes de continuar"
    echo "   Ejecuta de nuevo este script una vez configurado"
    exit 0
fi

echo "✅ Archivo .env encontrado"

# Construcción de imágenes
echo ""
echo "🔨 Construyendo imágenes Docker (esto puede tomar 5-10 minutos)..."
docker-compose build
if [ $? -ne 0 ]; then
    echo "❌ Error al construir imágenes Docker"
    exit 1
fi
echo "✅ Imágenes construidas exitosamente"

# Iniciar servicios
echo ""
echo "🚀 Iniciando servicios..."
docker-compose up -d
if [ $? -ne 0 ]; then
    echo "❌ Error al iniciar servicios"
    exit 1
fi
echo "✅ Servicios iniciados"

# Esperar a que se inicialicen
echo ""
echo "⏳ Esperando a que los servicios se inicialicen (30 segundos)..."
sleep 30

# Verificar estado
echo ""
echo "📊 Estado de los servicios:"
docker-compose ps

# Verificar endpoints
echo ""
echo "🔗 Verificando conectividad..."

MOTOR_HEALTH=false
CLIENT_HEALTH=false
MAX_ATTEMPTS=5
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))

    MOTOR_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5000/health" 2>/dev/null || echo "000")
    if [ "$MOTOR_RESPONSE" = "200" ]; then
        echo "✅ Motor (API) está respondiendo en http://localhost:5000"
        MOTOR_HEALTH=true
    fi

    CLIENT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000" 2>/dev/null || echo "000")
    if [ "$CLIENT_RESPONSE" = "200" ]; then
        echo "✅ Cliente está respondiendo en http://localhost:3000"
        CLIENT_HEALTH=true
    fi

    if [ "$MOTOR_HEALTH" = true ] && [ "$CLIENT_HEALTH" = true ]; then
        break
    fi

    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        echo "   Reintentando en 10 segundos..."
        sleep 10
    fi
done

# Resultado final
echo ""
echo "════════════════════════════════════════════════"
if [ "$MOTOR_HEALTH" = true ] && [ "$CLIENT_HEALTH" = true ]; then
    echo "✅ ¡Setup completado exitosamente!"
    echo ""
    echo "🎉 PricingML está listo para usar:"
    echo "   🌐 Cliente: http://localhost:3000"
    echo "   🔌 API: http://localhost:5000/swagger"
    echo "   🗄️  SQL: localhost,1433 (Usuario: sa)"
else
    echo "⚠️  Setup completado, pero verificar los servicios:"
    docker-compose logs --tail=20
    echo ""
    echo "   Ejecuta 'docker-compose logs -f' para más detalles"
fi
echo "════════════════════════════════════════════════"

echo ""
echo "💡 Comandos útiles:"
echo "   docker-compose ps          - Ver estado de servicios"
echo "   docker-compose logs -f     - Ver logs en tiempo real"
echo "   docker-compose down        - Detener servicios"
echo "   docker-compose restart     - Reiniciar servicios"
