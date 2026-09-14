variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "environment" {
  type    = string
  default = "alpha"
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "blue_weight" {
  type    = number
  default = 100
}

variable "green_weight" {
  type    = number
  default = 0
}

variable "blue_version" {
  type    = string
  default = "alpha-v1.0"
}

variable "green_version" {
  type    = string
  default = "beta-v2.0"
}