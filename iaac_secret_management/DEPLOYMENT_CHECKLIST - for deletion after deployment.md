# Deployment Checklist - IaaC Secret Management

## Pre-Deployment Verification

### 1. AWS Configuration
- [ ] AWS CLI installed and configured
- [ ] Profile `softserve-lab` configured and accessible
- [ ] Region set to `eu-central-1`
- [ ] IAM permissions verified:
  - [ ] Create Secrets Manager secrets
  - [ ] Create IAM roles and policies
  - [ ] Create Lambda functions (optional)
  - [ ] Create ECS resources (optional)

**Verify AWS access**:
```bash
aws sts get-caller-identity --profile softserve-lab
aws secretsmanager list-secrets --profile softserve-lab --region eu-central-1
```

### 2. Terraform Setup
- [ ] Terraform >= 1.0 installed
- [ ] Working directory: `iaac_secret_management/`
- [ ] All required files present:
  - [ ] main.tf
  - [ ] variables.tf
  - [ ] secrets.tf
  - [ ] iam.tf
  - [ ] outputs.tf
  - [ ] example-application.tf

**Verify Terraform**:
```bash
terraform version
cd iaac_secret_management && ls -la *.tf
```

### 3. Documentation Review
- [ ] README.md reviewed
- [ ] QUICKSTART.md reviewed
- [ ] IMPLEMENTATION_SUMMARY.md reviewed
- [ ] Helper scripts understood

### 4. Security Validation
- [ ] .gitignore configured
- [ ] No plaintext secrets in repository
- [ ] Default tags include Owner: szzuk@softserveinc.com
- [ ] Resource names prefixed with "szzuk"

**Run validation**:
```bash
./scripts/validate-no-secrets.sh
```

## Deployment Steps

### Step 1: Initialize Terraform
```bash
cd iaac_secret_management
terraform init
```

**Expected output**:
- Terraform initialized successfully
- AWS provider downloaded
- Random provider downloaded

**Verify**:
- [ ] `.terraform/` directory created
- [ ] `.terraform.lock.hcl` file created
- [ ] No errors in output

### Step 2: Validate Configuration
```bash
terraform validate
```

**Expected output**:
- "Success! The configuration is valid."

**Verify**:
- [ ] No syntax errors
- [ ] All resources properly defined
- [ ] No validation warnings

### Step 3: Review Execution Plan
```bash
terraform plan
```

**Expected resources (21 total)**:
- [ ] 4 × `aws_secretsmanager_secret`
- [ ] 4 × `aws_secretsmanager_secret_version`
- [ ] 1 × `aws_secretsmanager_secret_policy`
- [ ] 2 × `aws_iam_role` (reader, admin)
- [ ] 2 × `aws_iam_policy` (read, admin)
- [ ] 2 × `aws_iam_role_policy_attachment` (reader, admin)
- [ ] 1 × `aws_lambda_function`
- [ ] 1 × `aws_iam_role` (lambda execution)
- [ ] 2 × `aws_iam_role_policy_attachment` (lambda)
- [ ] 1 × `aws_ecs_task_definition`
- [ ] 1 × `aws_iam_role` (ecs execution)
- [ ] 2 × `aws_iam_role_policy_attachment` (ecs)
- [ ] 1 × `aws_cloudwatch_log_group`
- [ ] 4 × `random_password`
- [ ] 1 × `tls_private_key`
- [ ] 1 × `data.aws_caller_identity`
- [ ] 1 × `data.aws_secretsmanager_secret_version`

**Review**:
- [ ] All resource names start with "szzuk"
- [ ] No secret values exposed in plan output
- [ ] Tags applied correctly
- [ ] No unexpected changes

### Step 4: Apply Configuration
```bash
terraform apply
```

**Confirmation**:
- [ ] Review plan one more time
- [ ] Type "yes" to confirm
- [ ] Wait for completion (typically 2-5 minutes)

**Expected output**:
- "Apply complete! Resources: 21 added, 0 changed, 0 destroyed."
- Outputs displayed (ARNs, commands, etc.)

**Verify**:
- [ ] No errors during apply
- [ ] All resources created successfully
- [ ] Outputs displayed correctly

### Step 5: Verify Deployment
```bash
# Check secret names
terraform output secret_names

# List secrets in AWS
aws secretsmanager list-secrets \
  --profile softserve-lab \
  --region eu-central-1 \
  --query 'SecretList[?contains(Name, `szzuk`)].Name'

# Check IAM roles
terraform output iam_roles
```

**Verify**:
- [ ] 4 secrets visible in AWS console/CLI
- [ ] All secrets prefixed with "szzuk-dev-"
- [ ] IAM roles created
- [ ] IAM policies attached
- [ ] Example resources created (Lambda, ECS)

## Post-Deployment Testing

### Test 1: Secret Retrieval
```bash
# Using helper script
./scripts/retrieve-secret.sh db-password

# Using AWS CLI directly
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString \
  --output text \
  --profile softserve-lab \
  --region eu-central-1 | jq .
```

**Verify**:
- [ ] Secret retrieved successfully
- [ ] JSON structure correct
- [ ] All expected fields present
- [ ] No errors or access denied messages

### Test 2: IAM Permissions
```bash
# Get reader role ARN
READER_ROLE=$(terraform output -json iam_roles | jq -r '.secrets_reader_role_arn')

# Check role policies
aws iam list-attached-role-policies \
  --role-name szzuk-dev-secrets-reader \
  --profile softserve-lab
```

