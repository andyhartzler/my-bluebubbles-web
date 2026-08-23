#!/usr/bin/env bash
# Netlify "ignore" script. Exit 0 = SKIP the build. Exit 1 = BUILD.
#
# WHY THIS EXISTS. Netlify was rebuilding the whole Flutter web app on every
# push to master, and almost none of those pushes could change the built app.
# Measured on 2026-08-22: 22 commits reached master, and exactly ONE touched
# lib/, web/ or pubspec. The other 21 were Supabase edge functions, SQL
# migrations and AGENTS.md notes. A Flutter web build takes minutes, so that is
# 21 full builds of an identical artifact, paid for in build credits that had to
# be topped up three times.
#
# Edge functions are hand deployed and migrations are applied through the
# Supabase MCP. NEITHER is read by netlify-build.sh, so a change to them cannot
# alter build/web. Rebuilding for them produces a byte-identical site.
#
# The list below is deliberately an ALLOW list rather than a deny list. A deny
# list fails open: someone adds a new source directory, forgets this file, and
# the app silently stops deploying. An allow list fails closed, which for a
# deploy gate is the safe direction: an unrecognised path builds.
set -euo pipefail

# Netlify provides CACHED_COMMIT_REF (last built) and COMMIT_REF (this one).
# On a first build, a cleared cache, or a manual retry either can be missing;
# build rather than guess.
if [ -z "${CACHED_COMMIT_REF:-}" ] || [ -z "${COMMIT_REF:-}" ]; then
  echo "no cached commit ref, building"
  exit 1
fi

# If the diff itself fails (shallow clone, force push, rewritten history) we do
# not know what changed, so build.
if ! CHANGED=$(git diff --name-only "$CACHED_COMMIT_REF" "$COMMIT_REF" 2>/dev/null); then
  echo "cannot diff $CACHED_COMMIT_REF..$COMMIT_REF, building"
  exit 1
fi

if [ -z "$CHANGED" ]; then
  echo "no files changed, skipping"
  exit 0
fi

# Anything that can affect build/web. netlify-build.sh and this file are
# included because a change to the build itself must rebuild.
if echo "$CHANGED" | grep -qE '^(lib/|web/|assets/|fonts/|pubspec\.(yaml|lock)|analysis_options\.yaml|netlify\.toml|netlify-build\.sh|netlify-should-build\.sh)'; then
  echo "app files changed, building:"
  echo "$CHANGED" | grep -E '^(lib/|web/|assets/|fonts/|pubspec|analysis_options|netlify)' | head -20
  exit 1
fi

echo "no app files changed, skipping build. changed paths:"
echo "$CHANGED" | head -20
exit 0
