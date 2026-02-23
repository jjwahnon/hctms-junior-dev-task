# Quick Testing Reference

Fast command reference for testing before deployment.

## 1-Minute Quick Test

```bash
# Validate everything locally
cd terraform
terraform validate

# Check AWS credentials
aws sts get-caller-identity

# Create plan (no deployment)
terraform plan -out=test.plan
terraform show test.plan

# Clean up
rm test.plan
```

## 5-Minute Test

```bash
# From root directory
cd terraform

# Initialize
terraform init

# Format check
terraform fmt -recursive .

# Validate
terraform validate

# Plan
terraform plan -out=test.plan

# Review
terraform show test.plan | head -50

# Cleanup
rm test.plan
cd ..
```

## 15-Minute Full Test

### Local Rails Test
```bash
# Test Rails starts
bundle install
bin/rails db:setup
timeout 10 bin/rails server > /tmp/rails.log 2>&1 &
sleep 3
curl http://localhost:3000/up
pkill -f "rails server" || true
```

### Docker Test
```bash
# Build image
docker build -t apollo:test .

# Test it runs
docker run --rm -it apollo:test rails --version

# Check image
docker images apollo:test
```

### Terraform Test
```bash
cd terraform
terraform init
terraform validate
terraform fmt -check -recursive .
terraform plan -var-file=terraform.tfvars.example -out=test.plan
rm test.plan
cd ..
```

## 30-Minute Test Deployment

**WARNING: This WILL create AWS resources and cost money!**

```bash
# 1. Create test configuration
cd terraform
cat > terraform.test.tfvars << 'EOF'
aws_region           = "eu-west-2"
environment          = "test"
app_name             = "apollo-test"
database_password    = "TestPass123!"
rails_master_key     = "test-key-66f27e8b76f5372f5e89f7e2f97b46c8"
desired_count        = 1
min_count            = 0
database_type        = "aurora-serverless"
EOF

# 2. Plan deployment
terraform plan -var-file=terraform.test.tfvars -out=test.plan

# 3. Deploy
terraform apply test.plan
# Wait 10-15 minutes for resources to deploy

# 4. Test deployment
ALB=$(terraform output -raw load_balancer_dns)
curl http://$ALB/up

# 5. Check services
aws ecs list-tasks --cluster apollo-test-cluster
aws logs tail /ecs/apollo-test --follow --since 5m

# 6. Destroy (IMPORTANT - save costs!)
terraform destroy -var-file=terraform.test.tfvars -auto-approve
rm terraform.test.tfvars test.plan

cd ..
```

## Automated Testing Scripts

### Option 1: Quick Auto-Test (5 min)
```bash
cd terraform
bash test-all.sh
```

### Option 2: Full Verification (15 min)
```bash
bash terraform/verify-deployment.sh
```

### Option 3: Test Deploy + Verify (45 min)
```bash
bash terraform/verify-deployment.sh --test-deploy
```

## Testing by Component

### Rails Application
```bash
# Check it runs
bin/rails server &
sleep 2
curl http://localhost:3000/up
pkill -f "rails server"

# Run tests
bin/rails test

# Check database
bin/rails db:setup
bin/rails db:migrate
bin/rails db:seed
```

### Docker
```bash
# Build
docker build -t apollo:test .

# Run
docker run -it apollo:test bin/rails --version

# Test with database
docker network create test-net
docker run -d --name postgres --network test-net -e POSTGRES_PASSWORD=test postgres:16
docker run -it --network test-net apollo:test bundle exec rails --version
docker stop postgres
docker rm postgres
docker network rm test-net
```

### Terraform
```bash
cd terraform

# Validate
terraform init
terraform validate

# Format
terraform fmt -recursive .

# Plan
terraform plan

# Syntax
terraform console
# (type to check variables, exit with ctrl-d)
```

