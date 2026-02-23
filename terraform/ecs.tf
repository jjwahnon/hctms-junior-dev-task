# ECR Repository for Docker images
resource "aws_ecr_repository" "main" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.app_name}-ecr"
  }
}

# ECR Lifecycle Policy to cleanup old images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images, delete old ones"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.app_name}-ecs-logs"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.docker_image != "" ? var.docker_image : "${aws_ecr_repository.main.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "RAILS_ENV"
          value = var.environment
        },
        {
          name  = "RAILS_LOG_LEVEL"
          value = var.rails_log_level
        },
        {
          name  = "DATABASE_URL"
          value = var.database_type == "aurora-serverless" ?
            "postgresql://${var.database_user}:${var.database_password}@${aws_rds_cluster.aurora_serverless[0].endpoint}:5432/${var.database_name}" :
            "postgresql://${var.database_user}:${var.database_password}@${aws_db_instance.postgres[0].address}:5432/${var.database_name}"
        }
      ]

      secrets = [
        {
          name      = "RAILS_MASTER_KEY"
          valueFrom = "arn:aws:secretsmanager:${var.aws_region}:$(aws sts get-caller-identity --query Account --output text):secret:${var.app_name}/rails_master_key:RAILS_MASTER_KEY::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.app_name}-task-definition"
  }

  depends_on = [
    aws_rds_cluster.aurora_serverless,
    aws_db_instance.postgres,
    aws_cloudwatch_log_group.ecs
  ]
}

# ECS Service with Spot Instance Support
resource "aws_ecs_service" "main" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  
  # Use mix of FARGATE and FARGATE_SPOT for cost savings
  capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = var.use_fargate_spot ? 70 : 100  # Prefer Spot (70%)
    base              = 0
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 30  # Fallback to regular Fargate (30%)
      base              = 0
    }
  }

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  deployment_configuration {
    minimum_healthy_percent = var.min_count > 0 ? 100 : 0  # Allow zero tasks if min_count is 0
    maximum_percent         = 200
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role.ecs_task_execution_role,
    aws_iam_role.ecs_task_role
  ]

  tags = {
    Name = "${var.app_name}-service"
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = var.min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  
  depends_on = [aws_ecs_service.main]
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "${var.app_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "${var.app_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# ============================================================
# SCHEDULED SCALING (Optional: Shutdown during off-hours)
# ============================================================

# Scale down to 0 outside business hours
resource "aws_appautoscaling_scheduled_action" "scale_down_evening" {
  count               = var.enable_scheduled_scaling ? 1 : 0
  scheduled_action_name = "${var.app_name}-scale-down-evening"
  service_namespace   = "ecs"
  resource_id         = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension  = "ecs:service:DesiredCount"
  
  # Every day at 6 PM UTC
  schedule = "cron(${var.business_hours_end} * * ? *)"
  
  scalable_target_action {
    min_capacity = 0
    max_capacity = 1  # Max 1 task during off-hours for quick restart
  }
}

# Scale up to business hours capacity
resource "aws_appautoscaling_scheduled_action" "scale_up_morning" {
  count               = var.enable_scheduled_scaling ? 1 : 0
  scheduled_action_name = "${var.app_name}-scale-up-morning"
  service_namespace   = "ecs"
  resource_id         = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension  = "ecs:service:DesiredCount"
  
  # Every business day at 8 AM UTC
  schedule = "cron(${var.business_hours_start} ? * MON-FRI *)"
  
  scalable_target_action {
    min_capacity = var.min_count
    max_capacity = 4
  }
}
