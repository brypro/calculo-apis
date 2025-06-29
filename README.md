# Benchmark de Micro-APIs - Comparativa de Lenguajes

Este proyecto implementa cuatro micro-APIs idénticas en diferentes lenguajes de programación para realizar benchmarks de rendimiento y análisis de latencias con **cálculo diferencial**.

## 🎯 Objetivo

Comparar el rendimiento de APIs en:
- **Go 1.22** (net/http)
- **Python 3.12** (FastAPI)
- **Node.js 20** (TypeScript + Express)
- **C# .NET 8** (Minimal API)

Y derivar las funciones **T(x), T'(x), T''(x)** para análisis matemático de latencias.

## 📋 Contrato de API

Todas las APIs implementan el mismo endpoint:

```
GET /compute?size=n
```

**Parámetros:**
- `size` (opcional): Número para calcular Fibonacci (default: 30)

**Respuesta:**
```json
{
  "result": 832040,
  "size": 30,
  "latency_ms": 1
}
```

## 🏗️ Estructura del Proyecto

```
calculo-apis/
├── go-api/           # API en Go
├── python-api/       # API en Python + FastAPI
├── node-api/         # API en Node.js + TypeScript + Express
├── dotnet-api/       # API en C# .NET 8
├── scripts/          # Scripts de benchmark y análisis
│   ├── bombardier-master.sh           # Script maestro de Bombardier
│   ├── run-all-benchmarks.sh          # Benchmark completo
│   ├── advanced_mathematical_analysis.py  # Análisis matemático
│   ├── test-apis.ps1                  # Pruebas de APIs
│   └── run-benchmarks.ps1             # Benchmarks en PowerShell
├── data/             # Resultados de benchmarks
├── docker-compose.yml
└── README.md
```

## 🚀 Inicio Rápido

### 1. Construir y ejecutar todas las APIs
```bash
docker-compose up --build
```

### 2. Probar que las APIs funcionan
```powershell
# Windows
.\scripts\test-apis.ps1

# Linux/macOS
curl http://localhost:8081/compute?size=30
curl http://localhost:8082/compute?size=30
curl http://localhost:8083/compute?size=30
curl http://localhost:8084/compute?size=30
```

## 📊 Benchmark con Bombardier

### Instalar Bombardier
```bash
# Windows/Linux/macOS
go install github.com/codesenberg/bombardier@latest
```

### Ejecutar benchmarks completos

#### Opción 1: Script maestro (recomendado)
```bash
# Ejecutar todas las APIs
./scripts/run-all-benchmarks.sh

# Solo una API específica
./scripts/run-all-benchmarks.sh -s go-api

# Con parámetros personalizados
./scripts/run-all-benchmarks.sh -c 100 -n 3000
```

#### Opción 2: Script individual
```bash
# Análisis de una API específica
./scripts/bombardier-master.sh http://localhost:8081/compute

# PowerShell (Windows)
.\scripts\run-benchmarks.ps1
```

#### Opción 3: Manual
```bash
# Crear directorio de resultados
mkdir -p data

# Ejecutar benchmarks individuales
bombardier -c 10 -n 5000 -o json http://localhost:8081/compute?size=30 > data/go_api_c10.json
bombardier -c 25 -n 5000 -o json http://localhost:8082/compute?size=30 > data/python_api_c25.json
bombardier -c 50 -n 5000 -o json http://localhost:8083/compute?size=30 > data/node_api_c50.json
bombardier -c 100 -n 5000 -o json http://localhost:8084/compute?size=30 > data/dotnet_api_c100.json
```

## 🔬 Análisis Matemático

### Cálculo Diferencial de Latencias

El proyecto calcula automáticamente:

- **T(x)**: Función de latencia vs concurrencia
- **T'(x)**: Primera derivada (cambio de latencia)
- **T''(x)**: Segunda derivada (aceleración)

### Modelos Matemáticos Aplicados

1. **Modelo Polinomial**: T(x) = ax² + bx + c
2. **Modelo Exponencial**: T(x) = a * exp(bx)
3. **Modelo Logarítmico**: T(x) = a * ln(x) + b

