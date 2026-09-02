using System.Data;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

public class AdminCrudService
{
    private readonly string _connectionString;

    public AdminCrudService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
    }

    // Empresas
    public async Task<IEnumerable<EmpresaDto>> GetEmpresasAsync()
    {
        var list = new List<EmpresaDto>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT EmpresaID, RazonSocial, CUIT, Activo, FechaCreacion FROM Empresas";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new EmpresaDto
            {
                EmpresaID = Convert.ToInt32(reader["EmpresaID"]),
                RazonSocial = reader["RazonSocial"].ToString() ?? string.Empty,
                CUIT = reader["CUIT"].ToString() ?? string.Empty,
                Activo = Convert.ToBoolean(reader["Activo"]),
                FechaCreacion = Convert.ToDateTime(reader["FechaCreacion"])
            });
        }
        return list;
    }

    public async Task<EmpresaDto?> GetEmpresaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT EmpresaID, RazonSocial, CUIT, Activo, FechaCreacion FROM Empresas WHERE EmpresaID = @id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new EmpresaDto
            {
                EmpresaID = Convert.ToInt32(reader["EmpresaID"]),
                RazonSocial = reader["RazonSocial"].ToString() ?? string.Empty,
                CUIT = reader["CUIT"].ToString() ?? string.Empty,
                Activo = Convert.ToBoolean(reader["Activo"]),
                FechaCreacion = Convert.ToDateTime(reader["FechaCreacion"])
            };
        }
        return null;
    }

    public async Task<int> CreateEmpresaAsync(EmpresaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO Empresas (RazonSocial, CUIT, Activo, FechaCreacion) VALUES (@razon, @cuit, @activo, SYSDATETIME()); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@razon", SqlDbType.VarChar, 150).Value = dto.RazonSocial;
        cmd.Parameters.Add("@cuit", SqlDbType.VarChar, 20).Value = dto.CUIT;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateEmpresaAsync(int id, EmpresaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Empresas SET RazonSocial=@razon, CUIT=@cuit, Activo=@activo WHERE EmpresaID=@id";
        cmd.Parameters.Add("@razon", SqlDbType.VarChar, 150).Value = dto.RazonSocial;
        cmd.Parameters.Add("@cuit", SqlDbType.VarChar, 20).Value = dto.CUIT;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteEmpresaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM Empresas WHERE EmpresaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // NOTE: For brevity, implement basic CRUD patterns for a representative set of tables below.
    // Monedas
    public async Task<IEnumerable<MonedaDto>> GetMonedasAsync()
    {
        var list = new List<MonedaDto>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT MonedaID, CodigoISO, Nombre, Simbolo, Activa FROM Monedas";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new MonedaDto
            {
                MonedaID = Convert.ToInt32(reader["MonedaID"]),
                CodigoISO = reader["CodigoISO"].ToString() ?? string.Empty,
                Nombre = reader["Nombre"].ToString() ?? string.Empty,
                Simbolo = reader.IsDBNull(reader.GetOrdinal("Simbolo")) ? null : reader["Simbolo"].ToString(),
                Activa = Convert.ToBoolean(reader["Activa"])
            });
        }
        return list;
    }

    public async Task<int> CreateMonedaAsync(MonedaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO Monedas (CodigoISO, Nombre, Simbolo, Activa) VALUES (@code, @name, @simbolo, @activa); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@code", SqlDbType.VarChar, 3).Value = dto.CodigoISO.Trim().ToUpperInvariant();
        cmd.Parameters.Add("@name", SqlDbType.VarChar, 100).Value = dto.Nombre;
        cmd.Parameters.Add("@simbolo", SqlDbType.VarChar, 10).Value = (object?)dto.Simbolo ?? DBNull.Value;
        cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateMonedaAsync(int id, MonedaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Monedas SET CodigoISO=@code, Nombre=@name, Simbolo=@simbolo, Activa=@activa WHERE MonedaID=@id";
        cmd.Parameters.Add("@code", SqlDbType.VarChar, 3).Value = dto.CodigoISO.Trim().ToUpperInvariant();
        cmd.Parameters.Add("@name", SqlDbType.VarChar, 100).Value = dto.Nombre;
        cmd.Parameters.Add("@simbolo", SqlDbType.VarChar, 10).Value = (object?)dto.Simbolo ?? DBNull.Value;
        cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteMonedaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM Monedas WHERE MonedaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // Cotizaciones
    public async Task<long> CreateCotizacionAsync(CotizacionDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO Cotizaciones (MonedaID, Cotizacion, FechaCotizacion) VALUES (@moneda, @cot, @fecha); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@moneda", SqlDbType.Int).Value = dto.MonedaID;
        cmd.Parameters.Add("@cot", SqlDbType.Decimal).Value = dto.Cotizacion;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = dto.FechaCotizacion;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt64(idObj);
    }

    public async Task UpdateCotizacionAsync(long id, CotizacionDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Cotizaciones SET MonedaID=@moneda, Cotizacion=@cot, FechaCotizacion=@fecha WHERE CotizacionID=@id";
        cmd.Parameters.Add("@moneda", SqlDbType.Int).Value = dto.MonedaID;
        cmd.Parameters.Add("@cot", SqlDbType.Decimal).Value = dto.Cotizacion;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = dto.FechaCotizacion;
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteCotizacionAsync(long id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM Cotizaciones WHERE CotizacionID=@id";
        cmd.Parameters.Add("@id", SqlDbType.BigInt).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // ParametrosGenerales
    public async Task<int> CreateParametroGeneralAsync(ParametroGeneralDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO ParametrosGenerales (EmpresaID, MonedaPrincipalID, MonedaSecundariaID, SubidaAutomaticaCatalogoML) VALUES (@empresa, @mp, @ms, @autoMl); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@mp", SqlDbType.Int).Value = dto.MonedaPrincipalID;
        cmd.Parameters.Add("@ms", SqlDbType.Int).Value = dto.MonedaSecundariaID;
        cmd.Parameters.Add("@autoMl", SqlDbType.Bit).Value = dto.SubidaAutomaticaCatalogoML;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateParametroGeneralAsync(int id, ParametroGeneralDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE ParametrosGenerales SET EmpresaID=@empresa, MonedaPrincipalID=@mp, MonedaSecundariaID=@ms, SubidaAutomaticaCatalogoML=@autoMl WHERE ParametroGeneralID=@id";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@mp", SqlDbType.Int).Value = dto.MonedaPrincipalID;
        cmd.Parameters.Add("@ms", SqlDbType.Int).Value = dto.MonedaSecundariaID;
        cmd.Parameters.Add("@autoMl", SqlDbType.Bit).Value = dto.SubidaAutomaticaCatalogoML;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteParametroGeneralAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM ParametrosGenerales WHERE ParametroGeneralID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // CuentasML
    public async Task<int> CreateCuentaMlAsync(CuentaMlDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO CuentasML (EmpresaID, UserIDML, NicknameML, AccessToken, RefreshToken, FechaVencimientoToken, Activo) VALUES (@empresa, @user, @nick, @acc, @ref, @venc, @activo); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@user", SqlDbType.VarChar, 50).Value = dto.UserIDML;
        cmd.Parameters.Add("@nick", SqlDbType.VarChar, 100).Value = dto.NicknameML;
        cmd.Parameters.Add("@acc", SqlDbType.VarChar, -1).Value = (object?)dto.AccessToken ?? DBNull.Value;
        cmd.Parameters.Add("@ref", SqlDbType.VarChar, -1).Value = (object?)dto.RefreshToken ?? DBNull.Value;
        cmd.Parameters.Add("@venc", SqlDbType.DateTime2).Value = (object?)dto.FechaVencimientoToken ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateCuentaMlAsync(int id, CuentaMlDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE CuentasML SET EmpresaID=@empresa, UserIDML=@user, NicknameML=@nick, AccessToken=@acc, RefreshToken=@ref, FechaVencimientoToken=@venc, Activo=@activo WHERE CuentaMLID=@id";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@user", SqlDbType.VarChar, 50).Value = dto.UserIDML;
        cmd.Parameters.Add("@nick", SqlDbType.VarChar, 100).Value = dto.NicknameML;
        cmd.Parameters.Add("@acc", SqlDbType.VarChar, -1).Value = (object?)dto.AccessToken ?? DBNull.Value;
        cmd.Parameters.Add("@ref", SqlDbType.VarChar, -1).Value = (object?)dto.RefreshToken ?? DBNull.Value;
        cmd.Parameters.Add("@venc", SqlDbType.DateTime2).Value = (object?)dto.FechaVencimientoToken ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteCuentaMlAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM CuentasML WHERE CuentaMLID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // Productos upsert
    public async Task<int> CreateProductoAsync(ProductoDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO Productos (EmpresaID, SKU, Titulo, CategoriaID, Marca, Modelo, Activo, FechaCreacion) VALUES (@empresa, @sku, @titulo, @cat, @marca, @modelo, @activo, SYSDATETIME()); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@sku", SqlDbType.VarChar, 50).Value = dto.SKU;
        cmd.Parameters.Add("@titulo", SqlDbType.NVarChar, 255).Value = dto.Titulo;
        cmd.Parameters.Add("@cat", SqlDbType.VarChar, 50).Value = (object?)dto.CategoriaID ?? DBNull.Value;
        cmd.Parameters.Add("@marca", SqlDbType.VarChar, 100).Value = (object?)dto.Marca ?? DBNull.Value;
        cmd.Parameters.Add("@modelo", SqlDbType.VarChar, 100).Value = (object?)dto.Modelo ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateProductoAsync(int id, ProductoDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Productos SET EmpresaID=@empresa, SKU=@sku, Titulo=@titulo, CategoriaID=@cat, Marca=@marca, Modelo=@modelo, Activo=@activo WHERE ProductoID=@id";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@sku", SqlDbType.VarChar, 50).Value = dto.SKU;
        cmd.Parameters.Add("@titulo", SqlDbType.NVarChar, 255).Value = dto.Titulo;
        cmd.Parameters.Add("@cat", SqlDbType.VarChar, 50).Value = (object?)dto.CategoriaID ?? DBNull.Value;
        cmd.Parameters.Add("@marca", SqlDbType.VarChar, 100).Value = (object?)dto.Marca ?? DBNull.Value;
        cmd.Parameters.Add("@modelo", SqlDbType.VarChar, 100).Value = (object?)dto.Modelo ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteProductoAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM Productos WHERE ProductoID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // CostosProducto create/update
    public async Task<int> CreateCostoProductoAsync(CostoProductoDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO CostosProducto (ProductoID, CostoCompra, PorcentajeIVA, ImpuestosInternos, CostoEnvioPromedio, CostoLogisticoFijo, CostoFinancieroPorc, CostoPublicidadPorc, OtrosCostosFijos, FechaUltimaActualizacion) VALUES (@prod, @costo, @iva, @impuestos, @envio, @logistico, @financiero, @pub, @otros, SYSDATETIME()); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@prod", SqlDbType.Int).Value = dto.ProductoID;
        cmd.Parameters.Add("@costo", SqlDbType.Decimal).Value = dto.CostoCompra;
        cmd.Parameters.Add("@iva", SqlDbType.Decimal).Value = dto.PorcentajeIVA;
        cmd.Parameters.Add("@impuestos", SqlDbType.Decimal).Value = dto.ImpuestosInternos;
        cmd.Parameters.Add("@envio", SqlDbType.Decimal).Value = dto.CostoEnvioPromedio;
        cmd.Parameters.Add("@logistico", SqlDbType.Decimal).Value = dto.CostoLogisticoFijo;
        cmd.Parameters.Add("@financiero", SqlDbType.Decimal).Value = dto.CostoFinancieroPorc;
        cmd.Parameters.Add("@pub", SqlDbType.Decimal).Value = dto.CostoPublicidadPorc;
        cmd.Parameters.Add("@otros", SqlDbType.Decimal).Value = dto.OtrosCostosFijos;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateCostoProductoAsync(int id, CostoProductoDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE CostosProducto SET ProductoID=@prod, CostoCompra=@costo, PorcentajeIVA=@iva, ImpuestosInternos=@impuestos, CostoEnvioPromedio=@envio, CostoLogisticoFijo=@logistico, CostoFinancieroPorc=@financiero, CostoPublicidadPorc=@pub, OtrosCostosFijos=@otros, FechaUltimaActualizacion=SYSDATETIME() WHERE CostoID=@id";
        cmd.Parameters.Add("@prod", SqlDbType.Int).Value = dto.ProductoID;
        cmd.Parameters.Add("@costo", SqlDbType.Decimal).Value = dto.CostoCompra;
        cmd.Parameters.Add("@iva", SqlDbType.Decimal).Value = dto.PorcentajeIVA;
        cmd.Parameters.Add("@impuestos", SqlDbType.Decimal).Value = dto.ImpuestosInternos;
        cmd.Parameters.Add("@envio", SqlDbType.Decimal).Value = dto.CostoEnvioPromedio;
        cmd.Parameters.Add("@logistico", SqlDbType.Decimal).Value = dto.CostoLogisticoFijo;
        cmd.Parameters.Add("@financiero", SqlDbType.Decimal).Value = dto.CostoFinancieroPorc;
        cmd.Parameters.Add("@pub", SqlDbType.Decimal).Value = dto.CostoPublicidadPorc;
        cmd.Parameters.Add("@otros", SqlDbType.Decimal).Value = dto.OtrosCostosFijos;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteCostoProductoAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM CostosProducto WHERE CostoID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // PublicacionesML create
    public async Task<int> CreatePublicacionMlAsync(PublicacionMlDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO PublicacionesML (ProductoID, CuentaMLID, MeliItemID, TipoPublicacion, ComisionMLPorc, Estado, EsCatalogo, PrecioActual, PrecioMinimoPermitido, PrecioMaximoPermitido, PrecioObjetivo, FechaUltimoCambioPrecio) VALUES (@prod, @cuenta, @item, @tipo, @comision, @estado, @catalogo, @precio, @min, @max, @objetivo, @fecha); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@prod", SqlDbType.Int).Value = dto.ProductoID;
        cmd.Parameters.Add("@cuenta", SqlDbType.Int).Value = dto.CuentaMLID;
        cmd.Parameters.Add("@item", SqlDbType.VarChar, 50).Value = dto.MeliItemID;
        cmd.Parameters.Add("@tipo", SqlDbType.VarChar, 30).Value = dto.TipoPublicacion;
        cmd.Parameters.Add("@comision", SqlDbType.Decimal).Value = dto.ComisionMLPorc;
        cmd.Parameters.Add("@estado", SqlDbType.VarChar, 20).Value = dto.Estado;
        cmd.Parameters.Add("@catalogo", SqlDbType.Bit).Value = dto.EsCatalogo;
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = dto.PrecioActual;
        cmd.Parameters.Add("@min", SqlDbType.Decimal).Value = dto.PrecioMinimoPermitido;
        cmd.Parameters.Add("@max", SqlDbType.Decimal).Value = dto.PrecioMaximoPermitido;
        cmd.Parameters.Add("@objetivo", SqlDbType.Decimal).Value = (object?)dto.PrecioObjetivo ?? DBNull.Value;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = (object?)dto.FechaUltimoCambioPrecio ?? DBNull.Value;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdatePublicacionMlAsync(int id, PublicacionMlDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE PublicacionesML SET ProductoID=@prod, CuentaMLID=@cuenta, MeliItemID=@item, TipoPublicacion=@tipo, ComisionMLPorc=@comision, Estado=@estado, EsCatalogo=@catalogo, PrecioActual=@precio, PrecioMinimoPermitido=@min, PrecioMaximoPermitido=@max, PrecioObjetivo=@objetivo, FechaUltimoCambioPrecio=@fecha WHERE PublicacionID=@id";
        cmd.Parameters.Add("@prod", SqlDbType.Int).Value = dto.ProductoID;
        cmd.Parameters.Add("@cuenta", SqlDbType.Int).Value = dto.CuentaMLID;
        cmd.Parameters.Add("@item", SqlDbType.VarChar, 50).Value = dto.MeliItemID;
        cmd.Parameters.Add("@tipo", SqlDbType.VarChar, 30).Value = dto.TipoPublicacion;
        cmd.Parameters.Add("@comision", SqlDbType.Decimal).Value = dto.ComisionMLPorc;
        cmd.Parameters.Add("@estado", SqlDbType.VarChar, 20).Value = dto.Estado;
        cmd.Parameters.Add("@catalogo", SqlDbType.Bit).Value = dto.EsCatalogo;
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = dto.PrecioActual;
        cmd.Parameters.Add("@min", SqlDbType.Decimal).Value = dto.PrecioMinimoPermitido;
        cmd.Parameters.Add("@max", SqlDbType.Decimal).Value = dto.PrecioMaximoPermitido;
        cmd.Parameters.Add("@objetivo", SqlDbType.Decimal).Value = (object?)dto.PrecioObjetivo ?? DBNull.Value;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = (object?)dto.FechaUltimoCambioPrecio ?? DBNull.Value;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeletePublicacionMlAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM PublicacionesML WHERE PublicacionID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // StockEstado create/update
    public async Task<int> CreateStockEstadoAsync(StockEstadoDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO StockEstado (ProductoID, StockActual, StockReservado, StockMinimo, StockMaximo, StockObjetivo, FechaActualizacion) VALUES (@prod, @actual, @reservado, @min, @max, @obj, SYSDATETIME()); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@prod", SqlDbType.Int).Value = dto.ProductoID;
        cmd.Parameters.Add("@actual", SqlDbType.Int).Value = dto.StockActual;
        cmd.Parameters.Add("@reservado", SqlDbType.Int).Value = dto.StockReservado;
        cmd.Parameters.Add("@min", SqlDbType.Int).Value = dto.StockMinimo;
        cmd.Parameters.Add("@max", SqlDbType.Int).Value = dto.StockMaximo;
        cmd.Parameters.Add("@obj", SqlDbType.Int).Value = dto.StockObjetivo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateStockEstadoAsync(int id, StockEstadoDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE StockEstado SET ProductoID=@prod, StockActual=@actual, StockReservado=@reservado, StockMinimo=@min, StockMaximo=@max, StockObjetivo=@obj, FechaActualizacion=SYSDATETIME() WHERE StockID=@id";
        cmd.Parameters.Add("@prod", SqlDbType.Int).Value = dto.ProductoID;
        cmd.Parameters.Add("@actual", SqlDbType.Int).Value = dto.StockActual;
        cmd.Parameters.Add("@reservado", SqlDbType.Int).Value = dto.StockReservado;
        cmd.Parameters.Add("@min", SqlDbType.Int).Value = dto.StockMinimo;
        cmd.Parameters.Add("@max", SqlDbType.Int).Value = dto.StockMaximo;
        cmd.Parameters.Add("@obj", SqlDbType.Int).Value = dto.StockObjetivo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteStockEstadoAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM StockEstado WHERE StockID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // MetricasVentasHist create
    public async Task<int> CreateMetricasVentasAsync(MetricasVentasDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO MetricasVentasHist (PublicacionID, VentasHoy, Ventas7D, Ventas15D, Ventas30D, Ventas60D, Ventas90D, VelocidadVentaDiaria, TendenciaPorc, FechaCalculo) VALUES (@pub, @hoy, @7d, @15d, @30d, @60d, @90d, @vel, @tend, @fecha); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@pub", SqlDbType.Int).Value = dto.PublicacionID;
        cmd.Parameters.Add("@hoy", SqlDbType.Int).Value = dto.VentasHoy;
        cmd.Parameters.Add("@7d", SqlDbType.Int).Value = dto.Ventas7D;
        cmd.Parameters.Add("@15d", SqlDbType.Int).Value = dto.Ventas15D;
        cmd.Parameters.Add("@30d", SqlDbType.Int).Value = dto.Ventas30D;
        cmd.Parameters.Add("@60d", SqlDbType.Int).Value = dto.Ventas60D;
        cmd.Parameters.Add("@90d", SqlDbType.Int).Value = dto.Ventas90D;
        cmd.Parameters.Add("@vel", SqlDbType.Decimal).Value = dto.VelocidadVentaDiaria;
        cmd.Parameters.Add("@tend", SqlDbType.Decimal).Value = dto.TendenciaPorc;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = dto.FechaCalculo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    // CompetenciaSnapshot create
    public async Task<long> CreateCompetenciaSnapshotAsync(CompetenciaSnapshotDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO CompetenciaSnapshot (PublicacionID, CompetidorItemID, CompetidorVendedorID, PrecioCompetidor, StockCompetidor, TipoPublicacion, OfreceEnvioGratis, EsCompetidorDirecto, NivelRelevancia, FechaCaptura) VALUES (@pub, @item, @vend, @precio, @stock, @tipo, @envio, @directo, @nivel, @fecha); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@pub", SqlDbType.Int).Value = dto.PublicacionID;
        cmd.Parameters.Add("@item", SqlDbType.VarChar, 50).Value = dto.CompetidorItemID;
        cmd.Parameters.Add("@vend", SqlDbType.VarChar, 50).Value = (object?)dto.CompetidorVendedorID ?? DBNull.Value;
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = dto.PrecioCompetidor;
        cmd.Parameters.Add("@stock", SqlDbType.Int).Value = (object?)dto.StockCompetidor ?? DBNull.Value;
        cmd.Parameters.Add("@tipo", SqlDbType.VarChar, 30).Value = (object?)dto.TipoPublicacion ?? DBNull.Value;
        cmd.Parameters.Add("@envio", SqlDbType.Bit).Value = dto.OfreceEnvioGratis;
        cmd.Parameters.Add("@directo", SqlDbType.Bit).Value = dto.EsCompetidorDirecto;
        cmd.Parameters.Add("@nivel", SqlDbType.Int).Value = dto.NivelRelevancia;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = dto.FechaCaptura;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt64(idObj);
    }

    // Estrategias
    public async Task<IEnumerable<EstrategiaDto>> GetEstrategiasAsync()
    {
        var list = new List<EstrategiaDto>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT EstrategiaID, EmpresaID, NombreEstrategia, Descripcion, Activa FROM Estrategias ORDER BY EstrategiaID";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new EstrategiaDto
            {
                EstrategiaID = Convert.ToInt32(reader["EstrategiaID"]),
                EmpresaID = Convert.ToInt32(reader["EmpresaID"]),
                NombreEstrategia = reader["NombreEstrategia"].ToString() ?? string.Empty,
                Descripcion = reader.IsDBNull(reader.GetOrdinal("Descripcion")) ? null : reader["Descripcion"].ToString(),
                Activa = Convert.ToBoolean(reader["Activa"])
            });
        }
        return list;
    }

    public async Task<EstrategiaDto?> GetEstrategiaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT EstrategiaID, EmpresaID, NombreEstrategia, Descripcion, Activa FROM Estrategias WHERE EstrategiaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new EstrategiaDto
            {
                EstrategiaID = Convert.ToInt32(reader["EstrategiaID"]),
                EmpresaID = Convert.ToInt32(reader["EmpresaID"]),
                NombreEstrategia = reader["NombreEstrategia"].ToString() ?? string.Empty,
                Descripcion = reader.IsDBNull(reader.GetOrdinal("Descripcion")) ? null : reader["Descripcion"].ToString(),
                Activa = Convert.ToBoolean(reader["Activa"])
            };
        }
        return null;
    }

    public async Task<int> CreateEstrategiaAsync(EstrategiaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO Estrategias (EmpresaID, NombreEstrategia, Descripcion, Activa) VALUES (@empresa, @nombre, @desc, @activa); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 100).Value = dto.NombreEstrategia;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateEstrategiaAsync(int id, EstrategiaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE Estrategias SET EmpresaID=@empresa, NombreEstrategia=@nombre, Descripcion=@desc, Activa=@activa WHERE EstrategiaID=@id";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 100).Value = dto.NombreEstrategia;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteEstrategiaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM Estrategias WHERE EstrategiaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // ReglasNegocio
    public async Task<IEnumerable<ReglaNegocioDto>> GetReglasAsync()
    {
        var list = new List<ReglaNegocioDto>();
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT ReglaID, CodigoRegla, Nombre, TipoRegla, Descripcion, Activa FROM ReglasNegocio ORDER BY ReglaID";
        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new ReglaNegocioDto
            {
                ReglaID = Convert.ToInt32(reader["ReglaID"]),
                CodigoRegla = reader["CodigoRegla"].ToString() ?? string.Empty,
                Nombre = reader["Nombre"].ToString() ?? string.Empty,
                TipoRegla = reader["TipoRegla"].ToString() ?? string.Empty,
                Descripcion = reader.IsDBNull(reader.GetOrdinal("Descripcion")) ? null : reader["Descripcion"].ToString(),
                Activa = Convert.ToBoolean(reader["Activa"])
            });
        }
        return list;
    }

    public async Task<ReglaNegocioDto?> GetReglaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT ReglaID, CodigoRegla, Nombre, TipoRegla, Descripcion, Activa FROM ReglasNegocio WHERE ReglaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new ReglaNegocioDto
            {
                ReglaID = Convert.ToInt32(reader["ReglaID"]),
                CodigoRegla = reader["CodigoRegla"].ToString() ?? string.Empty,
                Nombre = reader["Nombre"].ToString() ?? string.Empty,
                TipoRegla = reader["TipoRegla"].ToString() ?? string.Empty,
                Descripcion = reader.IsDBNull(reader.GetOrdinal("Descripcion")) ? null : reader["Descripcion"].ToString(),
                Activa = Convert.ToBoolean(reader["Activa"])
            };
        }
        return null;
    }

    public async Task<int> CreateReglaNegocioAsync(ReglaNegocioDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO ReglasNegocio (CodigoRegla, Nombre, TipoRegla, Descripcion, Activa) VALUES (@codigo, @nombre, @tipo, @desc, @activa); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@codigo", SqlDbType.VarChar, 50).Value = dto.CodigoRegla;
        cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 100).Value = dto.Nombre;
        cmd.Parameters.Add("@tipo", SqlDbType.VarChar, 30).Value = dto.TipoRegla;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateReglaNegocioAsync(int id, ReglaNegocioDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE ReglasNegocio SET CodigoRegla=@codigo, Nombre=@nombre, TipoRegla=@tipo, Descripcion=@desc, Activa=@activa WHERE ReglaID=@id";
        cmd.Parameters.Add("@codigo", SqlDbType.VarChar, 50).Value = dto.CodigoRegla;
        cmd.Parameters.Add("@nombre", SqlDbType.VarChar, 100).Value = dto.Nombre;
        cmd.Parameters.Add("@tipo", SqlDbType.VarChar, 30).Value = dto.TipoRegla;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activa", SqlDbType.Bit).Value = dto.Activa;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteReglaNegocioAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM ReglasNegocio WHERE ReglaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // EstrategiaReglas
    public async Task<int> CreateEstrategiaReglaAsync(EstrategiaReglaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        using var tran = conn.BeginTransaction();
        try
        {
            // Validate existence
            await using (var cmdCheckE = conn.CreateCommand())
            {
                cmdCheckE.Transaction = tran;
                cmdCheckE.CommandText = "SELECT 1 FROM Estrategias WHERE EstrategiaID=@id";
                cmdCheckE.Parameters.Add("@id", SqlDbType.Int).Value = dto.EstrategiaID;
                var r = await cmdCheckE.ExecuteScalarAsync();
                if (r == null) throw new KeyNotFoundException("Estrategia no encontrada");
            }
            await using (var cmdCheckR = conn.CreateCommand())
            {
                cmdCheckR.Transaction = tran;
                cmdCheckR.CommandText = "SELECT 1 FROM ReglasNegocio WHERE ReglaID=@id";
                cmdCheckR.Parameters.Add("@id", SqlDbType.Int).Value = dto.ReglaID;
                var r = await cmdCheckR.ExecuteScalarAsync();
                if (r == null) throw new KeyNotFoundException("Regla no encontrada");
            }

            await using (var cmdIns = conn.CreateCommand())
            {
                cmdIns.Transaction = tran;
                cmdIns.CommandText = "INSERT INTO EstrategiaReglas (EstrategiaID, ReglaID, Prioridad, ParametrosJSON, Activa) VALUES (@e, @r, @p, @json, @a); SELECT SCOPE_IDENTITY();";
                cmdIns.Parameters.Add("@e", SqlDbType.Int).Value = dto.EstrategiaID;
                cmdIns.Parameters.Add("@r", SqlDbType.Int).Value = dto.ReglaID;
                cmdIns.Parameters.Add("@p", SqlDbType.Int).Value = dto.Prioridad;
                cmdIns.Parameters.Add("@json", SqlDbType.VarChar, -1).Value = (object?)dto.ParametrosJSON ?? DBNull.Value;
                cmdIns.Parameters.Add("@a", SqlDbType.Bit).Value = dto.Activa;
                var idObj = await cmdIns.ExecuteScalarAsync();
                tran.Commit();
                return Convert.ToInt32(idObj);
            }
        }
        catch
        {
            try { tran.Rollback(); } catch { }
            throw;
        }
    }

    public async Task UpdateEstrategiaReglaAsync(int id, EstrategiaReglaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE EstrategiaReglas SET EstrategiaID=@e, ReglaID=@r, Prioridad=@p, ParametrosJSON=@json, Activa=@a WHERE EstrategiaReglaID=@id";
        cmd.Parameters.Add("@e", SqlDbType.Int).Value = dto.EstrategiaID;
        cmd.Parameters.Add("@r", SqlDbType.Int).Value = dto.ReglaID;
        cmd.Parameters.Add("@p", SqlDbType.Int).Value = dto.Prioridad;
        cmd.Parameters.Add("@json", SqlDbType.VarChar, -1).Value = (object?)dto.ParametrosJSON ?? DBNull.Value;
        cmd.Parameters.Add("@a", SqlDbType.Bit).Value = dto.Activa;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteEstrategiaReglaAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM EstrategiaReglas WHERE EstrategiaReglaID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // ConfiguracionParametros
    public async Task<int> CreateConfiguracionParametroAsync(ConfiguracionParametroDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO ConfiguracionParametros (EmpresaID, ClaveParametro, ValorParametro, Descripcion) VALUES (@empresa, @clave, @valor, @desc); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@clave", SqlDbType.VarChar, 100).Value = dto.ClaveParametro;
        cmd.Parameters.Add("@valor", SqlDbType.VarChar, 255).Value = dto.ValorParametro;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateConfiguracionParametroAsync(int id, ConfiguracionParametroDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE ConfiguracionParametros SET EmpresaID=@empresa, ClaveParametro=@clave, ValorParametro=@valor, Descripcion=@desc WHERE ParametroID=@id";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@clave", SqlDbType.VarChar, 100).Value = dto.ClaveParametro;
        cmd.Parameters.Add("@valor", SqlDbType.VarChar, 255).Value = dto.ValorParametro;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteConfiguracionParametroAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM ConfiguracionParametros WHERE ParametroID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // DecisionesHistorial - only insert and get (no delete)
    public async Task<long> CreateDecisionHistorialAsync(DecisionHistorialDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"INSERT INTO DecisionesHistorial (EmpresaID, PublicacionID, EstrategiaID, PrecioAnterior, PrecioCalculado, PrecioSugerido, Accion, Motivo, ReglaGanadoraID, PrioridadAplicada, MargenActualPorc, MargenProyectadoPorc, PosicionCompetitiva, PrecioCompetenciaRef, StockDisponible, ClasificacionStock, ScoreConfianza, EsSimulacion, FechaDecision) VALUES (@empresa,@pub,@estrat,@ant,@calc,@suger,@accion,@motivo,@regla,@prioridad,@margAct,@margProj,@pos,@precRef,@stock,@clas,@score,@sim,@fecha); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@empresa", SqlDbType.Int).Value = dto.EmpresaID;
        cmd.Parameters.Add("@pub", SqlDbType.Int).Value = dto.PublicacionID;
        cmd.Parameters.Add("@estrat", SqlDbType.Int).Value = dto.EstrategiaID;
        cmd.Parameters.Add("@ant", SqlDbType.Decimal).Value = dto.PrecioAnterior;
        cmd.Parameters.Add("@calc", SqlDbType.Decimal).Value = dto.PrecioCalculado;
        cmd.Parameters.Add("@suger", SqlDbType.Decimal).Value = dto.PrecioSugerido;
        cmd.Parameters.Add("@accion", SqlDbType.VarChar, 50).Value = dto.Accion;
        cmd.Parameters.Add("@motivo", SqlDbType.VarChar, 500).Value = dto.Motivo;
        cmd.Parameters.Add("@regla", SqlDbType.Int).Value = (object?)dto.ReglaGanadoraID ?? DBNull.Value;
        cmd.Parameters.Add("@prioridad", SqlDbType.Int).Value = dto.PrioridadAplicada;
        cmd.Parameters.Add("@margAct", SqlDbType.Decimal).Value = dto.MargenActualPorc;
        cmd.Parameters.Add("@margProj", SqlDbType.Decimal).Value = dto.MargenProyectadoPorc;
        cmd.Parameters.Add("@pos", SqlDbType.Int).Value = (object?)dto.PosicionCompetitiva ?? DBNull.Value;
        cmd.Parameters.Add("@precRef", SqlDbType.Decimal).Value = (object?)dto.PrecioCompetenciaRef ?? DBNull.Value;
        cmd.Parameters.Add("@stock", SqlDbType.Int).Value = dto.StockDisponible;
        cmd.Parameters.Add("@clas", SqlDbType.VarChar, 20).Value = dto.ClasificacionStock;
        cmd.Parameters.Add("@score", SqlDbType.Decimal).Value = dto.ScoreConfianza;
        cmd.Parameters.Add("@sim", SqlDbType.Bit).Value = dto.EsSimulacion;
        cmd.Parameters.Add("@fecha", SqlDbType.DateTime2).Value = dto.FechaDecision;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt64(idObj);
    }

    // EstrategiaReglaParametros -- alta/edición simple (Activo/Inactivo, sin versionado por
    // fecha; ver Migrar-ParametrosMensajesReglaActivoSimple.sql). El historial de valores
    // pasados sigue viéndose por Reportes (mismo mecanismo genérico de AdminReportsService,
    // recurso "estrategias-reglas-parametros"), no por un método/endpoint aparte.
    public async Task<EstrategiaReglaParametroDto?> GetEstrategiaReglaParametroAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT ParametroID, EstrategiaReglaID, Clave, Valor, Descripcion, Activo FROM EstrategiaReglaParametros WHERE ParametroID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new EstrategiaReglaParametroDto
            {
                ParametroID = Convert.ToInt32(reader["ParametroID"]),
                EstrategiaReglaID = Convert.ToInt32(reader["EstrategiaReglaID"]),
                Clave = reader["Clave"].ToString() ?? string.Empty,
                Valor = Convert.ToDecimal(reader["Valor"]),
                Descripcion = reader.IsDBNull(reader.GetOrdinal("Descripcion")) ? null : reader["Descripcion"].ToString(),
                Activo = Convert.ToBoolean(reader["Activo"])
            };
        }
        return null;
    }

    public async Task<int> CreateEstrategiaReglaParametroAsync(EstrategiaReglaParametroDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO EstrategiaReglaParametros (EstrategiaReglaID, Clave, Valor, Descripcion, Activo) VALUES (@estrategiaReglaID, @clave, @valor, @desc, @activo); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@estrategiaReglaID", SqlDbType.Int).Value = dto.EstrategiaReglaID;
        cmd.Parameters.Add("@clave", SqlDbType.VarChar, 100).Value = dto.Clave;
        cmd.Parameters.Add("@valor", SqlDbType.Decimal).Value = dto.Valor;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateEstrategiaReglaParametroAsync(int id, EstrategiaReglaParametroDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE EstrategiaReglaParametros SET EstrategiaReglaID=@estrategiaReglaID, Clave=@clave, Valor=@valor, Descripcion=@desc, Activo=@activo WHERE ParametroID=@id";
        cmd.Parameters.Add("@estrategiaReglaID", SqlDbType.Int).Value = dto.EstrategiaReglaID;
        cmd.Parameters.Add("@clave", SqlDbType.VarChar, 100).Value = dto.Clave;
        cmd.Parameters.Add("@valor", SqlDbType.Decimal).Value = dto.Valor;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteEstrategiaReglaParametroAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM EstrategiaReglaParametros WHERE ParametroID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // EstrategiaReglaParametrosMensajes -- mismo criterio que EstrategiaReglaParametros
    // (arriba): alta/edición simple, historial por Reportes.
    public async Task<EstrategiaReglaParametroMensajeDto?> GetEstrategiaReglaParametroMensajeAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT MensajeID, EstrategiaReglaID, Clave, Idioma, Valor, Descripcion, Activo FROM EstrategiaReglaParametrosMensajes WHERE MensajeID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new EstrategiaReglaParametroMensajeDto
            {
                MensajeID = Convert.ToInt32(reader["MensajeID"]),
                EstrategiaReglaID = Convert.ToInt32(reader["EstrategiaReglaID"]),
                Clave = reader["Clave"].ToString() ?? string.Empty,
                Idioma = reader["Idioma"].ToString() ?? "ES",
                Valor = reader["Valor"].ToString() ?? string.Empty,
                Descripcion = reader.IsDBNull(reader.GetOrdinal("Descripcion")) ? null : reader["Descripcion"].ToString(),
                Activo = Convert.ToBoolean(reader["Activo"])
            };
        }
        return null;
    }

    public async Task<int> CreateEstrategiaReglaParametroMensajeAsync(EstrategiaReglaParametroMensajeDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO EstrategiaReglaParametrosMensajes (EstrategiaReglaID, Clave, Idioma, Valor, Descripcion, Activo) VALUES (@estrategiaReglaID, @clave, @idioma, @valor, @desc, @activo); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@estrategiaReglaID", SqlDbType.Int).Value = dto.EstrategiaReglaID;
        cmd.Parameters.Add("@clave", SqlDbType.VarChar, 100).Value = dto.Clave;
        cmd.Parameters.Add("@idioma", SqlDbType.VarChar, 5).Value = dto.Idioma;
        cmd.Parameters.Add("@valor", SqlDbType.NVarChar, -1).Value = dto.Valor;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(idObj);
    }

    public async Task UpdateEstrategiaReglaParametroMensajeAsync(int id, EstrategiaReglaParametroMensajeDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "UPDATE EstrategiaReglaParametrosMensajes SET EstrategiaReglaID=@estrategiaReglaID, Clave=@clave, Idioma=@idioma, Valor=@valor, Descripcion=@desc, Activo=@activo WHERE MensajeID=@id";
        cmd.Parameters.Add("@estrategiaReglaID", SqlDbType.Int).Value = dto.EstrategiaReglaID;
        cmd.Parameters.Add("@clave", SqlDbType.VarChar, 100).Value = dto.Clave;
        cmd.Parameters.Add("@idioma", SqlDbType.VarChar, 5).Value = dto.Idioma;
        cmd.Parameters.Add("@valor", SqlDbType.NVarChar, -1).Value = dto.Valor;
        cmd.Parameters.Add("@desc", SqlDbType.VarChar, 255).Value = (object?)dto.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DeleteEstrategiaReglaParametroMensajeAsync(int id)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "DELETE FROM EstrategiaReglaParametrosMensajes WHERE MensajeID=@id";
        cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
        await cmd.ExecuteNonQueryAsync();
    }

    // DecisionDetalleAuditoria insert
    public async Task<long> CreateDecisionDetalleAuditoriaAsync(DecisionDetalleAuditoriaDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO DecisionesDetalleAuditoria (DecisionID, ReglaID, Prioridad, EvaluacionResultado, ValorPrecioPropuesto, DetalleJSON) VALUES (@dec,@reg,@prior,@eval,@valor,@detalle); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@dec", SqlDbType.BigInt).Value = dto.DecisionID;
        cmd.Parameters.Add("@reg", SqlDbType.Int).Value = dto.ReglaID;
        cmd.Parameters.Add("@prior", SqlDbType.Int).Value = dto.Prioridad;
        cmd.Parameters.Add("@eval", SqlDbType.VarChar, 30).Value = dto.EvaluacionResultado;
        cmd.Parameters.Add("@valor", SqlDbType.Decimal).Value = (object?)dto.ValorPrecioPropuesto ?? DBNull.Value;
        cmd.Parameters.Add("@detalle", SqlDbType.VarChar, -1).Value = (object?)dto.DetalleJSON ?? DBNull.Value;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt64(idObj);
    }

    // ColaEjecucionML create
    public async Task<long> CreateColaEjecucionMlAsync(ColaEjecucionMlDto dto)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "INSERT INTO ColaEjecucionML (PublicacionID, MeliItemID, PrecioNuevo, AccionRequerida, EstadoEjecucion, MensajeError, FechaCreacion) VALUES (@pub, @item, @precio, @accion, @estado, @msg, SYSDATETIME()); SELECT SCOPE_IDENTITY();";
        cmd.Parameters.Add("@pub", SqlDbType.Int).Value = dto.PublicacionID;
        cmd.Parameters.Add("@item", SqlDbType.VarChar, 50).Value = dto.MeliItemID;
        cmd.Parameters.Add("@precio", SqlDbType.Decimal).Value = dto.PrecioNuevo;
        cmd.Parameters.Add("@accion", SqlDbType.VarChar, 30).Value = dto.AccionRequerida;
        cmd.Parameters.Add("@estado", SqlDbType.VarChar, 20).Value = dto.EstadoEjecucion;
        cmd.Parameters.Add("@msg", SqlDbType.VarChar, -1).Value = (object?)dto.MensajeError ?? DBNull.Value;
        var idObj = await cmd.ExecuteScalarAsync();
        return Convert.ToInt64(idObj);
    }
}
