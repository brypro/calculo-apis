#!/usr/bin/env bash

# Script maestro para ejecutar benchmarks en todas las APIs
# Genera análisis completo con cálculo diferencial

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuración
APIS=(
    "go-api:8081"
    "python-api:8082"
    "node-api:8083"
    "dotnet-api:8084"
)

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}🚀 Script Maestro - Benchmark Completo de APIs${NC}"
    echo "================================================"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help          Mostrar esta ayuda"
    echo "  -s, --single API    Ejecutar solo una API específica"
    echo "  -a, --all           Ejecutar todas las APIs (default)"
    echo "  -c, --concurrency   Nivel máximo de concurrencia (default: 300)"
    echo "  -n, --requests      Número de requests por test (default: 5000)"
    echo ""
    echo "Ejemplos:"
    echo "  $0                    # Ejecutar todas las APIs"
    echo "  $0 -s go-api          # Solo Go API"
    echo "  $0 -c 100 -n 3000     # Concurrencia 100, 3000 requests"
    echo ""
}

# Variables por defecto
SINGLE_API=""
MAX_CONCURRENCY=300
REQUESTS=5000

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--single)
            SINGLE_API="$2"
            shift 2
            ;;
        -a|--all)
            SINGLE_API=""
            shift
            ;;
        -c|--concurrency)
            MAX_CONCURRENCY="$2"
            shift 2
            ;;
        -n|--requests)
            REQUESTS="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}❌ Opción desconocida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Verificar que bombardier esté instalado
if ! command -v bombardier &> /dev/null; then
    echo -e "${RED}❌ Error: bombardier no está instalado${NC}"
    echo "Instala con: go install github.com/codesenberg/bombardier@latest"
    exit 1
fi

# Verificar que las APIs estén ejecutándose
check_apis_ready() {
    echo -e "${BLUE}🔍 Verificando que las APIs estén listas...${NC}"
    
    local apis_to_check=("${APIS[@]}")
    if [[ -n "$SINGLE_API" ]]; then
        apis_to_check=("$SINGLE_API")
    fi
    
    for api in "${apis_to_check[@]}"; do
        IFS=':' read -r name port <<< "$api"
        local url="http://localhost:$port/health"
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -s "$url" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ $name está lista${NC}"
                break
            fi
            echo -e "${YELLOW}⏳ Esperando $name en puerto $port... (intento $attempt/$max_attempts)${NC}"
            sleep 2
            attempt=$((attempt + 1))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            echo -e "${RED}❌ Error: $name no está disponible en puerto $port${NC}"
            echo "Asegúrate de ejecutar: docker-compose up --build"
            exit 1
        fi
    done
    echo ""
}

# Función para ejecutar benchmark de una API
run_api_benchmark() {
    local api_name=$1
    local port=$2
    local data_dir="data/${api_name}"
    
    echo -e "${CYAN}🚀 Ejecutando benchmark para $api_name${NC}"
    echo "=================================="
    
    # Crear directorio para esta API
    mkdir -p "$data_dir"
    
    # URL del endpoint
    local url="http://localhost:$port/compute?size=30"
    
    # Calentar endpoint
    echo -e "${YELLOW}🔥 Calentando $api_name...${NC}"
    bombardier -c 1 -n 100 -o json "$url" > /dev/null 2>&1
    echo -e "${GREEN}✅ Calentamiento completado${NC}"
    
    # Configuraciones de concurrencia
    local concurrencies=(10 25 50 75 100 150 200 300)
    
    # Filtrar por concurrencia máxima
    local filtered_concurrencies=()
    for conc in "${concurrencies[@]}"; do
        if [ "$conc" -le "$MAX_CONCURRENCY" ]; then
            filtered_concurrencies+=("$conc")
        fi
    done
    
    # Ejecutar benchmarks
    for conc in "${filtered_concurrencies[@]}"; do
        echo -e "${GREEN}📊 Concurrencia: $conc${NC}"
        
        local output_file="$data_dir/bomb_${conc}.json"
        bombardier \
            -c "$conc" \
            -n "$REQUESTS" \
            -o json \
            "$url" > "$output_file"
        
        # Mostrar métricas rápidas
        if command -v jq &> /dev/null; then
            local rps=$(jq -r '.result.requests_per_sec' "$output_file")
            local latency_p95=$(jq -r '.result.latency_p95_ms' "$output_file")
            echo -e "${CYAN}  📈 RPS: ${rps} | P95: ${latency_p95}ms${NC}"
        fi
        
        # Pausa entre tests
        if [[ "$conc" != "${filtered_concurrencies[-1]}" ]]; then
            echo -e "${BLUE}  ⏸️  Pausa de 3 segundos...${NC}"
            sleep 3
        fi
    done
    
    # Generar CSV para esta API
    generate_api_csv "$api_name" "$data_dir" "${filtered_concurrencies[@]}"
    
    echo -e "${GREEN}✅ Benchmark de $api_name completado${NC}"
    echo ""
}

