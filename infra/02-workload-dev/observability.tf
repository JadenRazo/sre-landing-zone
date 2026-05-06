# Observability: log group + dashboard + multi-window burn-rate alarms.
#
# This is the SRE narrative of the project — the burn-rate alarms (1h @ 14.4×
# fast-burn / 6h @ 6× slow-burn) come straight from the Google SRE Workbook
# and were the centerpiece of the original sre-reference-app GameDay.
#
# These alarms only produce signal when the real sre-reference-app is running
# (which actually returns 5xx ~5% of the time per its ERROR_RATE config). With
# the default nginx placeholder image, the alarms exist but never fire because
# nginx never errors.

resource "aws_cloudwatch_log_group" "app" {
  provider          = aws.workloads_dev
  name              = "/ecs/sre-reference-app"
  retention_in_days = var.log_retention_days
}

# SLO: 99% availability over 30 days. That gives a 1% error budget.
# Multi-window burn-rate from the Workbook:
#   Fast-burn:  alert if 1h error_rate > 14.4 × 0.01 = 14.4% (would burn 30d budget in 2h)
#   Slow-burn:  alert if 6h error_rate >  6.0 × 0.01 =  6.0% (would burn 30d budget in 5d)

resource "aws_cloudwatch_metric_alarm" "fast_burn" {
  provider            = aws.workloads_dev
  alarm_name          = "sre-reference-app-fast-burn-1h"
  alarm_description   = "Fast-burn: 1h error rate > 14.4% (will exhaust 30d 99% SLO budget in 2h)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0.144
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "errors / total"
    label       = "Error rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 3600
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }

  metric_query {
    id = "total"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 3600
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "slow_burn" {
  provider            = aws.workloads_dev
  alarm_name          = "sre-reference-app-slow-burn-6h"
  alarm_description   = "Slow-burn: 6h error rate > 6% (will exhaust 30d 99% SLO budget in 5d)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0.06
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "errors / total"
    label       = "Error rate"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 21600
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }

  metric_query {
    id = "total"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 21600
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }
}

# Compact dashboard: request count, p50/p99 latency, 5xx rate, task count, target health.
resource "aws_cloudwatch_dashboard" "app" {
  provider       = aws.workloads_dev
  dashboard_name = "sre-reference-app"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Request count + 5xx"
          region = var.home_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", yAxis = "right" }],
          ]
          view   = "timeSeries"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Latency p50 / p99"
          region = var.home_region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "p50" }],
            ["...", { stat = "p99" }],
          ]
          view   = "timeSeries"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS task count + target health"
          region = var.home_region
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", aws_ecs_service.app.name, "ClusterName", aws_ecs_cluster.main.name, { stat = "Average" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average", yAxis = "right" }],
          ]
          view   = "timeSeries"
          period = 60
        }
      },
    ]
  })
}
