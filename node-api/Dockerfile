# Build stage
FROM node:20-alpine AS build

# Establecer directorio de trabajo
WORKDIR /src

# Copiar archivos de configuración
COPY package*.json tsconfig.json ./

# Instalar todas las dependencias para build
RUN npm install && npm cache clean --force

# Copiar código fuente
COPY src ./src

# Compilar TypeScript
RUN npm run build

# Runtime stage
FROM node:20-alpine

# Instalar dependencias del sistema
RUN apk add --no-cache dumb-init wget

# Crear usuario no-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar solo dependencias de producción
RUN npm install --only=production && npm cache clean --force

# Copiar archivos compilados
COPY --from=build /src/dist ./dist

# Cambiar ownership al usuario no-root
RUN chown -R appuser:appgroup /app

# Cambiar al usuario no-root
USER appuser

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Comando de inicio con dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"] 