#!/bin/bash
# Netlify build script for Flutter web

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

FLUTTER_ROOT="${FLUTTER_ROOT:-/opt/buildhome/.flutter}"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.4}"

function ensure_flutter() {
  if [ ! -d "$FLUTTER_ROOT/.git" ]; then
    echo "Installing Flutter SDK ($FLUTTER_VERSION) from scratch..."
    rm -rf "$FLUTTER_ROOT"
    git clone --branch "$FLUTTER_VERSION" --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
    return
  fi

  if ! git -C "$FLUTTER_ROOT" rev-parse "refs/tags/$FLUTTER_VERSION" >/dev/null 2>&1; then
    echo "Fetching Flutter tag $FLUTTER_VERSION..."
    git -C "$FLUTTER_ROOT" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION:refs/tags/$FLUTTER_VERSION"
  fi

  echo "Switching Flutter SDK to $FLUTTER_VERSION..."
  git -C "$FLUTTER_ROOT" checkout --quiet "refs/tags/$FLUTTER_VERSION" || git -C "$FLUTTER_ROOT" checkout --quiet "$FLUTTER_VERSION"
}

ensure_flutter

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter config --enable-web
flutter precache --web

echo "Installing dependencies..."
flutter pub get

if grep -q "build_runner" pubspec.yaml; then
  echo "Running code generation..."
  flutter pub run build_runner build --delete-conflicting-outputs
fi

echo "Building web app..."
flutter build web --release

echo "Build complete! Output in build/web/"
