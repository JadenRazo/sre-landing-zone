# VPC + 2 public + 2 private subnets, IGW, single NAT Gateway in AZ 0.
#
# Cost trade-off explained: 1 NAT Gateway in 1 AZ = $32/mo. Two NATs (one per AZ)
# would be ~$64/mo and remove a single point of failure for outbound traffic
# from private subnets. For a $120 budget over 8 weeks this single-AZ NAT is the
# right call — cheaper, and during the destroy/recreate study cycle the SPOF
# doesn't matter.
#
# Prod-grade alternative (documented in this phase's README): replace NAT
# entirely with VPC Interface Endpoints to ECR, Logs, Secrets Manager, STS plus
# the S3 Gateway Endpoint. ~$29/mo in 1 AZ, but the SAA-favored "no public
# internet egress" pattern. We keep that as a manual swap rather than a default
# because it's a teaching exercise on its own.

resource "aws_vpc" "main" {
  provider             = aws.workloads_dev
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "sre-workloads-dev" }
}

resource "aws_internet_gateway" "main" {
  provider = aws.workloads_dev
  vpc_id   = aws_vpc.main.id

  tags = { Name = "sre-workloads-dev-igw" }
}

resource "aws_subnet" "public" {
  provider = aws.workloads_dev
  count    = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "sre-workloads-dev-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  provider = aws.workloads_dev
  count    = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "sre-workloads-dev-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

# Single Elastic IP + NAT Gateway in AZ 0. All private subnets route through it.
resource "aws_eip" "nat" {
  provider = aws.workloads_dev
  domain   = "vpc"

  tags = { Name = "sre-workloads-dev-nat-eip" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  provider      = aws.workloads_dev
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = "sre-workloads-dev-nat" }

  depends_on = [aws_internet_gateway.main]
}

# Route tables: public goes via IGW, private goes via NAT.
resource "aws_route_table" "public" {
  provider = aws.workloads_dev
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "sre-workloads-dev-public-rt" }
}

resource "aws_route_table_association" "public" {
  provider       = aws.workloads_dev
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  provider = aws.workloads_dev
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "sre-workloads-dev-private-rt" }
}

resource "aws_route_table_association" "private" {
  provider       = aws.workloads_dev
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# VPC Flow Logs deferred. Two blockers worth a future phase:
#  1. AWS reserves the `AWSLogs/` prefix in the destination URI; can't include it.
#  2. The log-archive bucket policy from Phase 1 doesn't currently grant the
#     VPC Flow Logs delivery service (delivery.logs.amazonaws.com) write
#     permissions for the workloads-dev account.
#
# Cleanest fix is to add a statement to the Phase 1 bucket policy that allows
# delivery.logs.amazonaws.com to PutObject under a /vpc-flow-logs/ prefix for
# every member account, then add this resource back with the right destination.
# Documented in docs/04-failover-drill.md as "polish later". CloudTrail org
# trail (already running) captures management events, which is the more
# critical audit trail for cert prep.

# Security groups
resource "aws_security_group" "alb" {
  provider    = aws.workloads_dev
  name        = "sre-alb"
  description = "ALB ingress from internet on 80/443"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress (ALB needs to reach targets)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sre-alb-sg" }
}

resource "aws_security_group" "task" {
  provider    = aws.workloads_dev
  name        = "sre-task"
  description = "ECS task ingress only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB on container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All egress (ECR, Logs, Secrets Manager, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sre-task-sg" }
}
