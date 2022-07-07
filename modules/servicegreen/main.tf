resource "aws_cloudwatch_log_group" "green_log_group" {
  name              = "/aws/ecs/service/${var.service_name}"
  retention_in_days = 7
}


resource "aws_security_group" "green_security_group" {
  name_prefix = var.service_name
  description = "Allow inbound traffic to envoy and application"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Inbound to the Envoy HTTP Port"
    from_port       = 15000
    to_port         = 15000
    protocol        = "tcp"
    security_groups = [var.app_mesh_vg_sg]
  }

  ingress {
    description     = "Inbound to the Envoy HTTPS Port"
    from_port       = 15001
    to_port         = 15001
    protocol        = "tcp"
    security_groups = [var.app_mesh_vg_sg]
  }

  ingress {
    description     = "Inbound to the Application Web Port"
    from_port       = var.application_web_port
    to_port         = var.application_web_port
    protocol        = "tcp"
    security_groups = [var.app_mesh_vg_sg]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}


data "aws_iam_policy_document" "green_task_init_iam_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "${var.s3_bucket_arn}",
      "${var.s3_bucket_arn}/*"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "green_task_firelens_iam_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_role" "green_task_iam_role" {
  name_prefix = var.service_name

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
    "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess",
    "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
  ]

  inline_policy {
    name   = "retrieve_s3_configs"
    policy = data.aws_iam_policy_document.green_task_init_iam_policy.json
  }

  inline_policy {
    name   = "firelens"
    policy = data.aws_iam_policy_document.green_task_firelens_iam_policy.json
  }

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

resource "aws_appmesh_virtual_node" "green_virtual_node" {
  name      = var.service_name
  mesh_name = var.app_mesh_mesh_name

  spec {
    #backend {
    #  virtual_service {
    #    virtual_service_name = "red.${var.cloud_map_namespace_name}"
    #  }
    #}

    listener {
      port_mapping {
        port     = var.application_web_port
        protocol = "http"
      }

      health_check {
        protocol            = "http"
        path                = "/health"
        port                = var.application_web_port
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout_millis      = 30000
        interval_millis     = 30000
      }
    }

    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = var.service_name
        namespace_name = var.cloud_map_namespace_name
      }
    }
  }
}

module "container_init" {
  source = "../containerinit"

  aws_region = var.aws_region
  init_image = var.init_image
  log_group  = aws_cloudwatch_log_group.green_log_group.name

  init_file_one_s3_bucket     = var.s3_bucket_name
  init_file_one_src_file_path = "samplingrule.json"
  init_file_one_dst_file_path = "/envoyvolume/samplingrule.json"

  init_file_two_s3_bucket     = var.s3_bucket_name
  init_file_two_src_file_path = "fluent-bit.conf"
  init_file_two_dst_file_path = "/firelensvolume/fluent-bit.conf"

  init_file_three_s3_bucket     = var.s3_bucket_name
  init_file_three_src_file_path = "envoy_parser.conf"
  init_file_three_dst_file_path = "/firelensvolume/envoy_parser.conf"

}

module "container_envoy" {
  source = "../containerenvoy"

  aws_region                = var.aws_region
  envoy_image               = var.app_mesh_envoy_image
  app_mesh_virtual_node_arn = aws_appmesh_virtual_node.green_virtual_node.arn
  log_group                 = aws_cloudwatch_log_group.green_log_group.name

}

module "container_firelens" {
  source = "../containerfirelens"

  aws_region     = var.aws_region
  firelens_image = var.firelens_image
  log_group      = aws_cloudwatch_log_group.green_log_group.name

}

module "container_xray" {
  source = "../containerxray"

  aws_region = var.aws_region
  xray_image = var.xray_image
  log_group  = aws_cloudwatch_log_group.green_log_group.name

}

