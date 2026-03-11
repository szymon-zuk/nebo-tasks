#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== Waiting for cloud-init to finish ==="
cloud-init status --wait

echo "=== System update ==="
apt-get update -y
apt-get upgrade -y

echo "=== Installing base packages ==="
apt-get install -y \
  nginx \
  stress-ng \
  python3-pip \
  python3-venv \
  auditd \
  audispd-plugins \
  unzip \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  jq

echo "=== Installing Amazon CloudWatch Agent ==="
CW_AGENT_DEB="/tmp/amazon-cloudwatch-agent.deb"
curl -fsSL "https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb" \
  -o "$CW_AGENT_DEB"
dpkg -i "$CW_AGENT_DEB"
rm -f "$CW_AGENT_DEB"

echo "=== Installing AWS SSM Agent ==="
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service

echo "=== Installing HashiCorp Vault ==="
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y vault

echo "=== Installing Poetry ==="
export POETRY_HOME="/opt/poetry"
curl -sSL https://install.python-poetry.org | python3 -
ln -sf /opt/poetry/bin/poetry /usr/local/bin/poetry

echo "=== Verifying installations ==="
nginx -v
stress-ng --version | head -1
vault version
poetry --version
python3 --version
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status || true

echo "=== Package installation complete ==="
