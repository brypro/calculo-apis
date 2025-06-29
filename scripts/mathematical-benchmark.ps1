# Mathematical Benchmark Script para Análisis T(x), T'(x), T''(x)
# Genera datos para modelado matemático de latencias vs concurrencia

param(
    [int]$Requests = 2000,
    [int]$MinConcurrency = 10,
    [int]$MaxConcurrency = 200,
    [int]$Step = 20,
    [int]$Replicas = 3
)

# APIs a probar
$APIs = @(
    @{Name="Go"; URL="http://localhost:8081/compute?size=30"; Port=8081},
    @{Name="Python"; URL="http://localhost:8082/compute?size=30"; Port=8082},
    @{Name="NodeJS"; URL="http://localhost:8083/compute?size=30"; Port=8083},
    @{Name="DotNet"; URL="http://localhost:8084/compute?size=30"; Port=8084}
)

# Verificar que bombardier esté disponible
if (-not (Get-Command bombardier -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Bombardier no encontrado. Instalando..." -ForegroundColor Red
    winget install bombardier
}

# Función para ejecutar benchmark
function Run-BenchmarkPoint {
    param($API, $Concurrency, $Requests, $ReplicaNum)
    
    Write-Host "  🔄 $($API.Name) - Concurrencia: $Concurrency (Réplica $ReplicaNum)" -ForegroundColor Cyan
    
    try {
        # Warm-up
        $warmupResult = bombardier -c 5 -n 100 --timeout=30s --format=json $API.URL 2>$null
        Start-Sleep -Seconds 1
        
        # Benchmark real
        $result = bombardier -c $Concurrency -n $Requests --timeout=60s --format=json $API.URL 2>$null
        
        if ($result) {
            $jsonResult = $result | ConvertFrom-Json
            return @{
                API = $API.Name
                Concurrency = $Concurrency
                Replica = $ReplicaNum
                RequestsPerSec = [math]::Round($jsonResult.result.rps.mean, 2)
                LatencyMean = [math]::Round($jsonResult.result.latencies.mean / 1000000, 2)  # ns to ms
                LatencyP50 = [math]::Round($jsonResult.result.latencies.p50 / 1000000, 2)
                LatencyP95 = [math]::Round($jsonResult.result.latencies.p95 / 1000000, 2)
                LatencyP99 = [math]::Round($jsonResult.result.latencies.p99 / 1000000, 2)
                ErrorRate = [math]::Round(($jsonResult.result.errors.total / $Requests) * 100, 2)
                Success = $true
            }
        }
    }
    catch {
        Write-Host "    ❌ Error en benchmark" -ForegroundColor Red
    }
    
    return @{
        API = $API.Name
        Concurrency = $Concurrency
        Replica = $ReplicaNum
        Success = $false
    }
}

# Verificar que todas las APIs estén funcionando
Write-Host "🔍 Verificando APIs..." -ForegroundColor Yellow
foreach ($API in $APIs) {
    try {
        $response = Invoke-RestMethod -Uri $API.URL -Method GET -TimeoutSec 5
        Write-Host "  ✅ $($API.Name) API - OK" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ $($API.Name) API - ERROR" -ForegroundColor Red
        exit 1
    }
}

# Ejecutar benchmarks
$AllResults = @()
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "`n📊 INICIANDO BENCHMARK MATEMÁTICO" -ForegroundColor Green
Write-Host "Requests por test: $Requests" -ForegroundColor White
Write-Host "Concurrencia: $MinConcurrency-$MaxConcurrency (paso $Step)" -ForegroundColor White
Write-Host "Réplicas por punto: $Replicas" -ForegroundColor White
Write-Host "=" * 50 -ForegroundColor Green

foreach ($API in $APIs) {
    Write-Host "`n🚀 Probando $($API.Name) API" -ForegroundColor Magenta
    
    for ($concurrency = $MinConcurrency; $concurrency -le $MaxConcurrency; $concurrency += $Step) {
        for ($replica = 1; $replica -le $Replicas; $replica++) {
            $result = Run-BenchmarkPoint -API $API -Concurrency $concurrency -Requests $Requests -ReplicaNum $replica
            
            if ($result.Success) {
                $AllResults += $result
                Write-Host "    ✅ RPS: $($result.RequestsPerSec), Latencia P95: $($result.LatencyP95)ms" -ForegroundColor Green
            }
            else {
                Write-Host "    ❌ Falló" -ForegroundColor Red
            }
            
            Start-Sleep -Seconds 2
        }
    }
}

# Exportar resultados a CSV
$CsvPath = "mathematical-benchmark-$Timestamp.csv"
$AllResults | Where-Object { $_.Success } | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

Write-Host "`n📈 RESUMEN DE RESULTADOS" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

foreach ($API in $APIs) {
    $apiResults = $AllResults | Where-Object { $_.API -eq $API.Name -and $_.Success }
    if ($apiResults.Count -gt 0) {
        $avgRPS = ($apiResults | Measure-Object -Property RequestsPerSec -Average).Average
        $avgLatency = ($apiResults | Measure-Object -Property LatencyP95 -Average).Average
        $minLatency = ($apiResults | Measure-Object -Property LatencyP95 -Minimum).Minimum
        $maxLatency = ($apiResults | Measure-Object -Property LatencyP95 -Maximum).Maximum
        
        Write-Host "$($API.Name):" -ForegroundColor Cyan
        Write-Host "  RPS Promedio: $([math]::Round($avgRPS, 2))" -ForegroundColor White
        Write-Host "  Latencia P95: $([math]::Round($avgLatency, 2))ms (min: $minLatency, max: $maxLatency)" -ForegroundColor White
        Write-Host "  Puntos de datos: $($apiResults.Count)" -ForegroundColor White
    }
}

Write-Host "`n💾 Datos guardados en: $CsvPath" -ForegroundColor Green
Write-Host "🔬 Listo para análisis matemático T(x), T'(x), T''(x)" -ForegroundColor Yellow

# Mostrar preview de los datos
Write-Host "`n📋 PREVIEW DE DATOS:" -ForegroundColor Yellow
$AllResults | Where-Object { $_.Success } | Select-Object API, Concurrency, RequestsPerSec, LatencyP95 | Sort-Object API, Concurrency | Format-Table -AutoSize 