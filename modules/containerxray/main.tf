module "xray_container" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_depends_on = [
    {
      containerName = "init"
      condition     = "SUCCESS"
    }
  ]

  container_name  = "xray"
  container_image = var.xray_image
  essential       = true
  user            = 1337

  port_mappings = [
    {
      containerPort = 2000
      hostPort      = 2000
      protocol      = "udp"
    }
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = "${var.log_group}"
      awslogs-region        = "${var.aws_region}"
      awslogs-stream-prefix = "adot"
    }
  }
}

output "xray_output" {
  value = module.xray_container.json_map_object
}
