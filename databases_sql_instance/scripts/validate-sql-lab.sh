#!/usr/bin/env bash
#
# validate-sql-lab.sh — bootstrap → seed → queries → RDS snapshot (./scripts/backup.sh).
#
# Extra arguments are passed to backup.sh, e.g.:
#   ./scripts/validate-sql-lab.sh --no-wait
#   ./scripts/validate-sql-lab.sh mysuffix --no-wait
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/bootstrap-db.sh"
"$SCRIPT_DIR/load-sample-data.sh"
"$SCRIPT_DIR/run-queries.sh"
"$SCRIPT_DIR/backup.sh" "$@"

echo "validate-sql-lab: all steps finished"
