package main

import (
	"fmt"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"

	"github.com/goccy/go-json"
	"github.com/valyala/fasthttp"
)

// Configurar GOMAXPROCS al número de CPUs disponibles
func init() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	// Configurar GC para máximo rendimiento
	runtime.GC()
}

// Estructuras de respuesta optimizadas
type ComputeResponse struct {
	Result    int64  `json:"result"`
	Size      int    `json:"size"`
	LatencyMs int64  `json:"latency_ms"`
	Algorithm string `json:"algorithm"`
}

type HealthResponse struct {
	Status    string    `json:"status"`
	Service   string    `json:"service"`
	Timestamp time.Time `json:"timestamp"`
}

type APIInfo struct {
	Message    string            `json:"message"`
	Version    string            `json:"version"`
	Features   []string          `json:"features"`
	Endpoints  map[string]string `json:"endpoints"`
	SystemInfo map[string]int    `json:"system_info"`
}

// Pool de objetos para reducir allocaciones
var (
	computeResponsePool = make(chan *ComputeResponse, 100)
	healthResponsePool  = make(chan *HealthResponse, 50)
)

// Cache global thread-safe para Fibonacci
var fibCache = sync.Map{}

// Obtener objeto del pool
func getComputeResponse() *ComputeResponse {
	select {
	case resp := <-computeResponsePool:
		return resp
	default:
		return &ComputeResponse{}
	}
}

// Devolver objeto al pool
func putComputeResponse(resp *ComputeResponse) {
	resp.Result = 0
	resp.Size = 0
	resp.LatencyMs = 0
	resp.Algorithm = ""

	select {
	case computeResponsePool <- resp:
	default:
	}
}

// Fibonacci con cache thread-safe para números pequeños
func fibonacciCached(n int) int64 {
	if n <= 1 {
		return int64(n)
	}

	// Verificar cache
	if cached, ok := fibCache.Load(n); ok {
		return cached.(int64)
	}

	// Calcular recursivamente solo para números pequeños
	result := fibonacciCached(n-1) + fibonacciCached(n-2)

	// Guardar en cache
	fibCache.Store(n, result)

	return result
}

// Fibonacci iterativo para números grandes
func fibonacciIterative(n int) int64 {
	if n <= 1 {
		return int64(n)
	}

	var a, b int64 = 0, 1
	for i := 2; i <= n; i++ {
		a, b = b, a+b
	}
	return b
}

// Algoritmo Fibonacci híbrido ultra-optimizado
func fibonacciOptimized(n int) (int64, string) {
	if n <= 35 {
		// Usar cache para números pequeños-medianos
		return fibonacciCached(n), "cached"
	} else {
		// Usar iterativo para números grandes
		return fibonacciIterative(n), "iterative"
	}
}

// Handler para CORS optimizado
func enableCORS(ctx *fasthttp.RequestCtx) {
	ctx.Response.Header.Set("Access-Control-Allow-Origin", "*")
	ctx.Response.Header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	ctx.Response.Header.Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if string(ctx.Method()) == "OPTIONS" {
		ctx.SetStatusCode(fasthttp.StatusOK)
		return
	}
}

// Handler principal de compute ultra-optimizado
func computeHandler(ctx *fasthttp.RequestCtx) {
	start := time.Now()

	enableCORS(ctx)
	if string(ctx.Method()) == "OPTIONS" {
		return
	}

	// Obtener parámetro size con parsing optimizado
	sizeStr := string(ctx.QueryArgs().Peek("size"))
	size := 30 // valor por defecto

	if len(sizeStr) > 0 {
		if parsedSize, err := strconv.Atoi(sizeStr); err == nil {
			if parsedSize >= 0 && parsedSize <= 50 {
				size = parsedSize
			}
		}
	}

	// Calcular Fibonacci con algoritmo optimizado
	result, algorithm := fibonacciOptimized(size)

	// Calcular latencia
	latency := time.Since(start).Milliseconds()

	// Obtener objeto de respuesta del pool
	response := getComputeResponse()
	response.Result = result
	response.Size = size
	response.LatencyMs = latency
	response.Algorithm = algorithm

	// Serializar respuesta con goccy/go-json (más rápido que encoding/json)
	jsonData, err := json.Marshal(response)
	if err != nil {
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		ctx.SetBodyString(`{"error":"Failed to serialize response"}`)
		putComputeResponse(response)
		return
	}

	// Devolver objeto al pool
	putComputeResponse(response)

	// Establecer headers y respuesta
	ctx.SetContentType("application/json")
	ctx.SetStatusCode(fasthttp.StatusOK)
	ctx.SetBody(jsonData)
}

