# AWS Budgets: forecasted-overspend alerts at the management account, which
# (via consolidated billing) sees spend across all member accounts.
#
# Why moved up from Phase 6: NAT Gateway in Phase 2 can burn $32/mo if left
# running. Without an alert, a leaked weekend = $15 of the $120 budget. The
# rest of cost discipline (auto-stop, anomaly detection) stays in Phase 6.
#
# AWS Budgets gives 2 budgets free, then $0.02/budget/day. We use 1 budget
# with 4 thresholds — well within free tier.

# SNS topic to receive budget alerts; subscribe email after first apply (AWS
# emails a confirmation link).
resource "aws_sns_topic" "budget_alerts" {
  name = "sre-budget-alerts"
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn    = aws_sns_topic.budget_alerts.arn
  policy = data.aws_iam_policy_document.sns_budget_alerts.json
}

data "aws_iam_policy_document" "sns_budget_alerts" {
  statement {
    sid    = "AllowBudgetsPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.budget_alerts.arn]
  }
}

resource "aws_sns_topic_subscription" "budget_email" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_budgets_budget" "monthly" {
  name              = "sre-landing-zone-monthly"
  budget_type       = "COST"
  limit_amount      = "100"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-05-01_00:00"

  # No cost_filter: catch ALL spend in the management account (which via
  # consolidated billing rolls up every linked account). Project-scoped
  # filtering would require a tag filter that not all services honor reliably.

  dynamic "notification" {
    for_each = var.budget_thresholds_usd
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = [var.alert_email]
      subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
    }
  }
}

# A separate "actual spend" budget at $20 — fires when we've ALREADY spent it.
# Distinct from the forecasted alerts above (which warn us before we spend).
resource "aws_budgets_budget" "actual_20" {
  name              = "sre-landing-zone-actual-20"
  budget_type       = "COST"
  limit_amount      = "20"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-05-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
  }
}
