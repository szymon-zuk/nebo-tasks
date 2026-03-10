#!/usr/bin/env bash
set -euo pipefail

PROFILE="softserve-lab"
REGION="eu-central-1"

FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")
if [[ -z "$FUNCTION_NAME" ]]; then
    echo "ERROR: Could not read lambda_function_name from terraform output."
    echo "Make sure you are in the compute_serverless directory and terraform has been applied."
    exit 1
fi

echo "=== Lambda Function Configuration ==="
aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query '{FunctionName:FunctionName,Runtime:Runtime,MemorySize:MemorySize,Timeout:Timeout,State:State,LastModified:LastModified,DeadLetterConfig:DeadLetterConfig}' \
    --output table 2>/dev/null

echo ""
echo "=== EventBridge Schedule ==="
RULE_NAME=$(terraform output -raw eventbridge_rule_name 2>/dev/null || echo "")
if [[ -n "$RULE_NAME" ]]; then
    aws events describe-rule \
        --name "$RULE_NAME" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query '{Name:Name,State:State,Schedule:ScheduleExpression}' \
        --output table 2>/dev/null
fi

echo ""
echo "=== CloudWatch Alarms ==="
aws cloudwatch describe-alarms \
    --alarm-name-prefix "szzuk-dev-ebs-metrics" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'MetricAlarms[*].[AlarmName,StateValue,MetricName]' \
    --output table 2>/dev/null

echo ""
echo "=== Custom Metrics ==="
NAMESPACE=$(aws lambda get-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Environment.Variables.CLOUDWATCH_NAMESPACE' \
    --output text 2>/dev/null)

if [[ -n "$NAMESPACE" && "$NAMESPACE" != "None" ]]; then
    aws cloudwatch list-metrics \
        --namespace "$NAMESPACE" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query 'Metrics[*].MetricName' \
        --output table 2>/dev/null || echo "No custom metrics found yet."
fi

echo ""
echo "=== Recent Invocations (last 30min) ==="
aws logs filter-log-events \
    --log-group-name "/aws/lambda/$FUNCTION_NAME" \
    --start-time "$(date -d '30 minutes ago' +%s000 2>/dev/null || date -v-30M +%s000)" \
    --filter-pattern '"metrics_published"' \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'events[*].message' \
    --output text 2>/dev/null || echo "No recent invocations found."

echo ""
echo "=== Dead Letter Queue ==="
DLQ_URL=$(terraform output -raw dlq_url 2>/dev/null || echo "")
if [[ -n "$DLQ_URL" ]]; then
    aws sqs get-queue-attributes \
        --queue-url "$DLQ_URL" \
        --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output table 2>/dev/null
fi
