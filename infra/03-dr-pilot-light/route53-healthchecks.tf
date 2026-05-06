# Route 53 health checks on both ALBs. We don't create a hosted zone or
# failover record here because the user's domain (raizhost.com) lives outside
# Route 53. The health checks themselves are the demo artifact: they prove
# Route 53 can detect a failed primary in ~90 seconds.
#
# To wire up actual DNS failover later: add an `aws_route53_zone` (or data
# source for an existing zone) and two `aws_route53_record` entries with
# `failover_routing_policy` blocks pointing at these health checks.

resource "aws_route53_health_check" "primary_alb" {
  fqdn              = data.aws_lb.primary.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "sre-alb-primary-health" }
}

resource "aws_route53_health_check" "dr_alb" {
  fqdn              = aws_lb.dr.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "sre-alb-dr-health" }
}

# CloudWatch alarms tied to the health checks — turn a failed health check
# into an alert event. Useful for demos: when primary goes red, this alarm
# trips, and you can wire SNS/Lambda off it.
resource "aws_cloudwatch_metric_alarm" "primary_alb_unhealthy" {
  alarm_name          = "sre-primary-alb-unhealthy"
  alarm_description   = "Route 53 says the primary ALB is unhealthy. DR failover candidate."
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  evaluation_periods  = 2
  period              = 60
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary_alb.id
  }
}
