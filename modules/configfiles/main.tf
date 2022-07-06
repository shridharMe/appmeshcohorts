resource "aws_s3_object" "adot_config" {
  bucket = var.s3_bucket_name
  key    = "adotconfig.yaml"
  source = "./modules/configfiles/adotconfig.yaml"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("./modules/configfiles/adotconfig.yaml")
}

resource "aws_s3_object" "samplingrule" {
  bucket = var.s3_bucket_name
  key    = "samplingrule.json"
  source = "./modules/configfiles/samplingrule.json"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("./modules/configfiles/samplingrule.json")
}

# Example config here
# https://github.com/aws-samples/amazon-ecs-firelens-examples/tree/mainline/examples/fluent-bit/parse-envoy-app-mesh

resource "aws_s3_object" "fluentbit_config" {
  bucket = var.s3_bucket_name
  key    = "fluent-bit.conf"
  source = "./modules/configfiles/fluent-bit.conf"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("./modules/configfiles/fluent-bit.conf")
}

resource "aws_s3_object" "fluenbit_parsers" {
  bucket = var.s3_bucket_name
  key    = "envoy_parser.conf"
  source = "./modules/configfiles/envoy_parser.conf"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("./modules/configfiles/envoy_parser.conf")
}
