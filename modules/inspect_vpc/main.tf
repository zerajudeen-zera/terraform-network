###############################################################
# Module: inspect_vpc
# Centralized Egress + GWLB hub VPC
# CIDR: 10.220.128.0/22
###############################################################

###############################################################
# VPC
###############################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-vpc"
  })
}

###############################################################
# Internet Gateway
###############################################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-igw"
  })
}

###############################################################
# Subnets — TGW Attachment (one per AZ)
###############################################################
resource "aws_subnet" "tgw" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_attachment_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-tgw-${substr(var.azs[count.index], -1, 1)}"
    Tier = "tgw-attach"
  })
}

###############################################################
# Subnets — Firewall / GWLB (one per AZ)
###############################################################
resource "aws_subnet" "firewall" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.firewall_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-fw-${substr(var.azs[count.index], -1, 1)}"
    Tier = "firewall"
  })
}

###############################################################
# Subnets — NAT Gateway (one per AZ)
###############################################################
resource "aws_subnet" "nat" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.nat_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-nat-${substr(var.azs[count.index], -1, 1)}"
    Tier = "nat"
  })
}

###############################################################
# Elastic IPs + NAT Gateways (one per AZ)
###############################################################
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-nat-eip-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.nat[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-natgw-${substr(var.azs[count.index], -1, 1)}"
  })

  depends_on = [aws_internet_gateway.this]
}

###############################################################
# Gateway Load Balancer (GWLB)
# Target group — appliance instances are registered separately
###############################################################
resource "aws_lb" "gwlb" {
  name               = "${var.name}-${var.environment}-gwlb"
  load_balancer_type = "gateway"
  subnets            = aws_subnet.firewall[*].id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-gwlb"
  })
}

resource "aws_lb_target_group" "gwlb" {
  name        = "${var.name}-${var.environment}-gwlb-tg"
  port        = 6081
  protocol    = "GENEVE"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    protocol = "TCP"
    port     = 80
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-gwlb-tg"
  })
}

resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-gwlb-listener"
  })
}

###############################################################
# GWLB Endpoint Service
# Exposes the GWLB as a PrivateLink endpoint service
# so the Ingress VPC can create a GWLBe pointing to it
###############################################################
resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-gwlb-endpoint-svc"
  })
}

###############################################################
# Route Tables
###############################################################

# TGW attachment subnet route table
# All traffic from TGW goes to GWLB endpoint (firewall first)
resource "aws_route_table" "tgw" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-rt-tgw-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_route_table_association" "tgw" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}

# Route: TGW subnet → GWLB endpoint (per AZ)
resource "aws_route" "tgw_to_gwlb" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.tgw[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlb[count.index].id
}

# Firewall subnet route table
# After inspection: allowed traffic → NAT GW
resource "aws_route_table" "firewall" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-rt-fw-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_route_table_association" "firewall" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.firewall[count.index].id
  route_table_id = aws_route_table.firewall[count.index].id
}

# Route: firewall subnet → NAT GW for internet-bound traffic
resource "aws_route" "fw_to_nat" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.firewall[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

# Route: firewall subnet → TGW for return RFC1918 traffic
resource "aws_route" "fw_to_tgw_pool1" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.firewall[count.index].id
  destination_cidr_block = "10.220.0.0/16"
  transit_gateway_id     = var.tgw_id
}

# NAT Gateway subnet route table
resource "aws_route_table" "nat" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-rt-nat-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_route_table_association" "nat" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.nat[count.index].id
  route_table_id = aws_route_table.nat[count.index].id
}

# Route: NAT subnet → IGW for outbound internet
resource "aws_route" "nat_to_igw" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.nat[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Route: NAT subnet → TGW for return RFC1918 traffic
resource "aws_route" "nat_to_tgw" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.nat[count.index].id
  destination_cidr_block = "10.220.0.0/16"
  transit_gateway_id     = var.tgw_id
}

###############################################################
# GWLB VPC Endpoint (one per AZ in firewall subnets)
# These are the endpoints inside the inspect VPC itself
# The ingress VPC will create its own GWLBe pointing to the
# endpoint service above
###############################################################
resource "aws_vpc_endpoint" "gwlb" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [aws_subnet.firewall[count.index].id]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-gwlbe-${substr(var.azs[count.index], -1, 1)}"
  })
}

###############################################################
# S3 + DynamoDB Gateway Endpoints (free, no TGW hop)
###############################################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    aws_route_table.firewall[*].id,
    aws_route_table.nat[*].id
  )

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    aws_route_table.firewall[*].id,
    aws_route_table.nat[*].id
  )

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-dynamodb-endpoint"
  })
}

###############################################################
# TGW Attachment
###############################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = var.tgw_id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = aws_subnet.tgw[*].id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  appliance_mode_support                          = "enable"  # Critical for stateful inspection

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-inspect-tgw-attach"
  })
}

# Associate inspect VPC to core route table
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_core_rt_id
}

# Propagate inspect VPC routes into core route table
resource "aws_ec2_transit_gateway_route_table_propagation" "core" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_core_rt_id
}

###############################################################
# Data sources
###############################################################
data "aws_region" "current" {}
