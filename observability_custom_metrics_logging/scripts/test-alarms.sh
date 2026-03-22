#!/usr/bin/env bash
# Exercise CloudWatch alarms for the custom-metrics-logging FastAPI app.
#
# Prerequisites:
#   - App reachable at BASE_URL (ECS public IP / ALB / localhost)
#   - PutMetricData working (ECS task role); otherwise metrics never reach alarms
#   - AWS CLI: profile softserve-lab + region eu-central-1 (or set AWS_PROFILE / AWS_REGION)
#
# Usage:
#   ./scripts/test-alarms.sh http://<host-or-ip>
#
# Optional env:
#   AWS_PROFILE   (default: softserve-lab)
#   AWS_REGION    (default: eu-central-1)
#   FORCE_ANOMALY_ALARM=1
#       After traffic, sets user-login-anomaly to ALARM so the composite can fire
#       while high-error-count is ALARM (anomaly model otherwise needs days of baseline).
#
set -euo pipefail

BASE_URL="${1:?Usage: $0 http://<app-host>}"
PROFILE="${AWS_PROFILE:-softserve-lab}"
REGION="${AWS_REGION:-eu-central-1}"
export AWS_PROFILE
export AWS_REGION

echo "App:     $BASE_URL"
echo "AWS:     profile=$PROFILE region=$REGION"
echo ""

curl_ok() {
  curl -s -S -o /dev/null -w "" --connect-timeout 5 "$@" || true
}

echo "== 0) Orders burst first (high-orders-volume: Sum >40 in 5 min) =="
echo "    Sending 55x POST /orders ..."
for _ in $(seq 1 55); do
  curl_ok -X POST "$BASE_URL/orders"
done
echo "    This alarm uses a 300s period — expect ALARM after ~5–12 minutes if PutMetricData works."
echo ""

echo "== 1) high-error-count (≥5 ErrorCount in 120s) =="
echo "    Sending 8x GET /error ..."
for _ in $(seq 1 8); do
  curl_ok "$BASE_URL/error"
done
echo "    Usually ALARM within ~2–4 minutes."
echo ""

echo "== 2) high-error-rate (>10% in one 60s period) =="
echo "    Filling ~70s with ~25% errors (25 /error + 75 /) ..."
t_start=$(date +%s)
while [ $(($(date +%s) - t_start)) -lt 70 ]; do
  for _ in $(seq 1 25); do
    curl_ok "$BASE_URL/error"
  done
  for _ in $(seq 1 75); do
    curl_ok "$BASE_URL/"
  done
done
echo "    Usually ALARM within ~2–4 minutes after this minute completes."
echo ""

echo "== 3) user-login-anomaly + composite =="
echo "    CloudWatch anomaly needs a long baseline; it rarely goes ALARM from a short test."
if [ "${FORCE_ANOMALY_ALARM:-}" = "1" ]; then
  echo "    FORCE_ANOMALY_ALARM=1 — setting user-login-anomaly to ALARM (lab only)."
  aws cloudwatch set-alarm-state \
    --alarm-name szzuk-custom-metrics-logging-user-login-anomaly \
    --state-value ALARM \
    --state-reason "Lab: FORCE_ANOMALY_ALARM=1 for composite testing" \
    --profile "$PROFILE" \
    --region "$REGION"
  echo "    If high-error-count is already ALARM, composite szzuk-custom-metrics-logging-composite-errors-login-anomaly should go ALARM within ~1 min."
else
  echo "    To test composite after step 1 fires: FORCE_ANOMALY_ALARM=1 $0 $BASE_URL"
  echo "    Or run: aws cloudwatch set-alarm-state --alarm-name szzuk-custom-metrics-logging-user-login-anomaly --state-value ALARM --state-reason test --profile $PROFILE --region $REGION"
fi
echo ""

echo "== Current alarm states =="
aws cloudwatch describe-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'MetricAlarms[].[AlarmName,StateValue]' \
  --output table || true

aws cloudwatch describe-composite-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'CompositeAlarms[].[AlarmName,StateValue]' \
  --output table 2>/dev/null || true

echo ""
echo "Why you often see only 1 ALARM at first:"
echo "  - high-error-count is the fastest (2 min period)."
echo "  - high-orders-volume waits for a full 5 min metric bucket."
echo "  - high-error-rate needs CloudWatch to ingest a full 60s window of samples."
echo "  - Re-run describe-alarms after 10–15 minutes, or use FORCE_ANOMALY_ALARM=1 for composite."
echo ""
echo "Console: CloudWatch → Alarms → filter szzuk-custom-metrics-logging"
