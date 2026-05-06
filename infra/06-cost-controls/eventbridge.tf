# Daily schedule that triggers the auto-stop Lambda.
#
# Why a fixed schedule (not "if idle for X hours"): adding idle-detection turns
# this from 30 minutes of work into a stateful system. The user is one person
# who studies on a predictable schedule. A 4 AM UTC (8 PM PST) run is fine.

resource "aws_cloudwatch_event_rule" "auto_stop_daily" {
  name                = "sre-auto-stop-daily"
  description         = "Scales sre-reference-app ECS service to 0 every night."
  schedule_expression = var.auto_stop_cron
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "auto_stop_lambda" {
  rule = aws_cloudwatch_event_rule.auto_stop_daily.name
  arn  = aws_lambda_function.auto_stop.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.auto_stop_daily.arn
}
