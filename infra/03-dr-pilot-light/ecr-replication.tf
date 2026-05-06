# ECR cross-region replication. The Phase 2 ECR repo in us-west-2 replicates
# any pushed image to us-east-1. AWS auto-creates the destination repo on first
# replicated push.
#
# Note: replication is configured at the registry (account) level, not per-repo,
# but you can scope by filter. We set a filter that matches the project's repo
# names. Replication is asynchronous, ~1 min to converge.

resource "aws_ecr_replication_configuration" "primary" {
  provider = aws.workloads_dev_primary

  replication_configuration {
    rule {
      destination {
        region      = var.dr_region
        registry_id = local.accounts.workloads_dev
      }

      repository_filter {
        filter      = var.ecr_repo_name
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}
