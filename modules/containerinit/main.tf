module "init_container" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.58.1"

  container_name  = "init"
  container_image = var.init_image
  essential       = false

  environment = [
    {
      name  = "S3_BUCKET_FILE_1"
      value = "${var.init_file_one_s3_bucket}"
    },
    {
      name  = "SRC_FILE_PATH_FILE_1"
      value = "${var.init_file_one_src_file_path}"
    },
    {
      name  = "DEST_FILE_PATH_FILE_1"
      value = "${var.init_file_one_dst_file_path}"
    },
    {
      name  = "S3_BUCKET_FILE_2"
      value = "${var.init_file_two_s3_bucket}"
    },
    {
      name  = "SRC_FILE_PATH_FILE_2"
      value = "${var.init_file_two_src_file_path}"
    },
    {
      name  = "DEST_FILE_PATH_FILE_2"
      value = "${var.init_file_two_dst_file_path}"
    },
    {
      name  = "S3_BUCKET_FILE_3"
      value = "${var.init_file_three_s3_bucket}"
    },
    {
      name  = "SRC_FILE_PATH_FILE_3"
      value = "${var.init_file_three_src_file_path}"
    },
    {
      name  = "DEST_FILE_PATH_FILE_3"
      value = "${var.init_file_three_dst_file_path}"
    },
    {
      name  = "S3_BUCKET_FILE_4"
      value = "${var.init_file_four_s3_bucket}"
    },
    {
      name  = "SRC_FILE_PATH_FILE_4"
      value = "${var.init_file_four_src_file_path}"
    },
    {
      name  = "DEST_FILE_PATH_FILE_4"
      value = "${var.init_file_four_dst_file_path}"
    }
  ]

  mount_points = [
    {
      containerPath = "/envoyvolume"
      sourceVolume  = "envoyvolume"
      readOnly      = false
    },
    {
      containerPath = "/firelensvolume"
      sourceVolume  = "firelensvolume"
      readOnly      = false
    },
    {
      containerPath = "/adotvolume"
      sourceVolume  = "adotvolume"
      readOnly      = false
    }
  ]
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = "${var.log_group}"
      awslogs-region        = "${var.aws_region}"
      awslogs-stream-prefix = "init"
    }
  }
}

output "init_output" {
  value = module.init_container.json_map_object
}
