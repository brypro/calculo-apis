# Script de PowerShell para ejecutar benchmarks de APIs
# Requiere: bombardier instalado (go install github.com/codesenberg/bombardier@latest)

param(
    [int]$MaxConcurrency = 100,
    [int]$Requests = 5000
)

# Configuración
$ResultsDir = "results"
$APIs = @(
    @{Name="go-api"; Port=8081},
    @{Name="python-api"; Port=8082},
    @{Name="node-api"; Port=8083},
    @{Name="dotnet-api"; Port=8084}
)

# Crear directorio de resultados
if (!(Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir | Out-Null
}

Write-Host "🚀 Iniciando benchmarks de APIs" -ForegroundColor Blue
Write-Host "==================================" -ForegroundColor Blue

# Función para verificar si una API está lista
function Test-ApiReady {
    param([int]$Port)
    
    $MaxAttempts = 30
    $Attempt = 1
    
    while ($Attempt -le $MaxAttempts) {
        try {
            $Response = Invoke-WebRequest -Uri "http://localhost:$Port/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($Response.StatusCode -eq 200) {
                return $true
            }
        }
        catch {
            # Ignorar errores de conexión
        }
        
        Write-Host "⏳ Esperando API en puerto $Port... (intento $Attempt/$MaxAttempts)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        $Attempt++
    }
    return $false
}

# Función para ejecutar benchmark
function Invoke-Benchmark {
    param(
        [string]$ApiName,
        [int]$Port,
        [int]$Concurrency,
        [int]$Requests
    )
    
    Write-Host "📊 Ejecutando benchmark para $ApiName (puerto $Port)" -ForegroundColor Green
    Write-Host "  - Concurrencia: $Concurrency" -ForegroundColor White
    Write-Host "  - Requests: $Requests" -ForegroundColor White
    
    $OutputFile = "$ResultsDir\${ApiName}_c${Concurrency}.json"
    
    try {
        bombardier -c $Concurrency -n $Requests -o json "http://localhost:$Port/compute?size=30" | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "✅ Benchmark completado: $OutputFile" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error ejecutando benchmark para $ApiName: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Verificar que bombardier esté instalado
try {
    $null = Get-Command bombardier -ErrorAction Stop
}
catch {
    Write-Host "❌ Error: bombardier no está instalado" -ForegroundColor Red
    Write-Host "Instala con: go install github.com/codesenberg/bombardier@latest" -ForegroundColor Yellow
    exit 1
}

# Verificar que las APIs estén ejecutándose
Write-Host "🔍 Verificando que las APIs estén listas..." -ForegroundColor Blue
foreach ($Api in $APIs) {
    if (!(Test-ApiReady -Port $Api.Port)) {
        Write-Host "❌ Error: API $($Api.Name) no está disponible en puerto $($Api.Port)" -ForegroundColor Red
        Write-Host "Asegúrate de ejecutar: docker-compose up --build" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ $($Api.Name) está lista" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎯 Configuraciones de benchmark:" -ForegroundColor Blue

# Configuraciones de concurrencia para probar
$Concurrencies = @(1, 5, 10, 25, 50, 100)

foreach ($Concurrency in $Concurrencies) {
    if ($Concurrency -gt $MaxConcurrency) {
        break
    }
    
    Write-Host "🔄 Ejecutando con concurrencia: $Concurrency" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    
    foreach ($Api in $APIs) {
        Invoke-Benchmark -ApiName $Api.Name -Port $Api.Port -Concurrency $Concurrency -Requests $Requests
    }
    
    Write-Host "⏸️  Pausa de 5 segundos entre configuraciones..." -ForegroundColor Blue
    Start-Sleep -Seconds 5
}

Write-Host ""
Write-Host "🎉 Todos los benchmarks completados!" -ForegroundColor Green
Write-Host "📁 Resultados guardados en: $ResultsDir" -ForegroundColor Blue
Write-Host ""

Write-Host "📊 Resumen de archivos generados:" -ForegroundColor Yellow
Get-ChildItem -Path $ResultsDir -Filter "*.json" | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}

Write-Host ""
Write-Host "📈 Para analizar los resultados, puedes usar:" -ForegroundColor Blue
Write-Host "  - Python: python scripts/analyze_results.py" -ForegroundColor White
Write-Host "  - Excel: Importar archivos JSON" -ForegroundColor White
Write-Host "  - Grafana: Configurar datasource JSON" -ForegroundColor White 