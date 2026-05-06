#!/usr/bin/env bash
# preflight.sh — read-only checks before any terraform apply
# Verifies: AWS CLI present, identity resolvable, region pinned, Org state matches expectation.
set -euo pipefail

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

echo "── preflight ─────────────────────────────────────────"

if ! command -v aws >/dev/null 2>&1; then
  red "FAIL: aws CLI not installed"
  exit 1
fi
green "OK: aws CLI $(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)"

if ! command -v terraform >/dev/null 2>&1; then
  red "FAIL: terraform not installed"
  exit 1
fi
green "OK: terraform $(terraform version | head -1 | awk '{print $2}')"

IDENTITY=$(aws sts get-caller-identity 2>&1)
if [ $? -ne 0 ]; then
  red "FAIL: aws sts get-caller-identity failed"
  echo "$IDENTITY"
  exit 1
fi
ACCOUNT=$(echo "$IDENTITY" | grep -oP '"Account": "\K[^"]+')
ARN=$(echo "$IDENTITY" | grep -oP '"Arn": "\K[^"]+')
green "OK: account $ACCOUNT, identity $ARN"

REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$REGION" ]; then
  yellow "WARN: no default region set; export AWS_REGION=us-west-2"
elif [ "$REGION" != "us-west-2" ]; then
  yellow "WARN: default region is $REGION (expected us-west-2 for this project)"
else
  green "OK: region us-west-2"
fi

echo "── Org state ─────────────────────────────────────────"
ORG=$(aws organizations describe-organization 2>&1 || true)
if echo "$ORG" | grep -q "AWSOrganizationsNotInUseException"; then
  yellow "Org NOT enabled — Phase 0 will create it"
elif echo "$ORG" | grep -q '"Id": "o-'; then
  ORG_ID=$(echo "$ORG" | grep -oP '"Id": "\Ko-[^"]+')
  MASTER=$(echo "$ORG" | grep -oP '"MasterAccountId": "\K[^"]+')
  if [ "$MASTER" != "$ACCOUNT" ]; then
    red "FAIL: this account ($ACCOUNT) is a member of Org $ORG_ID owned by $MASTER, not the management account"
    exit 1
  fi
  green "OK: Org $ORG_ID exists, current account is the management account"
else
  red "FAIL: unexpected describe-organization output"
  echo "$ORG"
  exit 1
fi

echo "── ready ─────────────────────────────────────────────"
green "Preflight passed. Review infra/00-org-bootstrap/README.md before applying."
