# Índice de Documentación - Pricing Engine

**Última actualización**: 2026-08-18  
**Versión**: 2.0  
**Estado**: MVP Funcional

---

## 📋 Índice Rápido

| Documento | Propósito | Audiencia |
|-----------|-----------|-----------|
| [README.md](../README.md) | Visión general del proyecto | Todos |
| [CONTEXT.md](../CONTEXT.md) | Lenguaje de dominio y relaciones | Domain Experts, Devs |
| [API-Endpoints.md](apis/API-Endpoints.md) | Referencia de todas las APIs | Desarrolladores Frontend, QA |
| [Arquitectura-Adaptadores.md](Arquitectura-Adaptadores.md) | Patrón de normalización de datos | Arquitectos, Senior Devs |
| [Paso-a-Paso-Compilar.md](Paso-a-Paso-Compilar.md) | Cómo compilar la API | DevOps, Desarrolladores |
| [Guia-Levantar-API-y-Postman.md](Guia-Levantar-API-y-Postman.md) | Inicio rápido + testing manual | Nuevos desarrolladores, QA |
| [Implementation-Notes.md](Implementation-Notes.md) | Estado actual de la implementación | Desarrolladores, Product Managers |
| [Casos-Prueba-Testing.md](Casos-Prueba-Testing.md) | Estrategia y casos de testing | QA, Desarrolladores |
| [Configuracion-por-Cliente.md](Configuracion-por-Cliente.md) | Multi-tenant, deployment | DevOps, SRE |

---

## 🚀 Inicio Rápido

**Tiempos**: 15 minutos para completar

### Paso 1: Preparar BD (5 min)
```powershell
sqlcmd -S localhost\SQLEXPRESS -Q "CREATE DATABASE PRICES_DB"
sqlcmd -S localhost\SQLEXPRESS -d PRICES_DB -i "C:\PricingEngine\SQL\Estructura.sql"
```

### Paso 2: Levantar API (5 min)
```powershell
cd C:\PricingEngine\src\PricingApi
dotnet restore
dotnet build
dotnet run
```

### Paso 3: Verificar (5 min)
```powershell
# En otra terminal
Invoke-WebRequest -Uri "http://localhost:5060/health"
# Response: {"status":"ok"}
```

**→ Ver**: [Guia-Levantar-API-y-Postman.md](Guia-Levantar-API-y-Postman.md)

---

## 📚 Documentación por Rol

### 👨‍💼 Product Manager / Stakeholder
1. [README.md](../README.md) - Visión y alcance
2. [CONTEXT.md](../CONTEXT.md) - Lenguaje del negocio
3. [Implementation-Notes.md](Implementation-Notes.md) - Estado actual

**Objetivo**: Entender qué está implementado y qué falta.

---

### 👨‍💻 Desarrollador Backend

**Primer día**:
1. [Paso-a-Paso-Compilar.md](Paso-a-Paso-Compilar.md) - Compilar
2. [Guia-Levantar-API-y-Postman.md](Guia-Levantar-API-y-Postman.md) - Ejecutar
3. [README.md](../README.md) - Arquitectura

**Para implementar features**:
1. [Arquitectura-Adaptadores.md](Arquitectura-Adaptadores.md) - Patrón de adaptadores
2. [API-Endpoints.md](apis/API-Endpoints.md) - Contratos de API
3. [Implementation-Notes.md](Implementation-Notes.md) - Decisiones técnicas

**Para debugging**:
1. [docs/Guia-Tecnica-Continuar-API.md](Guia-Tecnica-Continuar-API.md) - Deep dive técnico
2. [SQL/spCalcularDecision.sql](../SQL/spCalcularDecision.sql) - Motor de decisiones

---

### 🧪 QA / Testing

**Configuración de testing**:
1. [Casos-Prueba-Testing.md](Casos-Prueba-Testing.md) - Casos y estrategia
2. [Guia-Levantar-API-y-Postman.md](Guia-Levantar-API-y-Postman.md) - Testing manual con Postman

**Plan de testing**:
1. Unit tests: `dotnet test`
2. Manual tests: Postman collection
3. Integration tests: (Futuro)

---

### 🔧 DevOps / Infrastructure

**Deployment**:
1. [Paso-a-Paso-Compilar.md](Paso-a-Paso-Compilar.md) - Build pipeline
2. [Configuracion-por-Cliente.md](Configuracion-por-Cliente.md) - Multi-tenant config
3. [Guia-Levantar-API-y-Postman.md](Guia-Levantar-API-y-Postman.md) - Troubleshooting

**Monitoreo**:
- Health check: `GET /health`
- Logs: Configurables en appsettings.json
- BD: Tablas en PRICES_DB

---

### 🏗️ Arquitecto / Senior Dev

**Decisiones técnicas**:
1. [Arquitectura-Adaptadores.md](Arquitectura-Adaptadores.md) - Patrón completo
2. [Implementation-Notes.md](Implementation-Notes.md) - Decisiones implementadas
3. [CONTEXT.md](../CONTEXT.md) - Dominio

**Extensiones y mejoras**:
1. Agregar nuevos adaptadores
2. Integración con ML API
3. Optimizaciones de performance

---

## 🗂️ Estructura de Carpetas

