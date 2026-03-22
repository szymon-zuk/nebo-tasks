#!/usr/bin/env bash
#
# run-queries.sh — Run sql/03_queries.sql as app_rw (local psql).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

command -v psql >/dev/null 2>&1 || {
  echo "psql not found." >&2
  exit 1
}

RDS_ENDPOINT="${RDS_ENDPOINT:-$(terraform_output_raw rds_endpoint "$PROJECT_DIR")}"
DB_NAME="${DB_NAME:-$(terraform_output_raw db_name "$PROJECT_DIR")}"
APP_ARN="${APP_SECRET_ARN:-$(terraform_output_raw app_secret_arn "$PROJECT_DIR")}"

JSON="$(secret_string "$APP_ARN")"
export PGSSLMODE=require
export PGPASSWORD
PGPASSWORD="$(echo "$JSON" | jq -r .password)"
USER="$(echo "$JSON" | jq -r .username)"

psql -h "$RDS_ENDPOINT" -U "$USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 \
  -f "$PROJECT_DIR/sql/03_queries.sql"

echo "run-queries: complete"
