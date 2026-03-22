#!/usr/bin/env bash
#
# backup.sh — Create an RDS DB snapshot (recommended backup; runs on your laptop).
#
# Usage:
#   ./scripts/backup.sh [suffix]           # wait until snapshot completes (default suffix: manual)
#   ./scripts/backup.sh [suffix] --no-wait # start snapshot and return immediately
#   ./scripts/backup.sh --no-wait
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

SUFFIX="manual"
NO_WAIT=false
for arg in "$@"; do
  if [[ "$arg" == "--no-wait" ]]; then
    NO_WAIT=true
  elif [[ "$arg" == -* ]]; then
    echo "Unknown option: $arg" >&2
    exit 1
  else
    SUFFIX="$arg"
  fi
done

IDENTIFIER="$(terraform_output_raw rds_identifier "$PROJECT_DIR")"
SNAPSHOT_ID="${IDENTIFIER}-${SUFFIX}-$(date -u +%Y%m%d%H%M%S)"
SNAPSHOT_ID="$(echo "$SNAPSHOT_ID" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | cut -c1-255)"

echo "Creating RDS snapshot: $SNAPSHOT_ID"
aws rds create-db-snapshot \
  --db-instance-identifier "$IDENTIFIER" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$AWS_REGION" \
  --output text \
  --query 'DBSnapshot.DBSnapshotIdentifier'

if [[ "$NO_WAIT" == true ]]; then
  echo "backup: snapshot started (not waiting). Check: aws rds describe-db-snapshots --db-snapshot-identifier $SNAPSHOT_ID --region $AWS_REGION"
  exit 0
fi

echo "Waiting for snapshot to complete (aws rds wait db-snapshot-completed)..."
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$AWS_REGION"

echo "backup: snapshot completed — $SNAPSHOT_ID"
