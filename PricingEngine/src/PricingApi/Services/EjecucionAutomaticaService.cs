using System.Data;
using Microsoft.Data.SqlClient;
using PricingApi.Models;

namespace PricingApi.Services;

// #ejecucionAutomatica: corre el ciclo completo (ERP -> evaluar todos los productos ->
// procesar cola ML -> sincronizar ML) sin intervención manual, en vez de depender de
// que alguien apriete los 4 botones del header. Config de una fila, mismo patrón que
// ConfiguracionEmail/ConfiguracionMercadoLibre: on/off + cada cuántos minutos corre,
// sin horarios específicos (ver ADR 0019).
public class EjecucionAutomaticaService
{
    private readonly string _connectionString;
    private readonly ErpSyncService _erpSyncService;
    private readonly SqlPricingService _pricingService;
    private readonly MercadoLibreSyncService _mlSyncService;
    private readonly ILogger<EjecucionAutomaticaService> _logger;

    public EjecucionAutomaticaService(
        IConfiguration configuration,
        ErpSyncService erpSyncService,
        SqlPricingService pricingService,
        MercadoLibreSyncService mlSyncService,
        ILogger<EjecucionAutomaticaService> logger)
    {
        _connectionString = configuration.GetConnectionString("PricingDb")
            ?? throw new InvalidOperationException("Connection string 'PricingDb' not found.");
        _erpSyncService = erpSyncService;
        _pricingService = pricingService;
        _mlSyncService = mlSyncService;
        _logger = logger;
    }

    private record ConfigInterna(bool Activo, int IntervaloMinutos, DateTime? UltimaEjecucion);

    private async Task<ConfigInterna> ObtenerConfigInternaAsync(SqlConnection conn)
    {
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT TOP 1 Activo, IntervaloMinutos, UltimaEjecucion FROM ConfiguracionEjecucionAutomatica ORDER BY ConfiguracionEjecucionAutomaticaID DESC";
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return new ConfigInterna(false, 30, null);

        return new ConfigInterna(
            Convert.ToBoolean(reader["Activo"]),
            Convert.ToInt32(reader["IntervaloMinutos"]),
            reader["UltimaEjecucion"] as DateTime?);
    }

    public async Task<EjecucionAutomaticaConfiguracionResponse> GetConfiguracionAsync()
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = @"SELECT TOP 1 Activo, IntervaloMinutos, UltimaEjecucion, UltimoResultadoOk, UltimoResultadoResumen
                             FROM ConfiguracionEjecucionAutomatica ORDER BY ConfiguracionEjecucionAutomaticaID DESC";
        await using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
            return new EjecucionAutomaticaConfiguracionResponse { Activo = false, IntervaloMinutos = 30 };

