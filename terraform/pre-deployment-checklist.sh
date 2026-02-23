#!/bin/bash
# Pre-deployment checklist script for Apollo Rails app

set -e

echo "🚀 Apollo AWS Deployment - Pre-Deployment Checklist"
echo "=" | awk '{for(i=1;i<=50;i++)printf "="; print ""}'
echo ""

FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

check_aws_configured() {
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        REGION=$(aws configure get region)
        echo -e "${GREEN}✓${NC} AWS configured (Account: $ACCOUNT_ID, Region: $REGION)"
        return 0
    else
        echo -e "${RED}✗${NC} AWS not configured or credentials expired"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

check_file_exists() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
        return 0
    else
        echo -e "${RED}✗${NC} $1 missing"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

check_terraform_syntax() {
    if terraform fmt -check -recursive . &> /dev/null; then
        echo -e "${GREEN}✓${NC} Terraform syntax valid"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Terraform formatting issues (run 'terraform fmt -recursive .')"
        return 1
    fi
}

echo "📋 Checking Prerequisites..."
echo ""
check_command "terraform"
check_command "aws"
check_command "docker"
check_command "git"
echo ""

echo "🔑 Checking AWS Configuration..."
echo ""
check_aws_configured
echo ""

echo "📂 Checking Required Files..."
echo ""
cd "$(dirname "$0")" || exit 1
check_file_exists "terraform.tfvars"
check_file_exists "variables.tf"
check_file_exists "../config/master.key"
echo ""

echo "🔍 Checking Configuration..."
echo ""

# Check if docker_image is set in tfvars
if grep -q "^docker_image.*=" terraform.tfvars; then
    echo -e "${GREEN}✓${NC} docker_image configured in terraform.tfvars"
else
    echo -e "${YELLOW}⚠${NC} docker_image not set (you'll need to push to ECR first)"
fi

# Check if database password is set
if grep -q "database_password" terraform.tfvars; then
    echo -e "${GREEN}✓${NC} database_password configured"
else
    echo -e "${RED}✗${NC} database_password not configured"
    FAILED=$((FAILED + 1))
fi

# Check if rails_master_key is set
if grep -q "rails_master_key" terraform.tfvars; then
    echo -e "${GREEN}✓${NC} rails_master_key configured"
else
    echo -e "${YELLOW}⚠${NC} rails_master_key not configured (check example file)"
fi
echo ""

echo "🏗️  Checking Terraform..."
echo ""
check_terraform_syntax
terraform init -backend=false > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} Terraform initialized" || echo -e "${YELLOW}⚠${NC} Terraform init check skipped"
echo ""

echo "📊 Summary..."
echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "You can now run:"
    echo "  terraform plan"
    echo "  terraform apply"
else
    echo -e "${RED}❌ $FAILED check(s) failed${NC}"
    echo ""
    echo "Please fix the issues above before deploying"
    exit 1
fi
