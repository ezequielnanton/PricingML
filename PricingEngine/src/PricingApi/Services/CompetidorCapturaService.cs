using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

public class CompetidorCapturaService(SqlPricingService sqlService)
{
    private readonly SqlPricingService _sqlService = sqlService;

    public async Task<CompetidorCapturadoResponse> CapturarCompetidorAsync(
        CompetidorCapturadoRequest request)
    {
        try
        {
            // Validar datos básicos
            if (string.IsNullOrWhiteSpace(request.MeliItemId) || string.IsNullOrWhiteSpace(request.Titulo))
                return new CompetidorCapturadoResponse
                {
                    Vinculado = false,
                    Mensaje = "Faltan datos requeridos: MeliItemId, Titulo"
                };

            if (request.Precio <= 0)
                return new CompetidorCapturadoResponse
                {
                    Vinculado = false,
                    Mensaje = "Precio debe ser mayor a 0"
                };

            // Buscar por GTIN en el título o atributos
            var publicacionMatch = await BuscarPublicacionPorGtinOTituloAsync(request.Titulo);

            if (publicacionMatch is null)
                return new CompetidorCapturadoResponse
                {
                    Vinculado = false,
                    Mensaje = $"No se encontró un producto propio con características similares a '{request.Titulo}'"
                };

            // Vincular en BD
            var vinculoId = await VincularCompetidorAsync(
                publicacionMatch.PublicacionID,
                request.MeliItemId,
                request.Titulo,
                request.Precio,
                request.MonedaId,
                request.Vendedor,
                request.Link);

            if (vinculoId <= 0)
                return new CompetidorCapturadoResponse
                {
                    Vinculado = false,
                    Mensaje = "Error al vincular competidor en base de datos"
                };

            // Insertar snapshot
            await InsertarSnapshotAsync(publicacionMatch.PublicacionID, request.MeliItemId, request.Precio, request.MonedaId);

            return new CompetidorCapturadoResponse
            {
                Vinculado = true,
                PublicacionId = publicacionMatch.PublicacionID,
                ProductoId = publicacionMatch.ProductoID,
                ProductoNombre = publicacionMatch.ProductoNombre,
                RecomendacionNueva = null, // El motor la calcula, no aquí
                Motivo = $"Competidor capturado: {request.Titulo} a ${request.Precio}",
                Mensaje = "✓ Competidor vinculado correctamente"
            };
        }
        catch (Exception ex)
        {
            return new CompetidorCapturadoResponse
            {
                Vinculado = false,
                Mensaje = $"Error: {ex.Message}"
            };
        }
    }

    private async Task<(int PublicacionID, int ProductoID, string ProductoNombre)?> BuscarPublicacionPorGtinOTituloAsync(string titulo)
    {
        // Extraer posibles GTINs/EANs del título (13 o 12 dígitos consecutivos)
        var gtin = Regex.Match(titulo, @"\b(\d{12,13})\b").Groups[1].Value;

        using var connection = new SqlConnection(_sqlService.GetConnectionString());
        await connection.OpenAsync();

        // Primero por GTIN si lo encontramos
        if (!string.IsNullOrWhiteSpace(gtin))
        {
            const string sqlGtin = @"
                SELECT TOP 1 pm.PublicacionID, p.ProductoID, p.ProductoNombre
                FROM PublicacionesML pm
                INNER JOIN Productos p ON pm.ProductoID = p.ProductoID
                WHERE pm.CodigoBarras = @Gtin OR pm.CodigoBarrasAlternativo = @Gtin
                ORDER BY pm.PublicacionID DESC";

            using var cmd = new SqlCommand(sqlGtin, connection);
            cmd.Parameters.AddWithValue("@Gtin", gtin);

            using var reader = await cmd.ExecuteReaderAsync();
            if (reader.HasRows && await reader.ReadAsync())
                return (
                    reader.GetInt32(0),
                    reader.GetInt32(1),
                    reader.GetString(2));
        }

        // Sino, búsqueda fuzzy por similitud de título
        const string sqlTitulo = @"
            SELECT TOP 1 pm.PublicacionID, p.ProductoID, p.ProductoNombre
            FROM PublicacionesML pm
            INNER JOIN Productos p ON pm.ProductoID = p.ProductoID
            WHERE UPPER(p.ProductoNombre) LIKE '%' + UPPER(@TituloFuzzy) + '%'
            ORDER BY pm.PublicacionID DESC";

        using var cmdTitulo = new SqlCommand(sqlTitulo, connection);
        // Usar primeras palabras del título para búsqueda fuzzy
        var palabrasClave = string.Join(" ", titulo.Split(' ').Take(3));
        cmdTitulo.Parameters.AddWithValue("@TituloFuzzy", palabrasClave);

        using var readerTitulo = await cmdTitulo.ExecuteReaderAsync();
        if (readerTitulo.HasRows && await readerTitulo.ReadAsync())
            return (
                readerTitulo.GetInt32(0),
                readerTitulo.GetInt32(1),
                readerTitulo.GetString(2));

        return null;
    }

    private async Task<int> VincularCompetidorAsync(
        int publicacionId,
        string meliItemId,
        string titulo,
        decimal precio,
        int monedaId,
        string? vendedor,
        string? link)
    {
        using var connection = new SqlConnection(_sqlService.GetConnectionString());
        await connection.OpenAsync();

        const string sql = @"
            INSERT INTO PublicacionCompetidoresManual
                (PublicacionID, CompetidorItemID, CompetidorTitulo, CompetidorVendedorID,
                 UltimoPrecio, MonedaID, FechaUltimoPrecio, Activo, Link)
            VALUES
                (@PublicacionID, @CompetidorItemID, @CompetidorTitulo, @CompetidorVendedorID,
                 @UltimoPrecio, @MonedaID, @FechaUltimoPrecio, 1, @Link);
            SELECT CAST(SCOPE_IDENTITY() AS INT);";

        using var cmd = new SqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@PublicacionID", publicacionId);
        cmd.Parameters.AddWithValue("@CompetidorItemID", meliItemId);
        cmd.Parameters.AddWithValue("@CompetidorTitulo", titulo);
        cmd.Parameters.AddWithValue("@CompetidorVendedorID", (object?)vendedor ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@UltimoPrecio", precio);
        cmd.Parameters.AddWithValue("@MonedaID", monedaId);
        cmd.Parameters.AddWithValue("@FechaUltimoPrecio", DateTime.UtcNow);
        cmd.Parameters.AddWithValue("@Link", (object?)link ?? DBNull.Value);

        var result = await cmd.ExecuteScalarAsync();
        return result is int id ? id : 0;
    }

    private async Task InsertarSnapshotAsync(
        int publicacionId,
        string competidorItemId,
        decimal precio,
        int monedaId)
    {
        using var connection = new SqlConnection(_sqlService.GetConnectionString());
        await connection.OpenAsync();

        const string sql = @"
            INSERT INTO CompetenciaSnapshot
                (PublicacionID, CompetidorItemID, PrecioCompetidor, MonedaID, FechaCaptura)
            VALUES
                (@PublicacionID, @CompetidorItemID, @PrecioCompetidor, @MonedaID, @FechaCaptura)";

        using var cmd = new SqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@PublicacionID", publicacionId);
        cmd.Parameters.AddWithValue("@CompetidorItemID", competidorItemId);
        cmd.Parameters.AddWithValue("@PrecioCompetidor", precio);
        cmd.Parameters.AddWithValue("@MonedaID", monedaId);
        cmd.Parameters.AddWithValue("@FechaCaptura", DateTime.UtcNow);

        await cmd.ExecuteNonQueryAsync();
    }
}
