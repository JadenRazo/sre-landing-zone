# Minimal DR VPC in us-east-1. Two public subnets only — NO NAT.
#
# Why public-only here: standby tasks run with assign_public_ip = true. NAT
# Gateway is $32/mo per region; doubling to two regions doubles the bill.
# When we scale tasks to 0 between drills, public IPs are free, NAT-less is
# the cheapest tenable design. This is a documented trade-off in the
# README — for true production DR you'd want private subnets + NAT.

resource "aws_vpc" "dr" {
  provider             = aws.workloads_dev_dr
  cidr_block           = var.dr_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "sre-workloads-dev-dr" }
}

resource "aws_internet_gateway" "dr" {
  provider = aws.workloads_dev_dr
  vpc_id   = aws_vpc.dr.id

  tags = { Name = "sre-workloads-dev-dr-igw" }
}

resource "aws_subnet" "dr_public" {
  provider = aws.workloads_dev_dr
  count    = 2

  vpc_id                  = aws_vpc.dr.id
  cidr_block              = local.dr_public_subnet_cidrs[count.index]
  availability_zone       = local.dr_azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "sre-workloads-dev-dr-public-${local.dr_azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_route_table" "dr_public" {
  provider = aws.workloads_dev_dr
  vpc_id   = aws_vpc.dr.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr.id
  }

  tags = { Name = "sre-workloads-dev-dr-public-rt" }
}

resource "aws_route_table_association" "dr_public" {
  provider       = aws.workloads_dev_dr
  count          = 2
  subnet_id      = aws_subnet.dr_public[count.index].id
  route_table_id = aws_route_table.dr_public.id
}

resource "aws_security_group" "dr_alb" {
  provider    = aws.workloads_dev_dr
  name        = "sre-alb-dr"
  description = "Standby ALB ingress"
  vpc_id      = aws_vpc.dr.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sre-alb-dr-sg" }
}

resource "aws_security_group" "dr_task" {
  provider    = aws.workloads_dev_dr
  name        = "sre-task-dr"
  description = "Standby ECS task ingress only from DR ALB"
  vpc_id      = aws_vpc.dr.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.dr_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sre-task-dr-sg" }
}