// Handler de health check
func healthHandler(ctx *fasthttp.RequestCtx) {
	enableCORS(ctx)
	if string(ctx.Method()) == "OPTIONS" {
		return
	}

	response := HealthResponse{
		Status:    "healthy",
		Service:   "go-api",
		Timestamp: time.Now().UTC(),
	}

	jsonData, err := json.Marshal(response)
	if err != nil {
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetStatusCode(fasthttp.StatusOK)
	ctx.SetBody(jsonData)
}

// Handler de información de la API
func rootHandler(ctx *fasthttp.RequestCtx) {
	enableCORS(ctx)
	if string(ctx.Method()) == "OPTIONS" {
		return
	}

	// Obtener estadísticas de cache
	cacheSize := 0
	fibCache.Range(func(key, value interface{}) bool {
		cacheSize++
		return true
	})

	response := APIInfo{
		Message:  "Go FastHTTP API Benchmark - Ultra Optimized v3.0",
		Version:  "3.0.0",
		Features: []string{"FastHTTP", "goccy/go-json", "Object Pooling", "Hybrid Fibonacci", "Thread-Safe Cache", "GOMAXPROCS Tuned", "Zero-Copy"},
		Endpoints: map[string]string{
			"compute": "/compute?size=30",
			"health":  "/health",
		},
		SystemInfo: map[string]int{
			"gomaxprocs": runtime.GOMAXPROCS(0),
			"numcpu":     runtime.NumCPU(),
			"goroutines": runtime.NumGoroutine(),
			"cache_size": cacheSize,
		},
	}

	jsonData, err := json.Marshal(response)
	if err != nil {
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetStatusCode(fasthttp.StatusOK)
	ctx.SetBody(jsonData)
}

// Router principal
func requestHandler(ctx *fasthttp.RequestCtx) {
	path := string(ctx.Path())

	switch path {
	case "/compute":
		computeHandler(ctx)
	case "/health":
		healthHandler(ctx)
	case "/":
		rootHandler(ctx)
	default:
		enableCORS(ctx)
		ctx.SetStatusCode(fasthttp.StatusNotFound)
		ctx.SetBodyString(`{"error":"Not found"}`)
	}
}

func main() {
	// Manejar health check desde línea de comandos
	if len(os.Args) > 1 && os.Args[1] == "-healthcheck" {
		resp, err := http.Get("http://localhost:8080/health")
		if err != nil || resp.StatusCode != 200 {
			os.Exit(1)
		}
		os.Exit(0)
	}

	// Pre-calentar cache con valores comunes
	for i := 0; i <= 35; i++ {
		fibonacciCached(i)
	}

	// Configurar servidor FastHTTP para máximo rendimiento
	server := &fasthttp.Server{
		Handler:                      requestHandler,
		DisableKeepalive:             false,
		TCPKeepalive:                 true,
		MaxConnsPerIP:                2000,
		MaxRequestsPerConn:           20000,
		MaxKeepaliveDuration:         time.Minute * 15,
		MaxIdleWorkerDuration:        time.Second * 5,
		TCPKeepalivePeriod:           time.Second * 20,
		MaxRequestBodySize:           1024 * 1024, // 1MB
		DisablePreParseMultipartForm: true,
		NoDefaultServerHeader:        true,
		NoDefaultDate:                true,
		Concurrency:                  runtime.NumCPU() * 2000,
		// Optimizaciones adicionales ultra-agresivas
		ReadBufferSize:    8192,
		WriteBufferSize:   8192,
		ReadTimeout:       time.Second * 15,
		WriteTimeout:      time.Second * 15,
		IdleTimeout:       time.Minute * 5,
		ReduceMemoryUsage: false, // Priorizar velocidad sobre memoria
	}

	fmt.Printf("🚀 Go FastHTTP API Ultra-Optimizada v3.0 iniciando en puerto 8080\n")
	fmt.Printf("📊 GOMAXPROCS: %d\n", runtime.GOMAXPROCS(0))
	fmt.Printf("🔧 FastHTTP + goccy/go-json + Object Pooling + Hybrid Fibonacci\n")
	fmt.Printf("💾 Cache pre-calentado con Fibonacci(0-35)\n")
	fmt.Printf("⚡ Configuración ultra-agresiva para máximo throughput\n")

	if err := server.ListenAndServe(":8080"); err != nil {
		panic(fmt.Sprintf("Error starting server: %v", err))
	}
}
