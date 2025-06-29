# Benchmark Simple para APIs Optimizadas
param(
    [int]$Duration = 30,
    [int]$MaxConcurrency = 200,
    [int]$Step = 20
)

Write-Host "🚀 BENCHMARK SIMPLE DE APIS ULTRA-OPTIMIZADAS" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Verificar que bombardier esté disponible
if (-not (Get-Command bombardier -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: bombardier no está instalado" -ForegroundColor Red
    Write-Host "Instala bombardier desde: https://github.com/codesenberg/bombardier" -ForegroundColor Yellow
    exit 1
}

# Configuración de APIs
$APIs = @(
    @{ Name = "Go API (FastHTTP)"; URL = "http://localhost:8081/compute?size=30"; Language = "Go" },
    @{ Name = "Python API (uvloop)"; URL = "http://localhost:8082/compute?size=30"; Language = "Python" },
    @{ Name = "Node.js API (Express)"; URL = "http://localhost:8083/compute?size=30"; Language = "Node.js" },
    @{ Name = ".NET API (Kestrel)"; URL = "http://localhost:8084/compute?size=30"; Language = ".NET" }
)

# Verificar que todas las APIs estén disponibles
Write-Host "🔍 Verificando APIs..." -ForegroundColor Yellow
foreach ($API in $APIs) {
    try {
        $response = Invoke-RestMethod -Uri $API.URL -Method GET -TimeoutSec 5
        Write-Host "✅ $($API.Name) - OK" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $($API.Name) - ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎯 Iniciando benchmark..." -ForegroundColor Cyan
Write-Host "Duración: $Duration segundos por test" -ForegroundColor Gray
Write-Host "Concurrencia máxima: $MaxConcurrency" -ForegroundColor Gray
Write-Host "Paso: $Step" -ForegroundColor Gray
Write-Host ""

# Resultados
$Results = @()

# Ejecutar benchmarks
for ($Concurrency = 10; $Concurrency -le $MaxConcurrency; $Concurrency += $Step) {
    Write-Host "📊 Probando concurrencia: $Concurrency" -ForegroundColor Magenta
    
    foreach ($API in $APIs) {
        Write-Host "  🔄 $($API.Name)..." -ForegroundColor White
        
        # Warm-up
        $null = bombardier -c 5 -n 100 -l $API.URL 2>$null
        
        # Benchmark real
        $BombardierOutput = bombardier -c $Concurrency -d "${Duration}s" -l $API.URL 2>$null
        
        if ($BombardierOutput) {
            # Parsear resultados
            $ReqsPerSecLine = $BombardierOutput | Select-String "Reqs/sec"
            $LatencyLine = $BombardierOutput | Select-String "Latency"
            
            if ($ReqsPerSecLine) {
                $ReqsPerSec = [regex]::Match($ReqsPerSecLine.Line, "[\d.]+").Value
                $LatencyMatch = [regex]::Match($LatencyLine.Line, "[\d.]+ms")
                $Latency = if ($LatencyMatch.Success) { $LatencyMatch.Value -replace "ms", "" } else { "0" }
                
                $Results += [PSCustomObject]@{
                    API = $API.Name
                    Language = $API.Language
                    Concurrency = $Concurrency
                    ReqsPerSec = [double]$ReqsPerSec
                    LatencyMs = [double]$Latency
                    Timestamp = Get-Date
                }
                
                Write-Host "    ✅ $ReqsPerSec req/s, ${Latency}ms latency" -ForegroundColor Green
            }
            else {
                Write-Host "    ❌ Error parseando resultados" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    ❌ Error ejecutando bombardier" -ForegroundColor Red
        }
        
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""
}

# Generar reporte
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$CsvPath = "benchmark-results-$Timestamp.csv"
$Results | Export-Csv -Path $CsvPath -NoTypeInformation

Write-Host "📈 RESUMEN DE RESULTADOS" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""

# Mostrar mejores resultados por API
foreach ($API in $APIs) {
    $APIResults = $Results | Where-Object { $_.Language -eq $API.Language }
    if ($APIResults) {
        $BestThroughput = $APIResults | Sort-Object ReqsPerSec -Descending | Select-Object -First 1
        $BestLatency = $APIResults | Sort-Object LatencyMs | Select-Object -First 1
        
        Write-Host "$($API.Language) API:" -ForegroundColor Cyan
        Write-Host "  🚀 Mejor throughput: $([math]::Round($BestThroughput.ReqsPerSec, 2)) req/s (concurrencia: $($BestThroughput.Concurrency))" -ForegroundColor Yellow
        Write-Host "  ⚡ Mejor latencia: $([math]::Round($BestLatency.LatencyMs, 2))ms (concurrencia: $($BestLatency.Concurrency))" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Ranking final
Write-Host "🏆 RANKING POR THROUGHPUT MÁXIMO" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
$RankingThroughput = $Results | Group-Object Language | ForEach-Object {
    $MaxThroughput = $_.Group | Sort-Object ReqsPerSec -Descending | Select-Object -First 1
    [PSCustomObject]@{
        Language = $_.Name
        MaxReqsPerSec = $MaxThroughput.ReqsPerSec
        AtConcurrency = $MaxThroughput.Concurrency
    }
} | Sort-Object MaxReqsPerSec -Descending

$Position = 1
foreach ($Entry in $RankingThroughput) {
    $Medal = switch ($Position) {
        1 { "🥇" }
        2 { "🥈" }
        3 { "🥉" }
        default { "🏅" }
    }
    Write-Host "$Medal $Position. $($Entry.Language): $([math]::Round($Entry.MaxReqsPerSec, 2)) req/s" -ForegroundColor Yellow
    $Position++
}

Write-Host ""
Write-Host "🏆 RANKING POR MEJOR LATENCIA" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
$RankingLatency = $Results | Group-Object Language | ForEach-Object {
    $BestLatency = $_.Group | Sort-Object LatencyMs | Select-Object -First 1
    [PSCustomObject]@{
        Language = $_.Name
        BestLatencyMs = $BestLatency.LatencyMs
        AtConcurrency = $BestLatency.Concurrency
    }
} | Sort-Object BestLatencyMs

$Position = 1
foreach ($Entry in $RankingLatency) {
    $Medal = switch ($Position) {
        1 { "🥇" }
        2 { "🥈" }
        3 { "🥉" }
        default { "🏅" }
    }
    Write-Host "$Medal $Position. $($Entry.Language): $([math]::Round($Entry.BestLatencyMs, 2))ms" -ForegroundColor Yellow
    $Position++
}

Write-Host ""
Write-Host "💾 Resultados guardados en: $CsvPath" -ForegroundColor Green
Write-Host "🎉 Benchmark completado!" -ForegroundColor Green 