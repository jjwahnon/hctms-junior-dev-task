# Testing Overview & Getting Started

Quick guide to understand testing options and choose the right one for your needs.

## 📋 What Testing Resources Are Available?

| Document | Time | What It Does | When to Use |
|----------|------|--------------|-----------|
| [TESTING-QUICK-REFERENCE.md](TESTING-QUICK-REFERENCE.md) | 1-5 min | Command reference | Quick syntax checks |
| [test-all.sh](test-all.sh) | 5 min | Automated validation | Verify everything works locally |
| [verify-deployment.sh](verify-deployment.sh) | 15 min | Full verification + optional test deploy | Before production |
| [TESTING-GUIDE.md](TESTING-GUIDE.md) | Follow along | Step-by-step manual testing | Learn what's happening |

## 🚀 Choose Your Testing Path

### Path 1: I Want to Test Locally (5 minutes) ⚡

**Best for:** First-time users, quick validation

```bash
cd terraform
bash test-all.sh
```

**What it checks:**
- ✓ Ruby/Rails installed and working
- ✓ Docker can build image
- ✓ Terraform syntax is valid
- ✓ AWS credentials configured
- ✓ Terraform plan looks correct

**Cost:** $0

---

### Path 2: I Want Complete Verification (15 minutes) 📋

**Best for:** Before production deployment

```bash
bash terraform/verify-deployment.sh
```

**What it checks:**
- ✓ Everything from Path 1
- ✓ Local Rails server runs
- ✓ Docker container starts
- ✓ Terraform plan details reviewed
- ✓ Pre-production checklist

**Cost:** $0

---

### Path 3: I Want to Test in AWS (45 minutes) 🔥

**Best for:** Verify everything works in the cloud before production**

```bash
bash terraform/verify-deployment.sh --test-deploy
```

**What it does:**
- ✓ Everything from Paths 1-2
- ✓ Creates test infrastructure on AWS (~15 min)
- ✓ Tests app responds correctly
- ✓ Destroys test infrastructure (~5 min)

**Cost:** $5-15

---

### Path 4: I Want Manual Control (30+ minutes) 🎮

**Best for:** Understanding every step, learning Terraform**

See [TESTING-GUIDE.md](TESTING-GUIDE.md) for complete manual workflow.

---

## 📊 Decision Matrix

| Scenario | Recommended Path |
|----------|-----------------|
| First time developer | Path 1 (5 min local test) |
| Staging deployment | Path 2 (15 min verification) |
| Production deployment | Path 3 (45 min with AWS test) |
| Learning Terraform | Path 4 (manual, step by step) |
| Quick syntax check | Quick Reference (2 min) |

---

## 🎯 Recommended Pre-Deployment Workflow

1. **Make changes to code/Terraform** ✏️
2. **Run automated test** (5 min) - `bash test-all.sh`
3. **Review plan** (5 min) - `terraform plan`
4. **Deploy** - `terraform apply`

---

## 🐛 Quick Troubleshooting

**Problem: "terraform validate fails"**
```bash
# Check syntax
cd terraform
terraform fmt -recursive .
terraform validate
```

**Problem: "Docker build fails"**
```bash
# Ensure dependencies installed
bundle install

# Check Dockerfile
docker build -t apollo:test .
```

**Problem: "AWS credentials not working"**
```bash
# Reconfigure AWS
aws configure

# Verify credentials
aws sts get-caller-identity
```

**Problem: "ECS tasks won't start"**  
See [TESTING-GUIDE.md](TESTING-GUIDE.md#troubleshooting-ecs-task-stuck-in-pending) for debugging

---

## ⏱️ Typical Testing Timeline

```
Scenario: Full deployment with all tests

Preparation (before start):
├─ Review documentation      5 min
├─ Install tools             10 min
└─ Configure AWS credentials 5 min

Testing Phase 1: Local validation
├─ Run test-all.sh          5 min
├─ Review output            5 min
└─ Fix any issues           10 min (if needed)

Testing Phase 2: Build & validate
├─ Docker build             10 min
├─ Terraform plan           5 min
└─ Review plan              10 min

Testing Phase 3: Test deployment (OPTIONAL)
├─ Deploy to AWS            20 min
├─ Run integration tests    5 min
└─ Cleanup                  10 min

Production Deployment:
├─ Final plan review        10 min
├─ Deploy                   15 min
└─ Monitor deployment       10 min

TOTAL WITH ALL TESTS: ~2 hours
TOTAL WITHOUT TEST DEPLOY: ~1 hour
TOTAL QUICK ONLY: ~30 minutes
```

---

## 📚 Additional Testing Resources

### For Developers
- [TESTING-QUICK-REFERENCE.md](TESTING-QUICK-REFERENCE.md) - Commands reference
- [TESTING-GUIDE.md](TESTING-GUIDE.md) - Step-by-step guide
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#troubleshooting) - Troubleshooting section

### For DevOps/SRE
- [ARCHITECTURE.md](ARCHITECTURE.md) - Infrastructure design
- [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) - Cost analysis
- [ZERO-COST-IDLE-CHANGES.md](ZERO-COST-IDLE-CHANGES.md) - Configuration details

### For Managers/Decision Makers
- [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md) - Pricing details
- [QUICK_START.md](QUICK_START.md) - Summary overview
- [README.md](README.md) - Project overview

---

## ✅ Final Checklist Before Going Live

- [ ] Local validation passed (`test-all.sh` complete)
- [ ] Docker image builds successfully
- [ ] Terraform plan reviewed and approved
- [ ] AWS credentials verified
- [ ] terraform.tfvars configured with production values
- [ ] Database password is strong and secure
- [ ] rails_master_key from config/master.key
- [ ] Docker image pushed to ECR
- [ ] Test deployment successful (recommended)
- [ ] Health check endpoint responds
- [ ] Monitoring configured
- [ ] Backup strategy documented
- [ ] Team notified of deployment

---

## 🎓 Next Steps

1. **Choose your path** from above
2. **Run the tests** for your chosen path
3. **Fix any issues** (see troubleshooting)
4. **Review** [QUICK_START.md](QUICK_START.md) for deployment
5. **Deploy** to production with confidence!

---

## Support

- Quick syntax question? → See [TESTING-QUICK-REFERENCE.md](TESTING-QUICK-REFERENCE.md)
- Step-by-step guidance? → See [TESTING-GUIDE.md](TESTING-GUIDE.md)
- Something broke? → See [DEPLOYMENT_GUIDE.md#troubleshooting](DEPLOYMENT_GUIDE.md#troubleshooting)
- Cost question? → See [COST-OPTIMIZATION.md](COST-OPTIMIZATION.md)

**Ready to start?**

```bash
cd apollo/terraform
bash test-all.sh
```
