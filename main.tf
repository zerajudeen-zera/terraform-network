###############################################################
# Root main.tf — MCT Australia Stage Network Hub
# Region: ap-southeast-2 (Sydney)
###############################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

###############################################################
# Transit Gateway
###############################################################
module "tgw" {
  source = "./modules/tgw"

  name        = var.name
  environment = var.environment
  asn         = var.tgw_asn
  tags        = local.common_tags
}

###############################################################
# Inspect VPC
###############################################################
module "inspect_vpc" {
  source = "./modules/inspect_vpc"

  name        = var.name
  environment = var.environment
  vpc_cidr    = var.inspect_vpc_cidr
  azs         = var.azs

  tgw_attachment_subnets = var.inspect_tgw_subnets
  firewall_subnets       = var.inspect_fw_subnets
  nat_subnets            = var.inspect_nat_subnets

  tgw_id              = module.tgw.tgw_id
  tgw_core_rt_id      = module.tgw.core_route_table_id

  tags = local.common_tags
}

###############################################################
# Ingress VPC
###############################################################
module "ingress_vpc" {
  source = "./modules/ingress_vpc"

  name        = var.name
  environment = var.environment
  vpc_cidr    = var.ingress_vpc_cidr
  azs         = var.azs

  nlb_subnets    = var.ingress_nlb_subnets
  alb_subnets    = var.ingress_alb_subnets
  gwlbe_subnets  = var.ingress_gwlbe_subnets
  tgw_subnets    = var.ingress_tgw_subnets

  tgw_id         = module.tgw.tgw_id
  tgw_core_rt_id = module.tgw.core_route_table_id

  # GWLBe endpoint service ARN from inspect VPC GWLB
  gwlb_endpoint_service_name = module.inspect_vpc.gwlb_endpoint_service_name

  tags = local.common_tags
}

###############################################################
# Endpoints VPC
###############################################################
module "endpoints_vpc" {
  source = "./modules/endpoints_vpc"

  name        = var.name
  environment = var.environment
  vpc_cidr    = var.endpoints_vpc_cidr
  azs         = var.azs

  endpoint_subnets = var.endpoints_subnets
  tgw_subnets      = var.endpoints_tgw_subnets

  tgw_id          = module.tgw.tgw_id
  tgw_core_rt_id  = module.tgw.core_route_table_id
  tgw_spoke_rt_id = module.tgw.spoke_route_table_id

  # Allow endpoint access from all spoke CIDRs
  allowed_cidrs = var.spoke_cidrs

  tags = local.common_tags
}

###############################################################
# TGW Route Table Entries
# Done after all attachments are created
###############################################################
module "tgw_routes" {
  source = "./modules/tgw_routes"

  core_route_table_id  = module.tgw.core_route_table_id
  spoke_route_table_id = module.tgw.spoke_route_table_id

  inspect_attachment_id   = module.inspect_vpc.tgw_attachment_id
  ingress_attachment_id   = module.ingress_vpc.tgw_attachment_id
  endpoints_attachment_id = module.endpoints_vpc.tgw_attachment_id

  spoke_cidrs          = var.spoke_cidrs
  inspect_vpc_cidr     = var.inspect_vpc_cidr
  endpoints_vpc_cidr   = var.endpoints_vpc_cidr
  ingress_vpc_cidr     = var.ingress_vpc_cidr

  tags = local.common_tags
}
