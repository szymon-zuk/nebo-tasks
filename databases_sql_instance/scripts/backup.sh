#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ID="$(cd "$LAB_ROOT" && terraform output -raw rds_identifier)"
SID="$(echo "${ID}-lab-$(date -u +%Y%m%d%H%M%S)" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | cut -c1-255)"

aws rds create-db-snapshot \
  --db-instance-identifier "$ID" \
  --db-snapshot-identifier "$SID" \
  --profile softserve-lab \
  --region eu-central-1 \
  --output text \
  --query 'DBSnapshot.DBSnapshotIdentifier'

aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "$SID" \
  --profile softserve-lab \
  --region eu-central-1
echo "$SID"
