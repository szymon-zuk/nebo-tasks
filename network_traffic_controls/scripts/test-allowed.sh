#!/usr/bin/env bash
# Run a positive connectivity test: client -> server on the NACL-permitted app port.
# Requires: terraform apply, SSM online, AWS CLI (profile softserve-lab).
# Usage: ./scripts/test-allowed.sh [path-to-network_traffic_controls]
set -euo pipefail

wait_for_ssm_terminal_status() {
  local cmd_id="$1" instance_id="$2"
  local waited=0
  local max_wait=60
  local st
  while (( waited < max_wait )); do
    st=$(aws ssm get-command-invocation \
      --command-id "$cmd_id" \
      --instance-id "$instance_id" \
      --query 'Status' \
      --output text)
    if [[ "$st" != "InProgress" && "$st" != "Pending" ]]; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
}

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

export AWS_PROFILE="${AWS_PROFILE:-softserve-lab}"
export AWS_REGION="${AWS_REGION:-eu-central-1}"
export AWS_PAGER=cat

CLIENT_ID=$(terraform output -raw client_instance_id)
SERVER_IP=$(terraform output -raw server_private_ip)
PORT=$(terraform output -raw demo_app_port_allow)

echo "SSM run curl on client=$CLIENT_ID -> http://${SERVER_IP}:${PORT}/"
OUT=$(aws ssm send-command \
  --instance-ids "$CLIENT_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"curl -sS --connect-timeout 8 http://${SERVER_IP}:${PORT}/index.txt | head -c 200\"]" \
  --query "Command.CommandId" \
  --output text)

wait_for_ssm_terminal_status "$OUT" "$CLIENT_ID"
aws ssm get-command-invocation \
  --command-id "$OUT" \
  --instance-id "$CLIENT_ID" \
  --query "{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}" \
  --output yaml

echo "Expect Status: Success and body containing ALLOWED."