# Función para generar CSV de una API
generate_api_csv() {
    local api_name=$1
    local data_dir=$2
    shift 2
    local concurrencies=("$@")
    
    local csv_file="$data_dir/${api_name}_latency_data.csv"
    
    echo -e "${BLUE}📋 Generando CSV para $api_name...${NC}"
    
    # Crear header del CSV
    echo "concurrency,latency_p95_ms,latency_mean_ms,requests_per_sec" > "$csv_file"
    
    # Procesar cada archivo JSON
    for conc in "${concurrencies[@]}"; do
        local json_file="$data_dir/bomb_${conc}.json"
        
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
}

# Función para análisis matemático completo
run_mathematical_analysis() {
    echo -e "${MAGENTA}🔬 Iniciando análisis matemático completo...${NC}"
    echo "=========================================="
    
    # Verificar si Python está disponible
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}⚠️  Python3 no disponible, saltando análisis matemático${NC}"
        return
    fi
    
    # Verificar si scipy está instalado
    if ! python3 -c "import scipy" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  SciPy no instalado, instalando dependencias...${NC}"
        pip3 install scipy pandas matplotlib seaborn numpy
    fi
    
    # Ejecutar análisis avanzado
    python3 scripts/advanced_mathematical_analysis.py
    
    echo -e "${GREEN}✅ Análisis matemático completado${NC}"
    echo ""
}

# Función para generar reporte final
generate_final_report() {
    echo -e "${MAGENTA}📊 Generando reporte final...${NC}"
    
    local report_file="data/final_benchmark_report.txt"
    
    cat > "$report_file" << EOF
REPORTE FINAL DE BENCHMARK - ANÁLISIS DE LATENCIAS
==================================================

Fecha: $(date)
Configuración:
- Concurrencia máxima: $MAX_CONCURRENCY
- Requests por test: $REQUESTS
- APIs analizadas: ${#APIS[@]}

APIs incluidas:
EOF
    
    for api in "${APIS[@]}"; do
        IFS=':' read -r name port <<< "$api"
        echo "- $name (puerto $port)" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

Archivos generados:
- data/*/bomb_*.json: Resultados de Bombardier
- data/*/*_latency_data.csv: Datos de latencia
- data/advanced_comparative_analysis.png: Gráfico comparativo
- data/mathematical_report.txt: Análisis matemático detallado
- data/advanced_analysis_results.json: Resultados en JSON

Para análisis adicional:
1. Ver gráficos: data/advanced_comparative_analysis.png
2. Leer reporte: data/mathematical_report.txt
3. Analizar datos: data/advanced_analysis_results.json

EOF
    
    echo -e "${GREEN}✅ Reporte final generado: $report_file${NC}"
}

# Función principal
main() {
    echo -e "${BLUE}🎯 Iniciando benchmark completo de APIs${NC}"
    echo "============================================="
    echo -e "${CYAN}Configuración:${NC}"
    echo -e "  Concurrencia máxima: $MAX_CONCURRENCY"
    echo -e "  Requests por test: $REQUESTS"
    if [[ -n "$SINGLE_API" ]]; then
        echo -e "  API específica: $SINGLE_API"
    else
        echo -e "  Todas las APIs: ${#APIS[@]}"
    fi
    echo ""
    
    # Verificar APIs
    check_apis_ready
    
    # Crear directorio principal de datos
    mkdir -p data
    
    # Ejecutar benchmarks
    if [[ -n "$SINGLE_API" ]]; then
        # Solo una API
        IFS=':' read -r name port <<< "$SINGLE_API"
        run_api_benchmark "$name" "$port"
    else
        # Todas las APIs
        for api in "${APIS[@]}"; do
            IFS=':' read -r name port <<< "$api"
            run_api_benchmark "$name" "$port"
        done
    fi
    
    # Análisis matemático
    run_mathematical_analysis
    
    # Reporte final
    generate_final_report
    
    echo -e "${GREEN}🎉 Benchmark completo finalizado!${NC}"
    echo ""
    echo -e "${CYAN}📁 Resultados disponibles en:${NC}"
    echo -e "  - data/ (directorio principal)"
    echo -e "  - data/*/ (datos por API)"
    echo -e "  - data/advanced_comparative_analysis.png"
    echo -e "  - data/mathematical_report.txt"
    echo ""
    echo -e "${YELLOW}📊 Para ver resultados:${NC}"
    echo -e "  ls -la data/"
    echo -e "  cat data/mathematical_report.txt"
    echo -e "  open data/advanced_comparative_analysis.png"
}

# Ejecutar función principal
main 