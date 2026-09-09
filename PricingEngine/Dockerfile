# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/PricingApi/PricingApi.csproj", "src/PricingApi/"]
COPY ["src/PricingAdapter/PricingAdapter.csproj", "src/PricingAdapter/"]
COPY ["src/PricingApi.Tests/PricingApi.Tests.csproj", "src/PricingApi.Tests/"]

# Restore dependencies
RUN dotnet restore "src/PricingApi/PricingApi.csproj"

# Copy all source code
COPY . .

# Build and publish
RUN dotnet publish "src/PricingApi/PricingApi.csproj" -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app

# Copy published application
COPY --from=build /app/publish .

# Expose ports
EXPOSE 5000 5001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
ENTRYPOINT ["dotnet", "PricingApi.dll"]
