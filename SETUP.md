# Guía de Configuración - Benchmark de APIs

Esta guía te ayudará a configurar y ejecutar el proyecto de benchmark de APIs paso a paso.

## 📋 Prerrequisitos

### 1. Docker y Docker Compose
```bash
# Verificar instalación
docker --version
docker-compose --version
```

### 2. Go (para Bombardier)
```bash
# Instalar Go desde: https://golang.org/dl/
go version

# Instalar Bombardier
go install github.com/codesenberg/bombardier@latest
```

### 3. Python (opcional, para análisis)
```bash
# Instalar dependencias para análisis
pip install pandas matplotlib seaborn numpy
```

## 🚀 Configuración Inicial

### 1. Clonar y configurar el proyecto
```bash
# Navegar al directorio del proyecto
cd calculo-apis

# Verificar estructura
ls -la
```

### 2. Construir y ejecutar las APIs
```bash
# Construir todas las imágenes Docker
docker-compose build

# Ejecutar todas las APIs
docker-compose up -d

# Verificar que todas estén ejecutándose
docker-compose ps
```

### 3. Verificar que las APIs estén funcionando
```bash
# Go API
curl http://localhost:8081/compute?size=30

# Python API
curl http://localhost:8082/compute?size=30

# Node.js API
curl http://localhost:8083/compute?size=30

# .NET API
curl http://localhost:8084/compute?size=30
```

## 📊 Ejecutar Benchmarks

### Opción 1: Script automatizado (Linux/macOS)
```bash
# Hacer ejecutable el script
chmod +x scripts/run-benchmarks.sh

# Ejecutar benchmarks
./scripts/run-benchmarks.sh
```

### Opción 2: Script de PowerShell (Windows)
```powershell
# Ejecutar benchmarks
.\scripts\run-benchmarks.ps1

# Con parámetros personalizados
.\scripts\run-benchmarks.ps1 -MaxConcurrency 50 -Requests 3000
```

### Opción 3: Manual con Bombardier
```bash
# Crear directorio de resultados
mkdir -p results

# Ejecutar benchmarks individuales
bombardier -c 10 -n 5000 -o json http://localhost:8081/compute?size=30 > results/go_api_c10.json
bombardier -c 10 -n 5000 -o json http://localhost:8082/compute?size=30 > results/python_api_c10.json
bombardier -c 10 -n 5000 -o json http://localhost:8083/compute?size=30 > results/node_api_c10.json
bombardier -c 10 -n 5000 -o json http://localhost:8084/compute?size=30 > results/dotnet_api_c10.json
```

## 📈 Analizar Resultados

### 1. Análisis automático con Python
```bash
# Instalar dependencias (si no están instaladas)
pip install pandas matplotlib seaborn numpy

# Ejecutar análisis
python scripts/analyze_results.py
```

### 2. Ver resultados generados
```bash
# Ver archivos generados
ls -la results/
ls -la *.png *.csv
```

## 🔧 Configuración Avanzada

### Modificar parámetros de benchmark
Edita `scripts/run-benchmarks.sh` o `scripts/run-benchmarks.ps1`:

```bash
# Configuraciones de concurrencia
concurrencies=(1 5 10 25 50 100)

# Número de requests por prueba
requests=5000
```

### Personalizar algoritmos de cálculo
Cada API implementa el mismo algoritmo Fibonacci. Puedes modificarlo en:

- **Go**: `go-api/main.go` - función `fib()`
- **Python**: `python-api/main.py` - función `fib()`
- **Node.js**: `node-api/src/index.ts` - función `fib()`
- **.NET**: `dotnet-api/Program.cs` - función `Fib()`

### Ajustar configuración de Docker
Edita `docker-compose.yml` para modificar:
- Puertos de las APIs
- Variables de entorno
- Recursos asignados

## 🐛 Solución de Problemas

### Error: "bombardier no está instalado"
```bash
# Instalar Go primero
# Luego instalar Bombardier
go install github.com/codesenberg/bombardier@latest

# Verificar instalación
bombardier --version
```

### Error: "API no está disponible"
```bash
# Verificar que Docker esté ejecutándose
docker ps

# Reiniciar las APIs
docker-compose down
docker-compose up --build -d

# Verificar logs
docker-compose logs
```

### Error: "Puerto ya en uso"
```bash
# Verificar qué está usando el puerto
netstat -tulpn | grep :8081

# Cambiar puertos en docker-compose.yml
# O detener el proceso que usa el puerto
```

### Error: "Permisos denegados" (Linux/macOS)
```bash
# Hacer ejecutable el script
chmod +x scripts/run-benchmarks.sh

# O ejecutar con sudo (no recomendado)
sudo ./scripts/run-benchmarks.sh
```

## 📊 Interpretación de Resultados

### Métricas principales
- **Requests/sec**: Throughput de la API
- **Latency_mean_ms**: Latencia promedio
- **Latency_p95_ms**: 95% de requests bajo este tiempo
- **Latency_p99_ms**: 99% de requests bajo este tiempo

### Análisis de derivadas
- **T'(x)**: Cambio de latencia vs concurrencia
- **T''(x)**: Aceleración del cambio de latencia

### Comparación entre APIs
1. **Throughput**: Mayor es mejor
2. **Latencia**: Menor es mejor
3. **Escalabilidad**: Cómo cambia el rendimiento con concurrencia

## 🔄 Mantenimiento

### Actualizar dependencias
```bash
# Reconstruir imágenes con dependencias actualizadas
docker-compose build --no-cache

# Reiniciar servicios
docker-compose up -d
```

### Limpiar recursos
```bash
# Detener y eliminar contenedores
docker-compose down

# Eliminar imágenes no utilizadas
docker image prune -f

# Limpiar resultados anteriores
rm -rf results/
```

### Logs y monitoreo
```bash
# Ver logs en tiempo real
docker-compose logs -f

# Ver logs de una API específica
docker-compose logs -f go-api

# Ver uso de recursos
docker stats
```

## 📚 Recursos Adicionales

- [Documentación de Bombardier](https://github.com/codesenberg/bombardier)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Express.js Documentation](https://expressjs.com/)
- [ASP.NET Core Documentation](https://docs.microsoft.com/en-us/aspnet/core/)
- [Go HTTP Documentation](https://golang.org/pkg/net/http/) 