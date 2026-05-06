.PHONY: help up down plan validate logs scale-zero scale-one curl

ALB_DNS := $(shell terraform output -raw alb_dns_name 2>/dev/null)
CLUSTER := $(shell terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE := $(shell terraform output -raw ecs_service_name 2>/dev/null)

help:
	@echo "Phase 2 daily commands:"
	@echo "  make up           - terraform apply (provisions VPC + NAT + ALB + ECS, ~3 min)"
	@echo "  make down         - terraform destroy (stops all ongoing cost, ~2 min)"
	@echo "  make plan         - terraform plan"
	@echo "  make scale-zero   - keep infra alive but stop paying for tasks"
	@echo "  make scale-one    - resume tasks after scale-zero"
	@echo "  make curl         - curl the ALB to verify it's responding"
	@echo "  make logs         - tail CloudWatch logs from the running task"
	@echo ""
	@echo "RULE: run 'make down' when you stop studying for the day."
	@echo "      Leaving NAT up overnight = $$1+ wasted out of your $$120 budget."

up:
	terraform apply -auto-approve

down:
	terraform destroy -auto-approve

plan:
	terraform plan

validate:
	terraform fmt -check && terraform validate

scale-zero:
	@aws sts assume-role --role-arn arn:aws:iam::$$(jq -r .workloads_dev <<<"$$(aws ssm get-parameter --name /sre-landing-zone/account-map --query Parameter.Value --output text)"):role/OrganizationAccountAccessRole --role-session-name scale-down --query 'Credentials' > /tmp/wd-creds.json
	@AWS_ACCESS_KEY_ID=$$(jq -r .AccessKeyId /tmp/wd-creds.json) \
	 AWS_SECRET_ACCESS_KEY=$$(jq -r .SecretAccessKey /tmp/wd-creds.json) \
	 AWS_SESSION_TOKEN=$$(jq -r .SessionToken /tmp/wd-creds.json) \
	   aws ecs update-service --cluster $(CLUSTER) --service $(SERVICE) --desired-count 0 >/dev/null
	@rm /tmp/wd-creds.json
	@echo "Scaled $(SERVICE) to 0. NAT Gateway still running (~$$32/mo). For full stop: make down."

scale-one:
	@aws sts assume-role --role-arn arn:aws:iam::$$(jq -r .workloads_dev <<<"$$(aws ssm get-parameter --name /sre-landing-zone/account-map --query Parameter.Value --output text)"):role/OrganizationAccountAccessRole --role-session-name scale-up --query 'Credentials' > /tmp/wd-creds.json
	@AWS_ACCESS_KEY_ID=$$(jq -r .AccessKeyId /tmp/wd-creds.json) \
	 AWS_SECRET_ACCESS_KEY=$$(jq -r .SecretAccessKey /tmp/wd-creds.json) \
	 AWS_SESSION_TOKEN=$$(jq -r .SessionToken /tmp/wd-creds.json) \
	   aws ecs update-service --cluster $(CLUSTER) --service $(SERVICE) --desired-count 1 >/dev/null
	@rm /tmp/wd-creds.json
	@echo "Scaled $(SERVICE) to 1."

curl:
	@if [ -z "$(ALB_DNS)" ]; then echo "No ALB found. Run 'make up' first."; exit 1; fi
	@echo "GET http://$(ALB_DNS)/"
	@curl -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s\n" "http://$(ALB_DNS)/"

logs:
	@aws sts assume-role --role-arn arn:aws:iam::$$(jq -r .workloads_dev <<<"$$(aws ssm get-parameter --name /sre-landing-zone/account-map --query Parameter.Value --output text)"):role/OrganizationAccountAccessRole --role-session-name logs --query 'Credentials' > /tmp/wd-creds.json
	@AWS_ACCESS_KEY_ID=$$(jq -r .AccessKeyId /tmp/wd-creds.json) \
	 AWS_SECRET_ACCESS_KEY=$$(jq -r .SecretAccessKey /tmp/wd-creds.json) \
	 AWS_SESSION_TOKEN=$$(jq -r .SessionToken /tmp/wd-creds.json) \
	   aws logs tail /ecs/sre-reference-app --follow --format short
	@rm /tmp/wd-creds.json
