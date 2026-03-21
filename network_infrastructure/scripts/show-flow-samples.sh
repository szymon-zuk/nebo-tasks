#!/usr/bin/env bash
# Recent VPC Flow Log events (GNU date -d). Usage: ./scripts/show-flow-samples.sh [minutes] [path]
set -euo pipefail

MINUTES="${1:-15}"
ROOT="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

export AWS_PROFILE="${AWS_PROFILE:-softserve-lab}"
export AWS_REGION="${AWS_REGION:-eu-central-1}"
export AWS_PAGER=cat

LOG_GROUP=$(terraform output -raw flow_log_cloudwatch_log_group_name)
START_SEC=$(date -u -d "$MINUTES minutes ago" +%s)
START_MS=$((START_SEC * 1000))

echo "Log group: $LOG_GROUP"
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --start-time "$START_MS" \
  --limit 25 \
  --output text \
  --query 'events[*].[timestamp,message]' || true