**Verify**:
- [ ] Reader role has read policy attached
- [ ] Admin role has admin policy attached
- [ ] Policies scoped to correct secrets
- [ ] No overly permissive policies

### Test 3: Secret Metadata
```bash
# Check secret metadata (no values exposed)
aws secretsmanager describe-secret \
  --secret-id szzuk-dev-db-password \
  --profile softserve-lab \
  --region eu-central-1
```

**Verify**:
- [ ] Tags present (Owner, Project, etc.)
- [ ] Recovery window configured (7 days)
- [ ] Encryption enabled (AWS managed key)
- [ ] Version tracking enabled
- [ ] Last accessed time available

### Test 4: Security Validation
```bash
# Check for plaintext secrets in repository
./scripts/validate-no-secrets.sh

# Check Terraform state for exposed values
terraform show | grep -i "password\|secret\|key" | grep -v "arn:" | grep -v "id"
```

**Verify**:
- [ ] No plaintext secrets in Git
- [ ] No secrets in Terraform outputs
- [ ] No secrets in log files
- [ ] .gitignore working correctly

### Test 5: Example Application
```bash
# Check Lambda function
aws lambda get-function \
  --function-name szzuk-dev-example \
  --profile softserve-lab \
  --region eu-central-1

# Check ECS task definition
aws ecs describe-task-definition \
  --task-definition szzuk-dev-task \
  --profile softserve-lab \
  --region eu-central-1
```

**Verify**:
- [ ] Lambda function created
- [ ] Lambda has correct IAM role
- [ ] Lambda environment variables reference secret ARNs
- [ ] ECS task definition created
- [ ] ECS task has secrets configuration
- [ ] CloudWatch log group created

## Documentation Artifacts

### Required Screenshots
- [ ] AWS Secrets Manager console showing 4 secrets (values redacted)
- [ ] IAM roles list showing reader and admin roles
- [ ] IAM policy showing RBAC configuration
- [ ] Terraform apply output (success message)
- [ ] Secret retrieval CLI output (redacted values)
- [ ] Git log search showing no plaintext secrets

### Required Files
- [x] README.md - Complete documentation
- [x] QUICKSTART.md - Fast deployment guide
- [x] IMPLEMENTATION_SUMMARY.md - Acceptance criteria mapping
- [x] DEPLOYMENT_CHECKLIST.md - This file
- [x] .gitignore - Secret exclusion patterns
- [x] All .tf files - Infrastructure code
- [x] scripts/ - Helper scripts

## Troubleshooting

### Issue: "terraform init" fails
**Solution**: Check Terraform version (need >= 1.0) and internet connectivity for provider download.

### Issue: "Access Denied" during apply
**Solution**: Verify AWS profile has necessary IAM permissions. Check with:
```bash
aws iam get-user --profile softserve-lab
```

### Issue: "Secret already exists" error
**Solution**: Secrets from previous deployment may still exist. List and delete:
```bash
aws secretsmanager list-secrets --profile softserve-lab --region eu-central-1
aws secretsmanager delete-secret --secret-id <name> --force-delete-without-recovery
```

### Issue: Lambda deployment fails
**Solution**: The Lambda uses a placeholder.zip. This is expected - the Lambda demonstrates configuration, not functionality. To deploy a working Lambda, create proper deployment package with dependencies.

### Issue: Can't retrieve secrets
**Solution**: Check IAM role permissions and ensure the profile has GetSecretValue permission.

## Cleanup Instructions

### Option 1: Terraform Destroy (Recommended)
```bash
terraform destroy
```

**Note**: Secrets have a 7-day recovery window by default.

### Option 2: Force Delete Everything
```bash
# Delete secrets immediately
aws secretsmanager delete-secret \
  --secret-id szzuk-dev-db-password \
  --force-delete-without-recovery \
  --profile softserve-lab \
  --region eu-central-1

# Repeat for other secrets
# Then run terraform destroy
terraform destroy
```

### Verify Cleanup
```bash
# Check no secrets remain
aws secretsmanager list-secrets --profile softserve-lab --region eu-central-1

# Check no IAM roles remain
aws iam list-roles --profile softserve-lab | grep szzuk

# Check no Lambda functions remain
aws lambda list-functions --profile softserve-lab --region eu-central-1 | grep szzuk
```

## Sign-Off

### Deployment Completed
- [ ] All deployment steps completed successfully
- [ ] All post-deployment tests passed
- [ ] Documentation artifacts collected
- [ ] No errors or warnings encountered

**Deployment Date**: _______________
**Deployed By**: _______________
**Deployment Duration**: _______________
**Total Resources Created**: 21

### Acceptance Criteria Met
- [ ] All functional requirements satisfied
- [ ] All non-functional requirements satisfied
- [ ] Security best practices implemented
- [ ] Documentation complete and accurate

**Accepted By**: _______________
**Acceptance Date**: _______________

---

## Quick Reference Commands

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Retrieve secret
./scripts/retrieve-secret.sh db-password

# Rotate secret
./scripts/rotate-secret.sh api-key

# Validate security
./scripts/validate-no-secrets.sh

# View outputs
terraform output

# Destroy
terraform destroy
```

---

**Ready for Deployment**: ✅ Yes
**Security Review**: ✅ Passed
**Documentation**: ✅ Complete
**Testing**: ⏳ Pending deployment