```
c:\PricingEngine/
├── docs/                           ← Documentación
│   ├── DOCUMENTACION-INDEX.md      ← ESTE ARCHIVO
│   ├── README.md                   ← Visión general
│   ├── Implementation-Notes.md     ← Estado actual
│   ├── API-Endpoints.md            ← APIs
│   ├── Arquitectura-Adaptadores.md ← Patrón
│   ├── Casos-Prueba-Testing.md     ← Testing
│   ├── Paso-a-Paso-Compilar.md     ← Compilación
│   ├── Guia-Levantar-API-y-Postman.md ← Inicio rápido
│   ├── Configuracion-por-Cliente.md ← Multi-tenant
│   ├── apis/
│   │   └── API-Endpoints.md
│   └── adr/                         ← Decisiones de arquitectura
│       └── 0001-reportes-tablas-admin.md
│
├── src/
│   ├── PricingApi/                  ← API REST
│   │   ├── Program.cs               ← Punto de entrada
│   │   ├── Services/                ← Servicios de negocio
│   │   ├── Models/                  ← DTOs
│   │   └── appsettings.json         ← Configuración
│   ├── PricingAdapter/              ← Adaptadores
│   │   ├── Adapters/
│   │   └── Models/
│   ├── PricingApi.Tests/            ← Tests unitarios
│   └── SqlProbe/                    ← Utilidad de conexión BD
│
├── SQL/                             ← Base de datos
│   ├── Estructura.sql               ← Esquema principal
│   ├── fn_CalcularMargenNetoPorc.sql
│   └── spCalcularDecision.sql       ← Motor de decisiones
│
├── CONTEXT.md                       ← Lenguaje de dominio
└── README.md                        ← Resumen ejecutivo
```

---

## 🔑 Conceptos Clave

### ProductoInput (Modelo Canónico)
Todos los adaptadores normalizan a `ProductoInput`. Ver [Arquitectura-Adaptadores.md](Arquitectura-Adaptadores.md).

### Motor de Decisiones
`dbo.spCalcularDecision` es el corazón. Congelado hasta autorización. Ver [SQL/spCalcularDecision.sql](../SQL/spCalcularDecision.sql).

### Multi-tenant
Aislamiento por EmpresaID. Mismo binario, múltiples clientes. Ver [Configuracion-por-Cliente.md](Configuracion-por-Cliente.md).

### Auditoría
Todas las decisiones quedan registradas. Ver [CONTEXT.md](../CONTEXT.md).

---

## ✅ Estado de Implementación

### Implementado ✅
- ✅ Ingestión desde UI
- ✅ Persistencia transaccional
- ✅ Motor de decisiones (spCalcularDecision)
- ✅ Admin CRUD
- ✅ Reportes con protección SQL injection
- ✅ Auditoría completa
- ✅ Tests unitarios (AdminReportsService)
- ✅ Multi-tenant (por EmpresaID)

### Parcialmente ⚠️
- ⚠️ Backtesting (estructura, requiere snapshots)
- ⚠️ Validaciones exhaustivas (mínimas actualmente)

### No implementado ❌
- ❌ Adaptador Mercado Libre
- ❌ Adaptadores ERP
- ❌ Endpoints de reportes
- ❌ Autenticación (JWT)
- ❌ Integración ML execution

---

## 📞 Soporte y Contacto

| Tema | Responsable |
|------|------------|
| Preguntas de API | Equipo Backend |
| Deployment | Equipo DevOps |
| Testing | Equipo QA |
| Arquitectura | Tech Lead |
| Negocio | Product Manager |

---

## 🔄 Próximos Pasos (Roadmap)

### Fase 2 (Mes 1-2)
- [ ] Validaciones exhaustivas
- [ ] Adaptador Mercado Libre
- [ ] Logging estructurado
- [ ] Tests de integración

### Fase 3 (Mes 3-4)
- [ ] Autenticación JWT
- [ ] Endpoints de reportes activos
- [ ] Snapshots de backtesting
- [ ] Integración conversión moneda

### Fase 4 (Mes 5+)
- [ ] Auto-ejecución en ML
- [ ] Optimización de reglas con ML
- [ ] Mobile app
- [ ] Multi-región

---

## 📖 Recursos Externos

- [ASP.NET Core Documentation](https://docs.microsoft.com/aspnet/core)
- [SQL Server Documentation](https://docs.microsoft.com/sql/sql-server)
- [Postman Learning Center](https://learning.postman.com)

---

## 📝 Cambios Recientes

| Fecha | Cambio | Documento |
|-------|--------|-----------|
| 2026-08-18 | Actualización completa de documentación | Todos |
| 2026-08-18 | Creación de DOCUMENTACION-INDEX.md | Este archivo |
| 2026-08-15 | Implementación de AdminReportsService | Implementation-Notes.md |

---

## 🎯 Principios Documentados

1. **Claridad**: Documentos orientados a diferentes audiencias
2. **Actualización**: Sincronizados con código actual
3. **Practicidad**: Ejemplos listos para ejecutar
4. **Rastreabilidad**: Decisiones documentadas en ADRs

---

**Responsable de documentación**: Equipo Technical Writing  
**Última revisión**: 2026-08-18  
**Próxima revisión planeada**: 2026-09-18  
**Estado**: ✅ Actualizado y listo para producción
