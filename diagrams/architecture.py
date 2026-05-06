"""Architecture diagrams for sre-landing-zone.

Generates 7 PNGs at 200+ DPI under docs/. Each diagram is a self-contained
function. Run with:

    cd diagrams && python architecture.py

Requires: pip install diagrams + system Graphviz.
"""
import os
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECR, ECS, ElasticContainerServiceService, Fargate, Lambda
from diagrams.aws.cost import Budgets, CostExplorer
from diagrams.aws.database import Dynamodb
from diagrams.aws.general import GenericSamlToken, User
from diagrams.aws.integration import Eventbridge, SimpleNotificationServiceSnsTopic
from diagrams.aws.management import (
    Cloudtrail,
    Cloudwatch,
    CloudwatchAlarm,
    Config,
    Organizations,
    OrganizationsAccount,
)
from diagrams.aws.network import (
    ALB,
    CloudFront,
    InternetGateway,
    NATGateway,
    PrivateSubnet,
    PublicSubnet,
    Route53,
    VPC,
)
from diagrams.aws.security import (
    Cognito,
    Guardduty,
    IAMAWSSts,
    IAMRole,
    KMS,
    SecretsManager,
    SecurityHub,
    WAF,
)
from diagrams.aws.storage import S3, S3Glacier
from diagrams.onprem.client import Users as ClientUsers


# Output directory: ../docs relative to this script.
OUT_DIR = Path(__file__).parent.parent / "docs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Common Graphviz attributes — applied to every Diagram.
GRAPH_ATTR = {
    "fontsize": "14",
    "fontname": "Helvetica",
    "splines": "spline",
    "concentrate": "false",
    "ranksep": "1.0",
    "nodesep": "0.6",
    "dpi": "220",
    "pad": "0.4",
    "bgcolor": "white",
}
NODE_ATTR = {"fontname": "Helvetica", "fontsize": "12"}
EDGE_ATTR = {"fontname": "Helvetica", "fontsize": "10", "color": "#555555"}


