# Secrets Management for Apollo AWS Deployment

This guide covers how to securely manage sensitive data (database passwords, Rails master key, etc.) for your Apollo application deployed on AWS.

## Overview

There are several approaches to managing secrets, each with different security and operational characteristics:

1. **Terraform Variables** (Simple, less secure) - Good for non-sensitive config
2. **AWS Secrets Manager** (Recommended, secure) - Best for production
3. **Environment Variables** (Medium) - Good for application-level secrets
4. **Parameter Store** (Alternative) - AWS Systems Manager Parameter Store

## Option 1: Terraform Variables (Current Setup)

### How It Works
Secrets are stored in `terraform.tfvars` which is gitignored.

### Setup
```bash
cp terraform.tfvars.example terraform.tfvars

# Edit with sensitive values
vi terraform.tfvars
```

### Content
```hcl
database_password = "your-super-secure-password-32-chars-min"
rails_master_key  = "your-rails-master-key-from-config/master.key"
```

### Pros ✓
- Simple to set up
- Works immediately
- No additional AWS setup

### Cons ✗
- Secrets in local files (risk if compromised)
- Can accidentally be committed
- Shared among team members
- Not audited

### Security Best Practices
```bash
# Make sure terraform.tfvars is in .gitignore
echo "terraform.tfvars" >> .gitignore

# Secure file permissions
chmod 600 terraform.tfvars

# Use strong passwords (32+ characters)
# Generate with: openssl rand -base64 32
```

## Option 2: AWS Secrets Manager (Recommended for Production)

AWS Secrets Manager is the recommended approach for production deployments.

### Benefits ✓
- Centralized secret management
- Automatic rotation support
- Fine-grained access control (IAM)
- Audit logging (CloudTrail)
- Encryption at rest (KMS)
- No secrets in local files

### Setup

#### 1. Create Secrets in AWS Console or CLI

```bash
# Create database password secret
aws secretsmanager create-secret \
  --name apollo/database/password \
  --description "Apollo RDS database password" \
  --secret-string "your-secure-password-here"

# Create Rails master key secret
aws secretsmanager create-secret \
  --name apollo/rails/master_key \
  --description "Apollo Rails master key" \
  --secret-string "your-rails-master-key"

# Create combined app secrets
aws secretsmanager create-secret \
  --name apollo/app/secrets \
  --description "Apollo application secrets" \
  --secret-string '{
    "database_password": "your-db-password",
    "rails_master_key": "your-rails-key"
  }'
```

#### 2. Update Terraform Configuration

Modify `variables.tf` to reference Secrets Manager:

```hcl
variable "database_password" {
  description = "RDS master password (from Secrets Manager)"
  type        = string
  sensitive   = true
  # In terraform.tfvars, reference the secret:
  # Use data source in a new secrets.tf file
}
```

Create `secrets.tf`:

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "apollo/database/password"
}

data "aws_secretsmanager_secret_version" "rails_key" {
  secret_id = "apollo/rails/master_key"
}

locals {
  database_password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)
  rails_master_key  = jsondecode(data.aws_secretsmanager_secret_version.rails_key.secret_string)
}
```

#### 3. Update ECS Task Definition

In `ecs.tf`, reference the secrets:

```hcl
secrets = [
  {
    name      = "RAILS_MASTER_KEY"
    valueFrom = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:apollo/rails/master_key"
  }
]
```

#### 4. Update IAM Role

The ECS task role needs permission to read secrets:

```hcl
# In iam.tf, add to ecs_task_role
resource "aws_iam_role_policy" "ecs_task_secrets_manager" {
  name = "${var.app_name}-ecs-secrets-manager-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:apollo/*"
        ]
      }
    ]
  })
}
```

### Cost
- $0.40 per secret per month
- $0.05 per 10,000 API calls
- Usually < $5/month for small apps

### Rotation (Optional)

Enable automatic rotation:

```bash
aws secretsmanager rotate-secret \
  --secret-id apollo/database/password \
  --rotation-rules AutomaticallyAfterDays=30 \
  --rotation-lambda-arn arn:aws:lambda:region:account:function:rotate-function
```

## Option 3: Parameter Store (AWS Systems Manager)

Alternative to Secrets Manager, better for non-sensitive config.

### Create Parameters

```bash
# Standard parameter
aws ssm put-parameter \
  --name /apollo/rails_log_level \
  --value "info" \
  --type "String"

# Secure string (encrypted)
aws ssm put-parameter \
  --name /apollo/database/password \
  --value "your-password" \
  --type "SecureString" \
  --key-id alias/aws/ssm
```

### Use in Terraform

```hcl
data "aws_ssm_parameter" "rails_log_level" {
  name = "/apollo/rails_log_level"
}

