resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${local.aws_name_prefix}-netinfra-flowlogs"
  retention_in_days = 7

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-flowlogs"
    Environment = var.environment
  }
}

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

resource "aws_flow_log" "private_server_subnet" {
  subnet_id            = aws_subnet.private_server.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name        = "${local.aws_name_prefix}-private-server-subnet-flow-log"
    Environment = var.environment
  }
}