        return new EjecucionAutomaticaConfiguracionResponse
        {
            Activo = Convert.ToBoolean(reader["Activo"]),
            IntervaloMinutos = Convert.ToInt32(reader["IntervaloMinutos"]),
            UltimaEjecucion = reader["UltimaEjecucion"] as DateTime?,
            UltimoResultadoOk = reader["UltimoResultadoOk"] as bool?,
            UltimoResultadoResumen = reader["UltimoResultadoResumen"] as string,
        };
    }

    public async Task UpdateConfiguracionAsync(EjecucionAutomaticaConfiguracionUpdateRequest dto)
    {
        var intervalo = dto.IntervaloMinutos < 1 ? 30 : dto.IntervaloMinutos;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        await using var existeCmd = conn.CreateCommand();
        existeCmd.CommandText = "SELECT TOP 1 ConfiguracionEjecucionAutomaticaID FROM ConfiguracionEjecucionAutomatica ORDER BY ConfiguracionEjecucionAutomaticaID DESC";
        var existingId = (int?)await existeCmd.ExecuteScalarAsync();

        await using var cmd = conn.CreateCommand();
        if (existingId is null)
        {
            cmd.CommandText = @"INSERT INTO ConfiguracionEjecucionAutomatica (Activo, IntervaloMinutos, FechaActualizacion)
                                 VALUES (@activo, @intervalo, SYSUTCDATETIME())";
        }
        else
        {
            cmd.CommandText = @"UPDATE ConfiguracionEjecucionAutomatica
                                 SET Activo = @activo, IntervaloMinutos = @intervalo, FechaActualizacion = SYSUTCDATETIME()
                                 WHERE ConfiguracionEjecucionAutomaticaID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = existingId.Value;
        }
        cmd.Parameters.Add("@activo", SqlDbType.Bit).Value = dto.Activo;
        cmd.Parameters.Add("@intervalo", SqlDbType.Int).Value = intervalo;
        await cmd.ExecuteNonQueryAsync();
    }

    // Llamado por el hosted service en cada tick — decide si ya toca correr el ciclo
    // según Activo/IntervaloMinutos/UltimaEjecucion, sin necesitar reiniciar la API
    // cuando alguien cambia la configuración desde la pantalla.
    public async Task EjecutarSiCorrespondeAsync()
    {
        ConfigInterna config;
        await using (var conn = new SqlConnection(_connectionString))
        {
            await conn.OpenAsync();
            config = await ObtenerConfigInternaAsync(conn);
        }

        if (!config.Activo)
            return;
        if (config.UltimaEjecucion is not null && DateTime.UtcNow < config.UltimaEjecucion.Value.AddMinutes(config.IntervaloMinutos))
            return;

        await EjecutarCicloAsync();
    }

    public async Task EjecutarCicloAsync()
    {
        var partes = new List<string>();
        var ok = true;

        try
        {
            var resumenes = await _erpSyncService.PullFromAllConfiguredErpsAsync();
            var procesados = resumenes.Sum(s => s.Resultado?.Procesados ?? 0);
            var fallidas = resumenes.Count(s => !s.Ok);
            partes.Add(fallidas > 0
                ? $"ERP: {procesados} producto(s), {fallidas} conexión(es) fallaron"
                : $"ERP: {procesados} producto(s) sincronizados");
            if (fallidas > 0) ok = false;
        }
        catch (Exception ex)
        {
            ok = false;
            partes.Add("ERP: error");
            _logger.LogError(ex, "Ejecución automática: falló el paso de ERP.");
        }

        try
        {
            var (evaluados, cambios) = await _pricingService.EvaluarTodosLosProductosAsync();
            partes.Add($"Motor: {evaluados} producto(s) evaluados, {cambios} cambio(s) de precio");
        }
        catch (Exception ex)
        {
            ok = false;
            partes.Add("Motor: error");
            _logger.LogError(ex, "Ejecución automática: falló el paso de evaluación.");
        }

        try
        {
            var resultado = await _mlSyncService.ProcesarColaAsync();
            partes.Add(resultado.Errores > 0
                ? $"Cola ML: {resultado.Procesados} subido(s), {resultado.Errores} error(es)"
                : $"Cola ML: {resultado.Procesados} subido(s)");
            if (resultado.Errores > 0) ok = false;
        }
        catch (Exception ex)
        {
            ok = false;
            partes.Add("Cola ML: error");
            _logger.LogError(ex, "Ejecución automática: falló el paso de procesar cola ML.");
        }

        try
        {
            var pub = await _mlSyncService.SincronizarPublicacionesAsync();
            var ventas = await _mlSyncService.SincronizarVentasAsync();
            var erroresMl = pub.Errores + ventas.Errores;
            partes.Add(erroresMl > 0
                ? $"Sincronizar ML: {pub.Procesados} publicación(es), {ventas.PublicacionesActualizadas} con ventas, {erroresMl} error(es)"
                : $"Sincronizar ML: {pub.Procesados} publicación(es), {ventas.PublicacionesActualizadas} con ventas");
            if (erroresMl > 0) ok = false;
        }
        catch (Exception ex)
        {
            ok = false;
            partes.Add("Sincronizar ML: error");
            _logger.LogError(ex, "Ejecución automática: falló el paso de sincronizar ML.");
        }

        await GuardarResultadoAsync(ok, string.Join(" · ", partes));
    }

    private async Task GuardarResultadoAsync(bool ok, string resumen)
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        await using var existeCmd = conn.CreateCommand();
        existeCmd.CommandText = "SELECT TOP 1 ConfiguracionEjecucionAutomaticaID FROM ConfiguracionEjecucionAutomatica ORDER BY ConfiguracionEjecucionAutomaticaID DESC";
        var existingId = (int?)await existeCmd.ExecuteScalarAsync();

        await using var cmd = conn.CreateCommand();
        if (existingId is null)
        {
            cmd.CommandText = @"INSERT INTO ConfiguracionEjecucionAutomatica (Activo, IntervaloMinutos, UltimaEjecucion, UltimoResultadoOk, UltimoResultadoResumen)
                                 VALUES (0, 30, SYSUTCDATETIME(), @ok, @resumen)";
        }
        else
        {
            cmd.CommandText = @"UPDATE ConfiguracionEjecucionAutomatica
                                 SET UltimaEjecucion = SYSUTCDATETIME(), UltimoResultadoOk = @ok, UltimoResultadoResumen = @resumen
                                 WHERE ConfiguracionEjecucionAutomaticaID = @id";
            cmd.Parameters.Add("@id", SqlDbType.Int).Value = existingId.Value;
        }
        cmd.Parameters.Add("@ok", SqlDbType.Bit).Value = ok;
        cmd.Parameters.Add("@resumen", SqlDbType.VarChar, 1000).Value = resumen.Length > 1000 ? resumen[..1000] : resumen;
        await cmd.ExecuteNonQueryAsync();
    }
}

// #ejecucionAutomatica: BackgroundService de .NET (sin librería de scheduling nueva,
// ni Hangfire ni Quartz) — se despierta cada minuto y le pregunta al servicio si ya
// toca correr el ciclo según la configuración guardada, así prender/apagar o cambiar
// el intervalo desde la UI tiene efecto sin reiniciar la API.
public class EjecucionAutomaticaHostedService : BackgroundService
{
    private static readonly TimeSpan TickInterval = TimeSpan.FromMinutes(1);
    private readonly EjecucionAutomaticaService _service;
    private readonly ILogger<EjecucionAutomaticaHostedService> _logger;

    public EjecucionAutomaticaHostedService(EjecucionAutomaticaService service, ILogger<EjecucionAutomaticaHostedService> logger)
    {
        _service = service;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TickInterval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await _service.EjecutarSiCorrespondeAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ejecución automática: error inesperado en el tick del scheduler.");
            }
        }
    }
}
