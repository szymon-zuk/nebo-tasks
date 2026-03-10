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

echo "Invoking Lambda function: $FUNCTION_NAME"
echo "==========================================="

RESPONSE=$(aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --cli-binary-format raw-in-base64-out \
    --payload '{}' \
    --log-type Tail \
    /dev/stdout 2>/dev/null)

echo ""
echo "Response:"
echo "$RESPONSE" | head -n -1 | jq . 2>/dev/null || echo "$RESPONSE"

echo ""
echo "==========================================="
echo "Checking recent logs..."
echo ""

aws logs tail "/aws/lambda/$FUNCTION_NAME" \
    --since 5m \
    --profile "$PROFILE" \
    --region "$REGION" \
    --format short 2>/dev/null || echo "No recent logs found."
