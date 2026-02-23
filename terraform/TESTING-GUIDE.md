# Pre-Launch Testing Guide

Comprehensive guide to test your Apollo Rails app Terraform configuration before deploying to AWS.

## Testing Strategy Overview

```
Phase 1: Local Validation
  ↓
Phase 2: Docker Testing
  ↓
Phase 3: Terraform Validation
  ↓
Phase 4: AWS Credential Testing
  ↓
Phase 5: Small-Scale Test Deployment
  ↓
Phase 6: Integration Testing
  ↓
Phase 7: Cleanup & Production Deploy
```

## Phase 1: Local Validation (5 minutes)

### 1.1 Verify Rails App

Check that your Apollo app runs locally:

```bash
cd apollo

# Setup database
bin/rails db:setup

# Run tests if available
bin/rails test

# Start server
bin/rails server
# Visit http://localhost:3000
```

**What to check:**
- No Ruby/Rails errors
- Database migrations work
- Application boots without errors
- `/up` health check endpoint responds

### 1.2 Verify Dependencies

```bash
# Check Gemfile is valid
bundle check
bundle install

# Verify Docker can build
docker build -t test-apollo .

# Test Rails in container
docker run -it test-apollo bin/rails --version
```

## Phase 2: Docker Testing (10 minutes)

Test your Docker image locally before pushing to ECR.

### 2.1 Build Image

```bash
# Build locally
docker build -t apollo:test .

# Check image
docker images | grep apollo
```

### 2.2 Run Locally

```bash
# Create a test network
docker network create apollo-test

# Run just the app (without database)
docker run -it \
  --name apollo-app \
  --network apollo-test \
  -p 3000:3000 \
  -e RAILS_ENV=development \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  apollo:test \
  bin/rails server -b 0.0.0.0

# In another terminal, test the app
curl http://localhost:3000/up
```

### 2.3 Test with PostGres

```bash
# Run PostgreSQL for testing
docker run -d \
  --name apollo-postgres \
  --network apollo-test \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=apollo_test \
  postgres:16

# Wait for Postgres to start
sleep 5

# Run app with database
docker run -it \
  --name apollo-app-with-db \
  --network apollo-test \
  -p 3000:3000 \
  -e RAILS_ENV=development \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e DATABASE_URL="postgresql://postgres:testpass@apollo-postgres:5432/apollo_test" \
  apollo:test \
  bash -c "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0"

# Test API endpoints
curl -X GET http://localhost:3000/up
curl -X GET http://localhost:3000/tasks
```

### 2.4 Cleanup

```bash
docker stop apollo-app apollo-postgres 2>/dev/null || true
docker rm apollo-app apollo-postgres 2>/dev/null || true
docker network rm apollo-test 2>/dev/null || true
```

## Phase 3: Terraform Validation (5 minutes)

Validate Terraform configuration syntax and logic.

### 3.1 Format Check

```bash
cd terraform

# Check formatting
terraform fmt -check -recursive .

# Auto-fix formatting (safe)
terraform fmt -recursive .
```

### 3.2 Validate Configuration

```bash
# Initialize Terraform (without backend - local only)
terraform init -backend=false

# Validate syntax
terraform validate

# Expected output: Success! The configuration is valid.
```

### 3.3 Review Terraform Plan (DRY RUN)

```bash
# Create a plan without applying
terraform plan -out=tftest.plan

# Review the plan output carefully!
# Check for:
# - Correct number of resources
# - Expected resource names
# - Correct configurations
# - No typos or mistakes
```

The `terraform plan` shows exactly what will be created without touching AWS.

### 3.4 Cost Estimate

```bash
# Analyze plan file for cost impact
terraform show tftest.plan | grep -A 5 -B 5 "aws_"

# Check outputs that show estimated costs
```

## Phase 4: AWS Credential Testing (2 minutes)

Verify AWS credentials and permissions before deployment.

### 4.1 Test AWS Access

```bash
# Verify credentials are configured
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-user"
# }
```

### 4.2 Check Required Permissions

```bash
# Test ECR access (needed to push images)
aws ecr describe-repositories 2>&1
# Should show "No repositories" or list existing ones

# Test ECS access
aws ecs list-clusters
# Should show your clusters or empty list

# Test RDS access
aws rds describe-db-instances
# Should show your RDS instances or empty list

# Test VPC access
aws ec2 describe-vpcs
# Should show your VPCs

# Test S3 access
aws s3 ls
# Should list your buckets
```

### 4.3 Test CloudFormation/IAM

```bash
# Check if Terraform can assume roles (if using cross-account)
aws iam get-user

# Create a test resource to verify permissions
aws ec2 describe-instances
```

**If any command fails:** Check IAM permissions with your AWS administrator.

## Phase 5: Small-Scale Test Deployment (15-30 minutes)

Deploy to AWS *without* production settings to test everything works.

### 5.1 Create Test Configuration

