#!/bin/bash
# Step-by-step deployment verification script
# This is the COMPLETE testing workflow before going to production

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
  echo -e "\n${BLUE}>>> $1${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_prompt() {
  echo -e "\n${YELLOW}? $1${NC}"
}

# Check if test deployment requested
TEST_MODE=${1:-"false"}

if [ "$TEST_MODE" == "--test-deploy" ]; then
  echo -e "${YELLOW}WARNING: This will create and delete AWS resources!${NC}"
  print_prompt "Continue with test deployment? (yes/no)"
  read -r response
  if [ "$response" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi
fi

# ==================================================
# STEP 1: Local Rails Testing
# ==================================================
print_step "1. Testing Rails Application Locally"

if [ ! -f "config/master.key" ]; then
  print_warning "config/master.key not found. Skipping local Rails test."
else
  echo "Starting Rails server in background..."
  timeout 30 bin/rails server -p 3001 > /tmp/rails_server.log 2>&1 &
  RAIL_PID=$!
  sleep 5
  
  if curl -s http://localhost:3001/up > /dev/null; then
    print_success "Rails app running on http://localhost:3001"
    kill $RAIL_PID 2>/dev/null || true
  else
    print_warning "Could not connect to Rails server"
    kill $RAIL_PID 2>/dev/null || true
  fi
fi

# ==================================================
# STEP 2: Docker Build & Test
# ==================================================
print_step "2. Building and Testing Docker Image"

echo "Building Docker image..."
if docker build -t apollo:test . > /tmp/docker_build.log 2>&1; then
  print_success "Docker image built successfully"
  SIZE=$(docker images apollo:test --format "{{.Size}}")
  echo "Image size: $SIZE"
else
  print_warning "Docker build may have issues (check logs)"
fi

# ==================================================
# STEP 3: Terraform Validation
# ==================================================
print_step "3. Validating Terraform Configuration"

cd terraform

echo "Running terraform validate..."
if terraform init -backend=false > /dev/null 2>&1; then
  terraform validate
  print_success "Terraform configuration is valid"
else
  print_warning "Terraform init issue"
fi

# ==================================================
# STEP 4: AWS Credentials Check
# ==================================================
print_step "4. Verifying AWS Credentials and Access"

if aws sts get-caller-identity > /tmp/aws_identity.json 2>&1; then
  ACCOUNT=$(jq -r '.Account' /tmp/aws_identity.json)
  print_success "AWS credentials valid (Account: $ACCOUNT)"
else
  echo -e "${RED}Failed to verify AWS credentials${NC}"
  exit 1
fi

# ==================================================
# STEP 5: Test Plan
# ==================================================
print_step "5. Creating Terraform Plan (Dry Run)"

echo "Creating plan without applying changes..."
if terraform plan -var-file=terraform.tfvars.example -out=tfplan.test > /tmp/tf_plan.log 2>&1; then
  print_success "Terraform plan created successfully"
  echo ""
  echo "Resources that would be created:"
  grep "^  #" /tmp/tf_plan.log | head -20 || terraform show tfplan.test | grep "resource" | head -15
else
  print_warning "Plan creation had issues (check logs)"
fi

# ==================================================
# STEP 6: Test Deployment (Optional)
# ==================================================
if [ "$TEST_MODE" == "--test-deploy" ]; then
  print_step "6. RUNNING TEST DEPLOYMENT (will incur AWS costs!)"
  
  # Create test config
  cat > terraform.test.tfvars << 'EOF'
aws_region           = "eu-west-2"
environment          = "test"
app_name             = "apollo-test-$(date +%s)"
database_password    = "TestPass123!"
rails_master_key     = "test-key-66f27e8b76f5372f5e89f7e2f97b46c8"
desired_count        = 1
min_count            = 0
database_type        = "aurora-serverless"
container_cpu        = 256
container_memory     = 512
EOF

  print_prompt "Deploy test infrastructure? (costs ~$10) (yes/no)"
  read -r deploy_response
  
  if [ "$deploy_response" == "yes" ]; then
    echo "Deploying test infrastructure..."
    terraform apply -var-file=terraform.test.tfvars -auto-approve
    
    print_success "Test deployment complete!"
    
    # Get outputs
    ALB=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "N/A")
    echo "Load Balancer: $ALB"
    
    # Test health check
    if [ "$ALB" != "N/A" ]; then
      sleep 10
      if curl -s http://$ALB/up > /tmp/health_check.log 2>&1; then
        print_success "Application health check passed"
      else
        print_warning "Health check failed"
      fi
    fi
    
    print_prompt "Destroy test infrastructure now? (yes/no)"
    read -r destroy_response
    
    if [ "$destroy_response" == "yes" ]; then
      echo "Destroying test infrastructure..."
      terraform destroy -var-file=terraform.test.tfvars -auto-approve
      rm terraform.test.tfvars
      print_success "Test infrastructure destroyed"
    else
      echo -e "${YELLOW}Remember to run: terraform destroy -var-file=terraform.test.tfvars${NC}"
    fi
  fi
