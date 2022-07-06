output "elb_address" {
  value = aws_lb.vg_elb.dns_name
}

output "app_mesh_vg_name" {
  value = aws_appmesh_virtual_gateway.vg_1.name
}

output "app_mesh_vg_sg" {
  value = aws_security_group.vg_security_group.id
}
