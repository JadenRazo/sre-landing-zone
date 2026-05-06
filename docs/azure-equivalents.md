# Azure equivalents (AZ-204 conceptual cross-reference)

Same hands-on AWS work doubles as conceptual prep for AZ-204 by mapping every component to its Azure analog. **This is not a substitute for AZ-204 hands-on practice** — but it makes the eventual switch much faster.

## Identity & governance

| AWS (this project) | Azure analog |
|---|---|
| AWS Organizations | Microsoft Entra ID Tenant + Management Groups |
| Organizational Unit | Management Group |
| Member account | Subscription |
| Service Control Policy (SCP) | Azure Policy (deny / audit assignments at MG scope) |
| Tag Policy | Azure Policy `Require a tag and its value` |
| IAM Identity Center | Microsoft Entra ID + Privileged Identity Management |
| Permission set | Entra role assignment (built-in role or custom) |
| IAM role | Managed identity / service principal |
| KMS | Azure Key Vault |
| Secrets Manager | Azure Key Vault Secrets |

## Networking

| AWS | Azure |
|---|---|
| VPC | Virtual Network (VNet) |
| Subnet (public/private) | Subnet (with route table differences) |
| Internet Gateway | (implicit — system route) |
| NAT Gateway | NAT Gateway (Azure has the same, ~similar cost) |
| Security Group | Network Security Group (NSG) |
| ALB | Application Gateway (or Front Door for global) |
| NLB | Standard Load Balancer |
| VPC Interface Endpoint | Private Endpoint |
| VPC Gateway Endpoint (S3) | Service Endpoint |
| Transit Gateway | Virtual WAN / VNet Peering |
| Route 53 | Azure DNS / Traffic Manager / Front Door |

## Compute & data

| AWS | Azure |
|---|---|
| ECS Fargate | Container Apps (closest) / AKS (heavier) |
| ECR | Azure Container Registry |
| Lambda | Azure Functions |
| RDS Postgres | Azure Database for PostgreSQL (Flexible Server) |
| DynamoDB | Cosmos DB (NoSQL API) |
| S3 | Azure Blob Storage |
| S3 lifecycle (Standard → IA → Glacier) | Blob lifecycle (Hot → Cool → Cold → Archive) |
| CloudFront | Front Door |
| WAF | Front Door WAF / Application Gateway WAF |
| Cognito | Microsoft Entra External ID (B2C) |

## Observability & ops

| AWS | Azure |
|---|---|
| CloudWatch Logs | Azure Monitor Log Analytics |
| CloudWatch Metrics | Azure Monitor Metrics |
| CloudWatch Alarms | Azure Monitor Alerts |
| CloudTrail | Azure Activity Log + Diagnostic Settings |
| AWS Config | Azure Policy compliance + Resource Graph |
| GuardDuty | Microsoft Defender for Cloud |
| Security Hub | Defender for Cloud (compliance dashboard) |
| AWS Budgets | Azure Cost Management Budgets |
| Cost Anomaly Detection | Cost Management Anomaly Detection |
| Trusted Advisor | Azure Advisor |

## Disaster recovery

| AWS | Azure |
|---|---|
| Pilot Light pattern | Azure Site Recovery (cross-region) |
| Multi-region DynamoDB Global Table | Cosmos DB multi-region writes |
| Route 53 health-check failover | Traffic Manager priority routing |
| ECR cross-region replication | ACR geo-replication |
| S3 Cross-Region Replication | Geo-redundant storage (GRS / RA-GRS) |

## CI/CD & IaC

| AWS | Azure |
|---|---|
| GitHub Actions + OIDC to AWS role | GitHub Actions + OIDC to Entra app registration |
| Terraform AWS provider | Terraform AzureRM provider / Bicep |
| CloudFormation | ARM templates / Bicep |
| AWS CDK | Bicep / Pulumi |
| CodePipeline / CodeBuild | Azure DevOps Pipelines |
