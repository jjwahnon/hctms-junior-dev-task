# Cost Optimization Guide - Zero-Cost Idle Deployment

This guide explains how to configure your Apollo Rails app on AWS to cost **literally nothing when idle** and scale up only when users access it.

## Quick Comparison

| Configuration | Idle Cost | Active Cost | Best For |
|---------------|-----------|------------|----------|
| **Pay-Per-Use** (Recommended) | $0-5/mo | $10-50/mo | Staging, testing, low-traffic apps |
| **Business Hours** (Scheduled) | $16/mo | $50-80/mo | Business apps, 9-5 usage |
| **Always-On** (Default) | $70-80/mo | $80-100/mo | Production, high-traffic |
| **API Gateway + Lambda** | $1-3/mo | $10-30/mo | Low-traffic, background jobs |

## Configuration 1: Zero-Cost Idle (Recommended)

Use this for staging, testing, or low-traffic production apps.

### terraform.tfvars
```hcl
# *** Cost Optimization Settings ***
min_count              = 0              # Scale down to ZERO tasks when idle
database_type          = "aurora-serverless"  # Pay-per-use database
aurora_min_capacity    = 0.5            # Aurora auto-pauses after 5 min idle
use_fargate_spot       = true           # 70% cheaper Spot instances
enable_scheduled_scaling = false        # Disabled (always available)

# Regular settings
desired_count          = 1              # Run 1 task (when active)
container_cpu          = 256
container_memory       = 512
```

### How It Works

```
User makes request
        ↓
ALB receives request (always listening)
        ↓
0 ECS tasks present (auto-scaling triggers)
        ↓
ECS launches new task (~30-60 seconds)
        ↓
Application handles request
        ↓
5+ minutes idle
        ↓
ECS scales down to 0 tasks
        ↓
$0 cost until next request
```

### Cost Breakdown (Idle)

