#!/usr/bin/env bash

# Script maestro de Bombardier para análisis de latencias
# Genera datos para cálculo diferencial T(x), T'(x), T''(x)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
DEFAULT_URL="http://localhost:8080/compute?size=30"
URL=${1:-$DEFAULT_URL}
DATA_DIR="data"
WARMUP_REQUESTS=100
TEST_REQUESTS=5000
CONCURRENCIES=(10 25 50 75 100 150 200 300)

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}🚀 Script Maestro de Bombardier${NC}"
    echo "=================================="
    echo ""
    echo "Uso: $0 [URL]"
    echo ""
    echo "Parámetros:"
    echo "  URL    URL del endpoint a probar (default: $DEFAULT_URL)"
    echo ""
    echo "Ejemplos:"
    echo "  $0                                    # Usar URL por defecto"
    echo "  $0 http://localhost:8081/compute     # Go API"
    echo "  $0 http://localhost:8082/compute     # Python API"
    echo "  $0 http://localhost:8083/compute     # Node.js API"
    echo "  $0 http://localhost:8084/compute     # .NET API"
    echo ""
    echo "Configuración:"
    echo "  Concurrencias: ${CONCURRENCIES[*]}"
    echo "  Requests por test: $TEST_REQUESTS"
    echo "  Requests de calentamiento: $WARMUP_REQUESTS"
    echo ""
}

# Verificar argumentos
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Verificar que bombardier esté instalado
if ! command -v bombardier &> /dev/null; then
    echo -e "${RED}❌ Error: bombardier no está instalado${NC}"
    echo "Instala con: go install github.com/codesenberg/bombardier@latest"
    exit 1
fi

# Crear directorio de datos
mkdir -p "$DATA_DIR"

echo -e "${BLUE}🚀 Iniciando análisis de latencias${NC}"
echo "=================================="
echo -e "${CYAN}URL objetivo: $URL${NC}"
echo -e "${CYAN}Directorio de datos: $DATA_DIR${NC}"
echo ""

# Función para calentar el endpoint
warmup_endpoint() {
    local url=$1
    echo -e "${YELLOW}🔥 Calentando endpoint...${NC}"
    
    bombardier -c 1 -n $WARMUP_REQUESTS -o json "$url" > /dev/null 2>&1
    
    echo -e "${GREEN}✅ Calentamiento completado${NC}"
    echo ""
}

# Función para ejecutar benchmark
run_benchmark() {
    local url=$1
    local concurrency=$2
    local output_file="$DATA_DIR/bomb_${concurrency}.json"
    
    echo -e "${GREEN}📊 Ejecutando con concurrencia: $concurrency${NC}"
    echo "  - Requests: $TEST_REQUESTS"
    echo "  - Output: $output_file"
    
    # Ejecutar bombardier
    bombardier \
        -c "$concurrency" \
        -n "$TEST_REQUESTS" \
        -o json \
        "$url" > "$output_file"
    
    # Extraer métricas clave
    if command -v jq &> /dev/null; then
        local rps=$(jq -r '.result.requests_per_sec' "$output_file")
        local latency_mean=$(jq -r '.result.latency_mean_ms' "$output_file")
        local latency_p95=$(jq -r '.result.latency_p95_ms' "$output_file")
        
        echo -e "${CYAN}  📈 RPS: ${rps} | Latencia media: ${latency_mean}ms | P95: ${latency_p95}ms${NC}"
    else
        echo -e "${CYAN}  📈 Resultado guardado en: $output_file${NC}"
    fi
    
    echo ""
}

