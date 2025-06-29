# Script de inicio simple para Windows
# Inicia las APIs y ejecuta pruebas basicas

Write-Host "Iniciando proyecto de benchmark de APIs" -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# 1. Construir y ejecutar APIs
Write-Host ""
Write-Host "Construyendo y ejecutando APIs..." -ForegroundColor Cyan
try {
    docker-compose up --build -d
    Write-Host "APIs iniciadas correctamente" -ForegroundColor Green
}
catch {
    Write-Host "Error iniciando APIs: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Esperar a que las APIs esten listas
Write-Host ""
Write-Host "Esperando que las APIs esten listas..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 3. Probar APIs
Write-Host ""
Write-Host "Probando APIs..." -ForegroundColor Cyan
try {
    & ".\scripts\test-apis.ps1"
}
catch {
    Write-Host "Error probando APIs: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Mostrar informacion util
Write-Host ""
Write-Host "Informacion util:" -ForegroundColor Blue
Write-Host "=================" -ForegroundColor Blue
Write-Host "Go API:      http://localhost:8081/compute?size=30" -ForegroundColor White
Write-Host "Python API:  http://localhost:8082/compute?size=30" -ForegroundColor White
Write-Host "Node.js API: http://localhost:8083/compute?size=30" -ForegroundColor White
Write-Host ".NET API:    http://localhost:8084/compute?size=30" -ForegroundColor White
Write-Host ""
Write-Host "Para ejecutar benchmarks:" -ForegroundColor Yellow
Write-Host "  .\scripts\run-benchmarks.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Para ver logs:" -ForegroundColor Yellow
Write-Host "  docker-compose logs -f" -ForegroundColor White
Write-Host ""
Write-Host "Para detener:" -ForegroundColor Yellow
Write-Host "  docker-compose down" -ForegroundColor White 