output "ecr_repository_url" {
  description = "ECR repository URL; use this to tag and push your image (e.g. <url>:latest)"
  value       = aws_ecr_repository.app.repository_url
}
