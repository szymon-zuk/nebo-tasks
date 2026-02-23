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

# ==============================================================================
# ALARM TYPE 1: STATIC THRESHOLD - High Error Count
# Severity: HIGH | Monitors ALL endpoints for errors
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "high_error_count" {
  alarm_name          = "szzuk-custom-metrics-logging-high-error-count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "CustomMetricsLogging/App"
  period              = 120
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "[HIGH] Triggers when 5+ errors occur across ALL endpoints in 2 minutes. Runbook: https://github.com/your-org/runbooks/error-spike"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service = "fastapi-custom-metrics"
    # Note: No Endpoint dimension - monitors errors from ALL endpoints
  }

  tags = {
    Severity = "HIGH"
    Type     = "Threshold"
    Runbook  = "error-spike"
  }
}

# ==============================================================================
# ALARM TYPE 2: STATIC THRESHOLD - Performance Degradation
# Severity: MEDIUM | Validates RequestLatencyMs metric
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "performance_degradation" {
  alarm_name          = "szzuk-custom-metrics-logging-performance-degradation"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestLatencyMs"
  namespace           = "CustomMetricsLogging/App"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "[MEDIUM] Average latency >100ms for 2 minutes. Runbook: https://github.com/your-org/runbooks/high-latency"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service = "fastapi-custom-metrics"
  }

  tags = {
    Severity = "MEDIUM"
    Type     = "Threshold"
    Runbook  = "high-latency"
  }
}

# ==============================================================================
# ALARM TYPE 3: STATIC THRESHOLD - P99 Latency Spike
# Severity: MEDIUM | Monitors tail latency
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "latency_p99_spike" {
  alarm_name          = "szzuk-custom-metrics-logging-latency-p99-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  extended_statistic  = "p99"
  metric_name         = "RequestLatencyMs"
  namespace           = "CustomMetricsLogging/App"
  period              = 300
  threshold           = 200
  alarm_description   = "[MEDIUM] P99 latency >200ms. Affects 1% of users. Runbook: https://github.com/your-org/runbooks/tail-latency"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service = "fastapi-custom-metrics"
  }

  tags = {
    Severity = "MEDIUM"
    Type     = "Threshold"
    Runbook  = "tail-latency"
  }
}

# ==============================================================================
# ALARM TYPE 4: METRIC MATH - High Error Rate Percentage
# Severity: HIGH | Calculates error rate as percentage of total requests
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "szzuk-custom-metrics-logging-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 10
  alarm_description   = "[HIGH] Error rate >10% of total requests for 2 periods. Runbook: https://github.com/your-org/runbooks/high-error-rate"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "errors"
    return_data = false

    metric {
      metric_name = "ErrorCount"
      namespace   = "CustomMetricsLogging/App"
      period      = 60
      stat        = "Sum"

      dimensions = {
        Service = "fastapi-custom-metrics"
      }
    }
  }

  metric_query {
    id          = "requests"
    return_data = false

    metric {
      metric_name = "RequestCount"
      namespace   = "CustomMetricsLogging/App"
      period      = 60
      stat        = "Sum"

      dimensions = {
        Service = "fastapi-custom-metrics"
      }
    }
  }

  metric_query {
    id          = "error_rate"
    expression  = "(errors / requests) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }

  tags = {
    Severity = "HIGH"
    Type     = "MetricMath"
    Runbook  = "high-error-rate"
  }
}

# ==============================================================================
# ALARM TYPE 5: STATIC THRESHOLD - Service Availability
# Severity: CRITICAL | Detects complete service outage
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "service_unavailable" {
  alarm_name          = "szzuk-custom-metrics-logging-service-unavailable"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "CustomMetricsLogging/App"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "[CRITICAL] No requests for 10 minutes - service may be down. Runbook: https://github.com/your-org/runbooks/service-down"
  treat_missing_data  = "breaching"

  dimensions = {
    Service = "fastapi-custom-metrics"
  }

  tags = {
    Severity = "CRITICAL"
    Type     = "Threshold"
    Runbook  = "service-down"
  }
}

# ==============================================================================
# ALARM TYPE 6: COMPOSITE - Service Degraded
# Severity: HIGH | Combines errors + latency for degraded state
# ==============================================================================
resource "aws_cloudwatch_composite_alarm" "service_degraded" {
  alarm_name          = "szzuk-custom-metrics-logging-service-degraded"
  alarm_description   = "[HIGH] Service is degraded: high errors AND high latency simultaneously. Runbook: https://github.com/your-org/runbooks/service-degraded"
  actions_enabled     = true

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.high_error_count.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.performance_degradation.alarm_name})"

  tags = {
    Severity = "HIGH"
    Type     = "Composite"
    Runbook  = "service-degraded"
  }
}