### AWS Access
```bash
# Check credentials
aws sts get-caller-identity

# Check services
aws ec2 describe-regions
aws rds describe-db-instances
aws ecs list-clusters
aws ecr describe-repositories
```

## Testing Specific Features

### Auto-Scaling
```bash
# Make sure min_count = 0 in terraform.tfvars

cd terraform
terraform apply

# Check initial state
aws ecs describe-services \
  --cluster apollo-cluster \
  --services apollo-service \
  --query 'services[0].runningCount'

# Generate load
for i in {1..20}; do
  curl -s http://$ALB/up &
done
wait

# Check if scaled up
aws ecs describe-services \
  --cluster apollo-cluster \
  --services apollo-service \
  --query 'services[0].runningCount'
```

### Database Connection
```bash
# Get connection string
terraform output database_connection_string

# Test connection (if you have psql)
psql $(terraform output -raw database_connection_string)
# or
SELECT 1; -- if connected
\q -- to exit
```

### Health Checks
```bash
ALB=$(terraform output -raw load_balancer_dns)

# Health endpoint
curl -v http://$ALB/up

# HomePage
curl http://$ALB/

# API endpoints
curl http://$ALB/tasks
```

## Troubleshooting Tests

### Terraform Plan Fails
```bash
# Check syntax
terraform validate

# Check variables
cat terraform.tfvars

# Initialize fresh
rm -rf .terraform
terraform init
terraform plan
```

### ECS Tasks Don't Start
```bash
# Check logs
aws logs tail /ecs/apollo --follow

# Check task status
aws ecs describe-tasks \
  --cluster apollo-cluster \
  --tasks $(aws ecs list-tasks --cluster apollo-cluster --query 'taskArns[0]' --output text)

# Check if image exists
aws ecr describe-images --repository-names apollo
```

### Database Won't Connect
```bash
# Check RDS is running
aws rds describe-db-clusters --db-cluster-identifier apollo-aurora-cluster

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Test connection from ECS task (run a command)
aws ecs execute-command \
  --cluster apollo-cluster \
  --task <task-id> \
  --container apollo \
  --interactive \
  --command "/bin/sh"
```

## Test Failures: Common Causes

| Error | Cause | Fix |
|-------|-------|-----|
| "AccessDenied" | AWS credentials issue | Run `aws configure` |
| "InvalidParameterValue" | Variable value wrong | Check terraform.tfvars |
| "ECS task stuck PENDING" | Security group blocking | Check security group rules |
| "Cannot connect to database" | RDS not ready | Wait longer or check RDS status |
| "Docker build fails" | Missing dependencies | Run `bundle install` first |
| "Health check fails (502)" | App not listening | Check ECS task logs |

## Cost of Testing

| Phase | Duration | Est. Cost |
|-------|----------|-----------|
| Local testing | N/A | $0 |
| Docker testing | N/A | $0 |
| Terraform validation | N/A | $0 |
| AWS credential check | <5 min | $0 |
| Test deployment | 30 min | $5-15 |
| Total for everything | ~1 hour | $5-15 |

*Much cheaper than debugging in production!*

## Testing Checklist

Before production deployment, verify:

- [ ] `terraform validate` passes
- [ ] `terraform plan` looks correct
- [ ] Docker image builds successfully
- [ ] AWS credentials work
- [ ] Local Rails app runs
- [ ] Test deployment succeeded (optional but recommended)
- [ ] Application health check responds
- [ ] Database connects
- [ ] Auto-scaling works
- [ ] Logs present in CloudWatch
- [ ] Monitoring configured
- [ ] Backup strategy documented
- [ ] Disaster recovery plan ready

---

## Next Steps

1. **Quick verify**: Run `terraform/test-all.sh`
2. **Detailed test**: Run `terraform/verify-deployment.sh`
3. **Test deploy**: Run `terraform/verify-deployment.sh --test-deploy`
4. **Production deploy**: See [QUICK_START.md](QUICK_START.md)
