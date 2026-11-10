# Etapa 1: Compilación de Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=""
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Etapa 2: Servidor ligero Nginx para Producción en Render
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

