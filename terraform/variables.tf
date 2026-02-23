variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Apollo Database"
  type        = string
  default     = "apollo"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-2"]
}

variable "private_subnets_cidr" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets_cidr" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "CPU units for ECS task (256 = 0.25 CPU)"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_count" {
  description = "Minimum number of ECS tasks (set to 0 for true pay-per-use)"
  type        = number
  default     = 0  # Set to 1 if you need always-on availability
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot instances (70% cheaper, can be interrupted)"
  type        = bool
  default     = true  # Recommended for cost savings
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled auto-scaling (shut down during non-business hours)"
  type        = bool
  default     = false
}

variable "business_hours_start" {
  description = "Start of business hours for scheduled scaling (24-hour format, UTC)"
  type        = number
  default     = 8  # 8 AM UTC
}

variable "business_hours_end" {
  description = "End of business hours for scheduled scaling (24-hour format, UTC)"
  type        = number
  default     = 18  # 6 PM UTC
}

variable "business_days" {
  description = "Days of week to run (0=Monday, 6=Sunday)"
  type        = list(number)
  default     = [0, 1, 2, 3, 4]  # Monday-Friday
}

variable "docker_image" {
  description = "Docker image URL (e.g., ECR or Docker Hub)"
  type        = string
  default     = ""  # You'll need to provide this after pushing to ECR
}

variable "database_name" {
  description = "RDS database name"
  type        = string
  default     = "apollo_db"
}

variable "database_user" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "database_password" {
  description = "RDS master password (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "database_type" {
  description = "Database type: 'aurora-serverless' (pay-per-use, recommended) or 'postgres' (traditional RDS)"
  type        = string
  default     = "aurora-serverless"
  
  validation {
    condition     = contains(["aurora-serverless", "postgres"], var.database_type)
    error_message = "Must be 'aurora-serverless' or 'postgres'."
  }
}

variable "database_instance_class" {
  description = "RDS instance class (only used if database_type is 'postgres')"
  type        = string
  default     = "db.t3.micro"
}

variable "database_allocated_storage" {
  description = "Allocated storage in GB (only used if database_type is 'postgres')"
  type        = number
  default     = 20
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity (ACUs, 0.5, 1, 1.5, 2, etc.)"
  type        = number
  default     = 0.5  # Minimum possible
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity (ACUs)"
  type        = number
  default     = 2  # Can auto-scale up to this
}

variable "rails_master_key" {
  description = "Rails master key for credentials"
  type        = string
  sensitive   = true
}

variable "rails_log_level" {
  description = "Rails log level"
  type        = string
  default     = "info"
}

variable "enable_https" {
  description = "Enable HTTPS with ACM certificate"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Health check path for ALB"
  type        = string
  default     = "/up"
}
