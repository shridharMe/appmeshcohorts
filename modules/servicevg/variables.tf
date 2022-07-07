variable "service_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_private_subnet_1" {
  type = string
}

variable "vpc_private_subnet_2" {
  type = string
}

variable "vpc_public_subnet_1" {
  type = string
}

variable "vpc_public_subnet_2" {
  type = string
}

variable "task_execution_role" {
  type = string
}

variable "ecs_cluster" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "init_image" {
  type = string
}

variable "firelens_image" {
  type = string
}

variable "xray_image" {
  type = string
}

variable "app_mesh_mesh_name" {
  type = string
}

variable "app_mesh_envoy_image" {
  type = string
}
