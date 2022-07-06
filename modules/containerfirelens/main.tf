module "firelens_container" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_depends_on = [
    {
      containerName = "init"
      condition     = "SUCCESS"
    }
  ]

  container_name  = "firelens"
  container_image = var.firelens_image
  essential       = true

  environment = []

  firelens_configuration = {
    type = "fluentbit",
    options = {
      enable-ecs-log-metadata = "true",
      config-file-type        = "file"
      config-file-value       = "/data/fluent-bit.conf"
    }
  }

  mount_points = [
    {
      containerPath = "/data"
      sourceVolume  = "firelensvolume"
      readOnly      = true
    }
  ]
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = "${var.log_group}"
      awslogs-region        = "${var.aws_region}"
      awslogs-stream-prefix = "fluentbit"
    }
  }
}

output "firelens_output" {
  value = module.firelens_container.json_map_object
}
