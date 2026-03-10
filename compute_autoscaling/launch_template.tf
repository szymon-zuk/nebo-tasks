data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ec2_instance" {
  name = "${var.project_name}-${var.environment}-asg-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-asg-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${var.project_name}-${var.environment}-asg-instance-profile"
  role = aws_iam_role.ec2_instance.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-asg-instance-profile"
    Environment = var.environment
  }
}

resource "aws_launch_template" "app" {
  name        = "${var.project_name}-${var.environment}-launch-template"
  description = "Launch template for autoscaling EC2 instances with nginx and stress-ng"

  image_id      = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    yum update -y
    yum install -y nginx stress-ng

    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
    <head><title>AutoScaling Instance</title></head>
    <body>
      <h1>EC2 Auto Scaling Demo</h1>
      <p>Instance ID: <span id="iid"></span></p>
      <script>
        fetch("http://169.254.169.254/latest/meta-data/instance-id")
          .then(r => r.text())
          .then(id => document.getElementById("iid").textContent = id)
          .catch(() => document.getElementById("iid").textContent = "unavailable");
      </script>
    </body>
    </html>
    HTML

    systemctl enable nginx
    systemctl start nginx
  EOF
  )

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-asg-instance"
      Environment = var.environment
      Owner       = "szzuk@softserveinc.com"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.project_name}-${var.environment}-asg-volume"
      Environment = var.environment
      Owner       = "szzuk@softserveinc.com"
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      Name        = "${var.project_name}-${var.environment}-asg-eni"
      Environment = var.environment
      Owner       = "szzuk@softserveinc.com"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-launch-template"
    Environment = var.environment
  }
}
