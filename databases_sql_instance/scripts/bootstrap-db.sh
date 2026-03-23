#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v psql >/dev/null && command -v jq >/dev/null

EP="$(cd "$LAB_ROOT" && terraform output -raw rds_endpoint)"
DB="$(cd "$LAB_ROOT" && terraform output -raw db_name)"
MID="$(cd "$LAB_ROOT" && terraform output -raw rds_identifier)"
MA="$(cd "$LAB_ROOT" && terraform output -raw master_secret_arn)"
AA="$(cd "$LAB_ROOT" && terraform output -raw app_secret_arn)"

aws rds wait db-instance-available \
  --db-instance-identifier "$MID" \
  --profile softserve-lab \
  --region eu-central-1

MJ="$(aws secretsmanager get-secret-value --secret-id "$MA" --profile softserve-lab --region eu-central-1 --query SecretString --output text)"
AJ="$(aws secretsmanager get-secret-value --secret-id "$AA" --profile softserve-lab --region eu-central-1 --query SecretString --output text)"
MU="$(echo "$MJ" | jq -r .username)"
MP="$(echo "$MJ" | jq -r .password)"
AU="$(echo "$AJ" | jq -r .username)"
AP="$(echo "$AJ" | jq -r .password)"
AP_ESC="$(printf '%s' "$AP" | sed "s/'/''/g")"

export PGSSLMODE=require PGPASSWORD="$MP"

psql -h "$EP" -U "$MU" -d postgres -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  BEGIN
    EXECUTE format('CREATE ROLE ${AU} LOGIN PASSWORD %L', '${AP_ESC}');
  EXCEPTION
    WHEN duplicate_object THEN
      EXECUTE format('ALTER ROLE ${AU} PASSWORD %L', '${AP_ESC}');
  END;
END
\$\$;
SQL

psql -h "$EP" -U "$MU" -d postgres -v ON_ERROR_STOP=1 -c "GRANT CONNECT ON DATABASE \"${DB}\" TO ${AU};"
psql -h "$EP" -U "$MU" -d "$DB" -v ON_ERROR_STOP=1 -f "$LAB_ROOT/sql/01_schema.sql"
psql -h "$EP" -U "$MU" -d "$DB" -v ON_ERROR_STOP=1 <<SQL
GRANT USAGE ON SCHEMA public TO ${AU};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${AU};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${AU};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${AU};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ${AU};
SQL
