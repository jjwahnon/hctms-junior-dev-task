# Quick Start Guide - Apollo to AWS

## Testing Before Deployment ⚡

**Highly recommended: Test locally first!**

```bash
# Quick validation (2 minutes)
cd terraform
bash test-all.sh

# Full test workflow (15 minutes)
bash verify-deployment.sh

# Optional: Test deploy to AWS (30 minutes, costs ~$10)
bash verify-deployment.sh --test-deploy
```

See [TESTING-QUICK-REFERENCE.md](TESTING-QUICK-REFERENCE.md) for quick commands.  
See [TESTING-GUIDE.md](TESTING-GUIDE.md) for complete testing workflow.

---

## 5-Minute Setup

### 1. Prerequisites
```bash
# Install required tools
brew install terraform awscli docker  # macOS
# or for Windows, use Chocolatey: choco install terraform awscli docker-desktop

# Configure AWS
aws configure
# Enter your AWS Access Key and Secret
```

### 2. Prepare Configuration
```bash
cd apollo/terraform

# Copy and customize configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with:
#   - aws_region
#   - database_password (generate a secure one)
#   - rails_master_key (copy from config/master.key)
```

### 3. Create Infrastructure
```bash
# From apollo/terraform directory

terraform init
terraform plan     # Review what will be created
terraform apply    # Deploy infrastructure
```

### 4. Build & Push Docker Image
```bash
# Get values from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)

# From apollo directory (root)
docker build -t $ECR_URL:latest .

# Login and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL
docker push $ECR_URL:latest

# Update terraform.tfvars
# Add or update: docker_image = "$ECR_URL:latest"

# Reapply Terraform to deploy the app
cd terraform && terraform apply
```

### 5. Initialize Database
```bash
# Get outputs
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
SUBNETS=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].networkConfiguration.awsvpcConfiguration.subnets[0]' --output text)
SG=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' --output text)

# Run migrations
TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].taskDefinition' --output text)
aws ecs run-task \
  --cluster $CLUSTER \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"apollo","command":["bundle","exec","rails","db:migrate"]}]}'
```

### 6. Access Your App
```bash
# Get load balancer DNS
ALB_DNS=$(terraform output -raw load_balancer_dns)
echo "http://$ALB_DNS"
# Open in browser!
```

## Configuration Reference

### terraform.tfvars Required Variables
- `aws_region`: AWS region (default: us-east-1)
- `environment`: production/staging/development
- `database_password`: RDS password (REQUIRED - no default)
- `rails_master_key`: From config/master.key (REQUIRED)

### Optional Enhancements
- `enable_https`: Set to true for HTTPS
- `certificate_arn`: ACM certificate ARN for HTTPS
- `domain_name`: Custom domain
- `container_cpu`: Increase for large apps (256-4096)
- `container_memory`: Increase for large apps (512-30720)
- `desired_count`: Number of app instances (default: 2)

## Useful Commands

```bash
# View infrastructure outputs
terraform output

# View specific output
terraform output load_balancer_dns

# Check ECS service and tasks
aws ecs describe-services --cluster apollo-cluster --services apollo-service
aws ecs list-tasks --cluster apollo-cluster

# View logs
aws logs tail /ecs/apollo --follow

# Scale down to zero (pause app, keep infrastructure)
aws ecs update-service --cluster apollo-cluster --service apollo-service --desired-count 0

# Cleanup everything
terraform destroy
```

## 💰 Cost Estimate

### ⭐ ZERO COST IDLE (Recommended)
```hcl
min_count           = 0              # Scale to 0 when idle
database_type       = "aurora-serverless"
use_fargate_spot    = true
```
- **Idle: $16-22/month** (ALB + Aurora minimum)
- **With Usage: $40-60/month**

### Business Hours Only
```hcl
enable_scheduled_scaling = true
business_hours_start     = 8
business_hours_end       = 18
```
- **Nights/Weekends: $16/month**
- **Total: ~$40/month**

### Always-On (Default)
```hcl
min_count           = 2
database_type       = "postgres"
```
- **Total: ~$70-80/month** (steady cost)

## Troubleshooting

### Task not starting?
```bash
aws logs tail /ecs/apollo --follow
```

### Database connection failed?
- Check RDS identifier: `apollo-db`
- Check security group allows ECS → RDS
- Verify password in terraform.tfvars

### Can't push to ECR?
```bash
# Verify ECR login
aws ecr describe-repositories --repository-names apollo

# Re-authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_URL>
```

---

## More Information

- **[COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)** - Detailed cost optimization guide (highly recommended!)
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Comprehensive deployment documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Infrastructure design details
