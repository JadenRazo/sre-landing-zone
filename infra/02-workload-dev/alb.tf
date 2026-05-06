# Application Load Balancer. Public, internet-facing, HTTP-only for now.
# Phase 4 adds CloudFront in front + ACM cert + redirects HTTP→HTTPS at the edge.

resource "aws_lb" "main" {
  provider           = aws.workloads_dev
  name               = "sre-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  drop_invalid_header_fields = true # cheap WAF-like hardening
  enable_deletion_protection = false

  tags = { Name = "sre-alb" }
}

resource "aws_lb_target_group" "app" {
  provider             = aws.workloads_dev
  name_prefix          = "sre-"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "ip" # required for Fargate
  deregistration_delay = 30

  health_check {
    path                = "/health" # real sre-reference-app exposes /health, nginx returns 200 on /
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-399"
    timeout             = 5
  }

  # name_prefix + create_before_destroy lets us swap target groups when port
  # changes without violating the listener's ResourceInUse constraint.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  provider          = aws.workloads_dev
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
