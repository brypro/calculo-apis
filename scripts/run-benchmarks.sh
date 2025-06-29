#!/bin/bash

# Script para ejecutar benchmarks de todas las APIs
# Requiere: bombardier instalado (go install github.com/codesenberg/bombardier@latest)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
RESULTS_DIR="results"
APIS=(
    "go-api:8081"
    "python-api:8082"
    "node-api:8083"
    "dotnet-api:8084"
)

# Crear directorio de resultados
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}🚀 Iniciando benchmarks de APIs${NC}"
echo "=================================="

# Función para verificar si una API está lista
check_api_ready() {
    local url="http://localhost:$1/health"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            return 0
        fi
        echo -e "${YELLOW}⏳ Esperando API en puerto $1... (intento $attempt/$max_attempts)${NC}"
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

# Función para ejecutar benchmark
run_benchmark() {
    local api_name=$1
    local port=$2
    local concurrency=$3
    local requests=$4
    
    echo -e "${GREEN}📊 Ejecutando benchmark para $api_name (puerto $port)${NC}"
    echo "  - Concurrencia: $concurrency"
    echo "  - Requests: $requests"
    
    local output_file="$RESULTS_DIR/${api_name}_c${concurrency}.json"
    
    bombardier \
        -c "$concurrency" \
        -n "$requests" \
        -o json \
        "http://localhost:$port/compute?size=30" \
        > "$output_file"
    
    echo -e "${GREEN}✅ Benchmark completado: $output_file${NC}"
    echo ""
}

# Verificar que bombardier esté instalado
if ! command -v bombardier &> /dev/null; then
    echo -e "${RED}❌ Error: bombardier no está instalado${NC}"
    echo "Instala con: go install github.com/codesenberg/bombardier@latest"
    exit 1
fi

# Verificar que las APIs estén ejecutándose
echo -e "${BLUE}🔍 Verificando que las APIs estén listas...${NC}"
for api in "${APIS[@]}"; do
    IFS=':' read -r name port <<< "$api"
    if ! check_api_ready "$port"; then
        echo -e "${RED}❌ Error: API $name no está disponible en puerto $port${NC}"
        echo "Asegúrate de ejecutar: docker-compose up --build"
        exit 1
    fi
    echo -e "${GREEN}✅ $name está lista${NC}"
done

echo ""
echo -e "${BLUE}🎯 Configuraciones de benchmark:${NC}"

# Configuraciones de concurrencia para probar
concurrencies=(1 5 10 25 50 100)

for concurrency in "${concurrencies[@]}"; do
    echo -e "${YELLOW}🔄 Ejecutando con concurrencia: $concurrency${NC}"
    echo "----------------------------------------"
    
    for api in "${APIS[@]}"; do
        IFS=':' read -r name port <<< "$api"
        run_benchmark "$name" "$port" "$concurrency" 5000
    done
    
    echo -e "${BLUE}⏸️  Pausa de 5 segundos entre configuraciones...${NC}"
    sleep 5
done

echo ""
echo -e "${GREEN}🎉 Todos los benchmarks completados!${NC}"
echo -e "${BLUE}📁 Resultados guardados en: $RESULTS_DIR/${NC}"
echo ""
echo -e "${YELLOW}📊 Resumen de archivos generados:${NC}"
ls -la "$RESULTS_DIR"/*.json

echo ""
echo -e "${BLUE}📈 Para analizar los resultados, puedes usar:${NC}"
echo "  - Python: scripts/analyze_results.py"
echo "  - Excel: Importar archivos JSON"
echo "  - Grafana: Configurar datasource JSON" 