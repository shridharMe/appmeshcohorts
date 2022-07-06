resource "aws_appmesh_mesh" "mesh_1" {
  name = var.infra_name

  spec {
    egress_filter {
      type = "DROP_ALL"
    }
  }
}

resource "aws_ecs_cluster" "ecs_1" {
  name = var.infra_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_1_cp" {
  cluster_name = aws_ecs_cluster.ecs_1.name

  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT"
  ]

  default_capacity_provider_strategy {
    weight            = 1
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix = "ecstaskexecution"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

}

resource "aws_service_discovery_private_dns_namespace" "cloud_map_namespace" {
  name = "${var.infra_name}.local"
  vpc  = var.vpc_id
}

resource "aws_s3_bucket" "config_bucket" {
  bucket_prefix = "${var.infra_name}bucket"
}
