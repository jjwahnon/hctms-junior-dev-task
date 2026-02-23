#!/bin/bash
# Automated pre-deployment testing script for Apollo Rails app
# Usage: ./test-all.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Functions
print_header() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
  ((PASSED++))
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
  ((FAILED++))
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
  ((SKIPPED++))
}

check_command() {
  if command -v "$1" &> /dev/null; then
    print_success "$1 found"
    return 0
  else
    print_error "$1 not found - install required"
    return 1
  fi
}

# ==================================================
# PHASE 1: LOCAL VALIDATION
# ==================================================
print_header "Phase 1: Local Validation"

# Check required commands
check_command "terraform" || exit 1
check_command "aws" || exit 1
check_command "docker" || exit 1
check_command "git" || exit 1

# Check Rails app exists
if [ -f "Gemfile" ]; then
  print_success "Rails Gemfile found"
else
  print_error "Gemfile not found - not in Rails root?"
  exit 1
fi

# Check master key exists
if [ -f "config/master.key" ]; then
  print_success "Rails master key found"
else
  print_error "config/master.key not found"
  exit 1
fi

# Check Terraform directory exists
if [ -d "terraform" ]; then
  print_success "Terraform directory found"
else
  print_error "terraform/ directory not found"
  exit 1
fi

# ==================================================
# PHASE 2: RAILS VALIDATION
# ==================================================
print_header "Phase 2: Rails Application Check"

# Check Gemfile.lock exists
if [ -f "Gemfile.lock" ]; then
  print_success "Gemfile.lock found"
else
  print_warning "Gemfile.lock not found (run: bundle install)"
fi

# Check basic Rails structure
[ -d "app" ] && print_success "app/ directory found" || print_error "app/ directory missing"
[ -d "config" ] && print_success "config/ directory found" || print_error "config/ directory missing"
[ -d "db" ] && print_success "db/ directory found" || print_error "db/ directory missing"

# ==================================================
# PHASE 3: DOCKER VALIDATION
# ==================================================
print_header "Phase 3: Docker Build Test"

if docker build -t apollo:test . > /tmp/docker_build.log 2>&1; then
  print_success "Docker image builds successfully"
  
  # Check image size
  SIZE=$(docker images apollo:test --format "{{.Size}}")
  print_success "Docker image created (size: $SIZE)"
else
  print_error "Docker build failed"
  echo "Error details:"
  tail -20 /tmp/docker_build.log
  exit 1
fi

# ==================================================
# PHASE 4: TERRAFORM VALIDATION
# ==================================================
print_header "Phase 4: Terraform Configuration"

cd terraform

# Init terraform (backend=false for local testing)
if terraform init -backend=false > /tmp/tf_init.log 2>&1; then
  print_success "Terraform initialized"
else
  print_error "Terraform init failed"
  tail -10 /tmp/tf_init.log
  exit 1
fi

# Validate terraform
if terraform validate > /tmp/tf_validate.log 2>&1; then
  print_success "Terraform configuration valid"
else
  print_error "Terraform validation failed"
  cat /tmp/tf_validate.log
  exit 1
fi

# Format check
if terraform fmt -check -recursive . > /tmp/tf_fmt.log 2>&1; then
  print_success "Terraform formatting correct"
else
  print_warning "Terraform formatting issues detected"
  echo "Run: terraform fmt -recursive ."
fi

# Check for required files
[ -f "provider.tf" ] && print_success "provider.tf found" || print_error "provider.tf missing"
[ -f "variables.tf" ] && print_success "variables.tf found" || print_error "variables.tf missing"
[ -f "main.tf" ] && print_success "main.tf found" || print_error "main.tf missing"
[ -f "rds.tf" ] && print_success "rds.tf found" || print_error "rds.tf missing"
[ -f "ecs.tf" ] && print_success "ecs.tf found" || print_error "ecs.tf missing"

# ==================================================
# PHASE 5: AWS CREDENTIALS
# ==================================================
print_header "Phase 5: AWS Credentials & Permissions"

if aws sts get-caller-identity > /tmp/aws_check.json 2>&1; then
  ACCOUNT=$(jq -r '.Account' /tmp/aws_check.json)
  ARN=$(jq -r '.Arn' /tmp/aws_check.json)
  print_success "AWS credentials configured (Account: $ACCOUNT)"
else
  print_error "AWS credentials not configured"
  echo "Run: aws configure"
  exit 1
fi

# Check AWS service access
if aws ec2 describe-regions > /dev/null 2>&1; then
  print_success "EC2 access verified"
else
  print_error "Cannot access EC2 - check IAM permissions"
fi

