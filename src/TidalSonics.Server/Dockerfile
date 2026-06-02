  # syntax=docker/dockerfile:1.7

  # ---- build stage ----
  FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
  WORKDIR /src

  # Restore as a separate layer so source changes don't bust the package
  # cache
  COPY src/TidalSonics.Server/TidalSonics.Server.csproj src/TidalSonics.Server/
  RUN dotnet restore src/TidalSonics.Server/TidalSonics.Server.csproj

  # Copy the rest and publish
  COPY src/ src/
  RUN dotnet publish src/TidalSonics.Server/TidalSonics.Server.csproj \
      -c Release \
      -o /app/publish \
      --no-restore

  # ---- runtime stage ----
  FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
  WORKDIR /app
  COPY --from=build /app/publish .

  # Base image already runs as non-root $APP_UID and exposes 8080.
  ENTRYPOINT ["dotnet", "TidalSonics.Server.dll"]

