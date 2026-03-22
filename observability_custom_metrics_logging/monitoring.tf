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
          title  = "Request Latency (ms)"
          view   = "timeSeries"
          region = "eu-central-1"
          metrics = [
            ["CustomMetricsLogging/App", "RequestLatencyMs", "Service", "fastapi-custom-metrics", "Endpoint", "/", { stat = "Average" }],
            ["...", "Endpoint", "/Welcome", { stat = "Average" }],
            ["...", "Endpoint", "/error", { stat = "Average" }],
            ["...", "Endpoint", "/orders", { stat = "Average" }],
            ["...", "Endpoint", "/auth/login", { stat = "Average" }],
            ["...", "Endpoint", "/auth/signup", { stat = "Average" }],
            ["...", "Endpoint", "/slow", { stat = "Average" }]
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
          title  = "Error Count (GET /error only)"
          view   = "timeSeries"
          region = "eu-central-1"
          period = 60
          # Only /error publishes ErrorCount today; other routes are 2xx and never emit this metric.
          metrics = [
            ["CustomMetricsLogging/App", "ErrorCount", "Service", "fastapi-custom-metrics", "Endpoint", "/error", { stat = "Sum", label = "ErrorCount /error" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Business events"
          view   = "timeSeries"
          region = "eu-central-1"
          period = 60
          # Full metric rows (no "..." shorthand) so all three series resolve reliably in the console.
          metrics = [
            ["CustomMetricsLogging/App", "OrdersCount", "Service", "fastapi-custom-metrics", { stat = "Sum", label = "OrdersCount", period = 60 }],
            ["CustomMetricsLogging/App", "UserSignupCount", "Service", "fastapi-custom-metrics", { stat = "Sum", label = "UserSignupCount", period = 60 }],
            ["CustomMetricsLogging/App", "UserLoginCount", "Service", "fastapi-custom-metrics", { stat = "Sum", label = "UserLoginCount", period = 60 }]
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
# ALARM TYPE 2: ANOMALY DETECTION - User login volume
# Severity: MEDIUM | CloudWatch model on UserLoginCount (custom business metric)
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "user_login_anomaly" {
  alarm_name                = "szzuk-custom-metrics-logging-user-login-anomaly"
  comparison_operator       = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods        = 3
  threshold_metric_id       = "ad1"
  alarm_description         = "[MEDIUM] UserLoginCount outside expected band (anomaly). May indicate traffic spike, abuse, or broken clients. Tune after baseline exists."
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "UserLoginCount (expected range)"
    return_data = true
  }

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = "UserLoginCount"
      namespace   = "CustomMetricsLogging/App"
      period      = 60
      stat        = "Sum"

      dimensions = {
        Service = "fastapi-custom-metrics"
      }
    }
  }

  tags = {
    Severity = "MEDIUM"
    Type     = "AnomalyDetection"
    Runbook  = "login-anomaly"
  }
}

# ==============================================================================
# ALARM TYPE 3: STATIC THRESHOLD - High order volume (business metric)
# Severity: LOW | Demo threshold on OrdersCount — adjust for real SLOs
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "high_orders_volume" {
  alarm_name          = "szzuk-custom-metrics-logging-high-orders-volume"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "OrdersCount"
  namespace           = "CustomMetricsLogging/App"
  period              = 300
  statistic           = "Sum"
  threshold           = 40
  alarm_description   = "[LOW] OrdersCount sum >40 in 5 minutes (lab-friendly; raise for production)."
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service = "fastapi-custom-metrics"
  }

  tags = {
    Severity = "LOW"
    Type     = "Threshold"
    Runbook  = "orders-volume"
  }
}

# ==============================================================================
# ALARM TYPE 4: METRIC MATH - High Error Rate Percentage
# Severity: HIGH | Calculates error rate as percentage of total requests
# ==============================================================================
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "szzuk-custom-metrics-logging-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 10
  alarm_description   = "[HIGH] Error rate >10% of requests (vs RequestLatencyMs sample count) in one 60s period. Runbook: https://github.com/your-org/runbooks/high-error-rate"
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
      metric_name = "RequestLatencyMs"
      namespace   = "CustomMetricsLogging/App"
      period      = 60
      stat        = "SampleCount"

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
# ALARM TYPE 5: COMPOSITE - Errors + abnormal login traffic
# Severity: HIGH | Fires when error spike coincides with anomalous UserLoginCount
# Alarm name changed once from ...-service-degraded so Terraform can replace the
# composite before AWS allows deleting old rule dependencies (e.g. performance_degradation).
# ==============================================================================
resource "aws_cloudwatch_composite_alarm" "service_degraded" {
  alarm_name        = "szzuk-custom-metrics-logging-composite-errors-login-anomaly"
  alarm_description = "[HIGH] High ErrorCount AND UserLoginCount anomaly together (possible incident or attack). Runbook: https://github.com/your-org/runbooks/service-degraded"
  actions_enabled   = true

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.high_error_count.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.user_login_anomaly.alarm_name})"

  tags = {
    Severity = "HIGH"
    Type     = "Composite"
    Runbook  = "service-degraded"
  }
}
