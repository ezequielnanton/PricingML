using Microsoft.AspNetCore.Http;
using PricingApi.Services;
using Xunit;

namespace PricingApi.Tests;

public sealed class AdminReportsServiceTests
{
    private static ReportDefinition Productos => AdminReportsService.Definitions["productos"];
    private static IQueryCollection Query(params (string Key, string Value)[] values) =>
        new QueryCollection(values.ToDictionary(x => x.Key, x => new Microsoft.Extensions.Primitives.StringValues(x.Value)));

    [Fact]
    public void Usa_paginacion_por_defecto_y_admite_limite() 
    {
        var defaults = AdminReportsService.ParseRequest(Productos, Query());
        var custom = AdminReportsService.ParseRequest(Productos, Query(("page", "2"), ("pageSize", "100")));
        Assert.Equal((1, 50), (defaults.Page, defaults.PageSize));
        Assert.Equal((2, 100), (custom.Page, custom.PageSize));
    }

    [Theory]
    [InlineData("filter[titulo][contains]", "abc")]
    [InlineData("filter[productoId][gte]", "42")]
    [InlineData("filter[fechaCreacion][lt]", "2026-01-02T03:04:05Z")]
    [InlineData("filter[activo][eq]", "true")]
    public void Acepta_filtros_tipados(string key, string value) =>
        Assert.Single(AdminReportsService.ParseRequest(Productos, Query((key, value))).Filters);

    [Fact]
    public void Acepta_ordenamiento_por_campos_expuestos() 
    {
        var request = AdminReportsService.ParseRequest(Productos, Query(("sort", "sku:asc,productoId:desc")));
        Assert.Collection(request.Sort, x => Assert.Equal("ASC", x.Direction), x => Assert.Equal("DESC", x.Direction));
    }

    [Theory]
    [InlineData("page", "0")]
    [InlineData("pageSize", "101")]
    [InlineData("filter[noExiste][eq]", "x")]
    [InlineData("filter[activo][contains]", "true")]
    [InlineData("sort", "DROP TABLE:asc")]
    public void Rechaza_parametros_invalidos(string key, string value) =>
        Assert.Throws<ReportValidationException>(() => AdminReportsService.ParseRequest(Productos, Query((key, value))));

    [Fact]
    public void Trata_payload_sql_como_valor_de_filtro_textual() 
    {
        var request = AdminReportsService.ParseRequest(Productos, Query(("filter[sku][contains]", "' OR 1=1 --")));
        Assert.Equal("' OR 1=1 --", request.Filters.Single().Value);
    }

    [Theory]
    [InlineData("EmpresaID", "empresaID")]
    [InlineData("RazonSocial", "razonSocial")]
    [InlineData("SKU", "sku")]
    [InlineData("MeliItemID", "meliItemID")]
    [InlineData("CUIT", "cuit")]
    public void Convierte_columnas_a_camelCase_compatibles_con_front(string input, string expected)
    {
        var actual = typeof(AdminReportsService)
            .GetMethod("ToCamel", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)
            ?.Invoke(null, new object[] { input });

        Assert.NotNull(actual);
        Assert.Equal(expected, actual);
    }
}
