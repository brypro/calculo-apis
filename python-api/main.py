"""
FastAPI Ultra-Optimizada para benchmarks de rendimiento
Con algoritmo Fibonacci híbrido, cache LRU, y configuraciones avanzadas
"""

import time
import os
import asyncio
from functools import lru_cache
from typing import Dict, Any
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import psutil

# Cache LRU para Fibonacci con límite de memoria
@lru_cache(maxsize=128)
def fibonacci_cached(n: int) -> int:
    """Fibonacci con cache LRU para números pequeños"""
    if n <= 1:
        return n
    return fibonacci_cached(n - 1) + fibonacci_cached(n - 2)

def fibonacci_iterative(n: int) -> int:
    """Fibonacci iterativo para números grandes"""
    if n <= 1:
        return n
    
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

def fibonacci_optimized(n: int) -> int:
    """Algoritmo Fibonacci híbrido optimizado"""
    if n <= 30:  # Usar cache para números pequeños
        return fibonacci_cached(n)
    else:  # Usar iterativo para números grandes
        return fibonacci_iterative(n)

# Crear aplicación FastAPI ultra-optimizada
app = FastAPI(
    title="Python FastAPI Benchmark - Ultra Optimized",
    version="2.1.0",
    description="API ultra-optimizada con Fibonacci híbrido, cache LRU y configuraciones avanzadas",
    docs_url="/docs" if os.getenv("ENVIRONMENT") == "development" else None,
    redoc_url="/redoc" if os.getenv("ENVIRONMENT") == "development" else None
)

# Configurar CORS optimizado
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    max_age=86400  # Cache preflight por 24 horas
)

# Estadísticas globales
stats = {
    "requests": 0,
    "total_compute_time": 0.0,
    "cache_hits": 0
}

@app.middleware("http")
async def add_process_time_header(request, call_next):
    """Middleware para medir tiempo de respuesta"""
    start_time = time.perf_counter()
    response = await call_next(request)
    process_time = time.perf_counter() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response

@app.get("/compute")
async def compute_fibonacci(size: int = Query(30, ge=0, le=50, description="Tamaño del número Fibonacci a calcular")):
    """Endpoint principal para calcular Fibonacci con algoritmo optimizado"""
    start_time = time.perf_counter()
    
    try:
        # Actualizar estadísticas
        stats["requests"] += 1
        
        # Calcular Fibonacci con algoritmo optimizado
        result = fibonacci_optimized(size)
        
        # Calcular latencia
        compute_time = time.perf_counter() - start_time
        latency_ms = int(compute_time * 1000)
        
        # Actualizar estadísticas
        stats["total_compute_time"] += compute_time
        
        # Determinar si se usó cache
        cache_info = fibonacci_cached.cache_info() if size <= 30 else None
        
        response_data = {
            "result": result,
            "size": size,
            "latency_ms": latency_ms,
            "algorithm": "cached" if size <= 30 else "iterative",
            "cache_info": {
                "hits": cache_info.hits if cache_info else 0,
                "misses": cache_info.misses if cache_info else 0,
                "maxsize": cache_info.maxsize if cache_info else 0
            } if cache_info else None
        }
        
        return JSONResponse(content=response_data)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error en cálculo: {str(e)}")

@app.get("/health")
async def health_check():
    """Endpoint de health check con información del sistema"""
    try:
        # Test básico de funcionalidad
        test_result = fibonacci_optimized(10)
        
        # Información del sistema
        memory_info = psutil.virtual_memory()
        cpu_percent = psutil.cpu_percent(interval=0.1)
        
        return JSONResponse(content={
            "status": "healthy",
            "service": "python-api",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
            "worker_pid": os.getpid(),
            "test_result": test_result,
            "system_info": {
                "cpu_percent": cpu_percent,
                "memory_percent": memory_info.percent,
                "memory_available_mb": memory_info.available // (1024 * 1024)
            },
            "cache_stats": {
                "fibonacci_cache": fibonacci_cached.cache_info()._asdict()
            },
            "performance_stats": stats
        })
        
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Health check failed: {str(e)}")

@app.get("/")
async def root_info():
    """Información detallada de la API"""
    cache_info = fibonacci_cached.cache_info()
    
    return JSONResponse(content={
        "message": "Python FastAPI Benchmark - Ultra Optimized",
        "version": "2.1.0",
        "features": [
            "FastAPI + uvicorn",
            "uvloop (async I/O)",
            "Fibonacci Híbrido (Cache + Iterativo)",
            "LRU Cache",
            "Pydantic V2",
            "Async/Await",
            "Sistema de Estadísticas",
            "Monitoreo de Sistema"
        ],
        "endpoints": {
            "compute": "/compute?size=30",
            "health": "/health",
            "stats": "/stats"
        },
        "algorithm_info": {
            "small_numbers": "Recursive with LRU Cache (n <= 30)",
            "large_numbers": "Iterative Algorithm (n > 30)",
            "cache_maxsize": cache_info.maxsize,
            "current_cache_size": cache_info.currsize
        },
        "system_info": {
            "python_version": f"{os.sys.version_info.major}.{os.sys.version_info.minor}.{os.sys.version_info.micro}",
            "worker_pid": os.getpid(),
            "cpu_count": os.cpu_count()
        },
        "performance_stats": stats
    })

@app.get("/stats")
async def get_stats():
    """Endpoint para estadísticas de rendimiento"""
    cache_info = fibonacci_cached.cache_info()
    
    return JSONResponse(content={
        "requests_processed": stats["requests"],
        "total_compute_time_seconds": stats["total_compute_time"],
        "average_compute_time_ms": (stats["total_compute_time"] / max(stats["requests"], 1)) * 1000,
        "cache_statistics": cache_info._asdict(),
        "cache_hit_rate": cache_info.hits / max(cache_info.hits + cache_info.misses, 1) * 100,
        "system_resources": {
            "memory_usage": psutil.virtual_memory()._asdict(),
            "cpu_usage": psutil.cpu_percent(interval=0.1)
        }
    })

@app.on_event("startup")
async def startup_event():
    """Evento de inicio para configuraciones adicionales"""
    print(f"🚀 Python FastAPI Ultra-Optimizada iniciando (PID: {os.getpid()})")
    print(f"🧮 Fibonacci Híbrido: Cache LRU (n≤30) + Iterativo (n>30)")
    print(f"⚡ uvloop + httptools habilitados")
    print(f"🔧 Configuración para máximo rendimiento")
    print(f"💾 Cache LRU: {fibonacci_cached.cache_info().maxsize} elementos")

if __name__ == "__main__":
    import uvicorn
    
    # Configuración optimizada para desarrollo
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        log_level="warning",
        access_log=False,
        loop="uvloop",
        http="httptools"
    ) 