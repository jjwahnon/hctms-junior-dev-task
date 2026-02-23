# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

# Allow HTTP from anywhere to ALB
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "HTTP from anywhere"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Allow HTTPS from anywhere to ALB (if enabled)
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  description = "HTTPS from anywhere"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Allow all outbound traffic from ALB
resource "aws_vpc_security_group_egress_rule" "alb_outbound" {
  security_group_id = aws_security_group.alb.id

  description      = "Allow all outbound traffic"
  ip_protocol      = "-1"
  cidr_ipv4        = "0.0.0.0/0"
}

# ECS Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-ecs-tasks-sg"
  }
}

# Allow traffic from ALB to ECS tasks
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs_tasks.id

  description              = "Allow traffic from ALB"
  from_port                = var.container_port
  to_port                  = var.container_port
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# Allow ECS tasks to communicate with each other
resource "aws_vpc_security_group_ingress_rule" "ecs_self" {
  security_group_id = aws_security_group.ecs_tasks.id

  description              = "Allow ECS tasks to talk to each other"
  from_port                = 0
  to_port                  = 65535
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

# Allow all outbound traffic from ECS tasks
resource "aws_vpc_security_group_egress_rule" "ecs_outbound" {
  security_group_id = aws_security_group.ecs_tasks.id

  description      = "Allow all outbound traffic"
  ip_protocol      = "-1"
  cidr_ipv4        = "0.0.0.0/0"
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-rds-sg"
  }
}

# Allow PostgreSQL traffic from ECS tasks
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id = aws_security_group.rds.id

  description              = "PostgreSQL from ECS tasks"
  from_port                = 5432
  to_port                  = 5432
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

# Allow all outbound traffic from RDS (generally not needed for database)
resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.rds.id

  description      = "Allow all outbound traffic"
  ip_protocol      = "-1"
  cidr_ipv4        = "0.0.0.0/0"
}
