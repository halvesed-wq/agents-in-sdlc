#!/bin/bash
# Installs the workshop site's dependencies (website/) in Claude Code cloud sessions,
# so `npm run check:all` and `npm run build` work right away.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}/website"

# Run the install only if a listed file has changed since the install last succeeded
hashes=node_modules/.session-start.sha256
if ! sha256sum --check --status "$hashes" 2>/dev/null; then
  # Delete the old hashes first, so a failed install runs again next time
  rm -f "$hashes"

  npm ci --no-audit --no-fund

  sha256sum ../.claude/hooks/session-start.sh package.json package-lock.json > "$hashes" || rm -f "$hashes"
fi

# lychee checks the built site's links (CI and .github/skills/build-and-verify-docs).
# It is a global binary, so it is installed outside the hash check, only when missing.
lychee_version=0.24.2
if [ "$(lychee --version 2>/dev/null)" != "lychee $lychee_version" ]; then
  tmp=$(mktemp -d)
  curl -fsSL "https://github.com/lycheeverse/lychee/releases/download/lychee-v${lychee_version}/lychee-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C "$tmp"
  install -m 0755 "$(find "$tmp" -type f -name lychee | head -n1)" /usr/local/bin/lychee
  rm -rf "$tmp"
fi