```bash
cd terraform

# Create a test variables file (DO NOT USE PRODUCTION VALUES)
cat > terraform.auto.tfvars.test << 'EOF'
aws_region              = "eu-west-2"
environment             = "test"           # ⚠️ NOT production
app_name                = "apollo-test"    # Different name
database_password       = "Test@Password123"  # Different password
rails_master_key        = "test-key-value-${random-string}"  # Use test key
desired_count           = 1                # Just 1 task
min_count               = 0
database_type           = "aurora-serverless"
aurora_max_capacity     = 1                # Small max capacity
container_cpu           = 256
container_memory        = 512
EOF
```

### 5.2 Plan the Deployment

```bash
# Create test plan
terraform plan -var-file=terraform.auto.tfvars.test -out=tftest.plan

# Review resources that will be created
# Key things to check:
# - VPC created with 2 AZs
# - RDS cluster with Aurora Serverless
# - ECS cluster and service
# - ALB created
# - Security groups created
# - CloudWatch logs created
```

### 5.3 Apply in Test Environment

```bash
# Deploy to AWS (this WILL create resources and incur costs!)
terraform apply tftest.plan

# Wait for deployment (~5-10 minutes)
# Monitor in AWS console:
# - VPC status
# - RDS cluster status
# - ECS tasks status
# - ALB registration
```

### 5.4 Verify Test Deployment

```bash
# Get outputs
terraform output

# Should show:
# - load_balancer_dns: <ALB DNS name>
# - database_endpoint: <Aurora endpoint>
# - ecs_cluster_name: apollo-test-cluster
# etc.
```

### 5.5 Test the Deployed App

```bash
# Get the ALB DNS
ALB_DNS=$(terraform output -raw load_balancer_dns)

# Test health check endpoint
curl http://$ALB_DNS/up
# Should return success

# Check ECS tasks are running
aws ecs list-tasks --cluster apollo-test-cluster \
  --desired-status RUNNING

# Check RDS connection (from ECS task logs)
aws logs tail /ecs/apollo-test --follow --since 1m
```

### 5.6 Test Auto-Scaling

```bash
# Current task count
aws ecs describe-services \
  --cluster apollo-test-cluster \
  --services apollo-test-service \
  --query 'services[0].runningCount'
# Should show: 1

# Generate load (and watch it scale)
for i in {1..100}; do
  curl http://$ALB_DNS/up &
done
wait

# Check if more tasks launched
aws ecs describe-services \
  --cluster apollo-test-cluster \
  --services apollo-test-service \
  --query 'services[0].runningCount'
# Should show: 2 or 3 if scaled up
```

### 5.7 Test Database Failover

```bash
# If Multi-AZ, verify failover capability
aws rds describe-db-clusters \
  --db-cluster-identifier apollo-test-aurora-cluster \
  --query 'DBClusters[0].DBClusterMembers'
```

### 5.8 Cleanup Test Deployment

```bash
# IMPORTANT: Delete test resources to avoid costs!

# Option 1: Terraform destroy (recommended)
terraform destroy -var-file=terraform.auto.tfvars.test -auto-approve

# Wait for resources to be destroyed (~10 minutes)

# Option 2: Manual cleanup (if needed)
aws ecs delete-cluster --cluster apollo-test-cluster --force
aws rds delete-db-cluster --db-cluster-identifier apollo-test-aurora-cluster --skip-final-snapshot

# Verify cleanup
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=apollo-test-vpc" \
  --query 'Vpcs'
# Should be empty
```

## Phase 6: Integration Testing (10 minutes)

Test critical application functionality.

### 6.1 Create Test Script

```bash
# terraform/test-integration.sh
#!/bin/bash

set -e

ALB_DNS=$(terraform output -raw load_balancer_dns)
HEALTH_CHECK_URL="http://$ALB_DNS/up"

echo "Testing Apollo Application Integration..."
echo "ALB URL: $ALB_DNS"
echo

# Test 1: Health check
echo "1. Testing health check endpoint..."
RESPONSE=$(curl -s -w "\n%{http_code}" $HEALTH_CHECK_URL)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
  echo "✓ Health check passed"
else
  echo "✗ Health check failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Test 2: ECS tasks running
echo "2. Checking ECS tasks..."
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
RUNNING=$(aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].runningCount' \
  --output text)
if [ "$RUNNING" -gt 0 ]; then
  echo "✓ ECS tasks running: $RUNNING"
else
  echo "✗ No ECS tasks running"
  exit 1
fi

# Test 3: Database connectivity
echo "3. Checking database..."
DB_TYPE=$(terraform output -raw database_type)
DB_ENDPOINT=$(terraform output -raw database_endpoint)
echo "✓ Database type: $DB_TYPE"
echo "✓ Database endpoint: $DB_ENDPOINT"

# Test 4: S3 bucket
echo "4. Checking S3 bucket..."
S3_BUCKET=$(terraform output -raw s3_bucket_name)
if aws s3 ls s3://$S3_BUCKET 2>/dev/null; then
  echo "✓ S3 bucket accessible: $S3_BUCKET"
else
  echo "✗ S3 bucket not accessible"
  exit 1
fi

# Test 5: CloudWatch logs
echo "5. Checking CloudWatch logs..."
LOG_GROUP=$(terraform output -raw cloudwatch_log_group)
LOGS=$(aws logs describe-log-streams --log-group-name $LOG_GROUP --max-items 1)
if [ ! -z "$LOGS" ]; then
  echo "✓ CloudWatch logs configured: $LOG_GROUP"
else
  echo "⚠ No logs yet (normal for new deployment)"
fi

echo
echo "✓ All integration tests passed!"
```

