#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKER_DIR="$(dirname "$SCRIPT_DIR")/packer"

echo "=== Initializing Packer plugins ==="
packer init "$PACKER_DIR"

echo "=== Validating Packer template ==="
packer validate "$PACKER_DIR"

echo "=== Building AMI ==="
packer build "$PACKER_DIR"

MANIFEST="$PACKER_DIR/manifest.json"
if [ -f "$MANIFEST" ]; then
  AMI_ID=$(jq -r '.builds[-1].artifact_id' "$MANIFEST" | cut -d: -f2)
  echo ""
  echo "=== Build complete ==="
  echo "AMI ID: $AMI_ID"
  echo "Region: $(jq -r '.builds[-1].artifact_id' "$MANIFEST" | cut -d: -f1)"
  echo "Build time: $(jq -r '.builds[-1].build_time' "$MANIFEST")s"
fi
