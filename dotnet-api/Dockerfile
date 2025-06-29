# Etapa de construcción
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# Establecer directorio de trabajo
WORKDIR /src

# Copiar archivos de proyecto
COPY Api.csproj ./

# Restaurar dependencias con configuraciones optimizadas
RUN dotnet restore --runtime linux-x64

# Copiar código fuente
COPY . .

# Publicar con optimizaciones máximas de rendimiento
RUN dotnet publish -c Release -o /app \
    --runtime linux-x64 \
    --self-contained false \
    -p:PublishTrimmed=false \
    -p:PublishSingleFile=false \
    -p:PublishReadyToRun=true \
    -p:TieredPGO=true

# Etapa de runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# Instalar curl para health check
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Crear usuario no-root para seguridad
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --gid 1001 appuser

# Establecer variables de entorno para máximo rendimiento
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_TieredPGO=1
ENV DOTNET_TC_QuickJitForLoops=1
ENV DOTNET_ReadyToRun=1
ENV DOTNET_EnableDiagnostics=0
ENV DOTNET_gcServer=1
ENV DOTNET_GCHeapCount=0
ENV DOTNET_GCConserveMemory=0
ENV DOTNET_ThreadPool_UnfairSemaphoreSpinLimit=6

# Configuraciones adicionales de Kestrel
ENV ASPNETCORE_Kestrel__Limits__MaxConcurrentConnections=1000
ENV ASPNETCORE_Kestrel__Limits__MaxConcurrentUpgradedConnections=1000
ENV ASPNETCORE_Kestrel__Limits__MaxRequestBodySize=1048576

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos publicados
COPY --from=build /app .

# Cambiar ownership al usuario no-root
RUN chown -R appuser:appgroup /app

# Cambiar al usuario no-root
USER appuser

# Exponer puerto
EXPOSE 8080

# Health check mejorado con más tiempo
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Comando de inicio
ENTRYPOINT ["dotnet", "Api.dll"] 