module "envoy_container" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_depends_on = [
    {
      containerName = "init"
      condition     = "SUCCESS"
    }
  ]

  container_name  = "envoy"
  container_image = var.envoy_image
  essential       = true
  user            = "1337"

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
      value = "${var.app_mesh_virtual_node_arn}"
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
      containerPort = 15000
      hostPort      = 15000
      protocol      = "tcp"
    },
    {
      containerPort = 15001
      hostPort      = 15001
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
      log_group_name    = "${var.log_group}",
      auto_create_group = "false",
      log_stream_prefix = "envoy",
      retry_limit       = "2"
    }
  }
}

output "envoy_output" {
  value = module.envoy_container.json_map_object
}
