output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use as test endpoint)"
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Full URL of the Application Load Balancer"
  value       = "http://${aws_lb.app.dns_name}"
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.app.id
}

output "target_tracking_policy_arn" {
  description = "ARN of the CPU target tracking scaling policy"
  value       = aws_autoscaling_policy.cpu_target_tracking.arn
}

output "step_scale_out_policy_arn" {
  description = "ARN of the step scaling scale-out policy (request count)"
  value       = aws_autoscaling_policy.request_scale_out.arn
}

output "step_scale_in_policy_arn" {
  description = "ARN of the step scaling scale-in policy (request count)"
  value       = aws_autoscaling_policy.request_scale_in.arn
}

output "scheduled_action_names" {
  description = "Names of the scheduled scaling actions"
  value = [
    aws_autoscaling_schedule.scale_up_business_hours.scheduled_action_name,
    aws_autoscaling_schedule.scale_down_after_hours.scheduled_action_name,
  ]
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for scaling notifications"
  value       = aws_sns_topic.scaling_notifications.arn
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard for monitoring scaling activity"
  value       = "https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=${aws_cloudwatch_dashboard.autoscaling.dashboard_name}"
}

output "check_asg_status_command" {
  description = "AWS CLI command to check current ASG status"
  value       = "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.app.name} --profile softserve-lab --region eu-central-1 --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Instances:Instances[*].InstanceId}'"
}

output "check_scaling_activities_command" {
  description = "AWS CLI command to check recent scaling activities"
  value       = "aws autoscaling describe-scaling-activities --auto-scaling-group-name ${aws_autoscaling_group.app.name} --profile softserve-lab --region eu-central-1 --max-items 5 --query 'Activities[*].{Time:StartTime,Cause:Cause,Status:StatusCode}' --output table"
}
