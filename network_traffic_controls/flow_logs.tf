resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${local.aws_name_prefix}-netdemo-flowlogs"
  retention_in_days = 7

  tags = {
    Name        = "${local.aws_name_prefix}-netdemo-flowlogs"
    Environment = var.environment
  }
}

# Subnet-level logs only (this lab’s subnets) to avoid ingesting every flow in a shared VPC.
resource "aws_flow_log" "client_subnet" {
  subnet_id            = aws_subnet.client.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name        = "${local.aws_name_prefix}-client-subnet-flow-log"
    Environment = var.environment
  }
}

resource "aws_flow_log" "server_subnet" {
  subnet_id            = aws_subnet.server.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name        = "${local.aws_name_prefix}-server-subnet-flow-log"
    Environment = var.environment
  }
}
