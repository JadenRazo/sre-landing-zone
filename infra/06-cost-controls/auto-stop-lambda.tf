# Auto-stop Lambda. Runs in mgmt account, assumes role into workloads-dev,
# discovers ALL ECS services tagged Environment=dev, scales each to 0.
#
# Tag-based discovery (vs. hardcoded names) means:
#   - Add a new dev service → no Lambda code change needed
#   - Forget to tag a service → it doesn't get scaled (good — fail open)
#   - Audit trail: CloudWatch Logs records exactly which services were affected

data "archive_file" "auto_stop_zip" {
  type        = "zip"
  output_path = "${path.module}/auto-stop.zip"

  source {
    filename = "auto_stop.py"
    content  = <<-PYTHON
      """Tag-based ECS auto-stop.

      Discovers all ECS services in the target account whose service tags include
      Environment=dev, and scales each to 0. Idempotent — services already at 0
      are noop'd.
      """
      import os
      import boto3
      import logging

      log = logging.getLogger()
      log.setLevel(logging.INFO)

      EXECUTOR_ROLE_ARN = os.environ["EXECUTOR_ROLE_ARN"]
      REGION            = os.environ.get("AWS_REGION", "us-west-2")
      TARGET_TAG_KEY    = os.environ.get("TARGET_TAG_KEY", "Environment")
      TARGET_TAG_VALUE  = os.environ.get("TARGET_TAG_VALUE", "dev")


      def assume_executor():
          sts = boto3.client("sts")
          response = sts.assume_role(
              RoleArn=EXECUTOR_ROLE_ARN,
              RoleSessionName="auto-stop-cron",
          )
          c = response["Credentials"]
          return boto3.client(
              "ecs",
              region_name=REGION,
              aws_access_key_id=c["AccessKeyId"],
              aws_secret_access_key=c["SecretAccessKey"],
              aws_session_token=c["SessionToken"],
          )


      def has_target_tag(tags):
          for tag in tags or []:
              if tag.get("key") == TARGET_TAG_KEY and tag.get("value") == TARGET_TAG_VALUE:
                  return True
          return False


      def lambda_handler(event, context):
          log.info(f"Auto-stop fired. Looking for services tagged {TARGET_TAG_KEY}={TARGET_TAG_VALUE}")
          ecs = assume_executor()

          scanned = 0
          scaled = 0
          skipped_already_zero = 0
          skipped_untagged = 0

          # Iterate every cluster in the account
          paginator = ecs.get_paginator("list_clusters")
          for page in paginator.paginate():
              for cluster_arn in page["clusterArns"]:
                  cluster_name = cluster_arn.split("/")[-1]
                  service_paginator = ecs.get_paginator("list_services")
                  for service_page in service_paginator.paginate(cluster=cluster_arn):
                      for svc_arn in service_page["serviceArns"]:
                          scanned += 1
                          desc = ecs.describe_services(
                              cluster=cluster_arn,
                              services=[svc_arn],
                              include=["TAGS"],
                          )["services"][0]

                          svc_name = desc["serviceName"]
                          tags = desc.get("tags", [])

                          if not has_target_tag(tags):
                              skipped_untagged += 1
                              log.info(f"skip {cluster_name}/{svc_name}: not tagged {TARGET_TAG_KEY}={TARGET_TAG_VALUE}")
                              continue

                          if desc["desiredCount"] == 0:
                              skipped_already_zero += 1
                              log.info(f"skip {cluster_name}/{svc_name}: already at 0")
                              continue

                          ecs.update_service(
                              cluster=cluster_arn,
                              service=svc_arn,
                              desiredCount=0,
                          )
                          scaled += 1
                          log.info(f"scaled {cluster_name}/{svc_name} from {desc['desiredCount']} to 0")

          summary = {
              "scanned": scanned,
              "scaled_to_zero": scaled,
              "already_zero": skipped_already_zero,
              "untagged_skipped": skipped_untagged,
          }
          log.info(f"Auto-stop complete: {summary}")
          return summary
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
  timeout          = 60 # tag-discovery iterates clusters/services; bump from 30s
  memory_size      = 128

  environment {
    variables = {
      EXECUTOR_ROLE_ARN = aws_iam_role.executor.arn
      TARGET_TAG_KEY    = "Environment"
      TARGET_TAG_VALUE  = "dev"
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
