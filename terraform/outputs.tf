output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "database_type" {
  description = "Database type (aurora-serverless or postgres)"
  value       = var.database_type
}

output "database_endpoint" {
  description = "Database endpoint (Aurora cluster or RDS instance)"
  value = var.database_type == "aurora-serverless" ? 
    aws_rds_cluster.aurora_serverless[0].endpoint :
    aws_db_instance.postgres[0].endpoint
  sensitive   = true
}

output "database_connection_string" {
  description = "Full database connection string"
  value = var.database_type == "aurora-serverless" ? 
    "postgresql://${var.database_user}:${var.database_password}@${aws_rds_cluster.aurora_serverless[0].endpoint}:5432/${var.database_name}" :
    "postgresql://${var.database_user}:${var.database_password}@${aws_db_instance.postgres[0].endpoint}:5432/${var.database_name}"
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = aws_ecr_repository.main.repository_url
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "s3_bucket_name" {
  description = "S3 bucket for application assets"
  value       = aws_s3_bucket.app_assets.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cost_optimization_settings" {
  description = "Current cost optimization configuration"
  value = {
    min_count                = var.min_count
    use_fargate_spot         = var.use_fargate_spot
    database_type            = var.database_type
    aurora_min_capacity      = var.database_type == "aurora-serverless" ? var.aurora_min_capacity : null
    scheduled_scaling_enabled = var.enable_scheduled_scaling
  }
}

output "estimated_idle_cost" {
  description = "Estimated monthly cost when idle (ALB + Aurora minimum)"
  value       = "~$16-22/month (ALB + Aurora auto-pause)"
}

output "estimated_active_cost" {
  description = "Estimated monthly cost with normal usage"
  value       = "~$40-60/month (depends on traffic)"
}
