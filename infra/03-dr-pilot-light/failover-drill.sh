#!/usr/bin/env bash
# failover-drill.sh — chaos drill for the Pilot Light DR pattern.
#
# Procedure:
#   1. Confirm primary serving 200s
#   2. Scale primary to 0
#   3. Watch Route 53 health-check status flip
#   4. Scale DR to 2 (and pin desired-count, since Phase 3 ignores changes)
#   5. Confirm DR serving 200s; capture timing
#   6. Reverse: scale primary back, scale DR to 0
#
# Run from infra/03-dr-pilot-light/ after `terraform apply`.
set -euo pipefail

GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; NC='\033[0m'

WORKLOADS_DEV=$(jq -r .workloads_dev <<<"$(aws ssm get-parameter --name /sre-landing-zone/account-map --query Parameter.Value --output text)")
PRIMARY_REGION="us-west-2"
DR_REGION="us-east-1"

assume_role() {
  aws sts assume-role \
    --role-arn "arn:aws:iam::$WORKLOADS_DEV:role/OrganizationAccountAccessRole" \
    --role-session-name "failover-drill" \
    --query Credentials --output json > /tmp/wd-creds.json
  export AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId /tmp/wd-creds.json)
  export AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey /tmp/wd-creds.json)
  export AWS_SESSION_TOKEN=$(jq -r .SessionToken /tmp/wd-creds.json)
}

cleanup() {
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  rm -f /tmp/wd-creds.json
}
trap cleanup EXIT

assume_role

PRIMARY_ALB=$(aws elbv2 describe-load-balancers --region $PRIMARY_REGION --names sre-alb --query "LoadBalancers[0].DNSName" --output text)
DR_ALB=$(aws elbv2 describe-load-balancers --region $DR_REGION --names sre-alb-dr --query "LoadBalancers[0].DNSName" --output text)

echo -e "${YELLOW}── Pre-flight ──${NC}"
echo "Primary ALB: http://$PRIMARY_ALB"
echo "DR ALB:      http://$DR_ALB"
echo ""

primary_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$PRIMARY_ALB/" --max-time 5 || echo "fail")
echo -e "Primary GET / → ${primary_code}"
if [ "$primary_code" != "200" ]; then
  echo -e "${RED}Primary not healthy. Aborting drill.${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}── Step 1: Scale PRIMARY to 0 ──${NC}"
aws ecs update-service --region $PRIMARY_REGION \
  --cluster sre-workloads-dev --service sre-reference-app \
  --desired-count 0 --query "service.desiredCount" --output text > /dev/null
START=$(date +%s)
echo "Primary scaled to 0 at $(date -u +%H:%M:%S) UTC"

echo ""
echo -e "${YELLOW}── Step 2: Scale DR to 2 ──${NC}"
aws ecs update-service --region $DR_REGION \
  --cluster sre-workloads-dev-dr --service sre-reference-app \
  --desired-count 2 --query "service.desiredCount" --output text > /dev/null
echo "DR scaled to 2 at $(date -u +%H:%M:%S) UTC"

echo ""
echo -e "${YELLOW}── Step 3: Wait for DR to serve 200 ──${NC}"
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://$DR_ALB/" --max-time 5 || echo "fail")
  echo "  attempt $i: $code"
  if [ "$code" = "200" ]; then
    END=$(date +%s)
    ELAPSED=$((END - START))
    echo -e "${GREEN}DR healthy after ${ELAPSED}s.${NC}"
    break
  fi
  sleep 15
done

echo ""
echo -e "${YELLOW}── Step 4: Reverse — scale PRIMARY back to 1, DR to 0 ──${NC}"
aws ecs update-service --region $PRIMARY_REGION \
  --cluster sre-workloads-dev --service sre-reference-app \
  --desired-count 1 --query "service.desiredCount" --output text > /dev/null
aws ecs update-service --region $DR_REGION \
  --cluster sre-workloads-dev-dr --service sre-reference-app \
  --desired-count 0 --query "service.desiredCount" --output text > /dev/null

echo -e "${GREEN}Drill complete.${NC} Capture this terminal as screenshots/10-failover-drill.png."