# Función para generar CSV de latencias
generate_latency_csv() {
    local csv_file="$DATA_DIR/latency_data.csv"
    
    echo -e "${BLUE}📋 Generando CSV de latencias...${NC}"
    
    # Crear header del CSV
    echo "concurrency,latency_p95_ms,latency_mean_ms,requests_per_sec" > "$csv_file"
    
    # Procesar cada archivo JSON
    for conc in "${CONCURRENCIES[@]}"; do
        local json_file="$DATA_DIR/bomb_${conc}.json"
        
        if [[ -f "$json_file" ]]; then
            if command -v jq &> /dev/null; then
                local p95=$(jq -r '.result.latency_p95_ms' "$json_file")
                local mean=$(jq -r '.result.latency_mean_ms' "$json_file")
                local rps=$(jq -r '.result.requests_per_sec' "$json_file")
                
                echo "$conc,$p95,$mean,$rps" >> "$csv_file"
                echo -e "${CYAN}  ✅ Concurrencia $conc: P95=${p95}ms, Media=${mean}ms, RPS=${rps}${NC}"
            else
                echo -e "${YELLOW}  ⚠️  jq no disponible, datos sin procesar${NC}"
            fi
        else
            echo -e "${RED}  ❌ Archivo no encontrado: $json_file${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ CSV generado: $csv_file${NC}"
    echo ""
}

# Función para análisis matemático
run_mathematical_analysis() {
    echo -e "${BLUE}🔬 Iniciando análisis matemático...${NC}"
    
    # Verificar si Python está disponible
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}⚠️  Python3 no disponible, saltando análisis matemático${NC}"
        return
    fi
    
    # Crear script de análisis temporal
    cat > "$DATA_DIR/analyze_latency.py" << 'EOF'
#!/usr/bin/env python3
import pandas as pd
import numpy as np
from scipy import stats
import matplotlib.pyplot as plt
import sys
import os

def analyze_latency_data(csv_file):
    """Analiza datos de latencia y calcula derivadas"""
    
    if not os.path.exists(csv_file):
        print(f"❌ Archivo no encontrado: {csv_file}")
        return
    
    # Cargar datos
    df = pd.read_csv(csv_file)
    print(f"📊 Datos cargados: {len(df)} puntos")
    
    # Análisis para P95
    x = df['concurrency'].values
    y_p95 = df['latency_p95_ms'].values
    
    # Ajuste polinomial de segundo grado: T(x) = ax² + bx + c
    coeffs = np.polyfit(x, y_p95, 2)
    a, b, c = coeffs
    
    print(f"\n📈 FUNCIÓN T(x) = {a:.6f}x² + {b:.6f}x + {c:.6f}")
    print(f"   a (concavidad): {a:.6f}")
    print(f"   b (pendiente base): {b:.6f}")
    print(f"   c (latencia base): {c:.6f}")
    
    # Derivadas
    # T'(x) = 2ax + b
    # T''(x) = 2a
    print(f"\n🔬 DERIVADAS:")
    print(f"   T'(x) = {2*a:.6f}x + {b:.6f}")
    print(f"   T''(x) = {2*a:.6f}")
    
    # Análisis de comportamiento
    if a > 0:
        print(f"   📈 Concavidad hacia arriba (a > 0)")
        print(f"   ⚠️  La latencia crece aceleradamente")
    else:
        print(f"   📉 Concavidad hacia abajo (a < 0)")
        print(f"   ✅ La latencia se estabiliza")
    
    # Calcular derivadas en puntos específicos
    print(f"\n📊 VALORES DE DERIVADAS:")
    for conc in x:
        deriv1 = 2*a*conc + b
        deriv2 = 2*a
        print(f"   x={conc}: T'({conc}) = {deriv1:.3f} ms/conc, T''({conc}) = {deriv2:.3f} ms/conc²")
    
    # Generar gráfico
    plt.figure(figsize=(12, 8))
    
    # Datos originales
    plt.subplot(2, 2, 1)
    plt.scatter(x, y_p95, color='blue', label='Datos P95')
    x_fit = np.linspace(min(x), max(x), 100)
    y_fit = a*x_fit**2 + b*x_fit + c
    plt.plot(x_fit, y_fit, 'r-', label=f'T(x) = {a:.4f}x² + {b:.4f}x + {c:.4f}')
    plt.xlabel('Concurrencia')
    plt.ylabel('Latencia P95 (ms)')
    plt.title('Función T(x) - Latencia vs Concurrencia')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Primera derivada
    plt.subplot(2, 2, 2)
    deriv1_values = 2*a*x + b
    plt.plot(x, deriv1_values, 'g-', marker='o', label="T'(x)")
    plt.xlabel('Concurrencia')
    plt.ylabel("T'(x) (ms/conc)")
    plt.title("Primera Derivada - Cambio de Latencia")
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Segunda derivada
    plt.subplot(2, 2, 3)
    deriv2_values = [2*a] * len(x)
    plt.plot(x, deriv2_values, 'r-', marker='s', label="T''(x)")
    plt.xlabel('Concurrencia')
    plt.ylabel("T''(x) (ms/conc²)")
    plt.title("Segunda Derivada - Aceleración")
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Throughput
    plt.subplot(2, 2, 4)
    plt.scatter(x, df['requests_per_sec'], color='purple', label='Throughput')
    plt.xlabel('Concurrencia')
    plt.ylabel('Requests/segundo')
    plt.title('Throughput vs Concurrencia')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{os.path.dirname(csv_file)}/latency_analysis.png', dpi=300, bbox_inches='tight')
    print(f"\n📈 Gráfico guardado: {os.path.dirname(csv_file)}/latency_analysis.png")
    
    # Guardar resultados en archivo
    results_file = f'{os.path.dirname(csv_file)}/mathematical_results.txt'
    with open(results_file, 'w') as f:
        f.write("ANÁLISIS MATEMÁTICO DE LATENCIAS\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Función: T(x) = {a:.6f}x² + {b:.6f}x + {c:.6f}\n")
        f.write(f"Primera derivada: T'(x) = {2*a:.6f}x + {b:.6f}\n")
        f.write(f"Segunda derivada: T''(x) = {2*a:.6f}\n\n")
        f.write("Valores por concurrencia:\n")
        for conc in x:
            deriv1 = 2*a*conc + b
            deriv2 = 2*a
            f.write(f"x={conc}: T'({conc}) = {deriv1:.3f}, T''({conc}) = {deriv2:.3f}\n")
    
    print(f"📄 Resultados guardados: {results_file}")

