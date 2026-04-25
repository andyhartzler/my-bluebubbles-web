#!/usr/bin/env bash
# Patch linagora git deps in pub-cache for Flutter 3.24 / Dart 3.5 compatibility.
#
# tmail-flutter's git deps use Color.withValues(alpha: X) which is a Flutter
# 3.27+ API. Our baseline is Flutter 3.24.4 / Dart 3.5.4. This script
# replaces those calls with .withOpacity(X) (deprecated in 3.27 but
# functionally identical on 3.24).
#
# Run after `flutter pub get` until we either upgrade Flutter or fork the
# linagora repos with the fix baked in.

set -e

PATTERN='s/\.withValues\(\s*alpha:\s*([\d.]+)\s*,?\s*\)/.withOpacity($1)/g'

for dir in \
    ~/.pub-cache/git/html-editor-enhanced-* \
    ~/.pub-cache/git/rich-text-composer-* \
    ~/.pub-cache/git/jmap-dart-client-* \
    ~/.pub-cache/git/linagora-design-flutter-* \
    ~/.pub-cache/git/flutter_appauth_web-*
do
  if [ -d "$dir" ]; then
    find "$dir" -name "*.dart" -type f -print0 \
      | xargs -0 perl -i -0pe "$PATTERN" 2>/dev/null
    echo "patched: $(basename "$dir")"
  fi
done

echo "OK — linagora git deps in pub-cache are 3.24-compatible."
