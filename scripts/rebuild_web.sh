#!/bin/bash
# Script to fully rebuild the Flutter web application
# This is necessary after model changes (like removing fields)

echo "🧹 Cleaning build artifacts..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building web application..."
flutter build web --release

echo "✅ Build complete! Please restart your web server and hard refresh your browser (Ctrl+Shift+R or Cmd+Shift+R)"
