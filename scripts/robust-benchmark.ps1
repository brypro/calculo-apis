# Benchmark Robusto para Validación Estadística ABPro
# Ejecuta 5 réplicas por punto de concurrencia con warm-up
# Guarda cada corrida individual como bomb_{x}_run{n}.json

param(
    [int]$Requests = 1000,
    [array]$ConcurrencyPoints = @(10, 20, 30, 40, 50),
    [int]$Replicas = 5,
    [int]$WarmupRequests = 200
)

# APIs a probar (manteniendo rango coherente con análisis previo)
$APIs = @(
    @{Name="Go"; URL="http://localhost:8081/compute?size=30"; Port=8081},
    @{Name="Python"; URL="http://localhost:8082/compute?size=30"; Port=8082},
    @{Name="NodeJS"; URL="http://localhost:8083/compute?size=30"; Port=8083},
    @{Name="DotNet"; URL="http://localhost:8084/compute?size=30"; Port=8084}
)

# Verificar bombardier
if (-not (Get-Command bombardier -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Bombardier no encontrado. Instalar desde: https://github.com/codesenberg/bombardier" -ForegroundColor Red
    exit 1
}

# Crear directorio para resultados individuales
$ResultsDir = "benchmark_results_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null

Write-Host "BENCHMARK ROBUSTO - VALIDACION ESTADISTICA ABPro" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Directorio de resultados: $ResultsDir" -ForegroundColor Cyan
Write-Host "Puntos de concurrencia: $($ConcurrencyPoints -join ', ')" -ForegroundColor White
Write-Host "Replicas por punto: $Replicas (+ 1 warm-up descartado)" -ForegroundColor White
Write-Host ""

# Función para ejecutar benchmark individual
function Run-SingleBenchmark {
    param($API, $Concurrency, $Requests, $RunNumber, $IsWarmup = $false)
    
    $runType = if ($IsWarmup) { "WARM-UP" } else { "RUN $RunNumber" }
    Write-Host "  $runType - $($API.Name) - Concurrencia: $Concurrency" -ForegroundColor $(if ($IsWarmup) { "Yellow" } else { "Cyan" })
    
    try {
        # Ejecutar bombardier con formato JSON
        $result = bombardier -c $Concurrency -n $Requests --timeout=60s --format=json $API.URL 2>$null
        
        if ($result -and $result.Length -gt 0) {
            $jsonResult = $result | ConvertFrom-Json
            
            # Guardar resultado individual (solo si no es warm-up)
            if (-not $IsWarmup) {
                $filename = "bomb_$($Concurrency)_$($API.Name)_run$RunNumber.json"
                $filepath = Join-Path $ResultsDir $filename
                $result | Out-File -FilePath $filepath -Encoding UTF8
            }
            
            return @{
                API = $API.Name
                Concurrency = $Concurrency
                Run = $RunNumber
                IsWarmup = $IsWarmup
                RequestsPerSec = [math]::Round($jsonResult.result.rps.mean, 2)
                LatencyMean = [math]::Round($jsonResult.result.latencies.mean / 1000000, 2)  # ns to ms
                LatencyP50 = [math]::Round($jsonResult.result.latencies.p50 / 1000000, 2)
                LatencyP95 = [math]::Round($jsonResult.result.latencies.p95 / 1000000, 2)
                LatencyP99 = [math]::Round($jsonResult.result.latencies.p99 / 1000000, 2)
                ErrorCount = $jsonResult.result.errors.total
                ErrorRate = [math]::Round(($jsonResult.result.errors.total / $Requests) * 100, 2)
                Success = $true
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
        else {
            Write-Host "    ERROR: Respuesta vacía de bombardier" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return @{
        API = $API.Name
        Concurrency = $Concurrency
        Run = $RunNumber
        IsWarmup = $IsWarmup
        Success = $false
        Error = $_.Exception.Message
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

# Verificar que todas las APIs estén funcionando
Write-Host "Verificando APIs..." -ForegroundColor Yellow
foreach ($API in $APIs) {
    try {
        $response = Invoke-RestMethod -Uri $API.URL -Method GET -TimeoutSec 5
        Write-Host "  OK: $($API.Name) API (Latencia reportada: $($response.latency_ms)ms)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR: $($API.Name) API no responde" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Ejecutar benchmarks robustos
$AllResults = @()
$StartTime = Get-Date

foreach ($API in $APIs) {
    Write-Host "PROBANDO $($API.Name) API" -ForegroundColor Magenta
    Write-Host "=" * 30 -ForegroundColor Magenta
    
    foreach ($concurrency in $ConcurrencyPoints) {
        Write-Host "Concurrencia: $concurrency" -ForegroundColor White
        
        # 1. Warm-up (descartado)
        $warmupResult = Run-SingleBenchmark -API $API -Concurrency $concurrency -Requests $WarmupRequests -RunNumber 0 -IsWarmup $true
        Start-Sleep -Seconds 2
        
        # 2. Ejecutar réplicas válidas
        for ($run = 1; $run -le $Replicas; $run++) {
            $result = Run-SingleBenchmark -API $API -Concurrency $concurrency -Requests $Requests -RunNumber $run
            
            if ($result.Success) {
                $AllResults += $result
                Write-Host "    OK: RPS=$($result.RequestsPerSec), P95=$($result.LatencyP95)ms, Errores=$($result.ErrorCount)" -ForegroundColor Green
            }
            else {
                Write-Host "    FALLO: $($result.Error)" -ForegroundColor Red
            }
            
            # Pausa entre corridas para estabilización
            Start-Sleep -Seconds 3
        }
        
        Write-Host ""
    }
    
    # Pausa entre APIs
    Start-Sleep -Seconds 5
}

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Procesar resultados y calcular estadísticas
Write-Host "PROCESANDO RESULTADOS ESTADISTICOS" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green

$ConsolidatedResults = @()

foreach ($API in $APIs) {
    foreach ($concurrency in $ConcurrencyPoints) {
        $apiRuns = $AllResults | Where-Object { $_.API -eq $API.Name -and $_.Concurrency -eq $concurrency -and $_.Success }
        
        if ($apiRuns.Count -gt 0) {
            $latencyP95Values = $apiRuns | ForEach-Object { $_.LatencyP95 }
            $rpsValues = $apiRuns | ForEach-Object { $_.RequestsPerSec }
            $errorCounts = $apiRuns | ForEach-Object { $_.ErrorCount }
            
            # Calcular estadísticas
            $meanP95 = ($latencyP95Values | Measure-Object -Average).Average
            $stddevP95 = if ($latencyP95Values.Count -gt 1) { 
                [math]::Sqrt((($latencyP95Values | ForEach-Object { ($_ - $meanP95) * ($_ - $meanP95) }) | Measure-Object -Sum).Sum / ($latencyP95Values.Count - 1))
            } else { 0 }
            
            $meanRPS = ($rpsValues | Measure-Object -Average).Average
            $stddevRPS = if ($rpsValues.Count -gt 1) { 
                [math]::Sqrt((($rpsValues | ForEach-Object { ($_ - $meanRPS) * ($_ - $meanRPS) }) | Measure-Object -Sum).Sum / ($rpsValues.Count - 1))
            } else { 0 }
            
            $totalErrors = ($errorCounts | Measure-Object -Sum).Sum
            $cv = if ($meanP95 -gt 0) { ($stddevP95 / $meanP95) * 100 } else { 0 }
            
            $ConsolidatedResults += @{
                API = $API.Name
                x = $concurrency
                mean_p95_ms = [math]::Round($meanP95, 3)
                stddev_ms = [math]::Round($stddevP95, 3)
                cv_percent = [math]::Round($cv, 2)
                mean_rps = [math]::Round($meanRPS, 1)
                stddev_rps = [math]::Round($stddevRPS, 1)
                total_errors = $totalErrors
                valid_runs = $apiRuns.Count
                min_p95 = ($latencyP95Values | Measure-Object -Minimum).Minimum
                max_p95 = ($latencyP95Values | Measure-Object -Maximum).Maximum
            }
            
            Write-Host "$($API.Name) @ x=$concurrency : $([math]::Round($meanP95, 2)) ± $([math]::Round($stddevP95, 2)) ms (CV: $([math]::Round($cv, 1))%)" -ForegroundColor White
        }
        else {
            Write-Host "$($API.Name) @ x=$concurrency : SIN DATOS VALIDOS" -ForegroundColor Red
        }
    }
}

# Exportar CSV consolidado
$CsvPath = "consolidated_benchmark_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$ConsolidatedResults | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

# Exportar resultados individuales también
$AllResultsPath = "all_individual_runs_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$AllResults | Where-Object { $_.Success } | Export-Csv -Path $AllResultsPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "RESUMEN FINAL" -ForegroundColor Green
Write-Host "=============" -ForegroundColor Green
Write-Host "Duración total: $($Duration.TotalMinutes.ToString('F1')) minutos" -ForegroundColor White
Write-Host "Corridas exitosas: $($AllResults | Where-Object { $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
Write-Host "Corridas fallidas: $($AllResults | Where-Object { -not $_.Success } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
Write-Host ""
Write-Host "ARCHIVOS GENERADOS:" -ForegroundColor Cyan
Write-Host "1. CSV consolidado: $CsvPath" -ForegroundColor White
Write-Host "2. Corridas individuales: $AllResultsPath" -ForegroundColor White
Write-Host "3. JSONs individuales: $ResultsDir/*.json" -ForegroundColor White
Write-Host ""
Write-Host "VALIDACION ESTADISTICA COMPLETADA" -ForegroundColor Green
Write-Host "Datos listos para modelado matemático T(x)" -ForegroundColor Yellow 