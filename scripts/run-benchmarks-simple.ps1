# Script de benchmark simplificado para Windows PowerShell
# Ejecuta pruebas de rendimiento en todas las APIs

param(
    [int]$Requests = 1000,
    [int]$MaxConcurrency = 100
)

# Verificar si Bombardier esta disponible
function Test-Bombardier {
    try {
        $null = Get-Command bombardier -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

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
        $Result = bombardier -c $Concurrency -n $Requests --json $Url 2>$null
        if ($LASTEXITCODE -eq 0) {
            $JsonResult = $Result | ConvertFrom-Json
            
            Write-Host "  Requests/sec: $([math]::Round($JsonResult.result.rps.mean, 2))" -ForegroundColor Green
            Write-Host "  Latencia P95: $([math]::Round($JsonResult.result.latencies.p95 / 1000000, 2))ms" -ForegroundColor Cyan
            Write-Host "  Latencia P99: $([math]::Round($JsonResult.result.latencies.p99 / 1000000, 2))ms" -ForegroundColor Cyan
            
            return @{
                API = $ApiName
                Concurrency = $Concurrency
                RPS = [math]::Round($JsonResult.result.rps.mean, 2)
                P95 = [math]::Round($JsonResult.result.latencies.p95 / 1000000, 2)
                P99 = [math]::Round($JsonResult.result.latencies.p99 / 1000000, 2)
            }
        }
        else {
            Write-Host "  Error en benchmark" -ForegroundColor Red
            return $null
        }
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

# Verificar Bombardier
if (-not (Test-Bombardier)) {
    Write-Host "ERROR: Bombardier no encontrado" -ForegroundColor Red
    Write-Host "Instala Bombardier desde: https://github.com/codesenberg/bombardier" -ForegroundColor Yellow
    Write-Host "O usa: choco install bombardier" -ForegroundColor Yellow
    exit 1
}

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
        Write-Host "  Concurrencia $($Result.Concurrency): $($Result.RPS) req/s, P95: $($Result.P95)ms" -ForegroundColor White
    }
}

# Encontrar el mejor rendimiento
Write-Host ""
Write-Host "MEJORES RENDIMIENTOS:" -ForegroundColor Yellow
$BestRPS = $AllResults | Sort-Object RPS -Descending | Select-Object -First 1
$BestLatency = $AllResults | Sort-Object P95 | Select-Object -First 1

Write-Host "Mejor Throughput: $($BestRPS.API) - $($BestRPS.RPS) req/s (Concurrencia: $($BestRPS.Concurrency))" -ForegroundColor Green
Write-Host "Mejor Latencia: $($BestLatency.API) - $($BestLatency.P95)ms P95 (Concurrencia: $($BestLatency.Concurrency))" -ForegroundColor Green

Write-Host ""
Write-Host "Benchmark completado!" -ForegroundColor Blue 