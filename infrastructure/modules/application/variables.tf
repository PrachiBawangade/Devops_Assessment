variable "environment" {
  type = string
}

variable "app_version" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}