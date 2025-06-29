from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time
import logging
from typing import Dict, Any

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Crear aplicación FastAPI
app = FastAPI(
    title="Python API Benchmark",
    description="API para benchmark de rendimiento con cálculo de Fibonacci",
    version="1.0.0"
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def fib(n: int) -> int:
    """
    Calcula el n-ésimo número de Fibonacci de forma recursiva.
    
    Args:
        n: El índice del número de Fibonacci a calcular
        
    Returns:
        El n-ésimo número de Fibonacci
    """
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

@app.get("/compute")
async def compute(size: int = Query(default=30, ge=1, le=50, description="Tamaño para calcular Fibonacci")):
    """
    Calcula el n-ésimo número de Fibonacci.
    
    Args:
        size: El tamaño para calcular Fibonacci (default: 30, max: 50)
        
    Returns:
        JSON con el resultado, tamaño y latencia
    """
    start_time = time.time()
    
    # Calcular Fibonacci
    result = fib(size)
    
    # Calcular latencia
    latency_ms = int((time.time() - start_time) * 1000)
    
    # Crear respuesta
    response = {
        "result": result,
        "size": size,
        "latency_ms": latency_ms
    }
    
    # Log de la petición
    logger.info(f"Python API - Size: {size}, Result: {result}, Latency: {latency_ms}ms")
    
    return JSONResponse(content=response)

@app.get("/health")
async def health():
    """
    Endpoint de health check.
    
    Returns:
        Estado de salud de la API
    """
    return {"status": "healthy", "service": "python-api"}

@app.get("/")
async def root():
    """
    Endpoint raíz con información de la API.
    
    Returns:
        Información básica de la API
    """
    return {
        "message": "Python FastAPI Benchmark",
        "version": "1.0.0",
        "endpoints": {
            "compute": "/compute?size=30",
            "health": "/health",
            "docs": "/docs"
        }
    }

if __name__ == "__main__":
    import uvicorn
    logger.info("🚀 Python FastAPI iniciando...")
    logger.info("📊 Endpoint: http://localhost:8080/compute?size=30")
    logger.info("📚 Docs: http://localhost:8080/docs")
    logger.info("❤️  Health: http://localhost:8080/health")
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=False,
        log_level="info"
    ) 