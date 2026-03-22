#!/usr/bin/env bash
#
# backup-pgdump.sh — Logical SQL dump with local pg_dump → backups/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

command -v pg_dump >/dev/null 2>&1 || {
  echo "pg_dump not found. Install a PostgreSQL client (major >= RDS), or use ./scripts/backup.sh (snapshot)." >&2
  exit 1
}

RDS_ENDPOINT="${RDS_ENDPOINT:-$(terraform_output_raw rds_endpoint "$PROJECT_DIR")}"
DB_NAME="${DB_NAME:-$(terraform_output_raw db_name "$PROJECT_DIR")}"
MASTER_ARN="${MASTER_SECRET_ARN:-$(terraform_output_raw master_secret_arn "$PROJECT_DIR")}"

JSON="$(secret_string "$MASTER_ARN")"
export PGSSLMODE=require
export PGPASSWORD
PGPASSWORD="$(echo "$JSON" | jq -r .password)"
USER="$(echo "$JSON" | jq -r .username)"

mkdir -p "$PROJECT_DIR/backups"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$PROJECT_DIR/backups/pg_dump-${STAMP}.sql"

echo "pg_dump → $OUT"
pg_dump -h "$RDS_ENDPOINT" -U "$USER" -d "$DB_NAME" --no-owner --no-acl -f "$OUT"

echo "backup-pgdump: wrote $OUT"
