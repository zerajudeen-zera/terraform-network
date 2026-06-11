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

variable "nlb_subnets" {
  type = list(string)
}

variable "alb_subnets" {
  type = list(string)
}

variable "gwlbe_subnets" {
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

variable "gwlb_endpoint_service_name" {
  description = "GWLB endpoint service name from the inspect VPC"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
