terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.19"
    }
  }
}

provider "aws" {
  region = local.aws_region
}

data "aws_availability_zones" "available" {}

locals {
  name       = "cohort-demos"
  aws_region = "eu-west-1"
  vpc_cidr   = "10.2.0.0/16"
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)

  init_image           = "public.ecr.aws/h5g3j1b0/ecs-configmap:v0.5"
  firelens_image       = "906394416424.dkr.ecr.eu-west-1.amazonaws.com/aws-for-fluent-bit:2.26.0"
  xray_image           = "public.ecr.aws/xray/aws-xray-daemon:3.3.3"
  app_mesh_envoy_image = "840364872350.dkr.ecr.eu-west-1.amazonaws.com/aws-appmesh-envoy:v1.22.2.0-prod"

  application_image    = "public.ecr.aws/h5g3j1b0/wordechoer:v0.5"
  application_web_port = 80

}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

}

module "ecsinfra" {
  source = "./modules/infraecs"

  infra_name = local.name
  vpc_id     = module.vpc.vpc_id
}

module "configfiles" {
  source = "./modules/configfiles"

  s3_bucket_name = module.ecsinfra.s3_bucket_name
}

module "vg_service" {
  source = "./modules/servicevg"

  service_name        = "vg_1"
  task_execution_role = module.ecsinfra.task_execution_role
  ecs_cluster         = module.ecsinfra.ecs_cluster

  aws_region           = local.aws_region
  vpc_id               = module.vpc.vpc_id
  vpc_private_subnet_1 = module.vpc.private_subnets[0]
  vpc_private_subnet_2 = module.vpc.private_subnets[1]
  vpc_public_subnet_1  = module.vpc.public_subnets[0]
  vpc_public_subnet_2  = module.vpc.public_subnets[1]

  s3_bucket_name = module.ecsinfra.s3_bucket_name
  s3_bucket_arn  = "arn:aws:s3:::${module.ecsinfra.s3_bucket_name}"

  init_image     = local.init_image
  firelens_image = local.firelens_image
  xray_image     = local.xray_image

  app_mesh_mesh_name   = module.ecsinfra.app_mesh_mesh_name
  app_mesh_envoy_image = local.app_mesh_envoy_image
}

module "green_service" {
  source = "./modules/servicegreen"

  service_name        = "green"
  task_execution_role = module.ecsinfra.task_execution_role
  ecs_cluster         = module.ecsinfra.ecs_cluster

  aws_region           = local.aws_region
  vpc_id               = module.vpc.vpc_id
  vpc_private_subnet_1 = module.vpc.private_subnets[0]
  vpc_private_subnet_2 = module.vpc.private_subnets[1]

  s3_bucket_name = module.ecsinfra.s3_bucket_name
  s3_bucket_arn  = "arn:aws:s3:::${module.ecsinfra.s3_bucket_name}"

  init_image     = local.init_image
  firelens_image = local.firelens_image
  xray_image     = local.xray_image

  application_image    = local.application_image
  application_web_port = local.application_web_port

  cloud_map_namespace_id   = module.ecsinfra.cloud_map_namespace_id
  cloud_map_namespace_name = module.ecsinfra.cloud_map_namespace_name

  app_mesh_mesh_name   = module.ecsinfra.app_mesh_mesh_name
  app_mesh_envoy_image = local.app_mesh_envoy_image
  app_mesh_vg_name     = module.vg_service.app_mesh_vg_name
  app_mesh_vg_sg       = module.vg_service.app_mesh_vg_sg
}


module "red_service" {
  source = "./modules/servicered"

  service_name        = "red"
  task_execution_role = module.ecsinfra.task_execution_role
  ecs_cluster         = module.ecsinfra.ecs_cluster

  aws_region           = local.aws_region
  vpc_id               = module.vpc.vpc_id
  vpc_private_subnet_1 = module.vpc.private_subnets[0]
  vpc_private_subnet_2 = module.vpc.private_subnets[1]

  s3_bucket_name = module.ecsinfra.s3_bucket_name
  s3_bucket_arn  = "arn:aws:s3:::${module.ecsinfra.s3_bucket_name}"

  init_image     = local.init_image
  firelens_image = local.firelens_image
  xray_image     = local.xray_image

  application_image    = local.application_image
  application_web_port = local.application_web_port

  cloud_map_namespace_id   = module.ecsinfra.cloud_map_namespace_id
  cloud_map_namespace_name = module.ecsinfra.cloud_map_namespace_name

  app_mesh_mesh_name   = module.ecsinfra.app_mesh_mesh_name
  app_mesh_envoy_image = local.app_mesh_envoy_image
  app_mesh_green_sg    = module.green_service.green_security_group
}

module "blue_service" {
  source = "./modules/serviceblue"

  service_name        = "blue"
  task_execution_role = module.ecsinfra.task_execution_role
  ecs_cluster         = module.ecsinfra.ecs_cluster

  aws_region           = local.aws_region
  vpc_id               = module.vpc.vpc_id
  vpc_private_subnet_1 = module.vpc.private_subnets[0]
  vpc_private_subnet_2 = module.vpc.private_subnets[1]

  s3_bucket_name = module.ecsinfra.s3_bucket_name
  s3_bucket_arn  = "arn:aws:s3:::${module.ecsinfra.s3_bucket_name}"

  init_image     = local.init_image
  firelens_image = local.firelens_image
  xray_image     = local.xray_image

  application_image    = local.application_image
  application_web_port = local.application_web_port

  cloud_map_namespace_id   = module.ecsinfra.cloud_map_namespace_id
  cloud_map_namespace_name = module.ecsinfra.cloud_map_namespace_name

  app_mesh_mesh_name   = module.ecsinfra.app_mesh_mesh_name
  app_mesh_envoy_image = local.app_mesh_envoy_image
  app_mesh_vg_name     = module.vg_service.app_mesh_vg_name
  app_mesh_vg_sg       = module.vg_service.app_mesh_vg_sg
}
