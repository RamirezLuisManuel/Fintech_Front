#!/usr/bin/env bash
set -e

echo "=== Iniciando Build de Flutter Web para Render ==="

# Descargar Flutter SDK (rama stable) si no existe en caché
if [ ! -d "$HOME/flutter" ]; then
  echo "Clonando Flutter SDK (stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"

flutter config --enable-web
flutter pub get

# Si definiste API_BASE_URL en las variables de entorno de Render, se inyecta en compilación
if [ -n "$API_BASE_URL" ]; then
  echo "Compilando Flutter Web apuntando a API_BASE_URL=$API_BASE_URL"
  flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
else
  echo "Compilando Flutter Web con configuración estándar"
  flutter build web --release
fi

echo "=== Build completado exitosamente en build/web ==="

