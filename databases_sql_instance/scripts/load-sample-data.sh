#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v psql >/dev/null && command -v jq >/dev/null

EP="$(cd "$LAB_ROOT" && terraform output -raw rds_endpoint)"
DB="$(cd "$LAB_ROOT" && terraform output -raw db_name)"
ARN="$(cd "$LAB_ROOT" && terraform output -raw app_secret_arn)"
J="$(aws secretsmanager get-secret-value --secret-id "$ARN" --profile softserve-lab --region eu-central-1 --query SecretString --output text)"

export PGSSLMODE=require PGPASSWORD="$(echo "$J" | jq -r .password)"
U="$(echo "$J" | jq -r .username)"

psql -h "$EP" -U "$U" -d "$DB" -v ON_ERROR_STOP=1 -f "$LAB_ROOT/sql/02_seed.sql"
