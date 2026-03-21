data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lab_instance" {
  name               = "${local.aws_name_prefix}-netinfra-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "lab_ssm" {
  role       = aws_iam_role.lab_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "lab_instance" {
  name = "${local.aws_name_prefix}-netinfra-instance-profile"
  role = aws_iam_role.lab_instance.name

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-instance-profile"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${local.aws_name_prefix}-netinfra-flowlogs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-flowlogs-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "flow_logs_publish" {
  name = "${local.aws_name_prefix}-netinfra-flowlogs-publish"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
