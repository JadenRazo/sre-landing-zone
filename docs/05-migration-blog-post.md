# Day-2 SRE: turning a single-account ECS app into a multi-account landing zone for $43

After the GameDay finished, [sre-reference-app](https://github.com/JadenRazo/sre-reference-app) was a snapshot. One AWS account, one VPC, one ALB, one Fargate task. The Terraform was clean — that's not a knock on the original work — but it was a *demo* of SRE practices, not a production posture. **The interesting question was always: what do you actually need to add to call this Day-2?**

I gave myself $120 of AWS credits, an 8–10 week runway to AWS SAA-C03, and a constraint: no fake demos, every diagram has to come from infrastructure that actually ran.

This is what came out of it: [sre-landing-zone](https://github.com/JadenRazo/sre-landing-zone), the multi-account evolution of the same workload. Five AWS accounts, a Pilot-Light DR region, an edge layer, cross-account auto-stop, and an audit pipeline that survives a workload account compromise. Total spend at apply time: **$43**.

## What I added (and what I didn't)

The thing I keep coming back to in cert prep is that the SAA exam isn't really about services — it's about *which decisions matter*. Here's the decision matrix that drove the build:

**Cost decisions.** NAT Gateway is $32/mo, alone, untouched. That's 27% of the budget burned passively. The "right" SAA-flavored answer is to replace NAT with VPC Interface Endpoints. The honest answer is that 4 endpoints across 2 AZs is *worse* than NAT ($58/mo vs $32/mo). I wrote the endpoint pattern down as a documented alternative and defaulted to NAT + strict `make down` discipline. Same teaching point, much smaller blast radius for a budget mistake.

**Security decisions.** Four SCPs at the OU level, not five. AWS Tag Policies have a frustrating schema gotcha that took two hours of debugging to figure out (Terraform's wrapper schema didn't match what AWS actually accepted). I deferred the Tag Policy from Phase 0 to Phase 6, where I bypassed Terraform's wrapper and used the CLI directly. Lesson: when the platform abstraction fights you, drop down a layer.

**DR decisions.** Pilot Light, not Warm Standby. Standby ECS service runs at `desired_count=0`; Fargate at 0 tasks costs $0. The DR ALB stays warm at $16/mo because Cloud-init for a fresh ALB takes 90+ seconds and that would dominate RTO. ECR cross-region replication is $0.10/mo. DynamoDB Global Table: $0 at idle volumes. Total DR cost while up: ~$17/mo.

**What I deliberately didn't build.** EKS — control plane is $73/mo and I'm not learning Kubernetes by paying for an empty cluster. Aurora Serverless v2 — $43/mo at minimum 0.5 ACU. Transit Gateway — $36/mo + per-attachment, and VPC peering does what I need. AZ-204 hands-on — Azure equivalents are documented inline but I have no Azure credits. These are explicitly out-of-scope decisions, written down, defended in the README.

## The audit account is the one that matters

The decision I'd defend the hardest to a reviewer is the `log-archive` account having zero IAM principals beyond the org access role. Every account in the org ships CloudTrail events there, S3 has Object Lock + KMS + a deny-insecure-transport bucket policy, and the only way to mutate the trail is through the management account. **If a workload account credential leaks tomorrow, the audit trail proves what happened — that's the entire point of the architecture.**

This is the CCSP Domain 6 conversation in concrete form. Not a diagram of "centralized logging" — an actual account with a deliberately-restricted blast radius.

## The cost-control loop is what made it sustainable

The thing that surprised me — and that I'd argue is the most underrated piece of the SAA curriculum — is how much cost discipline shapes architecture. Every decision I made was dual-graded on (a) does this teach the SAA concept and (b) can I actually leave it running while I sleep.

The auto-stop Lambda landed in Phase 6 in the original plan. I moved it to Phase 2 after the first weekend of NAT-running-while-I-was-not-paying-attention. **Cost discipline is not a separate phase; it's a Phase 0 constraint that I should have wired in alongside the Org bootstrap.**

The pattern that ended up working:

```
EventBridge cron @ 8 PM PST
  → Lambda in mgmt account
  → assumes AutoStopExecutorRole in workloads-dev
  → ecs:UpdateService desired_count=0
```

The Lambda's mgmt-side role has only `sts:AssumeRole`. The executor role in workloads-dev has only `ecs:UpdateService` scoped to ONE service ARN. **This is the canonical least-privilege cross-account automation pattern, and it's the kind of thing that comes up verbatim in interviews.**

## What I'd do differently

Three things, ordered by importance:

1. **Wire the cost controls in Phase 0, not Phase 6.** I knew this was the right answer when I started; I wrote it down in the original plan; I still moved it to Phase 6 because "first get the workload running." That cost me $4 of NAT in week 1.

2. **Skip Tag Policy in Phase 0.** Terraform's `aws_organizations_policy` for `TAG_POLICY` returns `MalformedPolicyDocumentException` for reasons that don't match AWS's published schema. I lost 90 minutes to it. The Phase 6 retry via `aws organizations create-policy` worked first try. **When a Terraform abstraction has obscure failure modes, going direct to the CLI is faster than debugging the wrapper.**

3. **Push the real `sre-reference-app` image earlier.** I deployed nginx as a placeholder for the first 3 phases because it's faster. The CloudWatch dashboards looked boring (flat-line green) until I pushed the real Flask app with the intentional 5% error rate. **The portfolio screenshots only become compelling once the dashboard has actual signal on it.**

## The honest cost breakdown

| Phase | What's running | $/hr while up | Days to apply |
|---|---|---|---|
| 0 — Org bootstrap | Org, OUs, SCPs, Identity Center, SSM | $0 | 1 |
| 1 — Security baseline | CloudTrail, GuardDuty, Security Hub, Config, KMS | $0.012 | 1 |
| 2 — Workload | VPC + NAT + ALB + Fargate | $0.080 | 2 |
| 3 — DR | DR ALB + DDB Global + R53 health checks | $0.025 | 1 |
| 4 — Edge | CloudFront free, WAF $5/mo + 3 rules | $0.011 | 1 |
| 5 — Write-up | Diagrams + docs | $0 | 1 |
| 6 — Cost controls | Lambda + EventBridge | $0 | 1 |

Total run cost over the build: ~$43. Buffer remaining for additional study sessions + the SAA exam fee timeline: ~$77.

## The deliverable

GitHub: [github.com/JadenRazo/sre-landing-zone](https://github.com/JadenRazo/sre-landing-zone). Seven architecture diagrams generated from a single Python script (`diagrams/architecture.py`). Thirteen console screenshots captured during apply. Six phases of Terraform under `infra/`. Docs include this post, the 6 R's analysis, the failover drill writeup, the cost ledger, and an Azure equivalents table for AZ-204 conceptual prep.

The thing I want this project to be is honest. The screenshots show the actual ALB DNS. The cost numbers are the actuals from `aws ce get-cost-and-usage`. The "I made this decision because" sections explain the trade-offs I considered, not just the decisions I landed on.

The thing I learned, doing this: **cert prep that doesn't run on real infrastructure produces certifiable people who haven't built anything.** Eight weeks of real apply/destroy cycles taught me more about AWS architecture than the previous year of reading exam guides.

---

*If you're reading this for hiring purposes — the Terraform is at [github.com/JadenRazo/sre-landing-zone](https://github.com/JadenRazo/sre-landing-zone). Specific decisions I'd love to talk about: the NAT-vs-endpoints cost calculation, why the audit account has no IAM principals, the cross-account assume-role pattern in the auto-stop Lambda, and the SCP that I deferred and why.*
