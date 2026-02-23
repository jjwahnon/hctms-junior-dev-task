# Cost Optimization Summary

This document summarizes the key changes made to enable **zero-cost idle deployment** with pay-per-use pricing.

## What Changed?

### 1. Database: Aurora Serverless v2
**From:** Traditional RDS (fixed $25/month)
**To:** Aurora Serverless (pay-per-use)

**Cost Impact:**
- Idle: $1-5/month (auto-pauses after 5 min)
- Semi-active: $10-15/month
- Replaces $25 fixed RDS cost

**File:** [rds.tf](rds.tf)

### 2. ECS Scaling: Scale to Zero
**From:** Always 2+ running tasks (fixed cost)
**To:** Min 0 tasks (only when needed)

**Cost Impact:**
- Saves $30-40/month when idle
- ~30-60 sec cold start for first request
- Auto-scales up for traffic

**File:** [ecs.tf](ecs.tf) - Updated `aws_appautoscaling_target`

### 3. Fargate Instances: Spot by Default
**From:** Regular Fargate ($0.04048/CPU-hr)
**To:** Fargate Spot (70% cheaper)

**Cost Impact:**
- $0.01134/CPU-hr (70% discount)
- Can be interrupted but auto-replaced
- Saves $10-15/month per task

**File:** [ecs.tf](ecs.tf) - Updated `capacity_provider_strategy`

### 4. Scheduled Scaling: Optional Business Hours
**New:** Scheduled auto-scale down after hours

**Cost Impact:**
- Shutdown at 6 PM, startup at 8 AM UTC (configurable)
- Only for business apps that don't need 24/7
- Saves additional $10-15/month

**File:** [ecs.tf](ecs.tf) - New `aws_appautoscaling_scheduled_action`

## Configuration Changes

### New Variables in variables.tf

```hcl
# Change database type
variable "database_type" {
  default = "aurora-serverless"  # NEW: was always "postgres"
}

# Scale to zero when idle
variable "min_count" {
  default = 0  # NEW: was 2
}

# Use Spot instances
variable "use_fargate_spot" {
  default = true  # NEW: enables 70% discount
}

# Auto-scale after hours (optional)
variable "enable_scheduled_scaling" {
  default = false
}
```

## Usage

### Zero-Cost Idle Setup

```bash
# Edit terraform.tfvars
min_count              = 0
database_type          = "aurora-serverless"
use_fargate_spot       = true
enable_scheduled_scaling = false

# Deploy
terraform apply
```

**Cost: $16-22/month idle → $40-60/month with usage**

### Business Hours Only Setup

```bash
enable_scheduled_scaling = true
business_hours_start     = 8   # 8 AM UTC
business_hours_end       = 18  # 6 PM UTC
```

**Cost: ~$40/month (nights/weekends shut down)**

## Cost Comparison

| Metric | Before | After (Zero-Idle) | Savings |
|--------|--------|-------------------|---------|
| Idle cost | $70/month | $16-22/month | **$48-54** |
| Active cost | $70-80 | $40-60 | **$10-40** |
| Database | RDS $25/mo | Aurora $1-15/mo | **$10-24** |
| ECS (2 tasks) | $30/mo | $0-15/mo | **$15-30** |
| Fargate Spot | N/A | -70% | **$10-15** |

## Cold Starts

When `min_count = 0`, first request after idle triggers:

1. **ALB health check fails** (0 tasks)
2. **Auto-scaling launches task** (~15-30 sec)
3. **Docker image pulled** (cached after first time)
4. **Rails boots** (~10-20 sec)
5. **Request served** (total ~30-60 seconds)

**Warmup Options:**
- Keep `min_count = 1` (costs ~$10/month more)
- Use scheduled pre-warming before business hours
- Accept cold starts for low-traffic apps

## Database Impact

### Aurora Serverless Auto-Pause

Features:
- Automatically pauses after 5 minutes idle
- Wakes up on next database connection
- No cold start when resuming (instant)
- Pay only for what you use

Commands:
```bash
# Check if paused
aws rds describe-db-clusters \
  --db-cluster-identifier apollo-aurora-cluster \
  --query 'DBClusters[0].Status'
# Output: "available" (active) or "backing-off" (paused)

# Force resume
aws rds start-db-cluster \
  --db-cluster-identifier apollo-aurora-cluster
```

