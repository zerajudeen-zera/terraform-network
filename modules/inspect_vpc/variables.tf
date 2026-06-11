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

variable "tgw_attachment_subnets" {
  type = list(string)
}

variable "firewall_subnets" {
  type = list(string)
}

variable "nat_subnets" {
  type = list(string)
}

variable "tgw_id" {
  type = string
}

variable "tgw_core_rt_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
