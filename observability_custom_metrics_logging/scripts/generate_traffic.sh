#!/usr/bin/env bash
# Generate traffic to the FastAPI app for testing custom metrics and dashboard.
# Usage: ./scripts/generate_traffic.sh [BASE_URL]
# Example: ./scripts/generate_traffic.sh http://1.2.3.4

set -e
BASE_URL="${1:-http://localhost:80}"
LOG_GROUP="/ecs/custom-metrics-logging"

echo "App URL:    $BASE_URL"
echo "Log group:  $LOG_GROUP"
echo "Run for ~2 minutes; press Ctrl+C to stop early."
echo ""

for i in $(seq 1 120); do
  curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/" > /dev/null
  curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/Welcome?name=Test$i" > /dev/null
  # Trigger some errors (for ErrorCount and alarm testing)
  if [ $((i % 15)) -eq 0 ]; then
    curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/error" > /dev/null
  fi
  sleep 1
done

echo "Done. Check CloudWatch: Metrics (namespace CustomMetricsLogging/App) and Dashboard (CustomMetricsLogging-App)."
