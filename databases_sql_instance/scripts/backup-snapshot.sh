#!/usr/bin/env bash
# Deprecated alias for ./scripts/backup.sh (kept for older notes / muscle memory).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/backup.sh" "$@"
