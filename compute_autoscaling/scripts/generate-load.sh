#!/bin/bash
# generate-load.sh — Generate HTTP traffic to trigger autoscaling
#
# Usage:
#   ./scripts/generate-load.sh [ALB_DNS] [DURATION_SECONDS] [CONCURRENCY]
#
# Defaults: 300s duration, 5 workers, 50ms delay between requests per worker.
# Ctrl+C stops all workers cleanly.

set -euo pipefail

ALB_DNS="${1:-}"
DURATION_SECONDS="${2:-300}"
CONCURRENCY="${3:-5}"
DELAY=0.05

if [[ -z "$ALB_DNS" ]]; then
  echo "Reading ALB DNS from terraform output..."
  ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null) || {
    echo "Error: Could not read alb_dns_name from terraform output."
    echo "Usage: $0 <ALB_DNS> [DURATION_SECONDS] [CONCURRENCY]"
    exit 1
  }
fi

BASE_URL="http://${ALB_DNS}"

echo "============================================"
echo " Autoscaling Load Generator"
echo "============================================"
echo " Target:      ${BASE_URL}"
echo " Duration:    ${DURATION_SECONDS}s"
echo " Workers:     ${CONCURRENCY}"
echo " Delay:       ${DELAY}s between requests"
echo "============================================"
echo ""
echo " Press Ctrl+C to stop at any time."
echo ""

pids=()

cleanup() {
  echo ""
  echo "Stopping all workers..."
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null
  echo "Stopped."
  exit 0
}

trap cleanup INT TERM

send_requests() {
  local worker_id=$1
  local end_time=$((SECONDS + DURATION_SECONDS))
  local count=0
  while [[ $SECONDS -lt $end_time ]]; do
    curl -s -o /dev/null -w "" "${BASE_URL}/" 2>/dev/null || true
    count=$((count + 1))
    if ((count % 50 == 0)); then
      echo "[Worker ${worker_id}] ${count} requests sent"
    fi
    sleep "$DELAY"
  done
  echo "[Worker ${worker_id}] Done — ${count} total requests."
}

echo "Starting ${CONCURRENCY} workers..."

for i in $(seq 1 "$CONCURRENCY"); do
  send_requests "$i" &
  pids+=($!)
done

wait "${pids[@]}"

echo ""
echo "============================================"
echo " Load generation complete."
echo " Wait 2-5 minutes, then check scaling:"
echo "   ./scripts/check-scaling-status.sh"
echo "============================================"
