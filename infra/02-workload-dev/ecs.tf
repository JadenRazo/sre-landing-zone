# ECS Fargate cluster + task definition + service.
#
# Why Fargate over EC2 Launch Type: no EC2 capacity planning, no per-instance
# cost when idle, simpler IAM. Fargate Spot (up to 70% cheaper) is available
# but fault-tolerant patterns are out of scope for v1.

resource "aws_ecs_cluster" "main" {
  provider = aws.workloads_dev
  name     = "sre-workloads-dev"

  setting {
    name  = "containerInsights"
    value = "enhanced" # enhanced = per-task metrics; required for SRE-grade dashboards
  }
}

# Task execution role: ECS service uses this to PULL the image, write logs, fetch secrets.
resource "aws_iam_role" "task_execution" {
  provider = aws.workloads_dev
  name     = "sre-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  provider   = aws.workloads_dev
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy: read the ERROR_RATE secret. Scoped tighter than the AWS-managed
# AmazonECSTaskExecutionRolePolicy (which doesn't include Secrets Manager).
resource "aws_iam_role_policy" "task_execution_secrets" {
  provider = aws.workloads_dev
  name     = "read-error-rate-secret"
  role     = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.error_rate.arn
    }]
  })
}

# Task role: in-app permissions (anything the running container itself needs to call).
# Empty for nginx; sre-reference-app may add CloudWatch:PutMetricData later.
resource "aws_iam_role" "task" {
  provider = aws.workloads_dev
  name     = "sre-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_ecs_task_definition" "app" {
  provider                 = aws.workloads_dev
  family                   = "sre-reference-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = var.container_image
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    secrets = [{
      name      = "ERROR_RATE"
      valueFrom = "${aws_secretsmanager_secret.error_rate.arn}:ERROR_RATE::"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.home_region
        awslogs-stream-prefix = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  provider        = aws.workloads_dev
  name            = "sre-reference-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false # we have NAT for egress; no public IP on tasks
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  # ignore_changes is intentionally OFF for this stack — Terraform owns the
  # full container_image / container_port lifecycle. CI/CD that pushes new
  # task defs would normally want this on, but for this project we run
  # everything from Terraform.
}
