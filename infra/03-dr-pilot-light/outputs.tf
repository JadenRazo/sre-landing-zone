output "primary_alb_dns" {
  description = "Primary ALB DNS (us-west-2)."
  value       = data.aws_lb.primary.dns_name
}

output "dr_alb_dns" {
  description = "Standby ALB DNS (us-east-1). Direct hit during failover drill."
  value       = aws_lb.dr.dns_name
}

output "dr_ecs_cluster" {
  description = "DR cluster name."
  value       = aws_ecs_cluster.dr.name
}

output "dynamodb_global_table_arn" {
  description = "Global Table ARN. Inspect replicas: aws dynamodb describe-table --table-name sre-feature-flags"
  value       = aws_dynamodb_table.feature_flags.arn
}

output "primary_health_check_id" {
  description = "Route 53 health check on primary ALB."
  value       = aws_route53_health_check.primary_alb.id
}

output "dr_health_check_id" {
  description = "Route 53 health check on DR ALB."
  value       = aws_route53_health_check.dr_alb.id
}

output "next_steps" {
  description = "What to do after this apply succeeds."
  value       = <<-EOT

    Phase 3 apply complete. Next:

    1. Verify ECR replication (push an image to primary, wait ~1 min, check DR):
       aws ecr describe-images --repository-name sre-reference-app --region us-east-1

    2. Verify DynamoDB Global Table:
       aws dynamodb describe-table --table-name sre-feature-flags --query "Table.Replicas"

    3. RUN THE FAILOVER DRILL when Phase 2 (primary) is up:
       bash failover-drill.sh
       Captures terminal output → screenshots/10-failover-drill.png

    4. Tear down Phase 3 between sessions: terraform destroy (~$17/mo savings)

    5. Move to Phase 4: cd ../04-edge-and-data
  EOT
}
