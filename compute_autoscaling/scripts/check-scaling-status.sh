#!/bin/bash
# check-scaling-status.sh — Display current Auto Scaling Group status, recent
# scaling activities, and CloudWatch alarm states.
#
# Usage:
#   ./scripts/check-scaling-status.sh [ASG_NAME]
#
# If ASG_NAME is omitted, the script reads it from terraform output.

set -euo pipefail

PROFILE="softserve-lab"
REGION="eu-central-1"

ASG_NAME="${1:-}"
if [[ -z "$ASG_NAME" ]]; then
  ASG_NAME=$(terraform output -raw asg_name 2>/dev/null) || {
    echo "Error: Could not read asg_name from terraform output."
    echo "Usage: $0 <ASG_NAME>"
    exit 1
  }
fi

echo "============================================"
echo " Auto Scaling Status: ${ASG_NAME}"
echo "============================================"
echo ""

echo "--- ASG Configuration & Instance Count ---"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'AutoScalingGroups[0].{MinSize:MinSize,MaxSize:MaxSize,DesiredCapacity:DesiredCapacity,InstanceCount:length(Instances),HealthCheck:HealthCheckType,Instances:Instances[*].{Id:InstanceId,AZ:AvailabilityZone,State:LifecycleState,Health:HealthStatus}}' \
  --output table 2>/dev/null || echo "(no data)"

echo ""
echo "--- Recent Scaling Activities (last 5) ---"
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$ASG_NAME" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --max-items 5 \
  --query 'Activities[*].{Time:StartTime,Status:StatusCode,Description:Description}' \
  --output table 2>/dev/null || echo "(no activities)"

echo ""
echo "--- CloudWatch Alarm States ---"
aws cloudwatch describe-alarms \
  --alarm-name-prefix "szzuk-dev-" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue,Metric:MetricName,Threshold:Threshold}' \
  --output table 2>/dev/null || echo "(no alarms)"

echo ""
echo "============================================"
echo " Done."
echo "============================================"