if aws rds describe-db-instances > /dev/null 2>&1; then
  print_success "RDS access verified"
else
  print_error "Cannot access RDS - check IAM permissions"
fi

if aws ecs list-clusters > /dev/null 2>&1; then
  print_success "ECS access verified"
else
  print_error "Cannot access ECS - check IAM permissions"
fi

if aws ecr describe-repositories > /dev/null 2>&1; then
  print_success "ECR access verified"
else
  print_error "Cannot access ECR - check IAM permissions"
fi

# ==================================================
# PHASE 6: TERRAFORM PLAN
# ==================================================
print_header "Phase 6: Terraform Plan (Dry Run)"

echo "Creating test plan (no resources deployed)..."

# Create a test tfvars file
cat > terraform.auto.tfvars.test << 'EOF'
aws_region              = "eu-west-2"
environment             = "test"
app_name                = "apollo-test"
database_password       = "TestPassword123!"
rails_master_key        = "test-key-66f27e8b76f5372f5e89f7e2f97b46c8"
desired_count           = 1
min_count               = 0
database_type           = "aurora-serverless"
container_cpu           = 256
container_memory        = 512
EOF

if terraform plan -var-file=terraform.auto.tfvars.test -out=tftest.plan > /tmp/tf_plan.log 2>&1; then
  print_success "Terraform plan successful"
  
  # Count resources
  RESOURCE_COUNT=$(grep -c "^  # " /tmp/tf_plan.log || echo "?")
  print_success "Plan includes resources for deployment"
else
  print_error "Terraform plan failed"
  tail -20 /tmp/tf_plan.log
  exit 1
fi

# ==================================================
# PHASE 7: CONFIGURATION CHECK
# ==================================================
print_header "Phase 7: Configuration Validation"

# Check terraform.tfvars exists
if [ -f "terraform.tfvars" ]; then
  print_success "terraform.tfvars exists"
  
  # Check for required variables
  if grep -q "database_password" terraform.tfvars; then
    print_success "database_password configured"
  else
    print_warning "database_password not set in terraform.tfvars"
  fi
  
  if grep -q "rails_master_key" terraform.tfvars; then
    print_success "rails_master_key configured"
  else
    print_warning "rails_master_key not set in terraform.tfvars"
  fi
else
  print_warning "terraform.tfvars not found (run: cp terraform.tfvars.example terraform.tfvars)"
fi

# Check example file
[ -f "terraform.tfvars.example" ] && print_success "terraform.tfvars.example found" || print_error "terraform.tfvars.example missing"

# ==================================================
# PHASE 8: DOCUMENTATION CHECK
# ==================================================
print_header "Phase 8: Documentation"

[ -f "README.md" ] && print_success "README.md found" || print_warning "README.md missing"
[ -f "QUICK_START.md" ] && print_success "QUICK_START.md found" || print_warning "QUICK_START.md missing"
[ -f "DEPLOYMENT_GUIDE.md" ] && print_success "DEPLOYMENT_GUIDE.md found" || print_warning "DEPLOYMENT_GUIDE.md missing"
[ -f "COST-OPTIMIZATION.md" ] && print_success "COST-OPTIMIZATION.md found" || print_warning "COST-OPTIMIZATION.md missing"
[ -f "TESTING-GUIDE.md" ] && print_success "TESTING-GUIDE.md found" || print_warning "TESTING-GUIDE.md missing"

# ==================================================
# SUMMARY
# ==================================================
print_header "Test Summary"

echo "Passed:  ${GREEN}$PASSED${NC}"
echo "Failed:  ${RED}$FAILED${NC}"
echo "Skipped: ${YELLOW}$SKIPPED${NC}"

# ==================================================
# CLEANUP
# ==================================================
echo -e "\n${BLUE}Cleanup:${NC}"

# Remove test files
if [ -f "terraform.auto.tfvars.test" ]; then
  rm terraform.auto.tfvars.test
  echo "Removed terraform.auto.tfvars.test"
fi

if [ -f "tftest.plan" ]; then
  rm tftest.plan
  echo "Removed tftest.plan"
fi

# ==================================================
# FINAL STATUS
# ==================================================
cd ..

if [ $FAILED -eq 0 ]; then
  echo -e "\n${GREEN}✓ All tests passed! Ready for deployment.${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Review QUICK_START.md for deployment instructions"
  echo "2. Configure production terraform.tfvars"
  echo "3. Run: cd terraform && terraform plan -out=tfprod.plan"
  echo "4. Run: terraform apply tfprod.plan"
  exit 0
else
  echo -e "\n${RED}✗ Some tests failed. Resolve issues before deploying.${NC}"
  exit 1
fi
