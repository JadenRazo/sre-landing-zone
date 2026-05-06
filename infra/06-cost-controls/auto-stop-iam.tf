# Two roles work together for cross-account auto-stop:
#
#   1. (mgmt) sre-auto-stop-lambda     → the Lambda's execution role
#   2. (workloads_dev) AutoStopExecutorRole → role the Lambda assumes
#
# The Lambda has minimal permissions in mgmt (CloudWatch Logs + sts:AssumeRole).
# The AutoStopExecutorRole has ecs:UpdateService scoped to a single service.
# This is the canonical "least-privilege cross-account automation" pattern that
# shows up on SAA Domain 1 and CCSP Domain 5.

# === Mgmt-side: Lambda execution role ===
resource "aws_iam_role" "lambda_exec" {
  name = "sre-auto-stop-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow the Lambda to assume the cross-account executor role.
resource "aws_iam_role_policy" "lambda_assume_executor" {
  name = "assume-executor-role"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Resource = [
        "arn:aws:iam::${local.accounts.workloads_dev}:role/AutoStopExecutorRole",
      ]
    }]
  })
}

# === Workloads-dev-side: Executor role ===
resource "aws_iam_role" "executor" {
  provider = aws.workloads_dev
  name     = "AutoStopExecutorRole"

  # Trust policy: only the specific Lambda role in mgmt can assume this.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.lambda_exec.arn
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "executor_ecs_scale" {
  provider = aws.workloads_dev
  name     = "scale-ecs-service"
  role     = aws_iam_role.executor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
        ]
        # Scoped to ONE service. Tighter than this and a Lambda crash bricks recovery.
        Resource = "arn:aws:ecs:${var.home_region}:${local.accounts.workloads_dev}:service/${var.auto_stop_cluster_name}/${var.auto_stop_service_name}"
      },
      {
        # ListClusters / ListServices have to be on resource "*" — they're
        # account-scoped APIs, not resource-level. Read-only is acceptable.
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListServices",
        ]
        Resource = "*"
      },
    ]
  })
}
