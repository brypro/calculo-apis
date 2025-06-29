package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"
)

// fib calcula el n-ésimo número de Fibonacci de forma recursiva
func fib(n int) int {
	if n < 2 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

// computeHandler maneja las peticiones al endpoint /compute
func computeHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	// Obtener el parámetro size de la query string
	sizeStr := r.URL.Query().Get("size")
	size := 30 // valor por defecto

	if sizeStr != "" {
		if parsed, err := strconv.Atoi(sizeStr); err == nil && parsed > 0 {
			size = parsed
		}
	}

	// Calcular Fibonacci
	result := fib(size)

	// Crear respuesta
	response := map[string]interface{}{
		"result":     result,
		"size":       size,
		"latency_ms": time.Since(start).Milliseconds(),
	}

	// Configurar headers
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	// Responder con JSON
	json.NewEncoder(w).Encode(response)

	// Log de la petición
	log.Printf("Go API - Size: %d, Result: %d, Latency: %dms", size, result, time.Since(start).Milliseconds())
}

// healthHandler para health checks
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "service": "go-api"})
}

func main() {
	// Configurar rutas
	http.HandleFunc("/compute", computeHandler)
	http.HandleFunc("/health", healthHandler)

	// Configurar servidor
	port := ":8080"
	log.Printf("🚀 Go API iniciando en puerto %s", port)
	log.Printf("📊 Endpoint: http://localhost%s/compute?size=30", port)
	log.Printf("❤️  Health: http://localhost%s/health", port)

	// Iniciar servidor
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("❌ Error iniciando servidor: %v", err)
	}
}
