# Script de Benchmark Avanzado con Validez Estadística
# Implementa warm-up, múltiples réplicas y análisis diferencial

param(
    [int]$WarmupRequests = 500,
    [int]$BenchmarkRequests = 5000,
    [int]$Replicas = 5,
    [int]$MinConcurrency = 10,
    [int]$MaxConcurrency = 500,
    [int]$ConcurrencyStep = 25,
    [int]$FibonacciSize = 30,
    [string]$OutputDir = "data/advanced-benchmark"
)

# Crear directorio de salida
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Configuración de APIs
$APIs = @(
    @{Name="go-api"; Port=8081; Language="Go"},
    @{Name="python-api"; Port=8082; Language="Python"},
    @{Name="node-api"; Port=8083; Language="Node.js"},
    @{Name="dotnet-api"; Port=8084; Language=".NET"}
)

Write-Host "🚀 BENCHMARK AVANZADO CON VALIDEZ ESTADÍSTICA" -ForegroundColor Blue
Write-Host "=============================================" -ForegroundColor Blue
Write-Host "Configuración:" -ForegroundColor Cyan
Write-Host "  - Warm-up: $WarmupRequests requests" -ForegroundColor Gray
Write-Host "  - Benchmark: $BenchmarkRequests requests" -ForegroundColor Gray
Write-Host "  - Réplicas: $Replicas por punto" -ForegroundColor Gray
Write-Host "  - Concurrencia: $MinConcurrency-$MaxConcurrency (step $ConcurrencyStep)" -ForegroundColor Gray
Write-Host "  - Fibonacci: F($FibonacciSize)" -ForegroundColor Gray
Write-Host ""

# Función para ejecutar warm-up
function Invoke-Warmup {
    param([string]$Url, [string]$ApiName)
    
    Write-Host "🔥 Warm-up $ApiName..." -ForegroundColor Yellow
    $null = bombardier -c 10 -n $WarmupRequests $Url 2>&1
    Start-Sleep -Seconds 2
}

# Función para parsear resultados de Bombardier
function Parse-BombardierOutput {
    param([string[]]$Output)
    
    $Stats = @{
        ReqsPerSec = 0
        AvgLatency = 0
        P95Latency = 0
        P99Latency = 0
        Errors = 0
    }
    
    foreach ($Line in $Output) {
        if ($Line -match "Reqs/sec\s+(\d+\.?\d*)") {
            $Stats.ReqsPerSec = [double]$Matches[1]
        }
        elseif ($Line -match "Latency\s+(\d+\.?\d*)(ms|µs)") {
            $Value = [double]$Matches[1]
            if ($Matches[2] -eq "µs") { $Value = $Value / 1000 }
            $Stats.AvgLatency = $Value
        }
        elseif ($Line -match "95%\s+(\d+\.?\d*)(ms|µs)") {
            $Value = [double]$Matches[1]
            if ($Matches[2] -eq "µs") { $Value = $Value / 1000 }
            $Stats.P95Latency = $Value
        }
        elseif ($Line -match "99%\s+(\d+\.?\d*)(ms|µs)") {
            $Value = [double]$Matches[1]
            if ($Matches[2] -eq "µs") { $Value = $Value / 1000 }
            $Stats.P99Latency = $Value
        }
        elseif ($Line -match "Non-2xx or 3xx responses:\s+(\d+)") {
            $Stats.Errors = [int]$Matches[1]
        }
    }
    
    return $Stats
}

# Función para calcular estadísticas
function Calculate-Statistics {
    param([double[]]$Values)
    
    if ($Values.Count -eq 0) { return @{Mean=0; StdDev=0; Min=0; Max=0} }
    
    $Mean = ($Values | Measure-Object -Average).Average
    $Variance = ($Values | ForEach-Object { [Math]::Pow($_ - $Mean, 2) } | Measure-Object -Average).Average
    $StdDev = [Math]::Sqrt($Variance)
    $Min = ($Values | Measure-Object -Minimum).Minimum
    $Max = ($Values | Measure-Object -Maximum).Maximum
    
    return @{
        Mean = $Mean
        StdDev = $StdDev
        Min = $Min
        Max = $Max
    }
}

