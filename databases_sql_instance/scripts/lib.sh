#!/usr/bin/env bash
# Shared helpers for RDS lab scripts.

: "${AWS_PROFILE:=softserve-lab}"
export AWS_PROFILE

: "${AWS_REGION:=eu-central-1}"
export AWS_REGION

terraform_output_raw() {
  local key="$1"
  local dir="$2"
  (cd "$dir" && terraform output -raw "$key")
}

secret_string() {
  aws secretsmanager get-secret-value \
    --secret-id "$1" \
    --region "$AWS_REGION" \
    --query SecretString \
    --output text
}
