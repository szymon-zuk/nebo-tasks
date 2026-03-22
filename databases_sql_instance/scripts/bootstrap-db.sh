#!/usr/bin/env bash
#
# bootstrap-db.sh — Create app user, schema, grants (local psql → RDS).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

command -v psql >/dev/null 2>&1 || {
  echo "psql not found. Install a PostgreSQL client (same major as RDS, e.g. 16)." >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq not found." >&2
  exit 1
}

RDS_ENDPOINT="${RDS_ENDPOINT:-$(terraform_output_raw rds_endpoint "$PROJECT_DIR")}"
DB_NAME="${DB_NAME:-$(terraform_output_raw db_name "$PROJECT_DIR")}"
MASTER_ARN="${MASTER_SECRET_ARN:-$(terraform_output_raw master_secret_arn "$PROJECT_DIR")}"
APP_ARN="${APP_SECRET_ARN:-$(terraform_output_raw app_secret_arn "$PROJECT_DIR")}"
RDS_ID="${RDS_IDENTIFIER:-$(terraform_output_raw rds_identifier "$PROJECT_DIR")}"

echo "Waiting for RDS instance ${RDS_ID} to be available..."
aws rds wait db-instance-available --db-instance-identifier "$RDS_ID" --region "$AWS_REGION"

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

MASTER_JSON="$(secret_string "$MASTER_ARN")"
APP_JSON="$(secret_string "$APP_ARN")"
MASTER_USER="$(echo "$MASTER_JSON" | jq -r .username)"
MASTER_PASS="$(echo "$MASTER_JSON" | jq -r .password)"
APP_USER="$(echo "$APP_JSON" | jq -r .username)"
APP_PASS="$(echo "$APP_JSON" | jq -r .password)"
APP_PASS_ESC="$(sql_escape "$APP_PASS")"

export PGSSLMODE=require
export PGPASSWORD="$MASTER_PASS"

exists="$(psql -h "$RDS_ENDPOINT" -U "$MASTER_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_USER}'" | tr -d '[:space:]')"
if [[ "$exists" == "1" ]]; then
  psql -h "$RDS_ENDPOINT" -U "$MASTER_USER" -d postgres -v ON_ERROR_STOP=1 \
    -c "ALTER ROLE ${APP_USER} WITH PASSWORD '${APP_PASS_ESC}';"
else
  psql -h "$RDS_ENDPOINT" -U "$MASTER_USER" -d postgres -v ON_ERROR_STOP=1 \
    -c "CREATE ROLE ${APP_USER} LOGIN PASSWORD '${APP_PASS_ESC}';"
fi

psql -h "$RDS_ENDPOINT" -U "$MASTER_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO ${APP_USER};"

psql -h "$RDS_ENDPOINT" -U "$MASTER_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 \
  -f "$PROJECT_DIR/sql/01_schema.sql"

psql -h "$RDS_ENDPOINT" -U "$MASTER_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<SQL
GRANT USAGE ON SCHEMA public TO ${APP_USER};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${APP_USER};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ${APP_USER};
SQL

echo "bootstrap-db: complete"
