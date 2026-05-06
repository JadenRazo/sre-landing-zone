# Auto-stop Lambda. Runs in mgmt account, assumes role into workloads-dev,
# scales the configured ECS service to 0. Triggered by EventBridge cron.
#
# Why a Lambda (not EventBridge → AWS API Destination): cross-account assume-role
# is messy via API Destinations and the Lambda is ~30 lines. Worth the simplicity.

data "archive_file" "auto_stop_zip" {
  type        = "zip"
  output_path = "${path.module}/auto-stop.zip"

  source {
    filename = "auto_stop.py"
    content  = <<-PYTHON
      import os
      import boto3
      import logging

      log = logging.getLogger()
      log.setLevel(logging.INFO)

      EXECUTOR_ROLE_ARN = os.environ["EXECUTOR_ROLE_ARN"]
      CLUSTER           = os.environ["CLUSTER_NAME"]
      SERVICE           = os.environ["SERVICE_NAME"]
      REGION            = os.environ.get("AWS_REGION", "us-west-2")

      def assume_executor():
          sts = boto3.client("sts")
          response = sts.assume_role(
              RoleArn=EXECUTOR_ROLE_ARN,
              RoleSessionName="auto-stop-cron",
          )
          creds = response["Credentials"]
          return boto3.client(
              "ecs",
              region_name=REGION,
              aws_access_key_id=creds["AccessKeyId"],
              aws_secret_access_key=creds["SecretAccessKey"],
              aws_session_token=creds["SessionToken"],
          )

      def lambda_handler(event, context):
          log.info(f"Auto-stop fired: cluster={CLUSTER} service={SERVICE}")
          ecs = assume_executor()
          current = ecs.describe_services(cluster=CLUSTER, services=[SERVICE])["services"][0]
          desired_now = current["desiredCount"]
          log.info(f"Current desiredCount={desired_now}")
          if desired_now == 0:
              return {"status": "noop", "desiredCount": 0}
          ecs.update_service(cluster=CLUSTER, service=SERVICE, desiredCount=0)
          log.info("Scaled to 0")
          return {"status": "scaled-to-zero", "previousDesiredCount": desired_now}
    PYTHON
  }
}

resource "aws_lambda_function" "auto_stop" {
  function_name    = "sre-auto-stop"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "auto_stop.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.auto_stop_zip.output_path
  source_code_hash = data.archive_file.auto_stop_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      EXECUTOR_ROLE_ARN = aws_iam_role.executor.arn
      CLUSTER_NAME      = var.auto_stop_cluster_name
      SERVICE_NAME      = var.auto_stop_service_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_assume_executor,
  ]
}

resource "aws_cloudwatch_log_group" "auto_stop" {
  name              = "/aws/lambda/sre-auto-stop"
  retention_in_days = 30
}
