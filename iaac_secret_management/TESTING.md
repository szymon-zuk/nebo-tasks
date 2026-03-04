# Testing Summary

## Deployed Resources

| Resource | Name | Status |
|---|---|---|
| Secret | `szzuk-dev-db-password` | Created |
| Secret | `szzuk-dev-api-key` | Created |
| Secret | `szzuk-dev-ssh-key` | Created |
| Secret | `szzuk-dev-app-config` | Created |
| IAM Role | `szzuk-dev-secrets-reader` | Created |
| IAM Role | `szzuk-dev-secrets-admin` | Created |
| IAM Policy | `szzuk-dev-secrets-read` | Attached to reader |
| IAM Policy | `szzuk-dev-secrets-admin` | Attached to admin |
| Resource Policy | Deny external access | Applied to all 4 secrets |
| EC2 Instance | `szzuk-dev-app-server` (`i-0f8847cef63a3401b`) | Running |
| Security Group | `szzuk-dev-ec2-sg` | Applied |
| Instance Profile | `szzuk-dev-ec2-profile` | Attached (secrets-reader role) |

## Test 1: Secrets Are Stored Encrypted

**Verify secrets exist in Secrets Manager:**

```bash
aws secretsmanager list-secrets \
  --profile softserve-lab \
  --region eu-central-1 \
  --query 'SecretList[?contains(Name, `szzuk`)].{Name:Name,KmsKeyId:KmsKeyId}' \
  --output table
```

All secrets are encrypted at rest using AWS-managed KMS keys (default `aws/secretsmanager` key).

## Test 2: Secret Retrieval Without Exposing Values

**Retrieve each secret from your workstation:**

```bash
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1 | jq .

aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-api-key \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1 | jq .

aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-ssh-key \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1 | jq .

aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-app-config \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1 | jq .
```

Secrets are never exposed in Terraform outputs, logs, or error messages.

## Test 3: EC2 Application Retrieves Secrets via IAM Role

**Connect to the EC2 instance:**

```bash
aws ec2-instance-connect ssh \
  --instance-id i-0f8847cef63a3401b \
  --region eu-central-1 \
  --profile softserve-lab
```

**On the instance, verify boot-time check passed:**

```bash
cat boot-status.txt
```

**Retrieve secrets using the IAM role (no credentials on disk):**

```bash
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --region eu-central-1 \
  --query SecretString --output text | jq .
```

**Retrieve all four secrets:**

```bash
for s in db-password api-key ssh-key app-config; do
  echo "--- szzuk-dev-$s ---"
  aws secretsmanager get-secret-value \
    --secret-id "szzuk-dev-$s" \
    --region eu-central-1 \
    --query SecretString --output text | jq .
done
```

The instance has no stored credentials -- access is granted through the `szzuk-dev-secrets-reader` IAM role attached via instance profile.

## Test 4: RBAC -- Reader Role Cannot Modify Secrets

**From the EC2 instance, attempt to delete a secret (should fail):**

```bash
aws secretsmanager delete-secret \
  --secret-id szzuk-dev-db-password \
  --region eu-central-1
```

Expected: `AccessDeniedException` -- the reader role only has `GetSecretValue` and `DescribeSecret` permissions.

## Test 5: IAM Roles and Policies

**Verify reader role permissions:**

```bash
aws iam get-role --role-name szzuk-dev-secrets-reader \
  --profile softserve-lab --query 'Role.Arn'

aws iam list-attached-role-policies \
  --role-name szzuk-dev-secrets-reader \
  --profile softserve-lab
```

**Verify admin role permissions:**

```bash
aws iam get-role --role-name szzuk-dev-secrets-admin \
  --profile softserve-lab --query 'Role.Arn'

aws iam list-attached-role-policies \
  --role-name szzuk-dev-secrets-admin \
  --profile softserve-lab
```

## Test 6: Secret Rotation Without Code Changes

**Save current password, rotate, then verify the change:**

```bash
# Show current password
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1 | jq .password

# Generate new password
NEW_PASS=$(aws secretsmanager get-random-password \
  --password-length 32 --require-each-included-type \
  --exclude-characters '"@/\\' \
  --query RandomPassword --output text \
  --profile softserve-lab --region eu-central-1)

# Update the secret
CURRENT=$(aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1)

UPDATED=$(echo "$CURRENT" | jq --arg pw "$NEW_PASS" '.password = $pw')

aws secretsmanager put-secret-value \
  --secret-id szzuk-dev-db-password \
  --secret-string "$UPDATED" \
  --profile softserve-lab --region eu-central-1

# Verify new password
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString --output text \
  --profile softserve-lab --region eu-central-1 | jq .password
```

No Terraform code was modified. The password value should differ before and after rotation.

## Test 7: No Plaintext Secrets in Git

```bash
cd ~/nebo-tasks
git log -p --all -S "password" -- iaac_secret_management/ | grep -c "random_password"
git log -p --all -S "api_key" -- iaac_secret_management/ | grep -c "random_password"
```

All secret values are generated by Terraform's `random_password` resource and never appear as plaintext in code or git history.

## Test 8: Terraform Plan Shows No Drift

```bash
cd iaac_secret_management
terraform plan
```

Expected output: `No changes. Your infrastructure matches the configuration.`

## Test 9: Resource Policies Prevent Cross-Account Access

**Verify resource policy on a secret:**

```bash
aws secretsmanager get-resource-policy \
  --secret-id szzuk-dev-db-password \
  --profile softserve-lab --region eu-central-1 \
  --query 'ResourcePolicy' --output text | jq .
```

The policy denies all `secretsmanager:*` actions from principals outside account `737473224894`.

## Cleanup

```bash
cd iaac_secret_management
terraform destroy
```

Secrets are scheduled for deletion with a 7-day recovery window.