# Inicializar archivo CSV de resultados
$CsvPath = "$OutputDir/benchmark-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$CsvHeader = "API,Language,Concurrency,Replica,ReqsPerSec,AvgLatency,P95Latency,P99Latency,Errors,Timestamp"
$CsvHeader | Out-File -FilePath $CsvPath -Encoding UTF8

# Ejecutar benchmarks
foreach ($Api in $APIs) {
    $ApiUrl = "http://localhost:$($Api.Port)/compute?size=$FibonacciSize"
    
    Write-Host ""
    Write-Host "📊 Benchmarking $($Api.Name) ($($Api.Language))" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    
    # Warm-up
    Invoke-Warmup -Url $ApiUrl -ApiName $Api.Name
    
    # Ejecutar para cada nivel de concurrencia
    for ($Concurrency = $MinConcurrency; $Concurrency -le $MaxConcurrency; $Concurrency += $ConcurrencyStep) {
        Write-Host ""
        Write-Host "  Concurrencia: $Concurrency" -ForegroundColor Cyan
        
        # Ejecutar múltiples réplicas
        for ($Replica = 1; $Replica -le $Replicas; $Replica++) {
            Write-Host "    Réplica $Replica/$Replicas..." -ForegroundColor Gray
            
            try {
                $Output = bombardier -c $Concurrency -n $BenchmarkRequests $ApiUrl 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $Stats = Parse-BombardierOutput -Output $Output
                    
                    # Guardar en CSV
                    $CsvLine = "$($Api.Name),$($Api.Language),$Concurrency,$Replica,$($Stats.ReqsPerSec),$($Stats.AvgLatency),$($Stats.P95Latency),$($Stats.P99Latency),$($Stats.Errors),$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                    $CsvLine | Out-File -FilePath $CsvPath -Append -Encoding UTF8
                    
                    Write-Host "      RPS: $($Stats.ReqsPerSec), Latencia: $($Stats.AvgLatency)ms" -ForegroundColor White
                }
                else {
                    Write-Host "      ❌ Error en benchmark" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "      ❌ Excepción: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Pausa entre réplicas
            Start-Sleep -Seconds 2
        }
    }
}

Write-Host ""
Write-Host "✅ Benchmark completado!" -ForegroundColor Green
Write-Host "📄 Resultados guardados en: $CsvPath" -ForegroundColor Cyan

# Generar análisis estadístico
Write-Host ""
Write-Host "📈 Generando análisis estadístico..." -ForegroundColor Yellow

$AnalysisScript = @"
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from scipy.optimize import curve_fit
import os

# Configurar estilo
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

# Leer datos
df = pd.read_csv('$($CsvPath.Replace('\', '/'))')

# Análisis estadístico por API y concurrencia
print("🔍 ANÁLISIS ESTADÍSTICO AVANZADO")
print("=" * 50)

results = []
for api in df['API'].unique():
    for lang in df[df['API'] == api]['Language'].unique():
        api_data = df[(df['API'] == api) & (df['Language'] == lang)]
        
        for conc in sorted(api_data['Concurrency'].unique()):
            conc_data = api_data[api_data['Concurrency'] == conc]
            
            if len(conc_data) > 1:
                # Estadísticas descriptivas
                rps_stats = {
                    'mean': conc_data['ReqsPerSec'].mean(),
                    'std': conc_data['ReqsPerSec'].std(),
                    'min': conc_data['ReqsPerSec'].min(),
                    'max': conc_data['ReqsPerSec'].max(),
                    'cv': conc_data['ReqsPerSec'].std() / conc_data['ReqsPerSec'].mean()
                }
                
                lat_stats = {
                    'mean': conc_data['AvgLatency'].mean(),
                    'std': conc_data['AvgLatency'].std(),
                    'min': conc_data['AvgLatency'].min(),
                    'max': conc_data['AvgLatency'].max(),
                    'cv': conc_data['AvgLatency'].std() / conc_data['AvgLatency'].mean()
                }
                
                results.append({
                    'API': api,
                    'Language': lang,
                    'Concurrency': conc,
                    'RPS_Mean': rps_stats['mean'],
                    'RPS_StdDev': rps_stats['std'],
                    'RPS_CV': rps_stats['cv'],
                    'Latency_Mean': lat_stats['mean'],
                    'Latency_StdDev': lat_stats['std'],
                    'Latency_CV': lat_stats['cv'],
                    'Samples': len(conc_data)
                })

# Crear DataFrame de estadísticas
stats_df = pd.DataFrame(results)

# Guardar estadísticas
stats_path = '$($OutputDir.Replace('\', '/'))/statistical-analysis.csv'
stats_df.to_csv(stats_path, index=False)

print(f"📊 Estadísticas guardadas en: {stats_path}")

# Crear gráficos
fig, axes = plt.subplots(2, 2, figsize=(15, 12))
fig.suptitle('Análisis de Rendimiento con Intervalos de Confianza', fontsize=16)

# 1. Throughput vs Concurrencia
ax1 = axes[0, 0]
for api in stats_df['API'].unique():
    api_stats = stats_df[stats_df['API'] == api]
    x = api_stats['Concurrency']
    y = api_stats['RPS_Mean']
    yerr = api_stats['RPS_StdDev']
    
    ax1.errorbar(x, y, yerr=yerr, marker='o', capsize=5, label=api_stats['Language'].iloc[0])

ax1.set_xlabel('Concurrencia')
ax1.set_ylabel('Requests/segundo')
ax1.set_title('Throughput vs Concurrencia')
ax1.legend()
ax1.grid(True, alpha=0.3)

# 2. Latencia vs Concurrencia
ax2 = axes[0, 1]
for api in stats_df['API'].unique():
    api_stats = stats_df[stats_df['API'] == api]
    x = api_stats['Concurrency']
    y = api_stats['Latency_Mean']
    yerr = api_stats['Latency_StdDev']
    
    ax2.errorbar(x, y, yerr=yerr, marker='s', capsize=5, label=api_stats['Language'].iloc[0])

ax2.set_xlabel('Concurrencia')
ax2.set_ylabel('Latencia (ms)')
ax2.set_title('Latencia vs Concurrencia')
ax2.legend()
ax2.grid(True, alpha=0.3)

# 3. Coeficiente de Variación - RPS
ax3 = axes[1, 0]
for api in stats_df['API'].unique():
    api_stats = stats_df[stats_df['API'] == api]
    x = api_stats['Concurrency']
    y = api_stats['RPS_CV'] * 100  # Convertir a porcentaje
    
    ax3.plot(x, y, marker='^', label=api_stats['Language'].iloc[0])

ax3.set_xlabel('Concurrencia')
ax3.set_ylabel('Coeficiente de Variación (%)')
ax3.set_title('Estabilidad del Throughput')
ax3.legend()
ax3.grid(True, alpha=0.3)

# 4. Eficiencia (RPS/Latencia)
ax4 = axes[1, 1]
for api in stats_df['API'].unique():
    api_stats = stats_df[stats_df['API'] == api]
    x = api_stats['Concurrency']
    y = api_stats['RPS_Mean'] / api_stats['Latency_Mean']
    
    ax4.plot(x, y, marker='d', label=api_stats['Language'].iloc[0])

ax4.set_xlabel('Concurrencia')
ax4.set_ylabel('Eficiencia (RPS/ms)')
ax4.set_title('Eficiencia vs Concurrencia')
ax4.legend()
ax4.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('$($OutputDir.Replace('\', '/'))/advanced-statistical-analysis.png', dpi=300, bbox_inches='tight')
plt.close()

print("📈 Gráficos guardados en: advanced-statistical-analysis.png")

# Análisis de regresión y derivadas
print("\n🧮 ANÁLISIS DE REGRESIÓN Y CÁLCULO DIFERENCIAL")
print("=" * 50)

def quadratic_model(x, a, b, c):
    return a * x**2 + b * x + c

def exponential_model(x, a, b):
    return a * np.exp(b * x)

regression_results = []

for api in stats_df['API'].unique():
    api_stats = stats_df[stats_df['API'] == api].sort_values('Concurrency')
    
    if len(api_stats) >= 3:  # Necesitamos al menos 3 puntos para regresión cuadrática
        x = api_stats['Concurrency'].values
        y_latency = api_stats['Latency_Mean'].values
        
        try:
            # Ajuste cuadrático: T(x) = ax² + bx + c
            popt_quad, pcov_quad = curve_fit(quadratic_model, x, y_latency)
            a, b, c = popt_quad
            
            # Calcular R²
            y_pred_quad = quadratic_model(x, a, b, c)
            r2_quad = 1 - np.sum((y_latency - y_pred_quad)**2) / np.sum((y_latency - np.mean(y_latency))**2)
            
            # Derivadas
            # T'(x) = 2ax + b
            # T''(x) = 2a
            
            x_range = np.linspace(x.min(), x.max(), 100)
            T_x = quadratic_model(x_range, a, b, c)
            T_prime_x = 2*a*x_range + b
            T_double_prime = 2*a
            
            # Punto crítico donde T'(x) = 0
            critical_point = -b/(2*a) if a != 0 else None
            
            regression_results.append({
                'API': api,
                'Language': api_stats['Language'].iloc[0],
                'Model': 'Quadratic',
                'a': a,
                'b': b,
                'c': c,
                'R2': r2_quad,
                'T_double_prime': T_double_prime,
                'Critical_Point': critical_point,
                'Interpretation': 'Acelerada' if a > 0 else 'Desacelerada' if a < 0 else 'Lineal'
            })
            
            print(f"\n{api_stats['Language'].iloc[0]} ({api}):")
            print(f"  T(x) = {a:.6f}x² + {b:.4f}x + {c:.2f}")
            print(f"  T'(x) = {2*a:.6f}x + {b:.4f}")
            print(f"  T''(x) = {T_double_prime:.6f}")
            print(f"  R² = {r2_quad:.4f}")
            if critical_point and x.min() <= critical_point <= x.max():
                print(f"  Punto crítico: x = {critical_point:.1f}")
            print(f"  Interpretación: {regression_results[-1]['Interpretation']}")
            
        except Exception as e:
            print(f"Error en regresión para {api}: {e}")

# Guardar resultados de regresión
if regression_results:
    regression_df = pd.DataFrame(regression_results)
    regression_path = '$($OutputDir.Replace('\', '/'))/regression-analysis.csv'
    regression_df.to_csv(regression_path, index=False)
    print(f"\n📊 Análisis de regresión guardado en: {regression_path}")

print("\n✅ Análisis estadístico completado!")
"@

# Escribir y ejecutar script de análisis
$AnalysisPath = "$OutputDir/statistical_analysis.py"
$AnalysisScript | Out-File -FilePath $AnalysisPath -Encoding UTF8

try {
    python $AnalysisPath
}
catch {
    Write-Host "⚠️  Para análisis completo, instalar: pip install pandas numpy matplotlib seaborn scipy" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 BENCHMARK AVANZADO COMPLETADO" -ForegroundColor Green
Write-Host "Archivos generados:" -ForegroundColor Cyan
Write-Host "  - $CsvPath" -ForegroundColor Gray
Write-Host "  - $OutputDir/statistical-analysis.csv" -ForegroundColor Gray
Write-Host "  - $OutputDir/regression-analysis.csv" -ForegroundColor Gray
Write-Host "  - $OutputDir/advanced-statistical-analysis.png" -ForegroundColor Gray 