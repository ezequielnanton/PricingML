using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

// #integracionErp: el motor actúa como cliente activo contra el ERP (mismo espíritu que
// un conector de marketplace), en dos sentidos posibles sobre el mismo contrato canónico
// (ErpSyncItem): recibir un POST del ERP, o salir a buscar datos con GET si el ERP expone
// una API de lectura. No hay adaptador por ERP todavía (no hay un ERP concreto elegido);
// cuando aparezca uno con forma de datos distinta, se agrega un adaptador que traduzca a
// este contrato antes de llamar a UpsertItemsAsync.
public class ErpSyncService
{
    private readonly string _connectionString;
    private readonly IHttpClientFactory _httpClientFactory;

    public ErpSyncService(IConfiguration configuration, IHttpClientFactory httpClientFactory)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
        _httpClientFactory = httpClientFactory;
    }

    public async Task<ErpConexionCreateResponse> CreateConexionAsync(ErpConexionCreateRequest dto)
    {
        var apiKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(24));

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"INSERT INTO ErpConexiones (EmpresaID, ApiKeyEntrante, UrlSalida, ApiKeySaliente)
                             VALUES (@empresaId, @apiKeyEntrante, @urlSalida, @apiKeySaliente);
                             SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@apiKeyEntrante", SqlDbType.VarChar, 100).Value = apiKey;
        cmd.Parameters.Add("@urlSalida", SqlDbType.VarChar, 500).Value = (object?)dto.UrlSalida ?? DBNull.Value;
        cmd.Parameters.Add("@apiKeySaliente", SqlDbType.VarChar, 200).Value = (object?)dto.ApiKeySaliente ?? DBNull.Value;
        var idObj = await cmd.ExecuteScalarAsync();

        return new ErpConexionCreateResponse { ErpConexionID = Convert.ToInt32(idObj), ApiKeyEntrante = apiKey };
    }

    public async Task<ErpConexionDetail?> GetConexionAsync(int empresaId)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT ErpConexionID, EmpresaID, UrlSalida, ApiKeySaliente, UltimaSincronizacion
                             FROM ErpConexiones WHERE EmpresaID = @empresaId";
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return null;

        return new ErpConexionDetail
        {
            ErpConexionID = Convert.ToInt32(reader["ErpConexionID"]),
            EmpresaID = empresaId,
            UrlSalida = reader["UrlSalida"] as string,
            ApiKeySaliente = reader["ApiKeySaliente"] as string,
            UltimaSincronizacion = reader["UltimaSincronizacion"] as DateTime?
        };
    }

    public async Task UpdateConexionAsync(int empresaId, ErpConexionUpdateRequest dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"UPDATE ErpConexiones SET UrlSalida = @urlSalida, ApiKeySaliente = @apiKeySaliente
                             WHERE EmpresaID = @empresaId";
        cmd.Parameters.Add("@urlSalida", SqlDbType.VarChar, 500).Value = (object?)dto.UrlSalida ?? DBNull.Value;
        cmd.Parameters.Add("@apiKeySaliente", SqlDbType.VarChar, 200).Value = (object?)dto.ApiKeySaliente ?? DBNull.Value;
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
        var rows = await cmd.ExecuteNonQueryAsync();
        if (rows == 0)
            throw new InvalidOperationException("La empresa no tiene una conexión ERP creada todavía.");
    }

    public async Task<List<ErpCampoMapeoDto>> GetMapeoAsync(int empresaId)
    {
        var list = new List<ErpCampoMapeoDto>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT CampoCanonico, CampoOrigen FROM ErpCampoMapeos WHERE EmpresaID = @empresaId";
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new ErpCampoMapeoDto
            {
                CampoCanonico = reader["CampoCanonico"].ToString() ?? string.Empty,
                CampoOrigen = reader["CampoOrigen"].ToString() ?? string.Empty
            });
        }
        return list;
    }

    public async Task SaveMapeoAsync(int empresaId, ErpMapeoUpdateRequest dto)
    {
        var invalidos = dto.Mapeos
            .Where(m => !ErpCamposCanonicos.Todos.Contains(m.CampoCanonico))
            .Select(m => m.CampoCanonico)
            .ToList();
        if (invalidos.Count > 0)
            throw new ArgumentException($"Campo canónico desconocido: {string.Join(", ", invalidos)}");

        var faltantes = ErpCamposCanonicos.Requeridos
            .Where(req => !dto.Mapeos.Any(m => m.CampoCanonico == req && !string.IsNullOrWhiteSpace(m.CampoOrigen)))
            .ToList();
        if (faltantes.Count > 0)
            throw new ArgumentException($"Faltan mapear campos obligatorios: {string.Join(", ", faltantes)}");

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync();

        await using (var deleteCmd = conn.CreateCommand())
        {
            deleteCmd.Transaction = tx;
            deleteCmd.CommandText = "DELETE FROM ErpCampoMapeos WHERE EmpresaID = @empresaId";
            deleteCmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
            await deleteCmd.ExecuteNonQueryAsync();
        }

        foreach (var mapeo in dto.Mapeos.Where(m => !string.IsNullOrWhiteSpace(m.CampoOrigen)))
        {
            await using var insertCmd = conn.CreateCommand();
            insertCmd.Transaction = tx;
            insertCmd.CommandText = @"INSERT INTO ErpCampoMapeos (EmpresaID, CampoCanonico, CampoOrigen)
                                       VALUES (@empresaId, @campoCanonico, @campoOrigen)";
            insertCmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
            insertCmd.Parameters.Add("@campoCanonico", SqlDbType.VarChar, 50).Value = mapeo.CampoCanonico;
            insertCmd.Parameters.Add("@campoOrigen", SqlDbType.VarChar, 200).Value = mapeo.CampoOrigen;
            await insertCmd.ExecuteNonQueryAsync();
        }

        await tx.CommitAsync();
    }

    // #integracionErp: prueba el GET del ERP y devuelve los nombres de campo que
    // encuentra en el primer item, para que el admin arme el mapeo sin adivinar.
    public async Task<ErpDescubrirCamposResponse> DescubrirCamposAsync(ErpDescubrirCamposRequest dto)
    {
        var client = _httpClientFactory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, dto.Url);
        if (!string.IsNullOrWhiteSpace(dto.ApiKey))
            request.Headers.Add("Authorization", $"Bearer {dto.ApiKey}");

        var response = await client.SendAsync(request);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"El ERP respondió {(int)response.StatusCode}.");

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var items = ExtraerArrayDeItems(doc.RootElement);
        if (items.Count == 0)
            throw new InvalidOperationException("La respuesta del ERP no tiene ningún item para inspeccionar.");

        var primerItem = items[0];
        var muestra = new Dictionary<string, string>();
        foreach (var prop in primerItem.EnumerateObject())
            muestra[prop.Name] = prop.Value.ToString();

        return new ErpDescubrirCamposResponse
        {
            CamposDescubiertos = muestra.Keys.ToList(),
            Muestra = muestra
        };
    }

    // Encuentra el array de items dentro de la respuesta del ERP: si la raíz ya es un
    // array lo usa directo; si es un objeto, toma la primera propiedad que sea un array
    // (cubre formas comunes como {"items":[...]}, {"data":[...]}, {"productos":[...]}).
    private static List<JsonElement> ExtraerArrayDeItems(JsonElement root)
    {
        if (root.ValueKind == JsonValueKind.Array)
            return root.EnumerateArray().ToList();

        if (root.ValueKind == JsonValueKind.Object)
        {
            foreach (var prop in root.EnumerateObject())
            {
                if (prop.Value.ValueKind == JsonValueKind.Array)
                    return prop.Value.EnumerateArray().ToList();
            }
        }

        return new List<JsonElement>();
    }

    private static ErpSyncItem AplicarMapeo(JsonElement rawItem, Dictionary<string, string> mapeoPorCampo)
    {
        var item = new ErpSyncItem();

        string? ObtenerCrudo(string campoCanonico)
        {
            if (!mapeoPorCampo.TryGetValue(campoCanonico, out var campoOrigen))
                return null;
            foreach (var prop in rawItem.EnumerateObject())
            {
                if (string.Equals(prop.Name, campoOrigen, StringComparison.OrdinalIgnoreCase))
                    return prop.Value.ValueKind == JsonValueKind.String ? prop.Value.GetString() : prop.Value.ToString();
            }
            return null;
        }

        item.SKU = ObtenerCrudo(ErpCamposCanonicos.SKU) ?? string.Empty;
        item.Titulo = ObtenerCrudo(ErpCamposCanonicos.Titulo);
        item.CostoCompra = ParseDecimal(ObtenerCrudo(ErpCamposCanonicos.CostoCompra)) ?? 0;
        item.PorcentajeIVA = ParseDecimal(ObtenerCrudo(ErpCamposCanonicos.PorcentajeIVA));
        item.ImpuestosInternos = ParseDecimal(ObtenerCrudo(ErpCamposCanonicos.ImpuestosInternos));
        item.StockActual = ParseInt(ObtenerCrudo(ErpCamposCanonicos.StockActual)) ?? 0;
        item.StockMinimo = ParseInt(ObtenerCrudo(ErpCamposCanonicos.StockMinimo));
        item.StockMaximo = ParseInt(ObtenerCrudo(ErpCamposCanonicos.StockMaximo));

        return item;
    }

    private static decimal? ParseDecimal(string? raw) =>
        decimal.TryParse(raw, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var value)
            ? value : null;

    private static int? ParseInt(string? raw) =>
        int.TryParse(raw, out var value) ? value
        : decimal.TryParse(raw, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var dec) ? (int)dec
        : null;

    public async Task<int?> ResolveEmpresaByApiKeyAsync(string apiKey)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT EmpresaID FROM ErpConexiones WHERE ApiKeyEntrante = @apiKey AND Activo = 1";
        cmd.Parameters.Add("@apiKey", SqlDbType.VarChar, 100).Value = apiKey;
        var result = await cmd.ExecuteScalarAsync();
        return result is null ? null : Convert.ToInt32(result);
    }

    public async Task<ErpSyncResult> UpsertItemsAsync(int empresaId, IEnumerable<ErpSyncItem> items)
    {
        var result = new ErpSyncResult();

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        foreach (var item in items)
        {
            if (string.IsNullOrWhiteSpace(item.SKU))
            {
                result.Errores++;
                result.DetalleErrores.Add(new ErpSyncItemError { SKU = "(vacío)", Mensaje = "SKU obligatorio." });
                continue;
            }

            try
            {
                await using var tx = (SqlTransaction)await conn.BeginTransactionAsync();

                int productoId;
                await using (var findCmd = conn.CreateCommand())
                {
                    findCmd.Transaction = tx;
                    findCmd.CommandText = "SELECT ProductoID FROM Productos WHERE EmpresaID = @empresaId AND SKU = @sku";
                    findCmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
                    findCmd.Parameters.Add("@sku", SqlDbType.VarChar, 50).Value = item.SKU;
                    var existing = await findCmd.ExecuteScalarAsync();

                    if (existing is null)
                    {
                        await using var insertCmd = conn.CreateCommand();
                        insertCmd.Transaction = tx;
                        insertCmd.CommandText = @"INSERT INTO Productos (EmpresaID, SKU, Titulo)
                                                   VALUES (@empresaId, @sku, @titulo);
                                                   SELECT SCOPE_IDENTITY();";
                        insertCmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
                        insertCmd.Parameters.Add("@sku", SqlDbType.VarChar, 50).Value = item.SKU;
                        insertCmd.Parameters.Add("@titulo", SqlDbType.VarChar, 255).Value =
                            string.IsNullOrWhiteSpace(item.Titulo) ? item.SKU : item.Titulo;
                        productoId = Convert.ToInt32(await insertCmd.ExecuteScalarAsync());
                    }
                    else
                    {
                        productoId = Convert.ToInt32(existing);
                        if (!string.IsNullOrWhiteSpace(item.Titulo))
                        {
                            await using var updateTituloCmd = conn.CreateCommand();
                            updateTituloCmd.Transaction = tx;
                            updateTituloCmd.CommandText = "UPDATE Productos SET Titulo = @titulo WHERE ProductoID = @productoId";
                            updateTituloCmd.Parameters.Add("@titulo", SqlDbType.VarChar, 255).Value = item.Titulo;
                            updateTituloCmd.Parameters.Add("@productoId", SqlDbType.Int).Value = productoId;
                            await updateTituloCmd.ExecuteNonQueryAsync();
                        }
                    }
                }

                // CostosProducto: el ERP solo es dueño de CostoCompra/IVA/ImpuestosInternos;
                // CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc
                // y OtrosCostosFijos los configura el analista de pricing y nunca se tocan acá.
                await using (var costoCmd = conn.CreateCommand())
                {
                    costoCmd.Transaction = tx;
                    costoCmd.CommandText = @"
                        MERGE CostosProducto AS target
                        USING (SELECT @productoId AS ProductoID) AS src
                        ON target.ProductoID = src.ProductoID
                        WHEN MATCHED THEN UPDATE SET
                            CostoCompra = @costoCompra,
                            PorcentajeIVA = COALESCE(@porcentajeIVA, target.PorcentajeIVA),
                            ImpuestosInternos = COALESCE(@impuestosInternos, target.ImpuestosInternos),
                            FechaUltimaActualizacion = SYSDATETIME()
                        WHEN NOT MATCHED THEN INSERT (ProductoID, CostoCompra, PorcentajeIVA, ImpuestosInternos)
                            VALUES (@productoId, @costoCompra, COALESCE(@porcentajeIVA, 21.00), COALESCE(@impuestosInternos, 0));";
                    costoCmd.Parameters.Add("@productoId", SqlDbType.Int).Value = productoId;
                    costoCmd.Parameters.Add("@costoCompra", SqlDbType.Decimal).Value = item.CostoCompra;
                    costoCmd.Parameters.Add("@porcentajeIVA", SqlDbType.Decimal).Value = (object?)item.PorcentajeIVA ?? DBNull.Value;
                    costoCmd.Parameters.Add("@impuestosInternos", SqlDbType.Decimal).Value = (object?)item.ImpuestosInternos ?? DBNull.Value;
                    await costoCmd.ExecuteNonQueryAsync();
                }

                // StockEstado: el ERP es dueño de StockActual (y opcionalmente Min/Max);
                // StockObjetivo lo sigue manejando el motor.
                await using (var stockCmd = conn.CreateCommand())
                {
                    stockCmd.Transaction = tx;
                    stockCmd.CommandText = @"
                        MERGE StockEstado AS target
                        USING (SELECT @productoId AS ProductoID) AS src
                        ON target.ProductoID = src.ProductoID
                        WHEN MATCHED THEN UPDATE SET
                            StockActual = @stockActual,
                            StockMinimo = COALESCE(@stockMinimo, target.StockMinimo),
                            StockMaximo = COALESCE(@stockMaximo, target.StockMaximo),
                            FechaActualizacion = SYSDATETIME()
                        WHEN NOT MATCHED THEN INSERT (ProductoID, StockActual, StockMinimo, StockMaximo)
                            VALUES (@productoId, @stockActual, COALESCE(@stockMinimo, 5), COALESCE(@stockMaximo, 100));";
                    stockCmd.Parameters.Add("@productoId", SqlDbType.Int).Value = productoId;
                    stockCmd.Parameters.Add("@stockActual", SqlDbType.Int).Value = item.StockActual;
                    stockCmd.Parameters.Add("@stockMinimo", SqlDbType.Int).Value = (object?)item.StockMinimo ?? DBNull.Value;
                    stockCmd.Parameters.Add("@stockMaximo", SqlDbType.Int).Value = (object?)item.StockMaximo ?? DBNull.Value;
                    await stockCmd.ExecuteNonQueryAsync();
                }

                await tx.CommitAsync();
                result.Procesados++;
            }
            catch (Exception ex)
            {
                result.Errores++;
                result.DetalleErrores.Add(new ErpSyncItemError { SKU = item.SKU, Mensaje = ex.Message });
            }
        }

        return result;
    }

    public async Task LogSincronizacionAsync(int empresaId, string direccion, ErpSyncResult result)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"INSERT INTO ErpSincronizaciones (EmpresaID, Direccion, CantidadProcesados, CantidadErrores, DetalleErrores)
                             VALUES (@empresaId, @direccion, @procesados, @errores, @detalle)";
        cmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
        cmd.Parameters.Add("@direccion", SqlDbType.VarChar, 10).Value = direccion;
        cmd.Parameters.Add("@procesados", SqlDbType.Int).Value = result.Procesados;
        cmd.Parameters.Add("@errores", SqlDbType.Int).Value = result.Errores;
        cmd.Parameters.Add("@detalle", SqlDbType.VarChar).Value =
            result.DetalleErrores.Count == 0 ? DBNull.Value : (object)JsonSerializer.Serialize(result.DetalleErrores);
        await cmd.ExecuteNonQueryAsync();

        await using var updateCmd = conn.CreateCommand();
        updateCmd.CommandText = "UPDATE ErpConexiones SET UltimaSincronizacion = SYSDATETIME() WHERE EmpresaID = @empresaId";
        updateCmd.Parameters.Add("@empresaId", SqlDbType.Int).Value = empresaId;
        await updateCmd.ExecuteNonQueryAsync();
    }

    private record ConexionSalida(int EmpresaID, string RazonSocial, string UrlSalida, string? ApiKeySaliente);

    private async Task<List<ConexionSalida>> GetConexionesConUrlSalidaAsync()
    {
        var list = new List<ConexionSalida>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT ec.EmpresaID, e.RazonSocial, ec.UrlSalida, ec.ApiKeySaliente
                             FROM ErpConexiones ec
                             JOIN Empresas e ON e.EmpresaID = ec.EmpresaID
                             WHERE ec.Activo = 1 AND ec.UrlSalida IS NOT NULL AND ec.UrlSalida <> ''";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new ConexionSalida(
                Convert.ToInt32(reader["EmpresaID"]),
                reader["RazonSocial"].ToString() ?? string.Empty,
                reader["UrlSalida"].ToString() ?? string.Empty,
                reader["ApiKeySaliente"] as string));
        }
        return list;
    }

    // #cargaOperativaRepositor-style manual trigger: dispara un GET contra cada ERP
    // configurado con UrlSalida y aplica el mismo upsert que el camino de entrada.
    public async Task<List<ErpPullSummary>> PullFromAllConfiguredErpsAsync()
    {
        var conexiones = await GetConexionesConUrlSalidaAsync();
        var summaries = new List<ErpPullSummary>();

        foreach (var conexion in conexiones)
        {
            var summary = new ErpPullSummary { EmpresaID = conexion.EmpresaID, RazonSocial = conexion.RazonSocial };
            try
            {
                var client = _httpClientFactory.CreateClient();
                using var request = new HttpRequestMessage(HttpMethod.Get, conexion.UrlSalida);
                if (!string.IsNullOrWhiteSpace(conexion.ApiKeySaliente))
                    request.Headers.Add("Authorization", $"Bearer {conexion.ApiKeySaliente}");

                var response = await client.SendAsync(request);
                if (!response.IsSuccessStatusCode)
                {
                    summary.Ok = false;
                    summary.Error = $"El ERP respondió {(int)response.StatusCode}.";
                    summaries.Add(summary);
                    continue;
                }

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var rawItems = ExtraerArrayDeItems(doc.RootElement);

                if (rawItems.Count == 0)
                {
                    summary.Ok = true;
                    summary.Resultado = new ErpSyncResult();
                    summaries.Add(summary);
                    continue;
                }

                // Si la empresa configuró un mapeo (pantalla de Integración ERP), se traduce
                // cada campo real del ERP al contrato canónico. Si no configuró nada, se asume
                // que el ERP ya devuelve el contrato canónico directamente (mapeo identidad).
                var mapeoConfigurado = await GetMapeoAsync(conexion.EmpresaID);
                var mapeoPorCampo = mapeoConfigurado.Count > 0
                    ? mapeoConfigurado.ToDictionary(m => m.CampoCanonico, m => m.CampoOrigen)
                    : ErpCamposCanonicos.Todos.ToDictionary(c => c, c => c);

                var items = rawItems.Select(raw => AplicarMapeo(raw, mapeoPorCampo)).ToList();

                var result = await UpsertItemsAsync(conexion.EmpresaID, items);
                await LogSincronizacionAsync(conexion.EmpresaID, "SALIENTE", result);
                summary.Ok = true;
                summary.Resultado = result;
            }
            catch (Exception ex)
            {
                summary.Ok = false;
                summary.Error = ex.Message;
            }
            summaries.Add(summary);
        }

        return summaries;
    }
}
