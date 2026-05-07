# Compliance control mapping

Each phase's resources mapped to specific controls in **SOC 2 (Trust Services Criteria 2017)**, **ISO/IEC 27001:2022 Annex A**, and the **AWS Well-Architected Security Pillar** (which CCSP Domain 5 leans heavily on). The mapping is conservative — claims listed here are demonstrably satisfied by deployed resources, not aspirational.

This is the artifact a security auditor or CCSP-aspirant would actually want.

## Summary by framework

| Framework | Controls satisfied | Phase coverage |
|---|---|---|
| SOC 2 Common Criteria (CC6.x — Logical Access) | CC6.1, CC6.2, CC6.3, CC6.6, CC6.7, CC6.8 | Phases 0, 1, 2, 4, 7 |
| SOC 2 CC7.x (System Operations) | CC7.1, CC7.2, CC7.3 | Phases 1, 2, 6 |
| SOC 2 CC8.x (Change Management) | CC8.1 | Phase 7 |
| SOC 2 A1.x (Availability) | A1.1, A1.2, A1.3 | Phases 2, 3, 6 |
| ISO 27001 A.5 (Organizational) | A.5.15, A.5.18, A.5.31 | Phases 0, 6 |
| ISO 27001 A.8 (Asset/Access) | A.8.2, A.8.3, A.8.5, A.8.7, A.8.15, A.8.16, A.8.24, A.8.28 | Phases 0, 1, 2, 4 |
| AWS Well-Architected Security | SEC01–SEC11 | All phases |

## Detailed mapping — by control

### SOC 2 Trust Services Criteria

#### CC6.1 — Logical access controls restrict access to authorized users
| Evidence | Phase | Where |
|---|---|---|
| AWS Organizations multi-account boundary | 0 | `infra/00-org-bootstrap/main.tf` |
| IAM Identity Center as the only human-access path (no IAM users for employees) | 0 | `infra/00-org-bootstrap/identity-center.tf` |
| 4 SCPs at OU level (deny-root, deny-non-approved-regions, IMDSv2, deny-disable-security) | 0 | `infra/00-org-bootstrap/scps.tf` |
| Cognito User Pool with password complexity + optional MFA | 4 | `infra/04-edge-and-data/cognito.tf` |
| GitHub Actions OIDC role (federated, no static keys) | 7 | `infra/07-cicd/main.tf` |

#### CC6.2 — Prior to issuing credentials, identity is authenticated
| Evidence | Phase | Where |
|---|---|---|
| Identity Center user creation requires email-link verification | 0 | console step (Phase 0 README §3) |
| Cognito email-verified attribute required | 4 | `cognito.tf` `auto_verified_attributes = ["email"]` |
| GitHub OIDC trust policy gates `sub = repo:JadenRazo/sre-landing-zone:*` | 7 | `infra/07-cicd/main.tf` |

#### CC6.3 — Access to data and systems is restricted based on role
| Evidence | Phase | Where |
|---|---|---|
| Permission sets (AdminAccess / PowerUserAccess / ReadOnly / BillingOnly) — least-privilege RBAC | 0 | `identity-center.tf` |
| Auto-stop Lambda's executor role is `ecs:UpdateService` ONLY, scoped by tag condition | 6 | `auto-stop-iam.tf` |
| log-archive S3 bucket policy allows only CloudTrail / Config service principals to write | 1 | `log-archive-bucket.tf` |

#### CC6.6 — Logical access security measures protect against threats
| Evidence | Phase | Where |
|---|---|---|
| GuardDuty org-wide threat detection | 1 | `guardduty.tf` |
| AWS WAF on CloudFront (CommonRuleSet, KnownBadInputs, RateLimitPerIP) | 4 | `waf.tf` |
| Security Hub continuous compliance posture (AFSBP + CIS) | 1 | `security-hub.tf` |
| `RequireIMDSv2` SCP closes SSRF→credential exfil path | 0 | `scps.tf` |

