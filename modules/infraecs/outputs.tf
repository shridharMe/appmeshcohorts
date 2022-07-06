output "app_mesh_mesh_name" {
  value = aws_appmesh_mesh.mesh_1.name
}

output "ecs_cluster" {
  value = aws_ecs_cluster.ecs_1.name
}

output "task_execution_role" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "cloud_map_namespace_name" {
  value = aws_service_discovery_private_dns_namespace.cloud_map_namespace.name
}

output "cloud_map_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.cloud_map_namespace.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.config_bucket.id
}
