packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  profile       = var.aws_profile
  region        = var.aws_region
  instance_type = var.instance_type

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "x86_64"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  ssh_username                = "ubuntu"
  associate_public_ip_address = true

  ami_name        = "${var.project_name}-${var.environment}-custom-ami-{{timestamp}}"
  ami_description = var.ami_description

  tags = {
    Name        = "${var.project_name}-${var.environment}-custom-ami"
    Owner       = "szzuk@softserveinc.com"
    Environment = var.environment
    Project     = "compute-custom-ami"
    BaseOS      = "ubuntu-24.04"
    ManagedBy   = "packer"
    BuildTime   = "{{timestamp}}"
  }

  run_tags = {
    Name  = "${var.project_name}-${var.environment}-packer-builder"
    Owner = "szzuk@softserveinc.com"
  }
}

build {
  name    = "custom-ami"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    script          = "${path.root}/scripts/install-packages.sh"
    execute_command = "sudo -S bash -c '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = "${path.root}/scripts/configure-nginx.sh"
    execute_command = "sudo -S bash -c '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = "${path.root}/scripts/security-hardening.sh"
    execute_command = "sudo -S bash -c '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = "${path.root}/scripts/cleanup.sh"
    execute_command = "sudo -S bash -c '{{ .Path }}'"
  }

  post-processor "manifest" {
    output     = "${path.root}/manifest.json"
    strip_path = true
  }
}
