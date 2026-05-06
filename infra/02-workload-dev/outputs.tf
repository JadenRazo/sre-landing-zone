output "alb_dns_name" {
  description = "Public DNS name of the ALB. curl http://<this> to hit the app."
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "Push your image here when ready to swap from the placeholder nginx."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Cluster name for `aws ecs ...` commands."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Service name. Scale with `aws ecs update-service --desired-count N`."
  value       = aws_ecs_service.app.name
}

output "secret_arn" {
  description = "ARN of the ERROR_RATE secret. Rotate with `aws secretsmanager update-secret-version-stage`."
  value       = aws_secretsmanager_secret.error_rate.arn
}

output "vpc_id" {
  description = "VPC ID — Phase 3 (DR) and Phase 4 (CloudFront) reference this."
  value       = aws_vpc.main.id
}

output "next_steps" {
  description = "What to do after this apply succeeds."
  value       = <<-EOT

    Phase 2 apply complete. Next:

    1. Test the ALB: curl http://<alb_dns_name>
       Should return the nginx welcome page within ~2 minutes of apply.

    2. View the dashboard: AWS Console → CloudWatch → Dashboards →
       sre-reference-app (login as workloads-dev).

    3. (Optional) Swap to your real sre-reference-app image:
       cd ../../  # to your local clone of sre-reference-app
       aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <ecr_url>
       docker build -t sre-reference-app . && docker tag sre-reference-app:latest <ecr_url>:latest
       docker push <ecr_url>:latest
       Then set container_image = "<ecr_url>:latest" in terraform.tfvars and re-apply.

    4. WHEN DONE: run `make down` (full destroy) to stop NAT Gateway + ECS bills.
       Leaving it up overnight = ~$1 wasted; over a weekend = ~$3.

    5. Move to Phase 3: cd ../03-dr-pilot-light (not yet implemented).
  EOT
}
