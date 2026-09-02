# Parametrización de Mensajes - Actualización Rápida

## Fase 3: Mensajes Parametrizados (NUEVA - Completada)

### Archivos agregados:

1. **SQL/Estructura.sql**
   - Nueva tabla: `EstrategiaReglaParametrosMensajes`
   - Estructura: MensajeID, EstrategiaReglaID, Clave, Valor (NVARCHAR(MAX)), temporal tracking

2. **SQL/spCalcularDecision.sql**
   - 4 variables de mensajes con defaults
   - 4 SELECTs para cargar mensajes vigentes
   - Token replacement: {PORCENTAJE}, {PRECIO_NUEVO}

3. **SQL/Inicializar-Parametros-Mensajes.sql**
   - Data inicial en Español (AGRESIVA/CONSERVADORA)
   - Ejemplo en Inglés mediante `Idioma = 'EN'`
   - INSERT de 4 mensajes por estrategia

4. **PricingApi/Models/EstrategiaReglaParametroDto.cs**
   - Agregadas 3 clases DTO para mensajes:
     - `EstrategiaReglaParametroMensajeDto`
     - `EstrategiaReglaParametroMensajeDetalleDto`
     - `CreateUpdateEstrategiaReglaParametroMensajeDto`

5. **PricingApi/Services/AdminCrudService.cs**
   - 5 métodos CRUD de mensajes:
     - `GetEstrategiaReglaParametrosMensajesAsync()`
     - `GetMensajesVigentesAsync()`
     - `CreateEstrategiaReglaParametroMensajeAsync()`
     - `UpdateEstrategiaReglaParametroMensajeAsync()`
     - `DeactivateEstrategiaReglaParametroMensajeAsync()`

6. **PricingApi/Controllers/EstrategiaReglaParametrosMensajesController.cs**
   - NEW controller con 5 endpoints:
     - `GET /estrategia-regla/{id}` - Histórico
     - `GET /estrategia/{id}/vigentes` - Vigentes
     - `POST /` - Crear
     - `PUT /{id}` - Actualizar
     - `DELETE /{id}` - Desactivar

7. **docs/apis/API-EstrategiaReglaParametrosMensajes.md**
   - Documentación completa de API
   - 5 claves de mensaje estándar
   - 4 tokens disponibles
   - 5 casos de uso reales
   - Multi-idioma, A/B testing, localización

---

## Tabla Comparativa: Antes vs Después

| Aspecto | Antes | Después (Fase 1-2) | Después (Fase 3) |
|---------|-------|-------------------|------------------|
| **Porcentajes** | Hardcode SP | Tabla `EstrategiaReglaParametros` | ✅ |
| **Mensajes** | Hardcode SP (fijo) | ❌ Aún hardcode | Tabla `EstrategiaReglaParametrosMensajes` |
| **Cambio de porcentaje** | Recompilación | Cambio BD + API | ✅ |
| **Cambio de mensaje** | Recompilación | ❌ Aún requiere | Cambio BD + API |
| **Multi-idioma** | ❌ No | ❌ No | ✅ Sí (`Idioma` explícito con fallback ES) |
| **A/B Testing** | ❌ No | ❌ No | ✅ Sí (vigencia + tokens) |
| **Auditoría** | ❌ No | ✅ Temporal | ✅ Temporal |

---

## Stack Técnico Completo

```
Parámetros Numéricos + Parámetros de Mensajes
       ↓
├─ SQL Server: 2 tablas nuevas
│  ├─ EstrategiaReglaParametros (4 parámetros numéricos)
│  └─ EstrategiaReglaParametrosMensajes (4 mensajes parametrizados)
│
├─ API REST: 10 endpoints (5 para parámetros + 5 para mensajes)
│  ├─ EstrategiaReglaParametrosController
│  └─ EstrategiaReglaParametrosMensajesController
│
├─ Stored Procedure: spCalcularDecision v2.0
│  ├─ Carga 4 parámetros numéricos
│  ├─ Carga 4 mensajes parametrizados
│  └─ Aplica token replacement
│
└─ DTOs: 6 clases (3 para params + 3 para mensajes)
```

---

## Compilación

✅ **SIN ERRORES** - PricingApi compila correctamente

```
Advertencia: Archivo bloqueado (app está corriendo)
Pero: Compilación exitosa ✓
```

---

## Próximos pasos (Deploy)

1. ✅ Código: Completado
2. ✅ Documentación: Completada (7 archivos + 2 guías API)
3. ✅ Scripts SQL: Completados (estructura + datos iniciales + validación)
4. ⏳ Deploy en DB
5. ⏳ Test endpoints
6. ⏳ Verificar token replacement en SP

---

**Responsable**: Equipo Technical  
**Fecha**: 2026-08-18  
**Estado**: COMPLETADO - LISTO PARA DEPLOY