module "container_web_app" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_name  = "webapp"
  container_image = var.application_image
  essential       = true

  container_depends_on = [
    {
      containerName = "init"
      condition     = "SUCCESS"
    }
  ]

  environment = [
    {
      name  = "MAGIC_WORD"
      value = "green"
    },
    {
      name  = "VERSION"
      value = "1"
    },
    {
      name  = "HTTP_PORT"
      value = "${var.application_web_port}"
    },
    {
      name  = "HITAPI"
      value = "true"
    },
    {
      name  = "HITAPIURL"
      value = "http://red.${var.cloud_map_namespace_name}"
    }
  ]

  healthcheck = {
    command     = ["CMD", "python", "healthcheck.py"]
    startPeriod = 30
    retries     = 3
    timeout     = 5
    interval    = 10
  }

  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = "${aws_cloudwatch_log_group.green_log_group.id}"
      awslogs-region        = "${var.aws_region}"
      awslogs-stream-prefix = "webapp"
    }
  }
}


resource "aws_ecs_task_definition" "green_task_definition" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.task_execution_role
  task_role_arn            = aws_iam_role.green_task_iam_role.arn
  cpu                      = 256
  memory                   = 512

  proxy_configuration {
    type           = "APPMESH"
    container_name = "envoy"
    properties = {
      AppPorts         = "${var.application_web_port}"
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }

  container_definitions = jsonencode([
    module.container_init.init_output,
    module.container_firelens.firelens_output,
    module.container_envoy.envoy_output,
    module.container_xray.xray_output,
    module.container_web_app.json_map_object
  ])

  depends_on = [
    module.container_init,
    module.container_envoy,
    aws_service_discovery_service.green_cloud_map_service,
  ]

  volume {
    name = "envoyvolume"
  }
  volume {
    name = "firelensvolume"
  }

}

resource "aws_service_discovery_service" "green_cloud_map_service" {
  name         = var.service_name
  namespace_id = var.cloud_map_namespace_id

  dns_config {
    namespace_id = var.cloud_map_namespace_id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "WEIGHTED"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "green_service" {
  name            = var.service_name
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.green_task_definition.arn
  desired_count   = 1

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  service_registries {
    registry_arn = aws_service_discovery_service.green_cloud_map_service.arn
  }

  network_configuration {
    subnets = [
      var.vpc_private_subnet_1,
      var.vpc_private_subnet_2
    ]
    security_groups = [aws_security_group.green_security_group.id]
  }

  depends_on = [
    aws_ecs_task_definition.green_task_definition
  ]
}




resource "aws_appmesh_virtual_router" "green_virtual_router" {
  name      = "${var.service_name}-router"
  mesh_name = var.app_mesh_mesh_name

  spec {
    listener {
      port_mapping {
        port     = var.application_web_port
        protocol = "http"
      }
    }
  }
}

#resource "aws_appmesh_route" "green_virtual_route" {
#  name                = "${var.service_name}-color-route"
#  mesh_name           = var.app_mesh_mesh_name
#  virtual_router_name = aws_appmesh_virtual_router.green_virtual_router.name
#
#  spec {
#    http_route {
#      match {
#        prefix = "/"
#      }
#
#      action {
#        weighted_target {
#          virtual_node = aws_appmesh_virtual_node.green_virtual_node.name
#          weight       = 100
#        }
#      }
#    }
#  }
#}

resource "aws_appmesh_virtual_service" "green_virtual_service" {
  name      = "${var.service_name}.${var.cloud_map_namespace_name}"
  mesh_name = var.app_mesh_mesh_name

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.green_virtual_router.name
      }
    }
  }
}

#resource "aws_appmesh_gateway_route" "green_gateway_route" {
#  name                 = "green"
#  mesh_name            = var.app_mesh_mesh_name
#  virtual_gateway_name = var.app_mesh_vg_name
#
#  spec {
#    http_route {
#      action {
#        target {
#          virtual_service {
#            virtual_service_name = aws_appmesh_virtual_service.green_virtual_service.name
#          }
#        }
#      }
#
#      match {
#        prefix = "/green"
#      }
#    }
#  }
#}
