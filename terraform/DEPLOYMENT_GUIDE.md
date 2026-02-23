# Deployment Guide for Apollo Rails App to AWS with Terraform

## Prerequisites

1. **AWS Account**: You need an active AWS account
2. **AWS CLI**: Install and configure AWS CLI with your credentials
3. **Terraform**: Install Terraform >= 1.0
4. **Docker**: Install Docker (for building container images)
5. **Rails**: The Apollo Rails app (this repo)

### Installation

#### AWS CLI
```bash
# macOS with Homebrew
brew install awscli

# Windows with Chocolatey (in admin PowerShell)
choco install awscliv2

# Verify installation
aws --version
```

#### Terraform
```bash
# macOS with Homebrew
brew install terraform

# Windows with Chocolatey (in admin PowerShell)
choco install terraform

# Verify installation
terraform -v
```

#### Docker
Download from [Docker's official website](https://www.docker.com/products/docker-desktop)

## Setup Steps

### 1. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (e.g., json)
```

### 2. Prepare Terraform Configuration

```bash
cd apollo/terraform

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your values
vi terraform.tfvars  # or use your preferred editor
```

**Key variables to customize:**
- `aws_region`: Your preferred AWS region
- `environment`: Set to "production", "staging", or "development"
- `database_password`: A strong, random password for RDS
- `rails_master_key`: Copy from `config/master.key` in the Rails app
- `certificate_arn`: (optional) ACM certificate for HTTPS
- `domain_name`: (optional) Your domain name

### 3. Build and Push Docker Image to ECR

```bash
# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"  # or your chosen region

# Initialize Terraform (this creates ECR repository)
terraform init
terraform plan
terraform apply -target=aws_ecr_repository.main

# Get the ECR repository URL from output
ECR_URL=$(terraform output ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL

# Build Docker image from the Rails app root
cd ..  # Back to apollo root
docker build -t $ECR_URL:latest .

# Push to ECR
docker push $ECR_URL:latest

# Update terraform.tfvars with the docker_image value
# Add this line: docker_image = "$ECR_URL:latest"
```

### 4. Deploy Infrastructure with Terraform

```bash
cd terraform

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan

# Save the outputs
terraform output > outputs.txt
```

### 5. Initialize the Rails Database

After Terraform completes, you need to initialize the database:

```bash
# Get the RDS endpoint from Terraform outputs
DB_ENDPOINT=$(terraform output rds_endpoint | cut -d':' -f3)

# Run database migrations in the ECS task
# First, get the cluster and service names
CLUSTER=$(terraform output ecs_cluster_name)
SERVICE=$(terraform output ecs_service_name)

# Create a one-off task for database setup
aws ecs run-task \
  --cluster $CLUSTER \
  --task-definition apollo:1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"apollo","command":["bundle","exec","rails","db:create","db:migrate","db:seed"]}]}'
```

### 6. Access Your Application

```bash
# Get the load balancer DNS
LB_DNS=$(terraform output load_balancer_dns)

# Application will be available at:
echo "http://$LB_DNS"
```

## Environment Variables

The ECS task definition automatically sets these environment variables:

- `RAILS_ENV`: production/staging/development
- `RAILS_LOG_LEVEL`: Log level (info, debug, etc.)
- `DATABASE_URL`: PostgreSQL connection string
- `RAILS_MASTER_KEY`: Retrieved from AWS Secrets Manager

## Maintenance

### Cost Optimization - Zero Cost When Idle

To achieve **zero cost when there's no traffic**, use these settings in `terraform.tfvars`:

```hcl
# Database - Aurora Serverless auto-scales to minimum
database_type           = "aurora-serverless"
aurora_min_capacity     = 0.5  # Minimal cost when idle

# Application - Scale down to zero tasks
min_count              = 0     # Minimum tasks (ZERO = no cost when idle!)
use_fargate_spot       = true  # 70% cheaper than regular Fargate

