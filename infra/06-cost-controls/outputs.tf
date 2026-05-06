output "auto_stop_lambda_name" {
  description = "Lambda function name. Invoke manually: aws lambda invoke --function-name <this> /tmp/out.json"
  value       = aws_lambda_function.auto_stop.function_name
}

output "auto_stop_executor_role_arn" {
  description = "Cross-account executor role ARN in workloads-dev."
  value       = aws_iam_role.executor.arn
}

output "anomaly_monitor_arn" {
  description = "Cost Anomaly monitor ARN."
  value       = aws_ce_anomaly_monitor.service_level.arn
}

output "next_steps" {
  description = "What to do after this apply succeeds."
  value       = <<-EOT

    Phase 6 apply complete. Next:

    1. Confirm any new email subscriptions (AWS may send a fresh confirm
       link if you used a different email than Phase 1).

    2. Test the auto-stop Lambda end-to-end:
       a. Make sure Phase 2 is up (`make up` from infra/02-workload-dev)
       b. Verify ECS service is at desiredCount=1
       c. Trigger Lambda: aws lambda invoke --function-name sre-auto-stop /tmp/out.json
       d. Verify ECS service is now at desiredCount=0
       e. (You'll need to scale back to 1 manually for the next session)

    3. Cost Explorer → Cost Anomaly Detection → confirm monitor is "Active".

    4. Verify Tag Policy created: aws organizations list-policies --filter TAG_POLICY

    5. Move to Phase 3 (DR pilot light) — protected by these cost controls now.
  EOT
}
