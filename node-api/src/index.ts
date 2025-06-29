import express, { Request, Response } from 'express';
import cors from 'cors';

// Crear aplicación Express
const app = express();
const PORT = 8080;

// Middleware
app.use(express.json());
app.use(cors());

// Interfaz para la respuesta
interface ComputeResponse {
  result: number;
  size: number;
  latency_ms: number;
}

// Interfaz para health check
interface HealthResponse {
  status: string;
  service: string;
}

/**
 * Calcula el n-ésimo número de Fibonacci de forma recursiva
 * @param n - El índice del número de Fibonacci a calcular
 * @returns El n-ésimo número de Fibonacci
 */
function fib(n: number): number {
  if (n < 2) {
    return n;
  }
  return fib(n - 1) + fib(n - 2);
}

/**
 * Endpoint principal para calcular Fibonacci
 */
app.get('/compute', (req: Request, res: Response) => {
  const startTime = Date.now();
  
  // Obtener parámetro size de la query string
  const sizeParam = req.query.size as string;
  let size = 30; // valor por defecto
  
  if (sizeParam) {
    const parsed = parseInt(sizeParam);
    if (!isNaN(parsed) && parsed > 0 && parsed <= 50) {
      size = parsed;
    }
  }
  
  // Calcular Fibonacci
  const result = fib(size);
  
  // Calcular latencia
  const latency_ms = Date.now() - startTime;
  
  // Crear respuesta
  const response: ComputeResponse = {
    result,
    size,
    latency_ms
  };
  
  // Log de la petición
  console.log(`Node.js API - Size: ${size}, Result: ${result}, Latency: ${latency_ms}ms`);
  
  // Enviar respuesta
  res.json(response);
});

/**
 * Endpoint de health check
 */
app.get('/health', (req: Request, res: Response) => {
  const response: HealthResponse = {
    status: 'healthy',
    service: 'node-api'
  };
  res.json(response);
});

/**
 * Endpoint raíz con información de la API
 */
app.get('/', (req: Request, res: Response) => {
  res.json({
    message: 'Node.js TypeScript Express API Benchmark',
    version: '1.0.0',
    endpoints: {
      compute: '/compute?size=30',
      health: '/health'
    }
  });
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log('🚀 Node.js TypeScript Express API iniciando...');
  console.log(`📊 Endpoint: http://localhost:${PORT}/compute?size=30`);
  console.log(`❤️  Health: http://localhost:${PORT}/health`);
  console.log(`🌐 Server running on port ${PORT}`);
});

// Manejo de errores no capturados
process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
}); 