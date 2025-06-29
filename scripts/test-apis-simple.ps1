# Script para probar rapidamente todas las APIs
# Verifica que todas esten funcionando correctamente

param(
    [int]$Size = 30
)

# Configuracion de APIs
$APIs = @(
    @{Name="Go API"; Port=8081; Color="Green"},
    @{Name="Python API"; Port=8082; Color="Blue"},
    @{Name="Node.js API"; Port=8083; Color="Yellow"},
    @{Name=".NET API"; Port=8084; Color="Magenta"}
)

Write-Host "Probando APIs con size=$Size" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

foreach ($Api in $APIs) {
    $Url = "http://localhost:$($Api.Port)/compute?size=$Size"
    $HealthUrl = "http://localhost:$($Api.Port)/health"
    
    Write-Host ""
    Write-Host "Probando $($Api.Name) (puerto $($Api.Port))" -ForegroundColor $Api.Color
    
    try {
        # Probar health endpoint
        $HealthResponse = Invoke-WebRequest -Uri $HealthUrl -TimeoutSec 5 -ErrorAction Stop
        if ($HealthResponse.StatusCode -eq 200) {
            Write-Host "  Health check: OK" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Health check: FAILED" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
    
    try {
        # Probar endpoint principal
        $StartTime = Get-Date
        $Response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -ErrorAction Stop
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalMilliseconds
        
        if ($Response.StatusCode -eq 200) {
            $Data = $Response.Content | ConvertFrom-Json
            
            Write-Host "  Compute endpoint: OK" -ForegroundColor Green
            Write-Host "     Resultado: $($Data.result)" -ForegroundColor White
            Write-Host "     Size: $($Data.size)" -ForegroundColor White
            Write-Host "     Latencia API: $($Data.latency_ms)ms" -ForegroundColor White
            Write-Host "     Latencia total: $([math]::Round($Duration, 2))ms" -ForegroundColor White
        }
        else {
            Write-Host "  Compute endpoint: HTTP $($Response.StatusCode)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  Compute endpoint: FAILED" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Resumen de pruebas:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# Contar APIs exitosas
$SuccessfulAPIs = 0
foreach ($Api in $APIs) {
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost:$($Api.Port)/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($Response.StatusCode -eq 200) {
            $SuccessfulAPIs++
            Write-Host "$($Api.Name): Funcionando" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "$($Api.Name): No disponible" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "APIs funcionando: $SuccessfulAPIs/$($APIs.Count)" -ForegroundColor Cyan

if ($SuccessfulAPIs -eq $APIs.Count) {
    Write-Host "Todas las APIs estan funcionando correctamente!" -ForegroundColor Green
    Write-Host "Puedes proceder con los benchmarks." -ForegroundColor Green
}
else {
    Write-Host "Algunas APIs no estan disponibles." -ForegroundColor Yellow
    Write-Host "Ejecuta: docker-compose up --build" -ForegroundColor Yellow
} 