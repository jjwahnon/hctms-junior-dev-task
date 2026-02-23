# S3 Bucket for application assets
resource "aws_s3_bucket" "app_assets" {
  bucket = "${var.app_name}-assets-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.app_name}-assets"
  }
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for backup and recovery
resource "aws_s3_bucket_versioning" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable logging for S3 bucket access
resource "aws_s3_bucket_logging" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "app-assets/"
}

# S3 Bucket for logs (separate bucket for better organization)
resource "aws_s3_bucket" "logs" {
  bucket = "${var.app_name}-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.app_name}-logs"
  }
}

# Block public access to logs bucket
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to expire old logs
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
