output "ami_id" {
  description = "ID of the most recent custom AMI"
  value       = data.aws_ami.custom.id
}

output "ami_name" {
  description = "Name of the most recent custom AMI"
  value       = data.aws_ami.custom.name
}

output "ami_creation_date" {
  description = "Creation date of the most recent custom AMI"
  value       = data.aws_ami.custom.creation_date
}

output "ami_tags" {
  description = "Tags on the most recent custom AMI"
  value       = data.aws_ami.custom.tags
}
