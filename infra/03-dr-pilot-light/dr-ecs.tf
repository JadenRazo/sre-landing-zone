# Standby ECS in DR region. Service runs at desiredCount=0 normally; failover
# scales to 2. Task definition + ALB + target group all exist so failover is
# just an `aws ecs update-service --desired-count 2` away.

resource "aws_ecs_cluster" "dr" {
  provider = aws.workloads_dev_dr
  name     = "sre-workloads-dev-dr"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}

# Reuse the IAM roles created in Phase 2? No — they're regional in IAM (well,
# IAM is global but execution roles in workloads-dev are reusable). We'll just
# re-reference by name. Actually IAM roles are global to an account, so we can
# look them up.
data "aws_iam_role" "task_execution" {
  provider = aws.workloads_dev_dr
  name     = "sre-task-execution"
}

data "aws_iam_role" "task" {
  provider = aws.workloads_dev_dr
  name     = "sre-task"
}

# DR-region log group (CloudWatch is regional)
resource "aws_cloudwatch_log_group" "dr_app" {
  provider          = aws.workloads_dev_dr
  name              = "/ecs/sre-reference-app"
  retention_in_days = 30
}

# Task def references the DR-region ECR (which gets populated by replication).
resource "aws_ecs_task_definition" "dr_app" {
  provider                 = aws.workloads_dev_dr
  family                   = "sre-reference-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = data.aws_iam_role.task_execution.arn
  task_role_arn            = data.aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${local.accounts.workloads_dev}.dkr.ecr.${var.dr_region}.amazonaws.com/${var.ecr_repo_name}:${var.container_image_tag}"
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.dr_app.name
        awslogs-region        = var.dr_region
        awslogs-stream-prefix = "app"
      }
    }
    # Note: secrets omitted in DR. The Secrets Manager secret is in us-west-2
    # and would need replication or Secrets Manager Multi-region. For Pilot
    # Light demo, the placeholder image (or sre-reference-app) reads from env
    # if secret unset. Documented trade-off.
  }])
}

# Standby service at desiredCount=0. Failover script scales to 2.
resource "aws_ecs_service" "dr_app" {
  provider        = aws.workloads_dev_dr
  name            = "sre-reference-app"
  cluster         = aws_ecs_cluster.dr.id
  task_definition = aws_ecs_task_definition.dr_app.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.dr_public[*].id
    security_groups  = [aws_security_group.dr_task.id]
    assign_public_ip = true # public subnets, no NAT
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dr_app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.dr_http]

  lifecycle {
    ignore_changes = [task_definition, desired_count] # CI/CD + failover scripts manage these
  }
}
