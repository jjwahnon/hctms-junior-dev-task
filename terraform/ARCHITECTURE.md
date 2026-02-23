# AWS Deployment Architecture - Apollo Rails App

## Overview

This Terraform configuration deploys a production-ready Rails application to AWS using:
- **Container Orchestration**: ECS Fargate (serverless containers)
- **Load Balancing**: Application Load Balancer (ALB)
- **Database**: Managed RDS PostgreSQL
- **Storage**: S3 buckets with encryption
- **Networking**: VPC with public/private subnets across multiple AZs
- **Monitoring**: CloudWatch logs and alarms
- **Security**: Auto-scaling security groups, IAM roles, encryption

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │   Application       │
                    │   Load Balancer     │
                    │   (ALB)             │
                    └─────────────────────┘
                    (Security Group: HTTP/HTTPS)
                              ↓
        ┌─────────────────────────────────────────────────────┐
        │              VPC (10.0.0.0/16)                      │
        │                                                      │
        │ ┌──────────────────────────────────────────────────┐│
        │ │ Public Subnets (with NAT Gateways)              ││
        │ │ - 10.0.101.0/24 (AZ-a)                          ││
        │ │ - 10.0.102.0/24 (AZ-b)                          ││
        │ └──────────────────────────────────────────────────┘│
        │                      ↓                                │
        │ ┌──────────────────────────────────────────────────┐│
        │ │ Private Subnets (ECS Tasks)                      ││
        │ │ - 10.0.1.0/24 (AZ-a)                            ││
        │ │ - 10.0.2.0/24 (AZ-b)                            ││
        │ │                                                  ││
        │ │ ┌──────────────┐        ┌──────────────┐        ││
        │ │ │  ECS Task    │        │  ECS Task    │        ││
        │ │ │  (Fargate)   │        │  (Fargate)   │        ││
        │ │ │ Port: 3000   │        │ Port: 3000   │        ││
        │ │ └──────────────┘        └──────────────┘        ││
        │ │   (Security Group: ALB → 3000)                  ││
        │ └──────────────────────────────────────────────────┘│
        │                      ↓                                │
        │ ┌──────────────────────────────────────────────────┐│
        │ │ Private Subnets (RDS Database)                  ││
        │ │ - 10.0.3.0/24 (AZ-a)                            ││
        │ │ - 10.0.4.0/24 (AZ-b)                            ││
        │ │                                                  ││
        │ │ ┌──────────────────────────────────────────────┐││
        │ │ │  RDS PostgreSQL (Multi-AZ)                 │││
        │ │ │  - Automated backups (7 days)              │││
        │ │ │  - Encryption at rest                      │││
        │ │ │  - Port: 5432                              │││
        │ │ └──────────────────────────────────────────────┘││
        │ │  (Security Group: ECS → 5432)                  ││
        │ └──────────────────────────────────────────────────┘│
        │                                                      │
        └─────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │   S3 Buckets        │
                    │ - App Assets        │
                    │ - Logs/Backups      │
                    └─────────────────────┘