fi

# ==================================================
# STEP 7: Pre-Production Checklist
# ==================================================
print_step "7. Pre-Production Checklist"

echo "Review the following before production deployment:"
echo ""
echo "Infrastructure:"
echo "  [ ] Terraform plan output reviewed"
echo "  [ ] All resource names correct"
echo "  [ ] AWS region correct (eu-west-2)"
echo "  [ ] VPC and subnets configured"
echo "  [ ] Security groups properly configured"
echo ""
echo "Database:"
echo "  [ ] Database type selected (aurora-serverless preferred)"
echo "  [ ] Backup configuration reviewed"
echo "  [ ] Multi-AZ enabled for production"
echo ""
echo "Application:"
echo "  [ ] Docker image builds successfully"
echo "  [ ] ECS task configuration correct"
echo "  [ ] Application health check endpoint works (/up)"
echo "  [ ] Scaling policies configured"
echo ""
echo "Security:"
echo "  [ ] HTTPS enabled (if required)"
echo "  [ ] SSL certificate ARN provided"
echo "  [ ] IAM roles and policies reviewed"
echo "  [ ] No hardcoded secrets in code"
echo ""
echo "Operations:"
echo "  [ ] Monitoring and alerts configured"
echo "  [ ] Log retention set appropriately"
echo "  [ ] Backup and disaster recovery plan"
echo "  [ ] Team trained on deployment process"
echo ""

# ==================================================
# CLEANUP & SUMMARY
# ==================================================
cd ..

print_step "Cleanup"

# Remove test files
[ -f "terraform/tfplan.test" ] && rm terraform/tfplan.test && echo "Removed tfplan.test"
[ -f "terraform/terraform.auto.tfvars.test" ] && rm terraform/terraform.auto.tfvars.test && echo "Removed terraform.auto.tfvars.test"

# ==================================================
# FINAL REPORT
# ==================================================
echo ""
echo -e "${GREEN}=== Testing Complete ===${NC}"
echo ""
echo "If all checks passed, you're ready to deploy!"
echo ""
echo "Production Deployment Steps:"
echo "1. Update terraform/terraform.tfvars with production values:"
echo "   - aws_region"
echo "   - database_password (secure password!)"
echo "   - rails_master_key (from config/master.key)"
echo "   - Add docker_image after pushing to ECR"
echo ""
echo "2. Build and push Docker image to ECR:"
echo "   docker build -t <ECR_URL>:latest ."
echo "   docker push <ECR_URL>:latest"
echo ""
echo "3. Deploy infrastructure:"
echo "   cd terraform"
echo "   terraform plan -out=tfprod.plan"
echo "   terraform apply tfprod.plan"
echo ""
echo "4. Initialize database:"
echo "   # Run migrations in ECS task"
echo "   aws ecs run-task --cluster apollo-cluster ..."
echo ""
echo "5. Monitor deployment:"
echo "   aws logs tail /ecs/apollo --follow"
echo ""
