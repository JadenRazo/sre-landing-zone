# Standby ALB in DR region. Provisioned and warm — no spin-up time during
# failover. ~$16/mo while up; tear down between sessions like everything else.

resource "aws_lb" "dr" {
  provider           = aws.workloads_dev_dr
  name               = "sre-alb-dr"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dr_alb.id]
  subnets            = aws_subnet.dr_public[*].id

  drop_invalid_header_fields = true
  enable_deletion_protection = false

  tags = { Name = "sre-alb-dr" }
}

resource "aws_lb_target_group" "dr_app" {
  provider             = aws.workloads_dev_dr
  name                 = "sre-app-tg-dr"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.dr.id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-399"
    timeout             = 5
  }
}

resource "aws_lb_listener" "dr_http" {
  provider          = aws.workloads_dev_dr
  load_balancer_arn = aws_lb.dr.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dr_app.arn
  }
}