### 6.2 Run Tests

```bash
chmod +x terraform/test-integration.sh
./terraform/test-integration.sh
```

## Phase 7: Cleanup & Production Deploy

### 7.1 Clean Up Test Files

```bash
cd terraform

# Remove test plan
rm -f tftest.plan terraform.auto.tfvars.test

# Clean Terraform state (if using local state)
rm -rf .terraform.tfstate.d
```

### 7.2 Production Deployment Checklist

Before deploying to production, verify:

- [ ] Rails app runs locally without errors
- [ ] Docker image builds successfully
- [ ] Terraform validation passes
- [ ] AWS credentials configured
- [ ] Small-scale test deployment succeeded
- [ ] Integration tests all passed
- [ ] Database backup strategy in place
- [ ] Monitoring/alerting configured
- [ ] SSL certificate ready (if using HTTPS)
- [ ] Domain name configured (if using custom domain)
- [ ] Disaster recovery plan documented
- [ ] Team notified of deployment
- [ ] Deployment window scheduled

### 7.3 Production Deployment

```bash
cd terraform

# Create production configuration
cp terraform.tfvars.example terraform.tfvars
# Edit with PRODUCTION values

# Create production plan
terraform plan -out=tfprod.plan

# Review carefully!
terraform show tfprod.plan

# Deploy
terraform apply tfprod.plan

# Monitor
terraform output
aws logs tail /ecs/apollo --follow
```

## Troubleshooting Test Deployments

### "ECS task stuck in PENDING"

```bash
# Check task status
aws ecs describe-tasks \
  --cluster apollo-test-cluster \
  --tasks $(aws ecs list-tasks --cluster apollo-test-cluster --query 'taskArns[0]' --output text) \
  --query 'tasks[0].{lastStatus: lastStatus, stoppedReason: stoppedReason}'

# Common reasons:
# - Insufficient CPU/memory
# - Security group blocking traffic
# - ECR image not accessible
```

### "Cannot connect to database"

```bash
# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=apollo-test-rds-sg"

# Verify RDS cluster is running
aws rds describe-db-clusters \
  --db-cluster-identifier apollo-test-aurora-cluster \
  --query 'DBClusters[0].{Status: Status, Endpoint: Endpoint}'
```

### "ALB returns 502 Bad Gateway"

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --load-balancer-arn $(terraform output -raw alb_arn) \
    --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --query 'TargetHealthDescriptions'
```

### "Terraform plan shows unexpected changes"

```bash
# Check current state
terraform state list

# Inspect specific resource
terraform state show aws_db_instance.postgres

# Sometimes you need to refresh state
terraform refresh
```

## Manual Cleanup (if Destroy Fails)

```bash
# Delete stack via AWS CloudFormation (if applicable)
aws cloudformation delete-stack --stack-name apollo-test

# Manual resource deletion
aws ecs delete-cluster --cluster apollo-test-cluster --force
aws rds delete-db-cluster \
  --db-cluster-identifier apollo-test-aurora-cluster \
  --skip-final-snapshot

aws ec2 delete-default-subnet --availability-zone eu-west-2a \
  2>/dev/null || true

# Delete ALB
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names apollo-test-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null)
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN 2>/dev/null || true

# Delete VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=apollo-test-vpc" \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ ! -z "$VPC_ID" ]; then
  aws ec2 delete-vpc --vpc-id $VPC_ID
fi
```

## Quick Testing Checklist

- [ ] **Local validation** (5 min): `bin/rails server` works
- [ ] **Docker build** (5 min): `docker build -t apollo:test .` succeeds
- [ ] **Terraform validate** (2 min): `terraform validate` passes
- [ ] **AWS credentials** (2 min): `aws sts get-caller-identity` works
- [ ] **Test plan** (5 min): `terraform plan` shows expected resources
- [ ] **Test deploy** (15 min): `terraform apply` succeeds
- [ ] **Integration tests** (10 min): Health checks and services work
- [ ] **Cleanup** (5 min): `terraform destroy` completes successfully

**Total time: ~45-60 minutes to verify everything works before production!**

## Cost of Testing

- Test deployment: ~$5-10 for 30 minutes
- ALB: $2-3 per hour
- ECS tasks: $1-2 per hour
- Aurora: $2-3 per hour
- **Total test cost: ~$5-15**

(Much cheaper than debugging in production!)
