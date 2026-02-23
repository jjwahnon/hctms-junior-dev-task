# Environment-specific Terraform configurations

# Production
# This folder should contain specific production settings
# Example: terraform/prod/terraform.tfvars (use with: terraform apply -var-file=prod/terraform.tfvars)

# Staging
# Example: terraform/staging/terraform.tfvars

# Development
# Example: terraform/dev/terraform.tfvars

---

## Using Environment-Specific Configurations

Create separate directories for each environment:

```
terraform/
├── terraform.tfvars.example
├── prod/
│   └── terraform.tfvars
├── staging/
│   └── terraform.tfvars
└── dev/
    └── terraform.tfvars
```

Then deploy with:

```bash
# Production
terraform apply -var-file=prod/terraform.tfvars

# Staging
terraform apply -var-file=staging/terraform.tfvars

# Development
terraform apply -var-file=dev/terraform.tfvars
```

Or set the environment variable:

```bash
export TFVARS_FILE="prod/terraform.tfvars"
terraform apply -var-file=$TFVARS_FILE
```