# Optional: Schedule shutdown during off-hours
enable_scheduled_scaling = true
business_hours_start     = 8   # Start at 8 AM
business_hours_end       = 18  # Stop at 6 PM (UTC)
```

**Cost with this configuration:**
- $0 when idle (0 ECS tasks, Aurora paused)
- ~$5-10/month with normal usage
- ALB costs ~$16/month even when idle (unavoidable for this architecture)

### Alternative: True Serverless (Near-Zero Cost)

For even lower costs (~$1-3/month), consider:

**Option A: API Gateway + Lambda** (True serverless)
- Pay only per request (~$0.50 per million requests)
- Better for low-traffic apps or background services
- Limited to Lambda constraints (time, memory)

**Option B: Keep ALB + ECS but with aggressive auto-shutdown**
- Min ECS tasks: 0
- Aurora Serverless with 0.5 ACU minimum
- ~$16/month ALB cost + variable cost (currently used approach)

1. Update your code locally
2. Build and push new Docker image
3. Update task definition reference
4. Restart ECS tasks

```bash
# Build and push new image
docker build -t $ECR_URL:v2.0 .
docker push $ECR_URL:v2.0

# Update terraform.tfvars
# docker_image = "$ECR_URL:v2.0"

# Apply changes
terraform apply
```

### View Logs

```bash
# View CloudWatch logs
LOG_GROUP=$(terraform output cloudwatch_log_group)

aws logs tail $LOG_GROUP --follow
```

### Monitor Performance

- AWS CloudWatch Dashboard: Application metrics and logs
- RDS Console: Database performance
- ECS Console: Task status and scaling

### Scaling

Auto-scaling is configured to trigger when:
- CPU utilization exceeds 70%
- Memory utilization exceeds 80%

Adjust thresholds in `ecs.tf` if needed.

## Cleanup

To delete all resources (WARNING: This will delete the database):

```bash
cd terraform

# Backup database snapshot first (if using RDS)
aws rds create-db-snapshot \
  --db-instance-identifier apollo-db \
  --db-snapshot-identifier apollo-db-backup-$(date +%s)

# Destroy resources
terraform destroy
```

### Pause Infrastructure (Keep costs minimal)

To pause the application without destroying infrastructure:

```bash
# Scale down to zero tasks (database still running)
aws ecs update-service \
  --cluster apollo-cluster \
  --service apollo-service \
  --desired-count 0
```

Costs when paused:
- ALB: ~$16/month (cannot be paused)
- Aurora Serverless: $1-5/month (auto-pauses after 5 minutes idle)
- ECS: $0 (zero tasks running)
- **Total: ~$16-20/month**

## Troubleshooting

### Task not starting
Check ECS task logs:
```bash
aws logs tail /ecs/apollo --follow
```

### Database connection fails
- Verify security groups allow traffic from ECS to RDS
- Check database credentials in task definition
- Verify RDS is in the same VPC

### ECR image not found
- Verify image was pushed successfully: `aws ecr describe-images --repository-name apollo`
- Check IAM permissions for ECS task execution role

### Load balancer returns 502
- Check ECS task health status
- Verify container is listening on port 3000
- Check security groups allow ALB → ECS traffic

## Cost Optimization

- Use `db.t3.micro` for development/testing
- Enable RDS auto-pause for non-production databases
- Use Fargate Spot instances for non-critical workloads (mix with regular Fargate)
- Set appropriate log retention (currently 30 days)
- Delete unused resources regularly

## Security Best Practices

✅ Implemented:
- All traffic between services encrypted
- RDS encrypted at rest
- Multi-AZ database deployment
- No public access to RDS or ECS tasks
- S3 buckets with encryption and versioning
- IAM roles with least-privilege policies
- VPC with private subnets for app and database

⚠️ Additional recommended:
- Set up WAF (Web Application Firewall) for ALB
- Enable VPC Flow Logs
- Use AWS Secrets Manager for sensitive data
- Enable GuardDuty for threat detection
- Implement backup strategies
- Use CloudTrail for audit logging

## Support

For issues, check:
1. Terraform logs: `export TF_LOG=DEBUG`
2. AWS CloudFormation events in console
3. ECS task logs in CloudWatch
4. RDS events in RDS console