#### CC6.7 — System data transmission protected
| Evidence | Phase | Where |
|---|---|---|
| KMS-encrypted S3 for all CloudTrail + Config logs | 1 | `log-archive-bucket.tf` |
| Bucket policy denies `aws:SecureTransport=false` (TLS-only) | 1 | `log-archive-bucket.tf` |
| Secrets Manager for runtime config (KMS-encrypted at rest, in-transit via AWS APIs) | 2 | `secrets.tf` |
| CloudFront viewer-protocol-policy: `redirect-to-https` | 4 | `cloudfront.tf` |

#### CC6.8 — System protected against unauthorized changes
| Evidence | Phase | Where |
|---|---|---|
| `DenyDisablingSecurityServices` SCP (CloudTrail/Config/GuardDuty/SecurityHub) | 0 | `scps.tf` |
| Org-level CloudTrail can't be modified by member accounts | 1 | `cloudtrail.tf` `is_organization_trail = true` |
| ECR `image_scanning_configuration { scan_on_push = true }` | 2 | `ecr.tf` |
| GitHub Environment "production" gates apply with required reviewers | 7 | `.github/workflows/apply.yml` |

#### CC7.1 — Detection and monitoring of system operations
| Evidence | Phase | Where |
|---|---|---|
| Org-wide CloudTrail | 1 | `cloudtrail.tf` |
| Two burn-rate alarms (1h@14.4× / 6h@6×) per Google SRE Workbook | 2 | `observability.tf` |
| GuardDuty + Security Hub aggregator | 1 | `guardduty.tf`, `security-hub.tf` |
| Cost Anomaly Detection (CUSTOM monitor) | 6 | `cost-anomaly.tf` |

#### CC7.2 — Anomalies and indicators of compromise are evaluated
| Evidence | Phase | Where |
|---|---|---|
| Security Hub finding aggregation across 5 accounts | 1 | (delegated to audit-security) |
| GuardDuty finding publishing every 6 hours | 1 | `guardduty.tf` |

#### CC7.3 — Incidents are responded to and resolved
| Evidence | Phase | Where |
|---|---|---|
| SNS topic `sre-budget-alerts` with email subscription | 1 | `budgets.tf` |
| Documented failover drill with measured RTO | 3 | `infra/03-dr-pilot-light/failover-drill.sh`, `docs/04-failover-drill.md` |

#### CC8.1 — Authorized system changes
| Evidence | Phase | Where |
|---|---|---|
| All infrastructure changes go through Terraform | all | every phase is IaC-defined |
| GitHub Actions plan-on-PR gate | 7 | `.github/workflows/plan.yml` |
| Manual approval required for apply via GitHub Environment "production" | 7 | `.github/workflows/apply.yml` |

#### A1.1 — Capacity is assessed and managed
| Evidence | Phase | Where |
|---|---|---|
| ECS Fargate auto-scaling task definition with explicit CPU/memory | 2 | `ecs.tf` |
| ALB across 2 AZs | 2 | `network.tf` |
| AWS Budgets at 4 forecast thresholds | 1 | `budgets.tf` |

#### A1.2 — Environmental protection
| Evidence | Phase | Where |
|---|---|---|
| Multi-AZ deployment | 2 | `network.tf` `az_count = 2` |
| Pilot-Light DR to second region | 3 | all of `infra/03-dr-pilot-light/` |

#### A1.3 — Recovery is tested
| Evidence | Phase | Where |
|---|---|---|
| Documented + repeatable failover drill | 3 | `failover-drill.sh`, `docs/04-failover-drill.md` |

---

### ISO/IEC 27001:2022 Annex A

| Control | Title | Phase | Evidence |
|---|---|---|---|
| **A.5.15** | Access control | 0 | Identity Center + permission sets + SCPs |
| **A.5.18** | Access rights | 0, 7 | Permission sets, GitHub OIDC role least-privilege |
| **A.5.31** | Legal/contractual requirements | 1, 6 | KMS encryption (data-at-rest), audit trail (logging requirements) |
| **A.8.2** | Privileged access rights | 0 | Root MFA + SCPs preventing root usage |
| **A.8.3** | Information access restriction | 0, 1 | Per-account separation, log-archive zero-IAM-principals |
| **A.8.5** | Secure authentication | 0, 4 | Identity Center MFA, Cognito MFA-optional |
| **A.8.7** | Protection against malware | 1 | GuardDuty threat detection |
| **A.8.15** | Logging | 1 | Org CloudTrail + per-app CloudWatch Logs |
| **A.8.16** | Monitoring activities | 1, 2 | Security Hub + burn-rate alarms |
| **A.8.24** | Use of cryptography | 1, 4 | KMS CMK with rotation, ACM for TLS |
| **A.8.28** | Secure coding | 7 | CI/CD plan-on-PR gates Terraform changes |