- ALB: **$16/month** (always running, can't be turned off)
- ECS Tasks: **$0** (0 tasks running)
- Aurora Serverless: **$1-5/month** (auto-pauses)
- S3/Logs: **$1/month**
- **Total Idle: ~$18-22/month**

### Cost Breakdown (With Usage ~20/day requests)

- ALB: **$16/month**
- ECS Tasks: **~$15/month** (1 task, ~4 hours/day usage)
- Aurora Serverless: **~$10/month** (0.5-1 ACU average)
- Data transfer: **~$1/month**
- **Total Active: ~$42/month**

### Pros & Cons

✅ **Pros**
- True pay-for-what-you-use
- Great for testing/staging
- Scales automatically with traffic
- Aurora auto-pauses after 5 minutes

❌ **Cons**
- ~30-60 second cold start for first request
- ALB costs $16/month even when idle
- Not suitable for real-time apps
- Spot instances can be interrupted (but re-launched automatically)

### When to Use
- Staging environments
- Development testing
- Low-traffic production apps
- Background jobs that run occasionally
- Demos and prototypes

---

## Configuration 2: Business Hours Only

Scale down after work hours to save money during predictable idle times.

### terraform.tfvars
```hcl
# *** Business Hours Optimization ***
min_count                = 0
database_type            = "aurora-serverless"
use_fargate_spot         = true
enable_scheduled_scaling = true         # ENABLED

business_hours_start     = 8            # 8 AM UTC
business_hours_end       = 18           # 6 PM UTC
business_days            = [0,1,2,3,4]  # Monday-Friday

desired_count            = 1
```

### CloudWatch Log Configuration

Set up Lambda to auto-scale based on schedule:

```bash
# Scale down at 6 PM weekdays
aws events put-rule \
  --name "apollo-scale-down" \
  --schedule-expression "cron(0 18 ? * MON-FRI *)"

# Scale up at 8 AM weekdays  
aws events put-rule \
  --name "apollo-scale-up" \
  --schedule-expression "cron(0 8 ? * MON-FRI *)"
```

### Cost Breakdown

**Idle (nights + weekends): ~$16-20/month**
- ALB: $16
- Aurora paused: $1-4
- 0 ECS tasks: $0

**Business hours: ~$60/month**
- ALB: $16
- ECS tasks: $30
- Aurora: $14
- Total

**Monthly: ~$35-40/month** (vs $70 with always-on)

### When to Use
- Business apps (9-5 schedules)
- Internal tools
- SaaS apps with known usage patterns
- Dev/staging that's only used during work

---

## Configuration 3: Always-On (Default - Highest Cost)

For production apps that need instant response.

### terraform.tfvars
```hcl
min_count              = 2              # Always 2+ tasks running
database_type          = "postgres"     # Traditional RDS
use_fargate_spot       = false          # Reliable regular Fargate
enable_scheduled_scaling = false        # No scaling

desired_count          = 2
container_cpu          = 256
```

### Cost: ~$70-80/month steady

### When to Use
- Mission-critical production
- High-traffic apps
- Real-time requirements
- Must avoid cold starts

---

## AWS Service Details

### ALB (Application Load Balancer)

**Cost:** ~$16/month (fixed) + $0.006 per LCU (variable)

**Can't be reduced:** ALB must stay running to accept traffic

**Alternatives to save $16/month:**
- API Gateway (pay-per-request): ~$3.50 per million requests
- Classic Load Balancer: $9/month (older, limited features)

### ECS Fargate (Compute)

**Cost:** $0.04048 per vCPU-hour + $0.004445 per GB-hour

**How to optimize:**
- Set `min_count = 0` (scale to zero when idle)
- Use Spot instances: 70% discount
- Right-size: 256 CPU, 512 MB RAM is good start

**Examples:**
- 0.25 vCPU × 512 MB, 1 hour = $0.003
- 1 day usage (4 hours) = $0.012
- 30 days × 4 hours = $0.36/month

### Aurora Serverless v2 (Database)

**Cost:** $1.02 per ACU-hour + $0.25 per million writes

**How to optimize:**
- Auto-scales from 0.5 to 4+ ACUs
- Auto-pauses after 5 minutes idle
- Pay only for what you use

**Examples:**
- Min capacity 0.5 ACU idle: $1.02 × 730 hours = ~$6/month
- Active 1 ACU × 4 hours/day × 30 days = ~$120 ACU-hours = $12/month
- Writes 100k/day = ~$0.75/month

### S3 Storage

**Cost:** $0.023 per GB/month (US regions)

**Included in cost estimate:** ~$1/month for logs/assets

---

## Database Choice Impact

### Aurora Serverless v2 (RECOMMENDED for pay-per-use)

```hcl
database_type = "aurora-serverless"
aurora_min_capacity = 0.5
aurora_max_capacity = 2
```

**Cost Pattern:**
- Idle: ~$5/month
- Light usage (10-50 req/day): ~$8-12/month
- Medium usage (100-500 req/day): ~$15-25/month
- Heavy usage (1000+ req/day): ~$30-50/month

**Advantages:**
- Auto-scales up and down
- Survives cold starts
- Pay per second of use
- Perfect for variable workloads

**Disadvantages:**
- Slightly higher per-unit costs
- Can briefly exceed max capacity charges
- Limited parameter groups

### Traditional RDS (Fixed Cost)

```hcl
database_type = "postgres"
database_instance_class = "db.t3.micro"
```

**Cost:** ~$25/month (always)

**Advantages:**
- Predictable costs
- No cold starts
- Full control over parameters

**Disadvantages:**
- Pays same whether idle or active
- Hard to scale up/down
- Wasted money during idle periods

---

## Step-by-Step: Configure Zero-Cost Idle

### 1. Edit terraform.tfvars

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit with these settings:

```hcl
environment = "production"

# Cost Optimization - ZERO COST IDLE
min_count              = 0              # THIS IS KEY!
database_type          = "aurora-serverless"
aurora_min_capacity    = 0.5
use_fargate_spot       = true

# Application
desired_count          = 1
container_cpu          = 256
container_memory       = 512
```

### 2. Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Set up health checks

Ensure your Rails app responds quickly to /up endpoint:

```bash
# Quick health check
curl http://load-balancer-dns/up
```

### 4. Build and push image

```bash
docker build -t <ECR_URL>:latest .
docker push <ECR_URL>:latest
```

### 5. Monitor costs

```bash
# Use AWS Cost Explorer to track:
# - ECS Fargate costs (should spike only during usage)
# - Aurora RDS costs (should be minimal at idle)
# - ALB costs (steady at $16)
```

---

## Cost Calculator

Calculate your expected costs:

```
Monthly Cost = (ALB Cost) + (ECS Cost) + (Aurora Cost) + (S3 Cost)

ALB Cost = $0.50/day × 30 = $15

ECS Cost (with min_count=0):
  - Idle (0 hours): $0
  - Light use (4 hrs/day × 30 = 120 hrs/month × $0.003) = $0.36
  - Medium use (8 hrs/day × 30 = 240 hrs/month × $0.003) = $0.72
  - Heavy use (24 hrs/day × 30 = 720 hrs/month × $0.005) = $3.60

Aurora Cost:
  - Minimum (0.5 ACU idle): $10/month
  - With usage: +$0.05-100 depending on queries

Total Idle = $15 + $0 + $10 + $1 = ~$26/month
Total Light = $15 + $0.36 + $15 + $1 = ~$31/month
Total Medium = $15 + $0.72 + $20 + $1 = ~$37/month
Total Active = $15 + $4 + $30 + $1 = ~$50/month
```

---

## Advanced: Multi-Environment Setup

Use different configurations for different environments:

```
terraform/
├── prod/terraform.tfvars          # Always-on, min_count=2
├── staging/terraform.tfvars       # Zero-cost idle, min_count=0
└── dev/terraform.tfvars           # Business hours only
```

Deploy with:

```bash
terraform apply -var-file=staging/terraform.tfvars
```

---

## Troubleshooting High Bills

### 1. ECS costs unexpectedly high

```bash
# Check if tasks are running when they shouldn't be
aws ecs list-tasks --cluster apollo-cluster

# Check if desired_count was changed
aws ecs describe-services \
  --cluster apollo-cluster \
  --services apollo-service
```

### 2. Aurora costs high

```bash
# Check auto-scaling settings
aws rds describe-db-clusters --db-cluster-identifier apollo-aurora-cluster

# View query performance
# AWS Console → RDS → Performance Insights
```

### 3. Long cold starts

Cold starts typically take 30-60 seconds:
- ALB waits for ECS task to launch
- Docker pulls image (cached after first pull)
- Rails boots up

**Solutions:**
- Keep 1 minimum task running (costs more)
- Use scheduled pre-warming
- Use container warm-starting (Lambda SnapStart equivalent)

---

## FAQ

**Q: How do I make it truly $0 when unused?**
A: Currently ALB costs $16/month minimum. To get below $16/month:
- Use API Gateway + Lambda instead (true serverless)
- This requires rewriting for Lambda constraints
- Cost: ~$1-3/month at low usage

**Q: What about data transfer costs?**
A: Included in estimates. Usually $1-5/month for typical usage.

**Q: Can I pause the database separately?**
A: Aurora Serverless auto-pauses after 5 minutes idle. Traditional RDS cannot pause.

**Q: How do I handle spikes in traffic?**
A: Auto-scaling handles it:
- ECS: Launches 2-4 tasks as needed
- Aurora: Auto-scales capacity
- ALB: Handles distribution
- Max capacity is limited to prevent runaway costs

**Q: What if a task gets interrupted (Spot)?**
A: Auto-scaling replaces it within seconds. Your min_count setting ensures availability.

---

## Next Steps

1. **For Zero-Cost Idle**: Use Configuration 1 above
2. **For Business Hours**: Use Configuration 2 with scheduled scaling
3. **Track Costs**: Set up CloudWatch alarms for budget
4. **Optimize Over Time**: Monitor usage and adjust kapacity settings

See QUICK_START.md for deployment steps with these optimizations.
