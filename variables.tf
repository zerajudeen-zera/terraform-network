###############################################################
# Root Variables
###############################################################

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "name" {
  description = "Project / deployment name prefix"
  type        = string
  default     = "mct-au"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stage"
}

variable "tgw_asn" {
  description = "BGP ASN for the Transit Gateway (must not conflict with us-east-1 TGW ASN 65521)"
  type        = number
  default     = 65522
}

###############################################################
# AZs
###############################################################
variable "azs" {
  description = "Availability zones in ap-southeast-2"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
}

###############################################################
# Inspect VPC — 10.220.128.0/22
###############################################################
variable "inspect_vpc_cidr" {
  description = "CIDR block for the Inspect VPC"
  type        = string
  default     = "10.220.128.0/22"
}

variable "inspect_tgw_subnets" {
  description = "TGW attachment subnets in Inspect VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.128.0/28",    # AZ-a
    "10.220.128.64/28",   # AZ-b
    "10.220.128.128/28"   # AZ-c
  ]
}

variable "inspect_fw_subnets" {
  description = "Firewall / GWLB subnets in Inspect VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.128.16/28",   # AZ-a
    "10.220.128.80/28",   # AZ-b
    "10.220.128.144/28"   # AZ-c
  ]
}

variable "inspect_nat_subnets" {
  description = "NAT Gateway subnets in Inspect VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.128.32/28",   # AZ-a
    "10.220.128.96/28",   # AZ-b
    "10.220.128.160/28"   # AZ-c
  ]
}

###############################################################
# Ingress VPC — 10.220.132.0/23
###############################################################
variable "ingress_vpc_cidr" {
  description = "CIDR block for the Ingress VPC"
  type        = string
  default     = "10.220.132.0/23"
}

variable "ingress_nlb_subnets" {
  description = "NLB subnets in Ingress VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.132.0/27",    # AZ-a
    "10.220.132.96/27",   # AZ-b
    "10.220.133.0/27"     # AZ-c
  ]
}

variable "ingress_alb_subnets" {
  description = "ALB subnets in Ingress VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.132.32/28",   # AZ-a
    "10.220.132.128/28",  # AZ-b
    "10.220.133.32/28"    # AZ-c
  ]
}

variable "ingress_gwlbe_subnets" {
  description = "GWLBe subnets in Ingress VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.132.48/28",   # AZ-a
    "10.220.132.144/28",  # AZ-b
    "10.220.133.48/28"    # AZ-c
  ]
}

variable "ingress_tgw_subnets" {
  description = "TGW attachment subnets in Ingress VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.132.64/28",   # AZ-a
    "10.220.132.160/28",  # AZ-b
    "10.220.133.64/28"    # AZ-c
  ]
}

###############################################################
# Endpoints VPC — 10.220.134.0/23
###############################################################
variable "endpoints_vpc_cidr" {
  description = "CIDR block for the Endpoints VPC"
  type        = string
  default     = "10.220.134.0/23"
}

variable "endpoints_subnets" {
  description = "Interface endpoint subnets in Endpoints VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.134.0/25",    # AZ-a
    "10.220.135.0/25",    # AZ-b
    "10.220.135.128/25"   # AZ-c
  ]
}

variable "endpoints_tgw_subnets" {
  description = "TGW attachment subnets in Endpoints VPC (one per AZ)"
  type        = list(string)
  default     = [
    "10.220.134.128/28",  # AZ-a
    "10.220.134.144/28",  # AZ-b
    "10.220.134.160/28"   # AZ-c
  ]
}

###############################################################
# Spoke CIDRs (workload VPCs that will attach later)
###############################################################
variable "spoke_cidrs" {
  description = "List of spoke/workload VPC CIDRs — used for TGW routes and endpoint SG rules"
  type        = list(string)
  default     = [
    "10.220.136.0/21"   # Workload VPC (stage)
  ]
}
