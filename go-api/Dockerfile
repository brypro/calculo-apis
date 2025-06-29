# Build stage
FROM golang:1.22-alpine AS build

# Instalar dependencias del sistema
RUN apk add --no-cache git ca-certificates tzdata

# Establecer directorio de trabajo
WORKDIR /src

# Copiar archivos de dependencias
COPY go.mod go.sum ./

# Descargar dependencias (si existen)
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

# Runtime stage
FROM alpine:3.20

# Instalar ca-certificates para HTTPS
RUN apk --no-cache add ca-certificates tzdata

# Crear usuario no-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Establecer directorio de trabajo
WORKDIR /app

# Copiar el binario compilado
COPY --from=build /src/app .

# Cambiar ownership al usuario no-root
RUN chown -R appuser:appgroup /app

# Cambiar al usuario no-root
USER appuser

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Comando de inicio
ENTRYPOINT ["./app"] 