variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "endpoint_subnets" {
  type = list(string)
}

variable "tgw_subnets" {
  type = list(string)
}

variable "tgw_id" {
  type = string
}

variable "tgw_core_rt_id" {
  type = string
}

variable "tgw_spoke_rt_id" {
  type = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the interface endpoints (spoke VPCs)"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
