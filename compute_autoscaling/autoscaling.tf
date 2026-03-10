resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_cooldown          = var.cooldown_period

  enabled_metrics = [
    "GroupInServiceInstances",
    "GroupDesiredCapacity",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------
# Policy 1: Target Tracking — CPU Utilization
# AWS automatically creates and manages both scale-out and scale-in alarms.
# This is the simplest and most recommended approach for most workloads.
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-${var.environment}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

# ---------------------------------------------------------------------------
# Policy 2: Step Scaling — ALB Request Count Per Target
# Requires explicit CloudWatch alarms. Provides multi-step granularity:
#   +1 instance when requests exceed threshold
#   +2 instances when requests exceed 2x threshold
#   -1 instance when requests drop below low threshold
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "request_scale_out" {
  name                    = "${var.project_name}-${var.environment}-request-scale-out"
  autoscaling_group_name  = aws_autoscaling_group.app.name
  policy_type             = "StepScaling"
  adjustment_type         = "ChangeInCapacity"
  metric_aggregation_type = "Average"

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = 100
  }

  step_adjustment {
    scaling_adjustment          = 2
    metric_interval_lower_bound = 100
  }
}

resource "aws_autoscaling_policy" "request_scale_in" {
  name                    = "${var.project_name}-${var.environment}-request-scale-in"
  autoscaling_group_name  = aws_autoscaling_group.app.name
  policy_type             = "StepScaling"
  adjustment_type         = "ChangeInCapacity"
  metric_aggregation_type = "Average"

  step_adjustment {
    scaling_adjustment          = -1
    metric_interval_upper_bound = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "request_high" {
  alarm_name          = "${var.project_name}-${var.environment}-request-count-high"
  alarm_description   = "Scale out when ALB request count per target exceeds ${var.scale_out_request_threshold}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.scale_out_request_threshold
  alarm_actions       = [aws_autoscaling_policy.request_scale_out.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-request-count-high"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "request_low" {
  alarm_name          = "${var.project_name}-${var.environment}-request-count-low"
  alarm_description   = "Scale in when ALB request count per target drops below ${var.scale_in_request_threshold}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.scale_in_request_threshold
  alarm_actions       = [aws_autoscaling_policy.request_scale_in.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-request-count-low"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# Scheduled Scaling: Business Hours
# Scale up to a higher minimum during weekday business hours (7 AM–5 PM UTC)
# to handle predictable weekday traffic patterns.
# ---------------------------------------------------------------------------

resource "aws_autoscaling_schedule" "scale_up_business_hours" {
  scheduled_action_name  = "${var.project_name}-${var.environment}-scale-up-business-hours"
  autoscaling_group_name = aws_autoscaling_group.app.name
  recurrence             = "0 7 * * MON-FRI"
  min_size               = var.business_hours_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.business_hours_min_size
}

resource "aws_autoscaling_schedule" "scale_down_after_hours" {
  scheduled_action_name  = "${var.project_name}-${var.environment}-scale-down-after-hours"
  autoscaling_group_name = aws_autoscaling_group.app.name
  recurrence             = "0 17 * * MON-FRI"
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_min_size
}
