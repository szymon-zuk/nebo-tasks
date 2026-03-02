# IaaC Secret Management with AWS Secrets Manager

This project demonstrates secure secret management integration with Terraform and AWS Secrets Manager, following DevOps best practices for automated infrastructure provisioning.

## Secrets Managed

### 1. Database Password (`db-password`)
- **Type**: Database credentials
- **Contains**: username, password, host, port, dbname, engine
- **Use case**: Application database connections

### 2. API Key (`api-key`)
- **Type**: External API credentials
- **Contains**: api_key, service name, creation timestamp
- **Use case**: Third-party API authentication

### 3. SSH Private Key (`ssh-key`)
- **Type**: SSH authentication
- **Contains**: RSA private key (4096-bit), public key
- **Use case**: Server/instance access

### 4. Application Configuration (`app-config`)
- **Type**: Application secrets
- **Contains**: JWT secret, encryption key, session secret, OAuth config
- **Use case**: Application runtime configuration

## Retrieving Secrets

### Using AWS CLI

```bash
# Retrieve database password
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-db-password \
  --query SecretString \
  --output text \
  --profile softserve-lab \
  --region eu-central-1 | jq .

# Retrieve API key
aws secretsmanager get-secret-value \
  --secret-id szzuk-dev-api-key \
  --query SecretString \
  --output text \
  --profile softserve-lab \
  --region eu-central-1 | jq .
```

## Access Control Model

### Reader Role (`secrets-reader`)
- **Purpose**: Application runtime access to secrets
- **Permissions**: `GetSecretValue`, `DescribeSecret`, `ListSecrets`
- **Used by**: ECS tasks, Lambda functions, EC2 instances
- **Principle**: Least privilege - read-only access

### Admin Role (`secrets-admin`)
- **Purpose**: Secret lifecycle management
- **Permissions**: Full `secretsmanager:*` actions
- **Used by**: DevOps engineers, automation pipelines
- **Principle**: Administrative access for management only

### Resource Policies
- **Cross-account protection**: Deny access from external AWS accounts
- **Encryption**: All secrets encrypted with AWS-managed keys (KMS)
- **Audit logging**: CloudTrail captures all secret access attempts

## Security Best Practices

### Implemented
- [x] Secrets encrypted at rest (AWS Secrets Manager default encryption)
- [x] No plaintext secrets in Git repository
- [x] Least-privilege IAM policies (separate reader/admin roles)
- [x] Secrets never exposed in Terraform outputs
- [x] Resource policies prevent cross-account access
- [x] Secrets referenced by ARN, not by value
- [x] Recovery window prevents accidental deletion
- [x] All resources tagged for audit and cost tracking
