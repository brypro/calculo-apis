# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

# Establecer directorio de trabajo
WORKDIR /src

# Copiar archivos de proyecto
COPY Api.csproj ./

# Restaurar dependencias
RUN dotnet restore

# Copiar código fuente
COPY . .

# Publicar la aplicación
RUN dotnet publish -c Release -o /app

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos publicados
COPY --from=build /app .

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Comando de inicio
ENTRYPOINT ["dotnet", "Api.dll"] 