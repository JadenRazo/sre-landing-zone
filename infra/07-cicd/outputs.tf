output "oidc_provider_arn" {
  description = "OIDC provider ARN. Trust policies in member accounts could reference this directly for tighter chains."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_runner_role_arn" {
  description = "ARN of the role GitHub Actions assumes. Reference this in workflow files: role-to-assume: <this>"
  value       = aws_iam_role.terraform_runner.arn
}

output "github_actions_secret_setup" {
  description = "Commands to add the role ARN as a GitHub Actions secret/variable."
  value       = <<-EOT

    Add the runner role ARN as a GitHub Actions VARIABLE (not secret — ARNs aren't secret):

      gh variable set AWS_ROLE_ARN \
        --body "${aws_iam_role.terraform_runner.arn}" \
        --repo ${var.github_org}/${var.github_repo}

    Workflows reference it as: $${{ vars.AWS_ROLE_ARN }}
  EOT
}
