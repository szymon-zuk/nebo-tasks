# IaaC Secret Management

## Setup & Deployment

### 1. Initialize Terraform
```bash
cd iaac_secret_management
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Deploy Infrastructure
```bash
terraform apply
```

This will create:
- 4 secrets in AWS Secrets Manager (all prefixed with "szzuk-dev-")
- 2 IAM roles with RBAC policies (reader + admin)
- 1 EC2 instance demonstrating secret retrieval
- 1 Lambda function for automatic secret rotation
- Resource policies preventing cross-account access

### 4. View Outputs
```bash
terraform output
```

## Quick Commands

### List Your Secrets
```bash
aws secretsmanager list-secrets \
  --profile softserve-lab \
  --region eu-central-1 \
  --query 'SecretList[?contains(Name, `szzuk`)].Name'
```

### Retrieve a Secret
```bash
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString \
  --output text \
  --profile softserve-lab \
  --region eu-central-1 | jq .
```

## Cleanup

```bash
terraform destroy
```