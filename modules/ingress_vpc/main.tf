###############################################################
# Module: ingress_vpc
# Centralized Ingress VPC — NLB + GWLBe + ALB + TGW
# CIDR: 10.220.132.0/23
###############################################################

###############################################################
# VPC
###############################################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-vpc"
  })
}

###############################################################
# Internet Gateway
###############################################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-igw"
  })
}

###############################################################
# Subnets — NLB (one per AZ, /27)
###############################################################
resource "aws_subnet" "nlb" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.nlb_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-nlb-${substr(var.azs[count.index], -1, 1)}"
    Tier = "nlb"
  })
}

###############################################################
# Subnets — ALB (one per AZ, /28)
###############################################################
resource "aws_subnet" "alb" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.alb_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-alb-${substr(var.azs[count.index], -1, 1)}"
    Tier = "alb"
  })
}

###############################################################
# Subnets — GWLBe (one per AZ, /28)
###############################################################
resource "aws_subnet" "gwlbe" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.gwlbe_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-gwlbe-${substr(var.azs[count.index], -1, 1)}"
    Tier = "gwlbe"
  })
}

###############################################################
# Subnets — TGW Attachment (one per AZ, /28)
###############################################################
resource "aws_subnet" "tgw" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-tgw-${substr(var.azs[count.index], -1, 1)}"
    Tier = "tgw-attach"
  })
}

###############################################################
# Gateway Load Balancer Endpoints (GWLBe)
# One per AZ in the gwlbe subnets
# Points to the GWLB endpoint service in the inspect VPC
###############################################################
resource "aws_vpc_endpoint" "gwlbe" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  service_name      = var.gwlb_endpoint_service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [aws_subnet.gwlbe[count.index].id]

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-gwlbe-endpoint-${substr(var.azs[count.index], -1, 1)}"
  })
}

###############################################################
# Route Tables
###############################################################

# IGW Gateway Route Table
# Intercepts inbound packets destined for NLB subnets
# and sends them to GWLBe BEFORE they reach NLB
resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-rt-igw"
  })
}

# Associate the gateway route table to the IGW itself (edge association)
resource "aws_main_route_table_association" "igw_gateway" {
  gateway_id     = aws_internet_gateway.this.id
  route_table_id = aws_route_table.igw.id
}

# For each NLB subnet, add an IGW route table entry:
# "packets destined for NLB subnet → GWLBe"
resource "aws_route" "igw_to_gwlbe" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.igw.id
  destination_cidr_block = var.nlb_subnets[count.index]
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbe[count.index].id
}

# NLB subnet route tables
# Return path also goes through GWLBe (so firewall sees both directions)
resource "aws_route_table" "nlb" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-rt-nlb-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_route_table_association" "nlb" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.nlb[count.index].id
  route_table_id = aws_route_table.nlb[count.index].id
}

# Return traffic from NLB → GWLBe (inspected before going back to internet)
resource "aws_route" "nlb_to_gwlbe" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.nlb[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbe[count.index].id
}

# ALB subnet route tables
# ALB forwards accepted traffic to TGW → spoke VPC
resource "aws_route_table" "alb" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-rt-alb-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_route_table_association" "alb" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.alb[count.index].id
  route_table_id = aws_route_table.alb[count.index].id
}

resource "aws_route" "alb_to_tgw" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.alb[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.tgw_id
}

# TGW attachment subnet route tables (empty — local only)
resource "aws_route_table" "tgw" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-rt-tgw-${substr(var.azs[count.index], -1, 1)}"
  })
}

resource "aws_route_table_association" "tgw" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
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

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-tgw-attach"
  })
}

# Associate ingress VPC to core route table
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.tgw_core_rt_id
}

###############################################################
# Security Groups
###############################################################

# NLB security group — allow HTTPS from internet
resource "aws_security_group" "nlb" {
  name        = "${var.name}-${var.environment}-ingress-nlb-sg"
  description = "NLB - allow inbound HTTPS from internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet (redirect)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-nlb-sg"
  })
}

# ALB security group — allow only from NLB SG
resource "aws_security_group" "alb" {
  name        = "${var.name}-${var.environment}-ingress-alb-sg"
  description = "ALB - allow inbound only from NLB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
    description     = "HTTPS from NLB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.environment}-ingress-alb-sg"
  })
}
