# Guía técnica para continuar Pricing Engine

Esta guía explica el proyecto desde cero. No hace falta memorizarla: usala como mapa cuando quieras agregar o modificar una API.

## 1. Qué hace el proyecto

Pricing Engine calcula o administra precios de productos publicados en Mercado Libre. Guarda empresas, productos, costos, stock, competencia y decisiones en una base de datos. La aplicación web o un cliente HTTP le pide información a la API; la API consulta SQL Server y responde JSON.

```text
Frontend / Postman
       │ petición HTTP (GET, POST...)
       ▼
PricingApi (C# / ASP.NET Core)
       │ consultas parametrizadas
       ▼
SQL Server (PRICES_DB)
```

## 2. Tecnologías usadas

| Tecnología | Para qué se usa | Dónde verla |
| --- | --- | --- |
| C# | Lenguaje principal del backend. | `src/PricingApi` |
| .NET 10 | Plataforma que compila y ejecuta C#. | archivos `.csproj` |
| ASP.NET Core Minimal API | Crea las rutas HTTP con `app.MapGet`, `app.MapPost`, etc. | `src/PricingApi/Program.cs` |
| SQL Server Express | Base de datos relacional local. | `SQL/Estructura.sql` |
| Microsoft.Data.SqlClient | Conector de C# para ejecutar comandos SQL con parámetros. | servicios en `src/PricingApi/Services` |
| Swagger / OpenAPI | Pantalla para descubrir y probar la API en desarrollo. | `/swagger` al ejecutar la API |
| JSON | Formato de entrada y salida de las APIs. | DTOs en `src/PricingApi/Models` |
| xUnit | Framework de pruebas automatizadas. | `src/PricingApi.Tests` |
| PricingAdapter | Capa que adapta datos externos/UI al modelo interno. | `src/PricingAdapter` |

### Conceptos mínimos

- **API**: conjunto de URLs que otros programas pueden llamar.
- **Endpoint**: una URL más un método HTTP. Ejemplo: `GET /api/admin/empresas`.
- **DTO**: clase que representa los datos que entran o salen de una API. Ejemplo: `EmpresaDto`.
- **Servicio**: clase que concentra la lógica y acceso a datos. Ejemplo: `AdminCrudService`.
- **Base de datos**: tablas con filas. `Empresas` es una tabla; una empresa concreta es una fila.
- **JSON**: texto estructurado, por ejemplo `{ "razonSocial": "Mi empresa", "activo": true }`.

## 3. Archivos importantes

| Archivo o carpeta | Responsabilidad |
| --- | --- |
| `src/PricingApi/Program.cs` | Punto de inicio; registra servicios y define endpoints. |
| `src/PricingApi/Models/` | DTOs: forma de los datos recibidos. |
| `src/PricingApi/Services/AdminCrudService.cs` | Operaciones administrativas que escriben/leen SQL. |
| `src/PricingApi/Services/AdminReportsService.cs` | Reportes de solo lectura, paginación, filtros y ordenamiento seguros. |
| `src/PricingApi/appsettings.json` | Configuración; contiene la cadena de conexión local. No subir secretos reales. |
| `SQL/Estructura.sql` | Definición de tablas, relaciones e índices. |
| `src/PricingApi.Tests/` | Pruebas automatizadas. |

## 4. Cómo ejecutar y probar

1. Tener SQL Server Express iniciado y crear la base ejecutando `SQL/Estructura.sql`.
2. Revisar `src/PricingApi/appsettings.json`; el servidor y base deben coincidir con tu instalación.
3. Desde la raíz del proyecto ejecutar:

```powershell
dotnet run --project src/PricingApi
```

4. Abrir la dirección que muestra la consola y agregar `/swagger`; allí se pueden probar rutas sin Postman.
5. Para ejecutar pruebas:

```powershell
dotnet test src/PricingApi.Tests/PricingApi.Tests.csproj
```

## 5. Métodos HTTP

<a id="crearGet"></a>
### GET: consultar datos

`GET` no debe modificar datos. Se usa para listados o buscar un registro.

```csharp
app.MapGet("/api/admin/empresas/{id:int}", async (int id, AdminCrudService svc) =>
{
    var empresa = await svc.GetEmpresaAsync(id);
    return empresa is null ? Results.NotFound() : Results.Ok(empresa);
});
```

- `{id:int}` toma una parte de la URL y exige que sea un número entero.
- `Results.Ok(...)` responde HTTP `200`.
- `Results.NotFound()` responde HTTP `404` si no existe.
- En reportes se usa `GET /api/admin/recurso?page=1&pageSize=50`.

<a id="crearPost"></a>
### POST: crear un registro

`POST` recibe un JSON y crea algo nuevo. El DTO se completa automáticamente a partir del cuerpo JSON.

```csharp
app.MapPost("/api/admin/monedas", async (MonedaDto dto, AdminCrudService svc) =>
{
    var id = await svc.CreateMonedaAsync(dto);
    return Results.Created($"/api/admin/monedas/{id}", new { monedaId = id });
});
```

Usar `201 Created` cuando se creó correctamente. La URL entregada debe identificar al recurso recién creado.

<a id="crearPut"></a>
### PUT: reemplazar o actualizar un registro

