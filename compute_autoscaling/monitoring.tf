resource "aws_sns_topic" "scaling_notifications" {
  name = "${var.project_name}-${var.environment}-scaling-notifications"

  tags = {
    Name        = "${var.project_name}-${var.environment}-scaling-notifications"
    Environment = var.environment
  }
}

resource "aws_autoscaling_notification" "scaling_events" {
  group_names = [aws_autoscaling_group.app.name]
  topic_arn   = aws_sns_topic.scaling_notifications.arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}

resource "aws_cloudwatch_dashboard" "autoscaling" {
  dashboard_name = "${var.project_name}-${var.environment}-autoscaling"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ASG Instance Count"
          region = "eu-central-1"
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.app.name, { stat = "Average" }],
            [".", "GroupDesiredCapacity", ".", ".", { stat = "Average" }],
            [".", "GroupMinSize", ".", ".", { stat = "Average" }],
            [".", "GroupMaxSize", ".", ".", { stat = "Average" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Average CPU Utilization"
          region = "eu-central-1"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name, { stat = "Average" }],
          ]
          period = 60
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                label = "Target Tracking Threshold"
                value = var.cpu_target_value
                color = "#ff9900"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Target Response Time"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Average" }],
            ["...", { stat = "p99" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Request Count Per Target"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "RequestCountPerTarget", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum" }],
          ]
          period = 60
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                label = "Scale-Out Threshold"
                value = var.scale_out_request_threshold
                color = "#d62728"
              },
              {
                label = "Scale-In Threshold"
                value = var.scale_in_request_threshold
                color = "#2ca02c"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title  = "Healthy / Unhealthy Host Count"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Average" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average" }],
          ]
          period = 60
          view   = "timeSeries"
        }
      },
    ]
  })
}