### Ejecutar Análisis Matemático
```bash
# Análisis automático (incluido en run-all-benchmarks.sh)
python3 scripts/advanced_mathematical_analysis.py

# Instalar dependencias si es necesario
pip install scipy pandas matplotlib seaborn numpy
```

## 📈 Resultados Generados

### Archivos de Datos
- `data/*/bomb_*.json`: Resultados de Bombardier
- `data/*/*_latency_data.csv`: Datos de latencia procesados
- `data/advanced_analysis_results.json`: Resultados en JSON

### Gráficos y Reportes
- `data/advanced_comparative_analysis.png`: Gráfico comparativo completo
- `data/mathematical_report.txt`: Reporte matemático detallado
- `data/final_benchmark_report.txt`: Resumen ejecutivo

### Interpretación de Resultados

#### Métricas Principales
- **Throughput** (requests/segundo): Mayor es mejor
- **Latencia P95** (ms): Menor es mejor
- **Eficiencia** (req/s/ms): Balance entre throughput y latencia

#### Análisis de Derivadas
- **T'(x) > 0**: La latencia crece con la concurrencia
- **T'(x) < 0**: La latencia disminuye (poco común)
- **T''(x) > 0**: Aceleración positiva (crecimiento acelerado)
- **T''(x) < 0**: Aceleración negativa (estabilización)

## 🐳 Puertos de las APIs

- **Go API**: http://localhost:8081
- **Python API**: http://localhost:8082
- **Node.js API**: http://localhost:8083
- **.NET API**: http://localhost:8084

## 📊 Configuración de Benchmarks

### Niveles de Concurrencia
```bash
# Por defecto: 10, 25, 50, 75, 100, 150, 200, 300
# Personalizable con -c flag
```

### Parámetros de Test
```bash
# Requests por test: 5000 (por defecto)
# Calentamiento: 100 requests
# Pausa entre tests: 3 segundos
```

## 🛠️ Tecnologías Utilizadas

- **Docker & Docker Compose**: Containerización
- **Bombardier**: Herramienta de benchmark
- **Python + SciPy**: Análisis matemático
- **Matplotlib + Seaborn**: Visualización
- **Multi-stage builds**: Imágenes optimizadas
- **Alpine Linux**: Imágenes base ligeras

## 📝 Notas Técnicas

- Todas las APIs implementan el mismo algoritmo Fibonacci O(n)
- Operación CPU-bound controlada (~1ms para n=30)
- Calentamiento automático para estabilizar JIT y cachés
- Configuración mínima para evitar overhead
- Puertos únicos para evitar conflictos
- Logs estructurados para análisis

## 🔧 Configuración Avanzada

### Personalizar Algoritmos
Cada API implementa el mismo algoritmo Fibonacci. Puedes modificarlo en:

- **Go**: `go-api/main.go` - función `fib()`
- **Python**: `python-api/main.py` - función `fib()`
- **Node.js**: `node-api/src/index.ts` - función `fib()`
- **.NET**: `dotnet-api/Program.cs` - función `Fib()`

### Optimizaciones Sugeridas
- **Go**: `-race` flags, optimizaciones de compilador
- **Python**: `--min-workers` en Uvicorn, optimizaciones de JIT
- **Node.js**: `--max-old-space-size`, optimizaciones de V8
- **.NET**: ThreadPoolSettings, optimizaciones de GC

## 🐛 Solución de Problemas

### Error: "bombardier no está instalado"
```bash
go install github.com/codesenberg/bombardier@latest
```

### Error: "APIs no están disponibles"
```bash
docker-compose down
docker-compose up --build
```

### Error: "Dependencias de Python faltantes"
```bash
pip install scipy pandas matplotlib seaborn numpy
```

## 📚 Próximos Pasos

1. **Automatización**: GitHub Actions con matrix de lenguajes
2. **Optimizaciones**: Aplicar mejoras y medir impacto en T'(x)
3. **Escalabilidad**: Análisis con mayor concurrencia
4. **Integración**: Conectar con sistemas de monitoreo

## 🤝 Contribuir

1. Fork el proyecto
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.