output "client_instance_id" {
  description = "EC2 instance ID for connectivity tests (SSM session / run-command target)"
  value       = aws_instance.client.id
}

output "server_instance_id" {
  description = "EC2 instance ID for the demo server"
  value       = aws_instance.server.id
}

output "client_private_ip" {
  description = "Private IP of the client instance"
  value       = aws_instance.client.private_ip
}

output "server_private_ip" {
  description = "Private IP of the server; use with curl/nc from client"
  value       = aws_instance.server.private_ip
}

output "client_security_group_id" {
  description = "Security group ID attached to the client"
  value       = aws_security_group.client.id
}

output "server_security_group_id" {
  description = "Security group ID attached to the server"
  value       = aws_security_group.server.id
}

output "client_subnet_id" {
  value = aws_subnet.client.id
}

output "server_subnet_id" {
  value = aws_subnet.server.id
}

output "client_network_acl_id" {
  value = aws_network_acl.client.id
}

output "server_network_acl_id" {
  value = aws_network_acl.server.id
}

output "lab_route_table_id" {
  value = aws_route_table.lab_public.id
}

output "flow_log_client_subnet_id" {
  value = aws_flow_log.client_subnet.id
}

output "flow_log_server_subnet_id" {
  value = aws_flow_log.server_subnet.id
}

output "flow_log_cloudwatch_log_group_name" {
  description = "CloudWatch Logs group receiving VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "vpc_cidr" {
  value = data.aws_vpc.selected.cidr_block
}

output "demo_app_port_allow" {
  description = "TCP port permitted by both SG and NACL (positive connectivity test)"
  value       = var.demo_app_port_allow
}

output "demo_app_port_nacl_deny" {
  description = "TCP port allowed by SG but denied by server subnet NACL"
  value       = var.demo_app_port_nacl_deny
}