`PUT` actualiza un recurso que ya existe. En este proyecto se usa con un ID en la URL y un DTO en el cuerpo.

```csharp
app.MapPut("/api/admin/empresas/{id:int}", async (int id, EmpresaDto dto, AdminCrudService svc) =>
{
    await svc.UpdateEmpresaAsync(id, dto);
    return Results.NoContent();
});
```

`204 No Content` significa que se actualizó y no hay JSON para devolver.

<a id="crearDelete"></a>
### DELETE: eliminar un registro

`DELETE` quita un recurso. Es el método más riesgoso porque puede romper relaciones entre tablas. Antes de agregarlo, confirmar que la tabla no sea historial, auditoría o cola de ejecución y que la regla de negocio permita borrar.

```csharp
app.MapDelete("/api/admin/empresas/{id:int}", async (int id, AdminCrudService svc) =>
{
    await svc.DeleteEmpresaAsync(id);
    return Results.NoContent();
});
```

No crear `POST`, `PUT` ni `DELETE` para historial de decisiones, auditoría o cola de ejecución: son recursos de lectura/auditoría.

<a id="crearApi"></a>
## 6. Receta: crear una nueva API

Como ejemplo, supongamos que se agrega una tabla `Categorias`.

1. **Diseñar la tabla** en `SQL/Estructura.sql`, con una clave primaria y las relaciones necesarias.
2. **Crear el DTO** `src/PricingApi/Models/CategoriaDto.cs`. Solo colocar los campos que la API necesita recibir:

```csharp
namespace PricingApi.Models;
public class CategoriaDto
{
    public int CategoriaID { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public bool Activa { get; set; }
}
```

3. **Agregar métodos al servicio**. Siempre abrir conexión, usar `@parametros` y nunca unir valores del usuario dentro del texto SQL:

```csharp
public async Task<int> CreateCategoriaAsync(CategoriaDto dto)
{
    await using var conn = new SqlConnection(_connectionString);
    await conn.OpenAsync();
    await using var cmd = conn.CreateCommand();
    cmd.CommandText = "INSERT INTO Categorias (Nombre, Activa) VALUES (@nombre, @activa); SELECT SCOPE_IDENTITY();";
    cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 100).Value = dto.Nombre;
    cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
    return Convert.ToInt32(await cmd.ExecuteScalarAsync());
}
```

4. **Registrar el endpoint** en `Program.cs`. Usar el método HTTP correcto de la sección anterior.
5. **Agregar un reporte**, si la UI debe listar la tabla. Incorporar una definición en `AdminReportsService.CreateDefinitions()`: recurso, tabla, columnas permitidas y orden por defecto. No aceptar nombres de columnas enviados directamente por el cliente.
6. **Crear pruebas** que cubran éxito, datos inválidos y, para SQL, entradas como `' OR 1=1 --`.
7. Ejecutar `dotnet test` y probar manualmente con Swagger.

## 7. Cómo funcionan los reportes administrativos

Cada reporte usa `GET /api/admin/{recurso}` y responde:

```json
{ "items": [], "page": 1, "pageSize": 50, "totalCount": 0 }
```

Ejemplo:

```text
GET /api/admin/productos?page=1&pageSize=20&filter[sku][contains]=ABC&sort=sku:asc
```

`AdminReportsService` es importante por seguridad: la lista `Definitions` decide qué tabla y columnas existen. Los valores de filtros se envían a SQL como parámetros, por lo que el texto del usuario no se ejecuta como SQL.

Al agregar un campo al reporte:

1. Confirmar que no sea sensible (por ejemplo, tokens).
2. Agregarlo a la lista de columnas del recurso.
3. Verificar que `Kind(...)` le asigne el tipo correcto (`Text`, `Int`, `Decimal`, `Boolean` o `DateTime`).
4. Agregar una prueba de filtro y ordenamiento para ese campo.

## 8. Errores HTTP más comunes

| Código | Significado | Cuándo usarlo |
| --- | --- | --- |
| 200 OK | Todo salió bien. | GET exitoso. |
| 201 Created | Se creó algo. | POST exitoso. |
| 204 No Content | Operación exitosa sin respuesta. | PUT o DELETE exitoso. |
| 400 Bad Request | El cliente envió datos inválidos. | Tipo, filtro, página o campo inválido. |
| 404 Not Found | No existe el recurso pedido. | GET por ID inexistente. |
| 500 Internal Server Error | Error inesperado del servidor. | No exponer SQL ni detalles internos. |

## 9. Checklist antes de terminar un cambio

- ¿El endpoint usa el verbo HTTP correcto?
- ¿El DTO tiene validaciones básicas y nombres claros?
- ¿La consulta SQL usa parámetros (`@nombre`) para todo valor externo?
- ¿No se exponen contraseñas, tokens u otros secretos?
- ¿La respuesta JSON usa `camelCase`?
- ¿Se agregaron pruebas?
- ¿`dotnet test` termina correctamente?
- ¿Swagger permite probar el endpoint?

## 10. Cuando no sepas dónde cambiar algo

Seguí el recorrido de los datos: URL en `Program.cs` → DTO en `Models` → método del servicio → tabla/SQL. Hacé cambios pequeños, ejecutá pruebas después de cada uno y no borres una tabla o endpoint sin verificar quién lo usa.