```

## Infrastructure Components

### 1. Networking (main.tf)
- **VPC**: 10.0.0.0/16 CIDR block
- **Public Subnets**: 2 subnets across 2 AZs for ALB
- **Private Subnets**: 2 subnets across 2 AZs for application
- **NAT Gateways**: One per AZ for egress from private subnets
- **Internet Gateway**: For public subnet internet access
- **Route Tables**: Separate routing for public/private subnets

### 2. Security (security_groups.tf)
- **ALB Security Group**: Allows HTTP(80) and HTTPS(443)
- **ECS Security Group**: Allows port 3000 from ALB only
- **RDS Security Group**: Allows port 5432 from ECS only
- **All outbound traffic allowed** for pulling dependencies

### 3. Database (rds.tf)
- **Engine**: PostgreSQL 16.1
- **Instance**: db.t3.micro (adjustable)
- **Storage**: 20GB GP3 EBS (auto-expandable)
- **Backup**: 7-day retention, daily backups
- **High Availability**: Multi-AZ deployment
- **Encryption**: At-rest encryption enabled
- **Monitoring**: CloudWatch logs and performance insights

### 4. Container Orchestration (ecs.tf)
- **Platform**: ECS Fargate (serverless)
- **Cluster**: Single cluster for Apollo
- **Task Definition**: Specifies container image, CPU, memory, env vars
- **Service**: Maintains 2 desired tasks by default
- **Load Balancing**: ALB integration with health checks
- **Auto-Scaling**: CPU and memory-based scaling policies
- **Logging**: CloudWatch Logs integration

### 5. Load Balancing (load_balancer.tf)
- **ALB**: Application Load Balancer for Layer 7 routing
- **Target Group**: Routes to ECS tasks on port 3000
- **Health Checks**: Every 30 seconds on /up endpoint
- **HTTPS Support**: Optional with ACM certificate
- **Auto-redirect**: HTTP to HTTPS (if enabled)

### 6. Storage (s3.tf)
- **Assets Bucket**: For application assets and files
- **Logs Bucket**: For access logs and compliance
- **Encryption**: AES256 at rest
- **Versioning**: Enabled for recovery
- **Lifecycle**: Old logs deleted after 90 days

### 7. IAM & Access (iam.tf)
- **Task Execution Role**: Allows ECS to pull images, push logs
- **Task Role**: Application permissions (S3 access, secrets access)
- **ECR Push Policy**: For CI/CD pipelines
- **Least Privilege**: Each role has minimal required permissions

## Security Features

✅ **Implemented**
- Encryption in transit (Load balancer negotiates HTTPS/TLS)
- Encryption at rest (RDS, S3, EBS)
- Network segmentation (Public/Private subnets)
- Multi-AZ deployment for disaster recovery
- Automated backups (RDS: 7-day retention)
- Security groups with least privilege
- IAM roles with scoped permissions
- VPC with no public database access
- Secrets management support
- Auto-scaling for resilience

⚠️ **Recommended Additions**
- AWS WAF for ALB (DDoS/attack prevention)
- VPC Flow Logs (network monitoring)
- GuardDuty (threat detection)
- CloudTrail (audit logging)
- Backup plan (AWS Backup service)
- VPN/Bastion host for operations access

## Monitoring & Logging

### CloudWatch
- **Log Group**: `/ecs/apollo`
- **Retention**: 30 days
- **Metric**: CPU, memory, network metrics per task
- **Alarms**: Can be configured for auto-scaling

### RDS
- **Performance Insights**: Database performance monitoring
- **CloudWatch Logs**: PostgreSQL logs export
- **Backup Logs**: Backup and restore monitoring
- **Events**: RDS events and notifications

### Scaling Policies
- **CPU**: Scale up when > 70%, down when < 50%
- **Memory**: Scale up when > 80%, down when < 60%
- **Min Tasks**: 2 (high availability)
- **Max Tasks**: 4 (cost control)

## Deployment Workflow

```
1. Create Terraform Configuration
   └─ terraform init, plan, apply

2. Build Docker Image
   └─ docker build, push to ECR

3. Deploy Infrastructure
   └─ ECS cluster, tasks, ALB created

4. Initialize Database
   └─ rails db:create, db:migrate

5. Access Application
   └─ http://load-balancer-dns
```

## File Structure

```
terraform/
├── provider.tf              # AWS provider configuration
├── variables.tf             # Input variables with defaults
├── outputs.tf              # Outputs (DNS, endpoints, etc.)
├── main.tf                 # VPC and networking
├── security_groups.tf      # All security group rules
├── rds.tf                  # PostgreSQL database
├── ecs.tf                  # Container orchestration
├── load_balancer.tf        # ALB and target groups
├── iam.tf                  # IAM roles and policies
├── s3.tf                   # S3 buckets
├── terraform.tfvars.example # Example configuration
├── DEPLOYMENT_GUIDE.md     # Comprehensive deployment docs
├── QUICK_START.md          # Quick reference
└── setup.rb                # Setup automation script
```

## Cost Considerations

### Default Configuration (~$70-80/month)
- **ECS Fargate**: $0.04048/CPU-hour + $0.004445/GB-hour
  - 2 tasks × 0.25 CPU = 0.5 CPU = ~$14/month
  - 2 tasks × 512 MB = 1 GB = ~$20/month
- **ALB**: ~$16/month (fixed) + $0.006/LCU
- **RDS**: ~$25/month (db.t3.micro Multi-AZ)
- **S3**: ~$1/month (minimal usage)
- **Data Transfer**: ~$5/month

### Cost Optimization
- Use **Fargate Spot** for non-critical workloads (60% discount)
- **Single-AZ** for non-production (saves ~$10/month)
- **Smaller RDS** (db.t3.micro) for development
- **Reserved Instances** for production commitments
- Stop resources during non-business hours (dev/test only)

## Disaster Recovery

### Backup Strategy
- **RDS**: Automated daily backups (7-day retention)
- **Application Code**: Version controlled in Git
- **Secrets**: AWS Secrets Manager or encrypted files

### Recovery Options
1. **Database Failure**: Restore from automated snapshot
2. **Partial Outage**: Auto-scaling brings up new tasks
3. **Full Region Failure**: Replicate to another region (manual setup)

### RTO/RPO Targets
- **RTO**: 15 minutes (Multi-AZ failover)
- **RPO**: 1 day (7-day backup retention)

## Maintenance Tasks

### Regular
- Monitor CloudWatch dashboards
- Review scaling events and logs
- Test database backups monthly
- Update container images with security patches

### Periodic
- Review security group rules
- Update Terraform code for new AWS features
- Resize instances based on usage
- Clean up old ECR images

### Annual
- Disaster recovery drill
- Security assessment
- Cost optimization review
- Architecture update

---
For step-by-step deployment: See [QUICK_START.md](QUICK_START.md) or [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
