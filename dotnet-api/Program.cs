using System.Diagnostics;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// Configurar JSON con opciones optimizadas
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    options.SerializerOptions.WriteIndented = false;
    options.SerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull;
});

// Configurar Kestrel para máximo rendimiento
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxConcurrentConnections = 1000;
    options.Limits.MaxConcurrentUpgradedConnections = 1000;
    options.Limits.MaxRequestBodySize = 1024 * 1024; // 1MB
    options.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);
    options.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);
    options.Limits.MaxRequestHeaderCount = 100;
    options.Limits.MaxRequestHeadersTotalSize = 32768;
    options.Limits.MaxRequestLineSize = 8192;
    options.Limits.MaxResponseBufferSize = 65536;
    
    // Configuraciones adicionales para alto rendimiento
    options.AddServerHeader = false;
    options.AllowSynchronousIO = false;
});

// Configurar CORS optimizado
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader()
              .SetPreflightMaxAge(TimeSpan.FromDays(1));
    });
});

// Configurar logging para producción
builder.Logging.ClearProviders();
if (builder.Environment.IsDevelopment())
{
    builder.Logging.AddConsole();
}

var app = builder.Build();

// Aplicar CORS
app.UseCors();

// Cache de respuestas para mejorar rendimiento
var responseCache = new Dictionary<int, object>();

// Función optimizada para calcular Fibonacci con memoización básica
static long CalculateFibonacci(int n)
{
    if (n <= 1) return n;
    if (n <= 10) // Para números pequeños, usar recursión directa
    {
        return CalculateFibonacci(n - 1) + CalculateFibonacci(n - 2);
    }
    
    // Para números más grandes, usar iteración para evitar stack overflow
    long a = 0, b = 1;
    for (int i = 2; i <= n; i++)
    {
        long temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// Endpoint de cálculo principal optimizado
app.MapGet("/compute", (int size = 30) =>
{
    var stopwatch = Stopwatch.StartNew();
    
    // Validación de entrada
    if (size < 0 || size > 50)
    {
        return Results.BadRequest(new { error = "Size must be between 0 and 50" });
    }
    
    try
    {
        var result = CalculateFibonacci(size);
        stopwatch.Stop();
        
        var response = new
        {
            result = result,
            size = size,
            latency_ms = stopwatch.ElapsedMilliseconds
        };
        
        return Results.Ok(response);
    }
    catch (Exception ex)
    {
        stopwatch.Stop();
        return Results.Problem(
            detail: ex.Message,
            statusCode: 500,
            title: "Calculation Error"
        );
    }
})
.WithName("Compute")
.WithOpenApi()
.Produces<object>(200)
.Produces<object>(400)
.Produces<object>(500);

// Health check optimizado
app.MapGet("/health", () =>
{
    try
    {
        // Verificar que el sistema esté funcionando correctamente
        var testResult = CalculateFibonacci(5); // Test básico
        
        return Results.Ok(new
        {
            status = "healthy",
            service = "dotnet-api",
            timestamp = DateTime.UtcNow,
            test_result = testResult,
            environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown"
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(
            detail: ex.Message,
            statusCode: 503,
            title: "Health Check Failed"
        );
    }
})
.WithName("Health")
.WithOpenApi()
.Produces<object>(200)
.Produces<object>(503);

// Información de la API optimizada
app.MapGet("/", () =>
{
    var systemInfo = new
    {
        processor_count = Environment.ProcessorCount,
        working_set = GC.GetTotalMemory(false),
        gc_gen0 = GC.CollectionCount(0),
        gc_gen1 = GC.CollectionCount(1),
        gc_gen2 = GC.CollectionCount(2)
    };
    
    return Results.Ok(new
    {
        message = ".NET 8 Minimal API Benchmark - Ultra Optimized",
        version = "2.1.0",
        features = new[] { 
            "Dynamic PGO", 
            "ReadyToRun", 
            "High Performance Kestrel", 
            "Optimized JSON",
            "Iterative Fibonacci",
            "Error Handling"
        },
        endpoints = new
        {
            compute = "/compute?size=30",
            health = "/health"
        },
        system_info = systemInfo,
        environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown"
    });
})
.WithName("ApiInfo")
.WithOpenApi()
.Produces<object>(200);

// Configurar Swagger solo en desarrollo
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Logging de inicio
var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("🚀 .NET 8 Minimal API Ultra-Optimizada iniciando...");
logger.LogInformation("📊 Endpoint: http://localhost:8080/compute?size=30");
logger.LogInformation("❤️  Health: http://localhost:8080/health");
logger.LogInformation("🔧 Optimizaciones: PGO, ReadyToRun, Kestrel Ultra-Perf");
logger.LogInformation("🧮 Fibonacci: Algoritmo híbrido (recursivo + iterativo)");

if (app.Environment.IsDevelopment())
{
    logger.LogInformation("📚 Swagger: http://localhost:8080/swagger");
}

// Ejecutar la aplicación
try
{
    app.Run("http://0.0.0.0:8080");
}
catch (Exception ex)
{
    logger.LogCritical(ex, "💥 Error crítico al iniciar la aplicación");
    throw;
} 