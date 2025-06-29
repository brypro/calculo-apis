using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// Configurar CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Usar CORS
app.UseCors();

// Función para calcular Fibonacci
static int Fib(int n)
{
    if (n < 2)
        return n;
    return Fib(n - 1) + Fib(n - 2);
}

// Endpoint principal para calcular Fibonacci
app.MapGet("/compute", (int? size) =>
{
    var stopwatch = Stopwatch.StartNew();
    
    // Usar valor por defecto si no se proporciona size
    var n = size ?? 30;
    
    // Validar rango
    if (n <= 0 || n > 50)
    {
        n = 30;
    }
    
    // Calcular Fibonacci
    var result = Fib(n);
    
    // Detener cronómetro
    stopwatch.Stop();
    
    // Crear respuesta
    var response = new
    {
        result = result,
        size = n,
        latency_ms = stopwatch.ElapsedMilliseconds
    };
    
    // Log de la petición
    Console.WriteLine($"C# .NET API - Size: {n}, Result: {result}, Latency: {stopwatch.ElapsedMilliseconds}ms");
    
    return Results.Ok(response);
})
.WithName("Compute")
.WithOpenApi(operation =>
{
    operation.Summary = "Calcula el n-ésimo número de Fibonacci";
    operation.Description = "Calcula el número de Fibonacci para el tamaño especificado";
    return operation;
});

// Endpoint de health check
app.MapGet("/health", () =>
{
    return Results.Ok(new { status = "healthy", service = "dotnet-api" });
})
.WithName("Health")
.WithOpenApi();

// Endpoint raíz con información de la API
app.MapGet("/", () =>
{
    return Results.Ok(new
    {
        message = "C# .NET 8 Minimal API Benchmark",
        version = "1.0.0",
        endpoints = new
        {
            compute = "/compute?size=30",
            health = "/health",
            docs = "/swagger"
        }
    });
})
.WithName("Root")
.WithOpenApi();

// Configurar Swagger en desarrollo
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Configurar logging
app.Logger.LogInformation("🚀 C# .NET 8 Minimal API iniciando...");
app.Logger.LogInformation("📊 Endpoint: http://localhost:8080/compute?size=30");
app.Logger.LogInformation("📚 Swagger: http://localhost:8080/swagger");
app.Logger.LogInformation("❤️  Health: http://localhost:8080/health");

// Ejecutar la aplicación
app.Run("http://0.0.0.0:8080"); 