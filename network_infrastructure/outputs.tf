output "client_instance_id" {
  description = "EC2 instance ID for connectivity tests (SSM session / run-command target)"
  value       = aws_instance.client.id
}

output "server_instance_id" {
  description = "EC2 instance ID for the demo server (private subnet)"
  value       = aws_instance.server.id
}

output "client_private_ip" {
  description = "Private IP of the client instance (public subnet)"
  value       = aws_instance.client.private_ip
}

output "server_private_ip" {
  description = "Private IP of the server; use with curl from client"
  value       = aws_instance.server.private_ip
}

output "client_security_group_id" {
  value = aws_security_group.client.id
}

output "server_security_group_id" {
  value = aws_security_group.server.id
}

output "client_subnet_id" {
  value = aws_subnet.client.id
}

output "server_subnet_id" {
  description = "Private subnet where the demo server runs"
  value       = aws_subnet.private_server.id
}

output "public_secondary_subnet_id" {
  description = "Second public subnet (no compute by default)"
  value       = aws_subnet.public_secondary.id
}

output "private_a_subnet_id" {
  description = "Private subnet in the same AZ as the client (reserved)"
  value       = aws_subnet.private_a.id
}

output "client_network_acl_id" {
  value = aws_network_acl.client.id
}

output "server_network_acl_id" {
  value = aws_network_acl.server.id
}

output "lab_public_route_table_id" {
  description = "Public subnets: default route to Internet Gateway"
  value       = aws_route_table.lab_public.id
}

output "lab_private_route_table_id" {
  description = "Private subnets: default route to NAT Gateway"
  value       = aws_route_table.lab_private.id
}

output "nat_gateway_id" {
  description = "NAT Gateway in the client public subnet"
  value       = aws_nat_gateway.lab.id
}

output "flow_log_client_subnet_id" {
  value = aws_flow_log.client_subnet.id
}

output "flow_log_private_server_subnet_id" {
  value = aws_flow_log.private_server_subnet.id
}

output "flow_log_cloudwatch_log_group_name" {
  description = "CloudWatch Logs group receiving VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "vpc_id" {
  description = "VPC containing the lab (created or existing)"
  value       = local.vpc_id
}

output "vpc_cidr" {
  value = local.vpc_cidr
}

output "demo_app_port_allow" {
  description = "TCP port permitted by both SG and NACL (positive connectivity test)"
  value       = var.demo_app_port_allow
}

output "demo_app_port_nacl_deny" {
  description = "TCP port allowed by SG but denied by server subnet NACL"
  value       = var.demo_app_port_nacl_deny
}
