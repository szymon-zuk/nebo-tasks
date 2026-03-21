data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  server_user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y python3

    mkdir -p /opt/netinfra/p${var.demo_app_port_allow} /opt/netinfra/p${var.demo_app_port_nacl_deny}
    echo "ALLOWED — reached port ${var.demo_app_port_allow}" > /opt/netinfra/p${var.demo_app_port_allow}/index.txt
    echo "NACL deny port ${var.demo_app_port_nacl_deny}" > /opt/netinfra/p${var.demo_app_port_nacl_deny}/index.txt

    printf '%s\n' \
      '[Unit]' \
      'Description=Netinfra demo HTTP (NACL-allowed port)' \
      'After=network-online.target' \
      'Wants=network-online.target' \
      '' \
      '[Service]' \
      'Type=simple' \
      'WorkingDirectory=/opt/netinfra/p${var.demo_app_port_allow}' \
      'ExecStart=/usr/bin/python3 -m http.server ${var.demo_app_port_allow} --bind 0.0.0.0' \
      'Restart=on-failure' \
      '' \
      '[Install]' \
      'WantedBy=multi-user.target' \
      > /etc/systemd/system/netinfra-demo-allow.service

    printf '%s\n' \
      '[Unit]' \
      'Description=Netinfra demo HTTP (NACL-denied port)' \
      'After=network-online.target' \
      'Wants=network-online.target' \
      '' \
      '[Service]' \
      'Type=simple' \
      'WorkingDirectory=/opt/netinfra/p${var.demo_app_port_nacl_deny}' \
      'ExecStart=/usr/bin/python3 -m http.server ${var.demo_app_port_nacl_deny} --bind 0.0.0.0' \
      'Restart=on-failure' \
      '' \
      '[Install]' \
      'WantedBy=multi-user.target' \
      > /etc/systemd/system/netinfra-demo-deny.service

    systemctl daemon-reload
    systemctl enable --now netinfra-demo-allow.service netinfra-demo-deny.service
  EOT
}

resource "aws_instance" "client" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.client.id
  vpc_security_group_ids = [aws_security_group.client.id]
  iam_instance_profile   = aws_iam_instance_profile.lab_instance.name

  user_data_replace_on_change = true
  user_data                   = "#!/bin/bash\n# client — tests run via SSM; no listeners required\n"

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-client"
    Environment = var.environment
    Role        = "netinfra-client"
  }
}

resource "aws_instance" "server" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_server.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = aws_iam_instance_profile.lab_instance.name
  user_data_replace_on_change = true
  user_data                   = local.server_user_data

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${local.aws_name_prefix}-netinfra-server"
    Environment = var.environment
    Role        = "netinfra-server"
  }
}
