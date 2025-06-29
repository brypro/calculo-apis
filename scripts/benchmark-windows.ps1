# Script de benchmark para Windows con Bombardier
# Ejecuta pruebas de rendimiento en todas las APIs

param(
    [int]$Requests = 1000,
    [int]$MaxConcurrency = 100
)

# Ejecutar benchmark en una API
function Invoke-Benchmark {
    param(
        [string]$ApiName,
        [int]$Port,
        [int]$Requests,
        [int]$Concurrency
    )
    
    $Url = "http://localhost:$Port/compute?size=30"
    
    Write-Host "Ejecutando benchmark: $ApiName (Concurrencia: $Concurrency)" -ForegroundColor Yellow
    
    try {
        $Output = bombardier -c $Concurrency -n $Requests $Url 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Parsear la salida para extraer métricas
            $ReqsSecLine = $Output | Where-Object { $_ -match "Reqs/sec\s+(\d+\.\d+)" }
            $LatencyLine = $Output | Where-Object { $_ -match "Latency\s+(\d+\.\d+)ms" }
            
            if ($ReqsSecLine -and $LatencyLine) {
                $ReqsSecLine -match "Reqs/sec\s+(\d+\.\d+)" | Out-Null
                $RPS = [math]::Round([double]$Matches[1], 2)
                
                $LatencyLine -match "Latency\s+(\d+\.\d+)ms" | Out-Null
                $AvgLatency = [math]::Round([double]$Matches[1], 2)
                
                Write-Host "  Requests/sec: $RPS" -ForegroundColor Green
                Write-Host "  Latencia Avg: ${AvgLatency}ms" -ForegroundColor Cyan
                
                return @{
                    API = $ApiName
                    Concurrency = $Concurrency
                    RPS = $RPS
                    AvgLatency = $AvgLatency
                }
            }
        }
        
        Write-Host "  Error parseando resultado" -ForegroundColor Red
        return $null
    }
    catch {
        Write-Host "  Error ejecutando benchmark: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Main
Write-Host "Benchmark de APIs - Calculando Fibonacci(30)" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "Requests: $Requests, Max Concurrencia: $MaxConcurrency" -ForegroundColor White
Write-Host ""

# APIs a probar
$APIs = @(
    @{Name="Go API"; Port=8081},
    @{Name="Python API"; Port=8082},
    @{Name="Node.js API"; Port=8083},
    @{Name=".NET API"; Port=8084}
)

# Niveles de concurrencia a probar
$ConcurrencyLevels = @(10, 25, 50, $MaxConcurrency)

$AllResults = @()

# Ejecutar benchmarks
foreach ($Api in $APIs) {
    Write-Host ""
    Write-Host "=== $($Api.Name) ===" -ForegroundColor Magenta
    
    foreach ($Concurrency in $ConcurrencyLevels) {
        $Result = Invoke-Benchmark -ApiName $Api.Name -Port $Api.Port -Requests $Requests -Concurrency $Concurrency
        if ($Result) {
            $AllResults += $Result
        }
        Start-Sleep -Seconds 2
    }
}

# Mostrar resumen
Write-Host ""
Write-Host "RESUMEN DE RESULTADOS" -ForegroundColor Blue
Write-Host "====================" -ForegroundColor Blue

$GroupedResults = $AllResults | Group-Object API

foreach ($Group in $GroupedResults) {
    Write-Host ""
    Write-Host "$($Group.Name):" -ForegroundColor Green
    foreach ($Result in $Group.Group) {
        Write-Host "  Concurrencia $($Result.Concurrency): $($Result.RPS) req/s, Latencia: $($Result.AvgLatency)ms" -ForegroundColor White
    }
}

# Encontrar el mejor rendimiento
if ($AllResults.Count -gt 0) {
    Write-Host ""
    Write-Host "MEJORES RENDIMIENTOS:" -ForegroundColor Yellow
    $BestRPS = $AllResults | Sort-Object RPS -Descending | Select-Object -First 1
    $BestLatency = $AllResults | Sort-Object AvgLatency | Select-Object -First 1

    Write-Host "Mejor Throughput: $($BestRPS.API) - $($BestRPS.RPS) req/s (Concurrencia: $($BestRPS.Concurrency))" -ForegroundColor Green
    Write-Host "Mejor Latencia: $($BestLatency.API) - $($BestLatency.AvgLatency)ms (Concurrencia: $($BestLatency.Concurrency))" -ForegroundColor Green
    
    # Crear archivo de resultados
    $ResultsFile = "benchmark-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $AllResults | Export-Csv -Path $ResultsFile -NoTypeInformation
    Write-Host ""
    Write-Host "Resultados guardados en: $ResultsFile" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Benchmark completado!" -ForegroundColor Blue 