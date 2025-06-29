# Comandos útiles para el proyecto - Adaptado para Windows PowerShell

Write-Host "📋 Comandos disponibles para el proyecto" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

function Show-Help {
    Write-Host ""
    Write-Host "🚀 INICIO:" -ForegroundColor Green
    Write-Host "  .\scripts\start.ps1                    # Iniciar todo el proyecto"
    Write-Host "  docker-compose up --build              # Construir y ejecutar APIs"
    Write-Host "  docker-compose up -d                   # Ejecutar en background"
    Write-Host ""
    Write-Host "🧪 PRUEBAS:" -ForegroundColor Cyan
    Write-Host "  .\scripts\test-apis.ps1                # Probar todas las APIs"
    Write-Host "  .\scripts\test-apis.ps1 -Size 25       # Probar con Fibonacci(25)"
    Write-Host ""
    Write-Host "📊 BENCHMARKS:" -ForegroundColor Yellow
    Write-Host "  .\scripts\run-benchmarks.ps1           # Benchmark completo"
    Write-Host "  .\scripts\run-benchmarks.ps1 -MaxConcurrency 50  # Máx 50 concurrencia"
    Write-Host ""
    Write-Host "🔍 MONITOREO:" -ForegroundColor Magenta
    Write-Host "  docker-compose logs                    # Ver todos los logs"
    Write-Host "  docker-compose logs -f go-api          # Logs de Go API en vivo"
    Write-Host "  docker-compose ps                      # Estado de contenedores"
    Write-Host "  docker stats                           # Uso de recursos"
    Write-Host ""
    Write-Host "📁 ARCHIVOS:" -ForegroundColor White
    Write-Host "  Get-ChildItem data\                    # Ver resultados (ls data/)"
    Write-Host "  Get-Content data\mathematical_report.txt  # Ver reporte (cat)"
    Write-Host ""
    Write-Host "🛑 DETENER:" -ForegroundColor Red
    Write-Host "  docker-compose down                    # Detener todo"
    Write-Host "  docker-compose down -v                 # Detener y limpiar volúmenes"
    Write-Host ""
    Write-Host "🔧 UTILIDADES:" -ForegroundColor DarkCyan
    Write-Host "  docker system prune                    # Limpiar Docker"
    Write-Host "  docker-compose build --no-cache        # Reconstruir sin cache"
    Write-Host ""
}

function Test-SingleAPI {
    param([string]$ApiName, [int]$Port)
    
    $Url = "http://localhost:$Port/compute?size=30"
    try {
        $Response = Invoke-WebRequest -Uri $Url -TimeoutSec 5
        $Data = $Response.Content | ConvertFrom-Json
        Write-Host "✅ $ApiName - Resultado: $($Data.result), Latencia: $($Data.latency_ms)ms" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $ApiName - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Quick-Test {
    Write-Host "🧪 Prueba rápida de APIs:" -ForegroundColor Cyan
    Test-SingleAPI "Go API" 8081
    Test-SingleAPI "Python API" 8082
    Test-SingleAPI "Node.js API" 8083
    Test-SingleAPI ".NET API" 8084
}

function Show-Status {
    Write-Host "📊 Estado del proyecto:" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Contenedores:" -ForegroundColor Yellow
    docker-compose ps
    Write-Host ""
    Write-Host "Uso de recursos:" -ForegroundColor Yellow
    docker stats --no-stream
}

function Show-URLs {
    Write-Host "🌐 URLs de las APIs:" -ForegroundColor Blue
    Write-Host "• Go API:      http://localhost:8081/compute?size=30" -ForegroundColor Green
    Write-Host "• Python API:  http://localhost:8082/compute?size=30" -ForegroundColor Blue  
    Write-Host "• Node.js API: http://localhost:8083/compute?size=30" -ForegroundColor Yellow
    Write-Host "• .NET API:    http://localhost:8084/compute?size=30" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Health checks:" -ForegroundColor Cyan
    Write-Host "• http://localhost:8081/health" -ForegroundColor White
    Write-Host "• http://localhost:8082/health" -ForegroundColor White
    Write-Host "• http://localhost:8083/health" -ForegroundColor White
    Write-Host "• http://localhost:8084/health" -ForegroundColor White
}

# Funciones exportadas
Write-Host "Funciones disponibles:" -ForegroundColor Green
Write-Host "• Show-Help       # Mostrar todos los comandos"
Write-Host "• Quick-Test      # Prueba rápida de APIs"
Write-Host "• Show-Status     # Estado del proyecto"
Write-Host "• Show-URLs       # URLs de las APIs"
Write-Host ""
Write-Host "Ejecuta 'Show-Help' para ver todos los comandos disponibles." -ForegroundColor Yellow 