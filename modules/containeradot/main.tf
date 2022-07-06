module "adot_container" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_depends_on = [
    {
      containerName = "init"
      condition     = "SUCCESS"
    }
  ]

  container_name  = "adot"
  container_image = var.adot_image
  essential       = true

  command = [
    "--config",
    "/data/adotconfig.yaml"
  ]

  port_mappings = [
    {
      containerPort = 2000
      hostPort      = 2000
      protocol      = "udp"
    }
  ]

  mount_points = [
    {
      containerPath = "/data"
      sourceVolume  = "adotvolume"
      readOnly      = true
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

output "adot_output" {
  value = module.adot_container.json_map_object
}