---

### AWS Well-Architected — Security Pillar (high-level)

| Pillar question | Phase | Status |
|---|---|---|
| **SEC01** — How do you securely operate your workload? | 0 | Org + SCPs + Identity Center ✓ |
| **SEC02** — How do you manage identities for people and machines? | 0, 4, 7 | SSO + Cognito + OIDC ✓ |
| **SEC03** — How do you manage permissions? | 0, 6 | Permission sets + tag-conditioned IAM policies ✓ |
| **SEC04** — How do you detect and investigate security events? | 1 | CloudTrail + GuardDuty + Security Hub ✓ |
| **SEC05** — How do you protect your network? | 2, 4 | Private subnets + Security Groups + WAF ✓ |
| **SEC06** — How do you protect compute? | 2 | Fargate (no EC2 patching) + IMDSv2 SCP ✓ |
| **SEC07** — How do you classify data? | n/a | demo workload has no PII; not classified |
| **SEC08** — How do you protect data at rest? | 1, 2, 6 | KMS for S3/Secrets, AES256 for ECR ✓ |
| **SEC09** — How do you protect data in transit? | 1, 4 | bucket-policy `aws:SecureTransport`, CloudFront HTTPS-redirect ✓ |
| **SEC10** — How do you anticipate and respond to incidents? | 1, 3 | SNS alerts, documented DR drill ✓ |
| **SEC11** — How do you incorporate security into the dev process? | 7 | OIDC + plan-on-PR + manual-approve apply ✓ |

---

## Gaps (the honest part)

These are SOC 2 / ISO 27001 controls that this project **does not satisfy** without additional work. Listing them here demonstrates awareness — auditors prefer "we know we don't have this" over "we forgot to think about this."

| Gap | What's missing | Effort |
|---|---|---|
| CC6.4 (physical access) | Out of scope for cloud-only project (AWS handles physical security) | n/a |
| CC9.x (vendor management) | No third-party SaaS reviewed | days |
| Privacy criteria (P1–P8) | Demo workload has no PII; not applicable until real data introduced | n/a |
| ISO A.5.30 (ICT readiness for business continuity) | DR drill exists but no formal BCP document | hours |
| ISO A.6 (people security) | No employee handbook / security training program | weeks |
| Data classification scheme | Workload data is synthetic; no scheme defined | hours |
| Access reviews | No quarterly review process documented | hours per quarter |
| Pen test / red team | None performed | days/weeks |

The deployed controls are a foundation, not a complete compliance posture. A real audit-ready environment layers process (training, reviews, BCP/DR documentation, vendor management) on top of the technical controls — and a portion of that process is necessarily organizational, not infrastructural.

---

## CCSP exam relevance (per domain)

| CCSP Domain | What this project demonstrates |
|---|---|
| **D1 — Cloud Concepts/Architecture** | Multi-account topology, shared responsibility model in action |
| **D2 — Cloud Data Security** | KMS at rest, TLS in transit, S3 lifecycle, log-archive isolation |
| **D3 — Cloud Platform/Infra Security** | VPC segmentation, Security Groups, WAF, IMDSv2 enforcement |
| **D4 — Cloud Application Security** | Cognito federation pattern, CI/CD gates, ECR image scanning |
| **D5 — Cloud Sec Ops** | CloudTrail org trail, Config aggregator, GuardDuty, Security Hub |
| **D6 — Legal/Risk/Compliance** | Audit trail with Object Lock, control mapping (this doc) |

Use this document as conversation starter for CCSP-themed interview questions: "show me how you'd satisfy CC6.7 in a real cloud workload" → point at this file.
