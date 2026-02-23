# Terraform Deployment for Apollo Rails App

Complete Terraform infrastructure-as-code configuration for deploying Apollo (Rails 8 application) to AWS with production-ready setup.

## 🚀 Quick Start

```bash
# 1. Copy and customize configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 3. Build and push Docker image
docker build -t <ECR_URL>:latest .
docker push <ECR_URL>:latest

# 4. Initialize database
# (See QUICK_START.md for detailed steps)
```

## 📚 Documentation

### 🎯 Start Here
- **[TESTING-START-HERE.md](TESTING-START-HERE.md)** - ⭐ **Choose your testing path** (5-45 minutes)

### Main Guides
- **[QUICK_START.md](QUICK_START.md)** - Get up and running in 5 minutes
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Comprehensive step-by-step guide

### Testing & Validation
- **[TESTING-QUICK-REFERENCE.md](TESTING-QUICK-REFERENCE.md)** - Quick testing commands reference
- **[TESTING-GUIDE.md](TESTING-GUIDE.md)** - Complete manual testing workflow

### Advanced Topics
- **[COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)** - Zero-cost idle setup
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Infrastructure design and components
- **[README-ENV.md](README-ENV.md)** - Environment-specific configurations

## 📦 What Gets Deployed

### Compute
- **ECS Fargate Cluster** - Serverless container orchestration
- **Application Load Balancer** - Distributes traffic across instances
- **Auto-Scaling** - Scales based on CPU and memory usage

### Database
- **RDS PostgreSQL** - Managed relational database
- **Multi-AZ Deployment** - High availability with automatic failover
- **Automated Backups** - 7-day retention with point-in-time recovery

### Networking
- **VPC** - Isolated network environment
- **Public Subnets** - For load balancer (2 AZs)
- **Private Subnets** - For application and database (2 AZs)
- **NAT Gateways** - Secure outbound internet access
- **Security Groups** - Fine-grained network access control

### Storage
- **S3 Buckets** - For application assets and logs
- **Encryption** - All data encrypted at rest
- **Versioning** - Automatic backup and recovery

### Security
- **IAM Roles** - Least-privilege access control
- **Secrets Manager** - Integration for sensitive data
- **Encryption** - TLS, AES256, encrypted volumes

### Monitoring
- **CloudWatch Logs** - Application and system logs
- **Performance Monitoring** - RDS insights and metrics
- **Auto-Scaling Metrics** - CPU and memory baselines

## 📋 Requirements

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI v2
- Docker
- Git

## 🔧 Configuration

Edit `terraform.tfvars` before deploying:

```hcl
# Required
aws_region           = "us-east-1"
environment          = "production"
database_password    = "your-secure-password"  # Generate this!
rails_master_key     = "from-config/master.key"

# Optional
docker_image         = ""  # Set after pushing to ECR
enable_https         = false
certificate_arn      = ""  # For HTTPS
domain_name          = ""  # Custom domain
```

## 🚀 Deployment Steps

1. **Prepare Configuration**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review Plan**
   ```bash
   terraform plan
   ```

4. **Apply Configuration**
   ```bash
   terraform apply
   ```

5. **Build and Push Docker Image**
   ```bash
   docker build -t <ECR_URL>:latest .
   docker push <ECR_URL>:latest
   ```

6. **Deploy Application**
   ```bash
   # Update docker_image in terraform.tfvars
   terraform apply
   ```

7. **Initialize Database**
   ```bash
   # Run migrations in ECS task
   aws ecs run-task --cluster apollo-cluster ...
   ```

## 📊 File Structure

```
terraform/
├── provider.tf                      # AWS provider configuration
├── variables.tf                     # Input variables and defaults
├── outputs.tf                       # Output values (DNS, endpoints)
├── main.tf                          # VPC and networking
├── security_groups.tf               # All security group rules
├── rds.tf                           # PostgreSQL database
├── ecs.tf                           # Container orchestration
├── load_balancer.tf                 # ALB and target groups
├── iam.tf                           # IAM roles and policies
├── s3.tf                            # S3 buckets
├── terraform.tfvars.example         # Example configuration
├── .gitignore                       # Git ignore patterns
├── QUICK_START.md                   # 5-minute quick start
├── DEPLOYMENT_GUIDE.md              # Complete deployment guide
├── ARCHITECTURE.md                  # Infrastructure design
├── README-ENV.md                    # Multi-environment setup
├── pre-deployment-checklist.sh      # Pre-deployment checks
└── README.md                        # This file
```

## 🔑 Key Outputs

After deployment, Terraform provides:
- `load_balancer_dns` - Application URL
- `rds_endpoint` - Database connection string
- `ecs_cluster_name` - ECS cluster identifier
- `ecr_repository_url` - Docker image repository
- `cloudwatch_log_group` - Logs location

Access these with:
```bash
terraform output load_balancer_dns
terraform output -json  # All outputs
```

## 🛡️ Security Features

✅ Implemented:
- Encryption in transit (HTTPS support)
- Encryption at rest (RDS, S3, EBS)
- Network segmentation (public/private subnets)
- Least-privilege IAM roles
- Multi-AZ deployment for fault tolerance
- Automated backups and disaster recovery
- Security groups with minimal rules
- VPC with no public database access

⚠️ Recommended:
- AWS WAF for DDoS protection
- VPC Flow Logs for network monitoring
- GuardDuty for threat detection
- CloudTrail for audit logging

## 💰 Cost Optimization (NEW!)

**Pay ONLY when you have traffic - literally $0 when idle!**

Available configurations:
- **Zero-Cost Idle**: $16-22/month idle → $40-60/month with usage ⭐ Recommended
- **Business Hours**: ~$40/month (shutdown after hours)
- **Always-On**: ~$70-80/month (constant cost)

See **[COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)** for complete guide.

## 🔄 Continuous Deployment

GitHub Actions workflow included (`.github/workflows/deploy.yml`):
- Build Docker image on push to main
- Push to ECR
- Deploy infrastructure with Terraform
- Run database migrations
- Automatic rollback on failures

Set up secrets in GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DATABASE_PASSWORD`
- `RAILS_MASTER_KEY`

## 🆘 Troubleshooting

### ECS tasks not starting
```bash
# Check logs
aws logs tail /ecs/apollo --follow
```

### Database connection failed
```bash
# Verify database is running
aws rds describe-db-instances --db-instance-identifier apollo-db
```

### ECR image not found
```bash
# List images in repository
aws ecr describe-images --repository-name apollo
```

### Terraform state issues
```bash
# View current state
terraform state list

# Inspect resource
terraform state show aws_db_instance.main
```

## 🧹 Cleanup

To destroy all resources:

```bash
# Backup database first
aws rds create-db-snapshot \
  --db-instance-identifier apollo-db \
  --db-snapshot-identifier apollo-backup-$(date +%s)

# Destroy infrastructure
terraform destroy
```

## 📖 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Rails on AWS Best Practices](https://guides.rubyonrails.org/getting_started_with_devcontainer.html)
- [ECS Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/what-is-amazon-ecs.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## 📝 License

This Terraform configuration is part of the Apollo Rails application project.

## 🤝 Support

For issues or questions:
1. Check the [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review [QUICK_START.md](QUICK_START.md) for common scenarios
3. Check AWS CloudWatch logs for application errors
4. Enable Terraform debug logging: `export TF_LOG=DEBUG`

---

**Next Steps**: Read [QUICK_START.md](QUICK_START.md) or [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) to begin deployment.
