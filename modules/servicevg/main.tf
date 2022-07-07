## ELB Resources
resource "aws_security_group" "elb_security_group" {
  name_prefix = "elb_vg"
  description = "Allow inbound traffic to elb"
  vpc_id      = var.vpc_id

  ingress {
    description = "Inbound to the Envoy HTTP Port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}

resource "aws_lb" "vg_elb" {
  name_prefix        = "vg-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_security_group.id]
  subnets = [
    var.vpc_public_subnet_1,
    var.vpc_public_subnet_2
  ]
}

resource "aws_lb_target_group" "vg_elb_tg" {
  name_prefix = "vg-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    enabled  = true
    port     = 9901
    path     = "/ready"
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "vg_elb_listener" {
  load_balancer_arn = aws_lb.vg_elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
    }
  }
}

resource "aws_lb_listener_rule" "vg_elb_listener_rule" {
  listener_arn = aws_lb_listener.vg_elb_listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vg_elb_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

## ECS Services
resource "aws_cloudwatch_log_group" "vg_log_group" {
  name              = "/aws/ecs/service/${var.service_name}"
  retention_in_days = 7
}

resource "aws_security_group" "vg_security_group" {
  name_prefix = var.service_name
  description = "Allow inbound traffic to envoy and application"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Inbound to the Envoy HTTP Port"
    from_port       = 15000
    to_port         = 15000
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_security_group.id]
  }

  ingress {
    description     = "Inbound to the Envoy HTTPS Port"
    from_port       = 15001
    to_port         = 15001
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_security_group.id]
  }

  ingress {
    description     = "Inbound to the Envoy Admin Port"
    from_port       = 9901
    to_port         = 9901
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_security_group.id]
  }


  ingress {
    description     = "Inbound to the Application Web Port"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_security_group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}


data "aws_iam_policy_document" "vg_task_init_iam_policy" {
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

data "aws_iam_policy_document" "vg_task_firelens_iam_policy" {
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

resource "aws_iam_role" "vg_task_iam_role" {
  name_prefix = var.service_name

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
    "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess",
    "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
  ]

  inline_policy {
    name   = "retrieve_s3_configs"
    policy = data.aws_iam_policy_document.vg_task_init_iam_policy.json
  }

  inline_policy {
    name   = "firelens"
    policy = data.aws_iam_policy_document.vg_task_firelens_iam_policy.json
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

resource "aws_appmesh_virtual_gateway" "vg_1" {
  name      = var.service_name
  mesh_name = var.app_mesh_mesh_name

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }

      health_check {
        protocol            = "http"
        path                = "/"
        port                = 80
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
  }
}

module "container_init" {
  source = "../containerinit"

  aws_region = var.aws_region
  init_image = var.init_image
  log_group  = aws_cloudwatch_log_group.vg_log_group.name

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

module "container_firelens" {
  source = "../containerfirelens"

  aws_region     = var.aws_region
  firelens_image = var.firelens_image
  log_group      = aws_cloudwatch_log_group.vg_log_group.name

}

module "container_xray" {
  source = "../containerxray"

  aws_region = var.aws_region
  xray_image = var.xray_image
  log_group  = aws_cloudwatch_log_group.vg_log_group.name

}

module "vg_container" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_depends_on = [
    {
      containerName = "init"
      condition     = "SUCCESS"
    }
  ]

  container_name  = "vg"
  container_image = var.app_mesh_envoy_image
  essential       = true

  ulimits = [
    {
      name      = "nofile"
      hardLimit = 15000
      softLimit = 15000
    }
  ]

  environment = [
    {
      name  = "APPMESH_RESOURCE_ARN"
      value = "${aws_appmesh_virtual_gateway.vg_1.arn}"
    },
    {
      name  = "APPMESH_METRIC_EXTENSION_VERSION"
      value = "1"
    },
    {
      name  = "ENVOY_LOG_LEVEL"
      value = "info"
    },
    {
      name  = "ENVOY_ADMIN_ACCESS_LOG_FILE"
      value = "/dev/stdout"
    },
    {
      name  = "ENABLE_ENVOY_XRAY_TRACING"
      value = "1"
    },
    {
      name  = "XRAY_DAEMON_PORT"
      value = "2000"
    },
    {
      name  = "XRAY_SAMPLING_RULE_MANIFEST"
      value = "/data/samplingrule.json"
    }
  ]
  port_mappings = [
    {
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    },
    {
      containerPort = 9901
      hostPort      = 9901
      protocol      = "tcp"
    }
  ]
  mount_points = [
    {
      containerPath = "/data"
      sourceVolume  = "envoyvolume"
      readOnly      = true
    }
  ]
  log_configuration = {
    logDriver = "awsfirelens"
    options = {
      Name              = "cloudwatch",
      region            = "${var.aws_region}",
      log_group_name    = "${aws_cloudwatch_log_group.vg_log_group.name}",
      auto_create_group = "false",
      log_stream_prefix = "envoy",
      retry_limit       = "2"
    }
  }
}

resource "aws_ecs_task_definition" "vg_task_definition" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.task_execution_role
  task_role_arn            = aws_iam_role.vg_task_iam_role.arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    module.container_init.init_output,
    module.container_firelens.firelens_output,
    module.vg_container.json_map_object,
  module.container_xray.xray_output])

  volume {
    name = "envoyvolume"
  }
  volume {
    name = "firelensvolume"
  }

}

resource "aws_ecs_service" "vg_service" {
  name            = var.service_name
  cluster         = var.ecs_cluster
  task_definition = aws_ecs_task_definition.vg_task_definition.arn
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

  network_configuration {
    subnets = [
      var.vpc_private_subnet_1,
      var.vpc_private_subnet_2
    ]
    security_groups = [aws_security_group.vg_security_group.id]
  }

  health_check_grace_period_seconds = 30
  load_balancer {
    target_group_arn = aws_lb_target_group.vg_elb_tg.arn
    container_name   = "vg"
    container_port   = 80
  }

  depends_on = [
    aws_ecs_task_definition.vg_task_definition
  ]
}