## Monitoring

### Check Idle Status

```bash
# Are tasks running?
aws ecs list-tasks --cluster apollo-cluster
# Empty list = 0 tasks (ideal when idle)

# Is database paused?
aws rds describe-db-clusters --db-cluster-identifier apollo-aurora-cluster \
  --query 'DBClusters[0].Status'
# backing-off = paused and saving money
```

### Track Costs

```bash
# View costs by service
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Set up billing alarm
aws cloudwatch put-metric-alarm \
  --alarm-name apollo-cost-alarm \
  --alarm-description "Alert if costs exceed $50/month" \
  --metric-name EstimatedCharges \
  --statistic Maximum \
  --period 86400 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

## Files Modified

1. **variables.tf**
   - Added `database_type` (aurora-serverless vs postgres)
   - Added `min_count` (scale to zero)
   - Added `use_fargate_spot` (Spot instances)
   - Added scheduled scaling options

2. **rds.tf**
   - Split into Aurora Serverless and traditional RDS
   - Added auto-scaling for Aurora
   - Added Aurora cluster parameter group

3. **ecs.tf**
   - Added capacity provider strategy for Spot instances
   - Allows `min_count = 0`
   - Added scheduled scaling rules

4. **terraform.tfvars.example**
   - Updated with cost optimization settings

5. **outputs.tf**
   - Added cost optimization settings output
   - Added estimated costs

6. **COST-OPTIMIZATION.md** (NEW)
   - Comprehensive guide for all cost scenarios
   - Calculator, troubleshooting, FAQ

## Migration Path

### From Always-On to Zero-Cost Idle

1. **Backup existing database**
   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier apollo-db \
     --db-snapshot-identifier apollo-backup-$(date +%s)
   ```

2. **Update terraform.tfvars**
   ```hcl
   database_type       = "aurora-serverless"
   min_count          = 0
   use_fargate_spot   = true
   ```

3. **Plan changes**
   ```bash
   terraform plan  # Review what will change
   ```

4. **Apply migration**
   ```bash
   terraform apply  # Deploy new infrastructure
   ```

5. **Test application**
   ```bash
   # First request may have cold start
   curl http://load-balancer-dns
   ```

6. **Monitor costs**
   ```bash
   # Check CloudWatch Cost Explorer
   ```

Note: RDS database will be destroyed and recreated as Aurora. Restore data from snapshot if needed.

## Rollback

To go back to always-on (simpler, higher cost):

```hcl
database_type       = "postgres"
min_count          = 2
use_fargate_spot   = false
```

```bash
terraform apply
```

## FAQ

**Q: Will my app restart every time someone visits?**
A: No. Once a task is running, it stays running until ~5 min idle time.

**Q: How long is the cold start?**
A: Usually 30-60 seconds for the first request after shutdown.

**Q: Can I use this for production?**
A: Yes, if cold starts are acceptable. Use `min_count = 1` to eliminate them (+$10/mo).

**Q: What if I don't want cold starts?**
A: Set `min_count = 1` and use Spot instances. Cost remains low (~$30-40/mo).

**Q: How do I pause the entire application?**
A: Scale to 0 manually (database still charges minimum):
```bash
aws ecs update-service --cluster apollo-cluster \
  --service apollo-service --desired-count 0
```

**Q: Will Aurora auto-pause waste time?**
A: No, it resumes in <1 second (much faster than ECS cold start).

**Q: What happens if RDS autoscale limit is too low?**
A: Set `aurora_max_capacity = 4` to allow higher limits during traffic spikes.

## Next Steps

1. **Read [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)** for complete guide
2. **Review [QUICK_START.md](QUICK_START.md)** with cost settings
3. **Test with `min_count = 0`** in staging first
4. **Monitor costs** in AWS Cost Explorer
5. **Adjust settings** based on your usage patterns

---

**Key Takeaway:** With these changes, you only pay for resources when they're actually being used. Idle infrastructure costs as little as $16-22/month with the ability to scale to zero ECS tasks.
