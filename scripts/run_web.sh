#!/usr/bin/env bash
# Run the BlueBubbles web client inside GitHub Codespaces.
#
# Usage:
#   NEXT_PUBLIC_BLUEBUBBLES_HOST=https://example.com \
#   NEXT_PUBLIC_BLUEBUBBLES_PASSWORD=secret \
#   scripts/run_web.sh
#
# Optional environment variables:
#   FLUTTER_WEB_PORT   Port to expose via `flutter run` (default: 3000)
#   FLUTTER_WEB_HOST   Hostname for the web server (default: 0.0.0.0)
#   FLUTTER_WEB_RENDERER Renderer to use (default: auto)

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: Flutter SDK was not found in PATH." >&2
  echo "Install Flutter in the Codespace or use the pre-built devcontainer image." >&2
  exit 127
fi

export NEXT_PUBLIC_BLUEBUBBLES_HOST="${NEXT_PUBLIC_BLUEBUBBLES_HOST:-https://messages.moydchat.org}"
export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD="${NEXT_PUBLIC_BLUEBUBBLES_PASSWORD:-}"

HOST="${FLUTTER_WEB_HOST:-0.0.0.0}"
PORT="${FLUTTER_WEB_PORT:-3000}"
RENDERER="${FLUTTER_WEB_RENDERER:-auto}"

cd "$REPO_ROOT"

echo "==> Fetching dependencies"
flutter pub get

echo "==> Building web bundle"
flutter build web --web-renderer "$RENDERER"

echo "==> Launching development server on http://$HOST:$PORT"
exec flutter run -d web-server \
  --web-hostname "$HOST" \
  --web-port "$PORT" \
  --web-renderer "$RENDERER"
