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
- 2 IAM roles with RBAC policies
- Example Lambda and ECS resources

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
./scripts/retrieve-secret.sh db-password
./scripts/retrieve-secret.sh api-key
./scripts/retrieve-secret.sh ssh-key
./scripts/retrieve-secret.sh app-config
```

## Cleanup

```bash
terraform destroy
```