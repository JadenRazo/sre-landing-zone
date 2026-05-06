# AWS Cost Anomaly Detection: ML-driven cost spike detection. Free service —
# you only pay for the resources it monitors.
#
# Two pieces:
#   1. A monitor scoped to all services in the management (consolidated billing) account
#   2. A subscription that routes anomalies to the existing budget-alerts SNS topic
#
# Threshold: $5 as default. Tighter than AWS's $100 default — appropriate for a
# $120 total budget where a $5 spike is actually meaningful.

# AWS limits a single account to ONE dimensional monitor per dimension; the
# AWS-managed `Default-Services-Monitor` already occupies the SERVICE slot.
# So we use a CUSTOM-type monitor scoped to the project's tag, which can coexist.
resource "aws_ce_anomaly_monitor" "service_level" {
  name         = "sre-anomaly-monitor"
  monitor_type = "CUSTOM"

  monitor_specification = jsonencode({
    Tags = {
      Key          = "Project"
      Values       = ["sre-landing-zone"]
      MatchOptions = ["EQUALS"]
    }
  })
}

resource "aws_ce_anomaly_subscription" "service_level" {
  name             = "sre-service-anomaly-subscription"
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.service_level.arn]

  subscriber {
    type    = "SNS"
    address = data.aws_sns_topic.budget_alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = [tostring(var.anomaly_threshold_usd)]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  depends_on = [aws_sns_topic_policy.allow_costexplorer]
}

# The Phase 1 SNS topic policy doesn't allow Cost Explorer to publish — extend it.
data "aws_iam_policy_document" "sns_combined" {
  statement {
    sid    = "AllowBudgetsPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [data.aws_sns_topic.budget_alerts.arn]
  }

  statement {
    sid    = "AllowCostExplorerPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [data.aws_sns_topic.budget_alerts.arn]
  }
}

resource "aws_sns_topic_policy" "allow_costexplorer" {
  arn    = data.aws_sns_topic.budget_alerts.arn
  policy = data.aws_iam_policy_document.sns_combined.json
}

# Direct email subscription too, since Cost Explorer subscribers can be SNS-only.
resource "aws_sns_topic_subscription" "cost_anomaly_email" {
  topic_arn = data.aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
