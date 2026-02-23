# RDS Subnet Group (for both Aurora and traditional RDS)
resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# ============================================================
# AURORA SERVERLESS v2 (PAY-PER-USE - RECOMMENDED)
# ============================================================

resource "aws_rds_cluster" "aurora_serverless" {
  count              = var.database_type == "aurora-serverless" ? 1 : 0
  cluster_identifier = "${var.app_name}-aurora-cluster"
  engine             = "aurora-postgresql"
  engine_version     = "16.1"
  database_name      = var.database_name
  master_username    = var.database_user
  master_password    = var.database_password

  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora[0].name
  vpc_security_group_ids          = [aws_security_group.rds.id]

  # Security
  storage_encrypted = true

  # Backup - can be very short for Aurora Serverless
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  # Enable deletion protection for production
  deletion_protection = var.environment == "production" ? true : false

  # Enable logging
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Skip final snapshot for easier testing
  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment != "production" ? null : "${var.app_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Copy tags to snapshot
  copy_tags_to_snapshot = true

  tags = {
    Name = "${var.app_name}-aurora-cluster"
  }

  depends_on = [aws_security_group.rds]
}

# Aurora Serverless v2 Instance
resource "aws_rds_cluster_instance" "aurora_serverless" {
  count              = var.database_type == "aurora-serverless" ? 1 : 0
  cluster_identifier = aws_rds_cluster.aurora_serverless[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_serverless[0].engine
  engine_version     = aws_rds_cluster.aurora_serverless[0].engine_version

  # Enable monitoring
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring[0].arn

  tags = {
    Name = "${var.app_name}-aurora-instance"
  }
}

# Aurora Serverless v2 Auto-Scaling Policy
resource "aws_rds_cluster_scaling_configuration" "aurora_serverless" {
  count                         = var.database_type == "aurora-serverless" ? 1 : 0
  resource_id                   = aws_rds_cluster.aurora_serverless[0].cluster_resource_id
  scalable_dimension            = "rds:cluster:ReadReplicaCount"
  service_namespace             = "rds"
  min_capacity                  = var.aurora_min_capacity
  max_capacity                  = var.aurora_max_capacity
  auto_pause                    = true
  auto_pause_seconds            = 300  # Auto-pause after 5 minutes of inactivity
  seconds_until_auto_pause_cancelled = 300
}

# Aurora Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "aurora" {
  count       = var.database_type == "aurora-serverless" ? 1 : 0
  name        = "${var.app_name}-aurora-cluster-params"
  family      = "aurora-postgresql16"
  description = "Aurora parameter group for ${var.app_name}"

  # Optimize for Rails
  parameter {
    name  = "shared_preload_libraries"
    value = "pgaudit"
  }

  tags = {
    Name = "${var.app_name}-aurora-params"
  }
}

# IAM Role for RDS Monitoring (Aurora only)
resource "aws_iam_role" "rds_monitoring" {
  count = var.database_type == "aurora-serverless" ? 1 : 0
  name  = "${var.app_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.database_type == "aurora-serverless" ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================
# TRADITIONAL RDS POSTGRES (FIXED COST, NOT RECOMMENDED)
# ============================================================

resource "aws_db_instance" "postgres" {
  count                = var.database_type == "postgres" ? 1 : 0
  identifier           = "${var.app_name}-db"
  allocated_storage    = var.database_allocated_storage
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "16.1"
  instance_class       = var.database_instance_class
  db_name              = var.database_name
  username             = var.database_user
  password             = var.database_password
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Backup and maintenance
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  # Security
  publicly_accessible    = false
  storage_encrypted      = true
  multi_az               = true

  # Performance and monitoring
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment != "production" ? null : "${var.app_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  auto_minor_version_upgrade = true
  deletion_protection = var.environment == "production" ? true : false

  tags = {
    Name = "${var.app_name}-db"
  }

  depends_on = [aws_security_group.rds]
}

# Output the database connection string for later use
output "database_connection_string" {
  description = "Database connection string (PostgreSQL)"
  value = var.database_type == "aurora-serverless" ? 
    "postgresql://${var.database_user}:${var.database_password}@${aws_rds_cluster.aurora_serverless[0].endpoint}:5432/${var.database_name}" :
    "postgresql://${var.database_user}:${var.database_password}@${aws_db_instance.postgres[0].endpoint}:5432/${var.database_name}"
  sensitive   = true
}

output "database_endpoint" {
  description = "Database endpoint"
  value = var.database_type == "aurora-serverless" ? 
    aws_rds_cluster.aurora_serverless[0].endpoint :
    aws_db_instance.postgres[0].endpoint
}

output "database_type" {
  description = "Database type deployed"
  value       = var.database_type
}
