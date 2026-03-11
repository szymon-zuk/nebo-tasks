#!/bin/bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-softserve-lab}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

echo "=== Finding custom AMIs ==="
AMIS=$(aws ec2 describe-images \
  --owners self \
  --filters \
    "Name=tag:Project,Values=compute-custom-ami" \
    "Name=tag:ManagedBy,Values=packer" \
  --query 'Images | sort_by(@, &CreationDate) | [*].[ImageId,Name,CreationDate]' \
  --output text \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION")

if [ -z "$AMIS" ]; then
  echo "No custom AMIs found."
  exit 0
fi

echo "$AMIS" | while read -r ami_id ami_name creation_date; do
  echo "Deregistering: $ami_id ($ami_name, created $creation_date)"

  SNAPSHOTS=$(aws ec2 describe-images \
    --image-ids "$ami_id" \
    --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' \
    --output text \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION")

  aws ec2 deregister-image \
    --image-id "$ami_id" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

  for snap_id in $SNAPSHOTS; do
    if [ "$snap_id" != "None" ]; then
      echo "  Deleting snapshot: $snap_id"
      aws ec2 delete-snapshot \
        --snapshot-id "$snap_id" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"
    fi
  done
done

echo ""
echo "=== All custom AMIs deleted ==="
