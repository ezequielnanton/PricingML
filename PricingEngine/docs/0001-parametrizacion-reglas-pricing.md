# ADR 0001: Parametrización de Porcentajes de Reglas de Pricing

**Título**: Parametrización de porcentajes en reglas de pricing (stock crítico, oportunidad, exceso stock, competencia)

**Fecha**: 2026-08-18

**Estado**: APROBADO

**Contexto**

El motor de decisiones (`spCalcularDecision`) aplicaba porcentajes de ajuste de precio de forma hardcodeada:
- Stock Crítico: +5% (multiplicador 1.05)
- Oportunidad: +3% (multiplicador 1.03)
- Exceso Stock: -7% (multiplicador 0.93)
- Competencia: -10 unidades (valor absoluto)

Estos valores no eran flexibles por estrategia ni por empresa, impediendo ajustar la agresividad del motor sin recompilación y cambios en el SP.

**Problema**

- Estrategias diferentes requieren agresividades distintas (conservadora vs agresiva)
- Empresas diferentes operan en mercados con dinámicas distintas
- Cambios de porcentajes requerían modificar SQL y recompilar
- No había auditoría de cuándo o por qué cambiaron los parámetros

**Decisión**

Implementamos la tabla `EstrategiaReglaParametros` para almacenar parámetros configurables por estrategia con:

1. **Estructura de tabla**:
   - FK a `EstrategiaReglas`
   - Campo `Clave` (código del parámetro)
   - Campo `Valor` (numérico configurable)
   - Histórico temporal: `FechaVigencia`, `FechaFin`, `Activo`
   - Auditoría: `FechaCreacion`

2. **Parámetros parametrizados**:
   - `PORCENTAJE_INCREMENTO_STOCK_CRITICO` (ej: 5.00)
   - `PORCENTAJE_INCREMENTO_OPORTUNIDAD` (ej: 3.00)
   - `PORCENTAJE_DECREMENTO_EXCESO_STOCK` (ej: 7.00)
   - `PORCENTAJE_DESCUENTO_COMPETENCIA` (ej: 1.00) [ahora porcentaje, no absoluto]

3. **Carga de parámetros**: Al inicio de `spCalcularDecision`, después de determinar la estrategia, se cargan todos los parámetros vigentes con defaults defensivos.

4. **Aplicación**: Los UPDATEs de reglas usan variables en lugar de hardcodes:
   ```sql
   -- Antes
   SET PrecioSugerido = ctx.PrecioActual * 1.05
   
   -- Después
   SET PrecioSugerido = ctx.PrecioActual * (1 + (@PorcentajeStockCritico / 100))
   ```

**Alternativas consideradas**

| Alternativa | Ventajas | Desventajas | Estado |
|-------------|----------|------------|--------|
| **A: Tabla nueva `EstrategiaReglaParametros`** | Flexible, auditable, permite histórico | Complejidad moderada en queries | ✅ **ELEGIDA** |
| B: Columnas en `EstrategiaReglas` | Simple | Sin histórico, menos escalable | ❌ Descartada |
| C: Reutilizar `ConfiguracionParametros` | Ya existe la tabla | Naming engorroso, mezcla niveles | ❌ Descartada |

**Consecuencias**

### Positivas ✅
- Parametrización sin recompilación: cambios en parámetros son instantáneos
- Histórico temporal: auditoría completa de cambios
- Flexibilidad por estrategia: cada estrategia puede tener porcentajes distintos
- Escalabilidad: fácil agregar más parámetros en futuro
- Defaults defensivos: si parámetro no existe, usa default sensato

### Negativas ⚠️
- Complejidad en queries: 4 SELECTs para cargar parámetros (aceptable, ocurre 1 vez/ejecución)
- Mantenimiento: requiere población inicial de datos en tabla
- Competencia ahora porcentaje: requiere cálculo en lugar de resta simple (más predecible)

**Versión 2.0 del SP**

- Declaración de variables parametrizadas con defaults
- 4 SELECTs para cargar valores vigentes de `EstrategiaReglaParametros`
- Reemplazo de hardcodes en 4 UPDATEs de reglas
- Motivo dinámico que incluye el porcentaje aplicado

**Cambios en Base de Datos**

```sql
-- Nueva tabla
CREATE TABLE EstrategiaReglaParametros (
    ParametroID INT IDENTITY(1,1),
    EstrategiaReglaID INT NOT NULL FK,
    Clave VARCHAR(100),  -- PORCENTAJE_INCREMENTO_STOCK_CRITICO, etc.
    Valor DECIMAL(18,4),
    Descripcion VARCHAR(255),
    FechaVigencia DATETIME2,
    FechaFin DATETIME2,
    Activo BIT,
    FechaCreacion DATETIME2
);
```

**Datos Iniciales Recomendados**

```sql
-- Asumiendo Estrategia 1, Regla STOCK_CRITICO, EstrategiaReg laID = 1
INSERT INTO EstrategiaReglaParametros
VALUES (1, 'PORCENTAJE_INCREMENTO_STOCK_CRITICO', 5.00, 'Default MVP', SYSDATETIME(), NULL, 1, SYSDATETIME());
```

**Términos nuevos en CONTEXT.md**

- **Parámetro de Regla**: Valor configurable que modula el comportamiento de una regla dentro de una estrategia.

**Impacto en otros sistemas**

| Sistema | Impacto |
|---------|---------|
| Frontend Admin | Necesita UI para gestionar parámetros (CRUD en `EstrategiaReglaParametros`) |
| APIs | Posible nuevo endpoint `GET/PUT /api/admin/estrategias/{id}/parametros` |
| Testing | Tests deben validar carga de parámetros y defaults |
| Documentación | Actualizar guía de estrategias para incluir parámetros |

**Riesgos mitigados**

- ✅ Sin parámetro → default defensivo sensato
- ✅ FechaFin NULL → parámetro vigente indefinidamente
- ✅ Histórico temporal → trazabilidad completa
- ✅ Clave única por EstrategiaRegla y FechaFin → evita conflictos

**Próximos pasos**

1. Ejecutar DDL de tabla nueva en ambiente
2. Poblar datos iniciales por cada estrategia existente
3. Crear endpoints admin para CRUD de parámetros
4. Documentar en guía de operación cómo cambiar parámetros
5. (Futuro) Dashboard para visualizar parámetros vigentes vs histórico

---

**Autor**: Equipo de Arquitectura  
**Revisado por**: Product Manager, Tech Lead  
**Aprobado**: 2026-08-18  
**Links relacionados**:
- [CONTEXT.md](../CONTEXT.md) - Término "Parámetro de Regla"
- [spCalcularDecision.sql](../../SQL/spCalcularDecision.sql) - Implementación
- [Estructura.sql](../../SQL/Estructura.sql) - Tabla nueva