def landing_zone():
    """Diagram 1: 5-account Organization overview with OUs and SCPs."""
    with Diagram(
        "AWS Landing Zone — Multi-Account Organization",
        show=False,
        filename=str(OUT_DIR / "architecture-landing-zone"),
        outformat="png",
        direction="TB",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        users = User("Engineer\n(jadenrazo)")
        identity_center = GenericSamlToken("IAM Identity Center\n(SSO + 4 permission sets)")

        with Cluster("AWS Organization (o-9itq8iim1q)\n4 SCPs at OU level: deny-root, deny-non-approved-regions, IMDSv2, deny-disable-security"):
            mgmt = OrganizationsAccount("management\n569239324174")

            with Cluster("Security OU"):
                log_archive = OrganizationsAccount("log-archive\n378356707832")
                audit_security = OrganizationsAccount("audit-security\n995303881355")

            with Cluster("Workloads OU"):
                workloads_dev = OrganizationsAccount("workloads-dev\n422783588447")
                workloads_prod = OrganizationsAccount("workloads-prod\n648664873534")

            with Cluster("Sandbox OU"):
                sandbox = OrganizationsAccount("(reserved)")

        users >> Edge(label="SSO login") >> identity_center
        identity_center >> Edge(label="federate", style="dashed") >> [mgmt, log_archive, audit_security, workloads_dev, workloads_prod]


def runtime():
    """Diagram 2: workloads-dev runtime — request flow through CloudFront/ALB/ECS."""
    with Diagram(
        "Runtime — workloads-dev (us-west-2)",
        show=False,
        filename=str(OUT_DIR / "architecture-runtime"),
        outformat="png",
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        users = ClientUsers("Internet\nclient")
        cloudfront = CloudFront("CloudFront\n+ WAF (3 rules)")

        with Cluster("VPC 10.0.0.0/16 — workloads-dev"):
            igw = InternetGateway("IGW")

            with Cluster("AZ us-west-2a"):
                pub_a = PublicSubnet("public 10.0.0.0/24")
                priv_a = PrivateSubnet("private 10.0.10.0/24")
                nat = NATGateway("NAT Gateway\n($32/mo)")

            with Cluster("AZ us-west-2b"):
                pub_b = PublicSubnet("public 10.0.1.0/24")
                priv_b = PrivateSubnet("private 10.0.11.0/24")

            alb = ALB("ALB\nsre-alb")

            with Cluster("ECS Fargate"):
                task = Fargate("sre-reference-app\n(Python/Flask, ERROR_RATE=0.05)")

        ecr = ECR("ECR\nsre-reference-app")
        secrets = SecretsManager("Secrets Manager\nerror-rate")
        cw = Cloudwatch("CloudWatch\nLogs + Dashboard")
        alarms = CloudwatchAlarm("Burn-rate alarms\n1h@14.4× / 6h@6×")

        users >> Edge(label="HTTPS") >> cloudfront >> Edge(label="HTTP origin") >> alb
        alb >> Edge(label="forward :8080") >> task
        task << Edge(label="pull image", style="dashed") << ecr
        task << Edge(label="GetSecretValue\nat boot", style="dashed") << secrets
        task >> Edge(label="JSON logs", style="dashed") >> cw
        cw >> Edge(label="metric query") >> alarms


def security_baseline():
    """Diagram 3: org-wide audit data flow (Phase 1)."""
    with Diagram(
        "Security & Audit Baseline — Org-wide",
        show=False,
        filename=str(OUT_DIR / "architecture-security-baseline"),
        outformat="png",
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        with Cluster("All Org accounts (5)"):
            mgmt = OrganizationsAccount("management")
            wd = OrganizationsAccount("workloads-dev")
            wp = OrganizationsAccount("workloads-prod")
            sandbox = OrganizationsAccount("sandbox")
            origins = [mgmt, wd, wp, sandbox]

        with Cluster("log-archive account\n(passive — no IAM principals)"):
            kms = KMS("KMS CMK\n(rotated yearly)")
            log_bucket = S3("sre-log-archive-bucket\n(Object Lock + lifecycle)")
            kms >> Edge(label="encrypt", style="dashed") >> log_bucket

        with Cluster("audit-security account\n(delegated admin)"):
            cloudtrail = Cloudtrail("Org CloudTrail\nsre-org-trail")
            config = Config("AWS Config\nrecorder + 8 rules + aggregator")
            guardduty = Guardduty("GuardDuty\norg-wide auto-enroll")
            sechub = SecurityHub("Security Hub\nAFSBP + CIS 1.4")

        for src in origins:
            src >> Edge(label="all API events") >> cloudtrail
        cloudtrail >> Edge(label="ship encrypted") >> log_bucket

        for src in origins:
            src >> Edge(label="config changes", style="dashed") >> config
            src >> Edge(label="threat findings", style="dashed") >> guardduty

        config >> sechub
        guardduty >> sechub


def dr_pilot_light():
    """Diagram 4: Pilot Light DR across regions."""
    with Diagram(
        "DR — Pilot Light: us-west-2 (active) ↔ us-east-1 (standby)",
        show=False,
        filename=str(OUT_DIR / "architecture-dr-pilot-light"),
        outformat="png",
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        users = ClientUsers("Internet\nclient")
        r53 = Route53("Route 53\nhealth-checked failover")

        with Cluster("us-west-2 (PRIMARY)"):
            primary_alb = ALB("sre-alb")
            primary_task = Fargate("ECS @ 1 task")
            primary_ecr = ECR("ECR")
            primary_ddb = Dynamodb("DynamoDB Global\nsre-feature-flags")
            primary_alb >> primary_task

        with Cluster("us-east-1 (STANDBY)"):
            dr_alb = ALB("sre-alb-dr\n(warm, no targets)")
            dr_task = Fargate("ECS @ 0 tasks\n(failover scales to 2)")
            dr_ecr = ECR("ECR\n(replica)")
            dr_ddb = Dynamodb("DynamoDB Global\nsre-feature-flags")
            dr_alb >> Edge(style="dotted", label="(scaled to 0)") >> dr_task

        users >> r53
        r53 >> Edge(label="primary route\n(healthy)", color="green") >> primary_alb
        r53 >> Edge(label="failover route\n(unhealthy)", color="red", style="dashed") >> dr_alb
        primary_ecr >> Edge(label="cross-region\nreplication", style="dashed") >> dr_ecr
        primary_ddb << Edge(label="LWW replication\nbi-directional", style="dashed", dir="both") >> dr_ddb


def edge_stack():
    """Diagram 5: edge — CloudFront + WAF + Cognito."""
    with Diagram(
        "Edge — CloudFront + WAF + Cognito",
        show=False,
        filename=str(OUT_DIR / "architecture-edge"),
        outformat="png",
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        users = ClientUsers("Internet\nclient")

        with Cluster("Edge (us-east-1 for ACM + WAF)"):
            cf = CloudFront("CloudFront\nPriceClass_100\ngeo-restrict: US/CA/MX/GB")
            waf = WAF("WAF\nCommonRuleSet\nKnownBadInputs\nRateLimit 1k/5min")
            waf >> Edge(label="attached to") >> cf

        with Cluster("Identity"):
            cognito = Cognito("Cognito User Pool\nsre-users\nMFA optional + Hosted UI")

        with Cluster("Origin (us-west-2)"):
            alb = ALB("sre-alb")
            ecs = Fargate("ECS")
            alb >> ecs

        with Cluster("Logs (lifecycle)"):
            s3 = S3("Standard")
            s3_ia = S3("Standard-IA\n@ 30d")
            glacier = S3Glacier("Glacier IR\n@ 90d")
            deep = S3Glacier("Deep Archive\n@ 365d")
            s3 >> Edge(label="tier-down", style="dashed") >> s3_ia >> glacier >> deep

        users >> Edge(label="HTTPS") >> cf
        cf >> Edge(label="HTTP origin") >> alb
        users >> Edge(label="auth flow", style="dashed", color="blue") >> cognito


def cost_controls():
    """Diagram 6: cost discipline — auto-stop Lambda + anomaly detection."""
    with Diagram(
        "Cost Controls — Auto-stop + Anomaly Detection",
        show=False,
        filename=str(OUT_DIR / "architecture-cost-controls"),
        outformat="png",
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        with Cluster("management account"):
            schedule = Eventbridge("EventBridge\ncron(0 4 * * ? *)\n8 PM PST daily")
            lambda_fn = Lambda("sre-auto-stop\n(Python 3.12)")
            lambda_role = IAMRole("Lambda Exec Role\nminimal")
            anomaly = CostExplorer("Cost Anomaly\nDetection\n(CUSTOM monitor)")
            budgets = Budgets("Budgets\n$20 / $50 / $80 / $100")
            sns = SimpleNotificationServiceSnsTopic("sre-budget-alerts")

        with Cluster("workloads-dev account"):
            sts = IAMAWSSts("AssumeRole\nAutoStopExecutorRole")
            executor_role = IAMRole("AutoStopExecutorRole\necs:UpdateService\n(scoped to 1 service)")
            ecs_service = ElasticContainerServiceService("sre-reference-app\nECS service")

        engineer = User("jadenrazo\n(email)")

        schedule >> Edge(label="invoke") >> lambda_fn
        lambda_fn >> Edge(label="assume", style="dashed") >> sts >> executor_role
        executor_role >> Edge(label="UpdateService\ndesired_count=0", color="red") >> ecs_service
        anomaly >> Edge(label="threshold > $5") >> sns
        budgets >> Edge(label="forecast %") >> sns
        sns >> Edge(label="email") >> engineer


def six_rs_before_after():
    """Diagram 7: side-by-side migration story (BEFORE / AFTER)."""
    with Diagram(
        "Migration — 6 R's (Before vs After)",
        show=False,
        filename=str(OUT_DIR / "architecture-six-rs-before-after"),
        outformat="png",
        direction="LR",
        graph_attr={**GRAPH_ATTR, "ranksep": "1.5"},
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    ):
        with Cluster("BEFORE — sre-reference-app (single account)\nGameDay snapshot"):
            with Cluster("1 AWS account"):
                b_alb = ALB("ALB")
                b_ecs = Fargate("ECS Fargate\n(1 task)")
                b_nat = NATGateway("NAT")
                b_cw = Cloudwatch("CloudWatch\nburn-rate alarms")
                b_alb >> b_ecs
                b_ecs >> Edge(style="dashed") >> b_cw

        with Cluster("AFTER — sre-landing-zone (5 accounts)\nDay-2 production posture"):
            with Cluster("Org with SCPs + Identity Center"):
                a_id = GenericSamlToken("IAM Identity Center")
                a_org = Organizations("AWS Organizations\n4 SCPs")

            with Cluster("Edge"):
                a_cf = CloudFront("CloudFront")
                a_waf = WAF("WAF")
                a_cognito = Cognito("Cognito")

            with Cluster("Workload (us-west-2)"):
                a_alb = ALB("ALB")
                a_ecs = Fargate("ECS")
                a_secrets = SecretsManager("Secrets Mgr")
                a_alb >> a_ecs >> a_secrets

            with Cluster("DR (us-east-1)"):
                a_r53 = Route53("R53\nfailover")
                a_dr = Fargate("ECS @ 0")
                a_ddb = Dynamodb("DDB Global")

            with Cluster("Audit"):
                a_trail = Cloudtrail("Org Trail")
                a_gd = Guardduty("GuardDuty")
                a_sh = SecurityHub("Security Hub")

            with Cluster("Cost"):
                a_lambda = Lambda("auto-stop")
                a_anomaly = CostExplorer("Anomaly")

            a_cf >> a_waf
            a_cf >> a_alb
            a_r53 >> a_alb
            a_r53 >> Edge(style="dashed") >> a_dr

        # Migration arrow + 6 R's annotation
        b_ecs >> Edge(label="REPLATFORM\nADD: SCPs, audit trail, DR,\nedge, secrets, cost ctrls", color="darkgreen", style="bold") >> a_alb


def main():
    print("Generating architecture diagrams...")
    landing_zone()
    print("  1/7 architecture-landing-zone.png")
    runtime()
    print("  2/7 architecture-runtime.png")
    security_baseline()
    print("  3/7 architecture-security-baseline.png")
    dr_pilot_light()
    print("  4/7 architecture-dr-pilot-light.png")
    edge_stack()
    print("  5/7 architecture-edge.png")
    cost_controls()
    print("  6/7 architecture-cost-controls.png")
    six_rs_before_after()
    print("  7/7 architecture-six-rs-before-after.png")
    print(f"\nDone. PNGs in {OUT_DIR}/")


if __name__ == "__main__":
    main()