if __name__ == "__main__":
    csv_file = sys.argv[1] if len(sys.argv) > 1 else "latency_data.csv"
    analyze_latency_data(csv_file)
EOF
    
    # Ejecutar análisis
    python3 "$DATA_DIR/analyze_latency.py" "$DATA_DIR/latency_data.csv"
    
    echo -e "${GREEN}✅ Análisis matemático completado${NC}"
    echo ""
}

# Función principal
main() {
    echo -e "${BLUE}🎯 Iniciando secuencia de benchmarks${NC}"
    echo "=================================="
    
    # Calentar endpoint
    warmup_endpoint "$URL"
    
    # Ejecutar benchmarks para cada nivel de concurrencia
    for conc in "${CONCURRENCIES[@]}"; do
        run_benchmark "$URL" "$conc"
        
        # Pausa entre tests para estabilizar
        if [[ "$conc" != "${CONCURRENCIES[-1]}" ]]; then
            echo -e "${BLUE}⏸️  Pausa de 3 segundos...${NC}"
            sleep 3
        fi
    done
    
    # Generar CSV
    generate_latency_csv
    
    # Análisis matemático
    run_mathematical_analysis
    
    echo -e "${GREEN}🎉 Análisis completado!${NC}"
    echo -e "${CYAN}📁 Archivos generados en: $DATA_DIR${NC}"
    echo ""
    echo -e "${YELLOW}📊 Archivos disponibles:${NC}"
    ls -la "$DATA_DIR"/*.json 2>/dev/null || echo "  No hay archivos JSON"
    ls -la "$DATA_DIR"/*.csv 2>/dev/null || echo "  No hay archivos CSV"
    ls -la "$DATA_DIR"/*.png 2>/dev/null || echo "  No hay archivos PNG"
    ls -la "$DATA_DIR"/*.txt 2>/dev/null || echo "  No hay archivos TXT"
}

# Ejecutar función principal
main 