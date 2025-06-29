import express from 'express';
import cors from 'cors';

const app = express();
const PORT = 8080;

// Configurar Express para alto rendimiento
app.set('trust proxy', false);
app.set('x-powered-by', false);

// Configurar CORS
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Configurar JSON parsing con límites
app.use(express.json({ limit: '1mb' }));

// Interfaces para TypeScript
interface ComputeResponse {
  result: number;
  size: number;
  latency_ms: number;
}

interface HealthResponse {
  status: string;
  service: string;
  timestamp: string;
}

interface APIInfo {
  message: string;
  version: string;
  features: string[];
  endpoints: {
    compute: string;
    health: string;
  };
}

// Función Fibonacci optimizada
function fibonacci(n: number): number {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

/**
 * Endpoint principal de cálculo
 */
app.get('/compute', (_req, res) => {
  const startTime = Date.now();
  
  try {
    // Obtener parámetro size con validación
    const sizeParam = _req.query.size as string;
    let size = 30; // valor por defecto
    
    if (sizeParam) {
      const parsedSize = parseInt(sizeParam, 10);
      if (!isNaN(parsedSize) && parsedSize >= 0 && parsedSize <= 50) {
        size = parsedSize;
      }
    }
    
    // Calcular Fibonacci
    const result = fibonacci(size);
    const totalLatency = Date.now() - startTime;
    
    const response: ComputeResponse = {
      result,
      size,
      latency_ms: totalLatency
    };
    
    res.json(response);
    
  } catch (error) {
    console.error('Error in compute endpoint:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

/**
 * Endpoint de health check
 */
app.get('/health', (_req, res) => {
  const response: HealthResponse = {
    status: 'healthy',
    service: 'node-api',
    timestamp: new Date().toISOString()
  };
  res.json(response);
});

/**
 * Endpoint raíz con información de la API
 */
app.get('/', (_req, res) => {
  const response: APIInfo = {
    message: 'Node.js TypeScript Express API Benchmark - Optimized',
    version: '2.0.0',
    features: [
      'High Performance Config',
      'Optimized JSON Parsing',
      'TypeScript',
      'Express.js'
    ],
    endpoints: {
      compute: '/compute?size=30',
      health: '/health'
    }
  };
  res.json(response);
});

// Manejador de errores global
app.use((error: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: error.message 
  });
});

// Configurar servidor con optimizaciones
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Node.js API optimizada escuchando en puerto ${PORT}`);
  console.log(`📊 Configuración de alto rendimiento habilitada`);
});

// Configuraciones de rendimiento para el servidor
server.keepAliveTimeout = 65000; // Mayor que el load balancer típico
server.headersTimeout = 66000;   // Ligeramente mayor que keepAliveTimeout
server.maxConnections = 1000;    // Límite de conexiones

// Manejar shutdown graceful
process.on('SIGTERM', () => {
  console.log('Recibido SIGTERM, cerrando servidor...');
  server.close(() => {
    process.exit(0);
  });
}); 