#!/bin/bash
# Netlify build script for Flutter web

set -e

echo "Installing Flutter SDK..."

# Clone Flutter SDK if not already present
if [ ! -d "/opt/buildhome/.flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/buildhome/.flutter
fi

# Add Flutter to PATH
export PATH="$PATH:/opt/buildhome/.flutter/bin"

# Verify Flutter installation
flutter --version

# Enable web support
flutter config --enable-web

# Get dependencies
echo "Installing dependencies..."
flutter pub get

# Build for web
echo "Building web app..."
flutter build web --release

echo "Build complete! Output in build/web/"
