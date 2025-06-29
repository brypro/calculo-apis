Write-Host "🚀 BENCHMARK RAPIDO DE APIS OPTIMIZADAS" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""

$APIs = @(
    @{ Name = "Go (FastHTTP)"; URL = "http://localhost:8081/compute?size=30" },
    @{ Name = "Python (uvloop)"; URL = "http://localhost:8082/compute?size=30" },
    @{ Name = "Node.js (Express)"; URL = "http://localhost:8083/compute?size=30" },
    @{ Name = ".NET (Kestrel)"; URL = "http://localhost:8084/compute?size=30" }
)

$Results = @()

foreach ($API in $APIs) {
    Write-Host "📊 $($API.Name):" -ForegroundColor Cyan
    
    $times = @()
    for ($i = 1; $i -le 10; $i++) {
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri $API.URL -Method GET -TimeoutSec 5
            $end = Get-Date
            $latency = ($end - $start).TotalMilliseconds
            $times += $latency
            Write-Host "  Test $i`: $([math]::Round($latency, 2))ms - Fibonacci(30) = $($response.result)" -ForegroundColor White
        }
        catch {
            Write-Host "  Test $i`: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 100
    }
    
    if ($times.Count -gt 0) {
        $avg = ($times | Measure-Object -Average).Average
        $min = ($times | Measure-Object -Minimum).Minimum
        $max = ($times | Measure-Object -Maximum).Maximum
        
        Write-Host "  📈 Promedio: $([math]::Round($avg, 2))ms" -ForegroundColor Yellow
        Write-Host "  ⚡ Minimo: $([math]::Round($min, 2))ms" -ForegroundColor Green
        Write-Host "  🔥 Maximo: $([math]::Round($max, 2))ms" -ForegroundColor Red
        
        $Results += [PSCustomObject]@{
            API = $API.Name
            AvgLatency = [math]::Round($avg, 2)
            MinLatency = [math]::Round($min, 2)
            MaxLatency = [math]::Round($max, 2)
            EstimatedRPS = [math]::Round(1000 / $avg, 2)
        }
    }
    
    Write-Host ""
}

Write-Host "🏆 RANKING DE RENDIMIENTO" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host ""

Write-Host "Por MENOR latencia promedio:" -ForegroundColor Cyan
$RankingLatency = $Results | Sort-Object AvgLatency
$Position = 1
foreach ($Result in $RankingLatency) {
    $Medal = switch ($Position) {
        1 { "🥇" }
        2 { "🥈" }
        3 { "🥉" }
        default { "🏅" }
    }
    Write-Host "$Medal $Position. $($Result.API): $($Result.AvgLatency)ms promedio" -ForegroundColor Yellow
    $Position++
}

Write-Host ""
Write-Host "Por MAYOR throughput estimado:" -ForegroundColor Cyan
$RankingThroughput = $Results | Sort-Object EstimatedRPS -Descending
$Position = 1
foreach ($Result in $RankingThroughput) {
    $Medal = switch ($Position) {
        1 { "🥇" }
        2 { "🥈" }
        3 { "🥉" }
        default { "🏅" }
    }
    Write-Host "$Medal $Position. $($Result.API): ~$($Result.EstimatedRPS) req/s estimado" -ForegroundColor Yellow
    $Position++
}

Write-Host ""
Write-Host "🎉 Benchmark completado!" -ForegroundColor Green 