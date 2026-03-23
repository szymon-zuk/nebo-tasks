#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v pg_dump >/dev/null && command -v jq >/dev/null

EP="$(cd "$LAB_ROOT" && terraform output -raw rds_endpoint)"
DB="$(cd "$LAB_ROOT" && terraform output -raw db_name)"
ARN="$(cd "$LAB_ROOT" && terraform output -raw master_secret_arn)"
J="$(aws secretsmanager get-secret-value --secret-id "$ARN" --profile softserve-lab --region eu-central-1 --query SecretString --output text)"

export PGSSLMODE=require PGPASSWORD="$(echo "$J" | jq -r .password)"
U="$(echo "$J" | jq -r .username)"

mkdir -p "$LAB_ROOT/backups"
OUT="$LAB_ROOT/backups/pg_dump-$(date -u +%Y%m%dT%H%M%SZ).sql"
pg_dump -h "$EP" -U "$U" -d "$DB" --no-owner --no-acl -f "$OUT"
