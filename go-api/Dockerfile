# Etapa de construcción
FROM golang:1.22-alpine AS builder

# Instalar dependencias de sistema necesarias
RUN apk add --no-cache git ca-certificates

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias
COPY go.mod go.sum ./

# Descargar dependencias con verbose para debug
RUN go mod download -x

# Verificar dependencias descargadas
RUN go list -m all

# Copiar código fuente
COPY . .

# Compilar aplicación con optimizaciones para producción
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags='-w -s -extldflags "-static"' \
    -tags netgo -installsuffix netgo \
    -o main .

# Etapa de producción ultra-ligera
FROM scratch

# Copiar certificados SSL
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copiar binario compilado
COPY --from=builder /app/main /main

# Configurar variables de entorno para máximo rendimiento
ENV GOGC=100
ENV GOMAXPROCS=0
ENV GOMEMLIMIT=512MiB

# Exponer puerto
EXPOSE 8080

# Health check optimizado
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/main", "-healthcheck"]

# Ejecutar aplicación
ENTRYPOINT ["/main"] 