locals {
  rails_log_level = data.aws_ssm_parameter.rails_log_level.value
}
```

## Option 4: Environment Variables

Application reads from ECS environment variables (least secure for sensitive data).

### In `ecs.tf`

```hcl
environment = [
  {
    name  = "RAILS_LOG_LEVEL"
    value = var.rails_log_level
  },
  {
    name  = "DATABASE_URL"
    value = "postgresql://${var.database_user}:${var.database_password}@${aws_db_instance.main.address}:5432/${var.database_name}"
  }
]
```

### Pros
- Simple
- Works immediately

### Cons ✗
- Visible in ECS console (security risk!)
- Visible in logs if not careful
- No audit trail
- No rotation support

### Not Recommended for Production

## Comparison Table

| Method | Setup | Security | Audit | Rotation | Cost | Recommended |
|--------|-------|----------|-------|----------|------|-------------|
| Terraform Variables | Easy | Medium | No | Manual | Free | Dev/Staging |
| Secrets Manager | Medium | High | Yes | Automatic | ~$5/mo | Production |
| Parameter Store | Easy | Medium | Yes | No | Low | Config |
| Environment Variables | Very Easy | Low | Partial | No | Free | Not Recommended |

## Implementation for Your App

### Current Setup (Development)
Using `terraform.tfvars` is fine for development:
```bash
cp terraform.tfvars.example terraform.tfvars
# Add: database_password and rails_master_key
terraform apply
```

### Production Setup (Recommended)

1. Create secrets in AWS Secrets Manager:
```bash
# Create secret with all sensitive values
aws secretsmanager create-secret \
  --name apollo-prod \
  --secret-string '{
    "database_password": "produce-random-password",
    "rails_master_key": "from-config/master.key"
  }'
```

2. Create `secrets.tf`:
```hcl
data "aws_secretsmanager_secret_version" "app_secrets" {
  count     = var.use_secrets_manager ? 1 : 0
  secret_id = "apollo-prod"
}

locals {
  secrets = var.use_secrets_manager ? jsondecode(data.aws_secretsmanager_secret_version.app_secrets[0].secret_string) : {}
}
```

3. Update `variables.tf`:
```hcl
variable "use_secrets_manager" {
  description = "Use AWS Secrets Manager for credentials"
  type        = bool
  default     = true # For production
}
```

4. In production terraform.tfvars:
```hcl
use_secrets_manager = true
database_password   = "" # Will be fetched from Secrets Manager
rails_master_key    = "" # Will be fetched from Secrets Manager
```

## Accessing Secrets in Your Rails App

### Option 1: Via Environment Variables
Rails automatically reads DATABASE_URL and RAILS_MASTER_KEY from environment.

### Option 2: Rails Credentials
```ruby
Rails.application.credentials.dig(:database, :password)
Rails.application.credentials.secret_key_base
```

### Option 3: AWS SDK
```ruby
require 'aws-sdk-secretsmanager'

client = Aws::SecretsManager::Client.new(region: 'us-east-1')
response = client.get_secret_value(secret_id: 'apollo/database/password')
password = response.secret_string
```

## CLI Commands Reference

### Secrets Manager
```bash
# List all secrets
aws secretsmanager list-secrets

# Get secret value
aws secretsmanager get-secret-value --secret-id apollo/database/password

# Update secret
aws secretsmanager update-secret --secret-id apollo/database/password --secret-string "new-password"

# Delete secret (with recovery window)
aws secretsmanager delete-secret --secret-id apollo/database/password --recovery-window-in-days 7
```

### Parameter Store
```bash
# Get parameter
aws ssm get-parameter --name /apollo/rails_log_level

# Get secure string (decrypted)
aws ssm get-parameter --name /apollo/database/password --with-decryption

# List parameters
aws ssm describe-parameters --filters "Key=Name,Values=/apollo"
```

## Security Checklist

- [ ] Never commit secrets to git (use .gitignore)
- [ ] Set terraform.tfvars permissions: `chmod 600`
- [ ] Use strong passwords (32+ characters, mix of char types)
- [ ] Enable MFA for AWS console access
- [ ] Use IAM roles (not root credentials)
- [ ] Enable CloudTrail for audit logging
- [ ] Rotate credentials regularly
- [ ] Use Secrets Manager for production
- [ ] Enable KMS encryption for secrets at rest
- [ ] Limit IAM permissions to least privilege

## Troubleshooting

### "Access Denied" errors with Secrets Manager
Ensure ECS task execution role has permission:
```bash
aws iam get-role-policy --role-name apollo-ecs-task-role --policy-name apollo-ecs-task-secrets-policy
```

### Secret not updating in running tasks
ECS tasks cache secrets. Restart tasks:
```bash
aws ecs update-service --cluster apollo-cluster --service apollo-service --force-new-deployment
```

### Rotate database password without downtime
1. Create new password in Secrets Manager
2. Update RDS password
3. Restart ECS tasks (zero-downtime with desired_count > 1)

## Further Reading

- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [AWS Parameter Store Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Terraform AWS Provider - Secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version)
