resource "aws_cloudwatch_dashboard" "custom_metrics" {
  dashboard_name = "szzuk-custom-metrics-logging-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Request Count"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "RequestCount", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Sum" }],
            ["...", "Endpoint", "/Welcome", { stat = "Sum" }],
            ["...", "Endpoint", "/error", { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Request Latency (ms)"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "RequestLatencyMs", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Average" }],
            ["...", "Endpoint", "/Welcome", { stat = "Average" }],
            ["...", "Endpoint", "/error", { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Error Count"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "ErrorCount", "Service", "fastapi-custom-metrics", "Endpoint", "/error", { stat = "Sum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Active Requests"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "ActiveRequests", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Maximum" }],
            ["...", "Endpoint", "/Welcome", { stat = "Maximum" }],
            ["...", "Endpoint", "/error", { stat = "Maximum" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Endpoint Invocations"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "EndpointInvocations", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Sum" }],
            ["...", "Endpoint", "/Welcome", { stat = "Sum" }],
            ["...", "Endpoint", "/error", { stat = "Sum" }]
          ]
        }
      }
    ]
  })
}

# Alarm when ErrorCount (sum over 2 minutes) is >= 5
resource "aws_cloudwatch_metric_alarm" "high_error_count" {
  alarm_name          = "szzuk-custom-metrics-logging-high-error-count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "CustomMetricsLogging/App"
  period              = 120
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Triggers when application error count (4xx/5xx) sum over 2 minutes is >= 5"

  dimensions = {
    Service  = "fastapi-custom-metrics"
    Endpoint = "/error"
  }
}
