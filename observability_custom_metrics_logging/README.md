# Custom Metrics for Monitoring and Logging

Implementation of custom application metrics for a FastAPI service deployed on **AWS ECS Fargate**, using **Embedded Metric Format (EMF)** for CloudWatch integration. Infrastructure is managed with **Terraform**.

## Custom Metrics Defined

Five custom metrics are published under namespace **`CustomMetricsLogging/App`** with dimensions `Service` and `Endpoint`:

| Metric                  | Type    | Unit         | Purpose                                              |
| ----------------------- | ------- | ------------ | ---------------------------------------------------- |
| **RequestCount**        | Counter | Count        | Total HTTP requests; correlates with traffic volume. |
| **RequestLatencyMs**    | Gauge   | Milliseconds | Per-request response time (Average/p99).             |
| **ErrorCount**          | Counter | Count        | Responses with status >= 400; drives alerting.       |
| **ActiveRequests**      | Gauge   | Count        | In-flight requests; indicates concurrency.           |
| **EndpointInvocations** | Counter | Count        | Per-route call counts (`/`, `/Welcome`, `/error`).   |

Full definitions, expected ranges, and anomaly interpretation: [docs/custom_metrics.md](docs/custom_metrics.md).

## Implementation Approach

- **Instrumentation**: A FastAPI middleware (`EMFMetricsMiddleware`) captures path, status code, latency, and active-request count per request, then flushes an EMF JSON payload to **stdout**.
- **Collection**: ECS `awslogs` driver forwards stdout to CloudWatch Logs (`/ecs/custom-metrics-logging`). CloudWatch automatically extracts EMF metrics -- no CloudWatch Agent or `PutMetricData` needed.
- **Dashboard**: Terraform-managed CloudWatch dashboard with widgets for all five metrics, broken down by endpoint.
- **Alerting**: Six CloudWatch alarms covering multiple alarm types with severity-based response:

  | Type | Alarm | Severity | Purpose |
  |------|-------|----------|---------|
  | **Threshold** | High Error Count | HIGH | Error spikes ≥5 in 2min (all endpoints) |
  | **Threshold** | Performance Degradation | MEDIUM | Avg latency >100ms for 2min |
  | **Threshold** | P99 Latency Spike | MEDIUM | Tail latency >200ms |
  | **Metric Math** | High Error Rate | HIGH | Error rate >10% of requests (calculated) |
  | **Threshold** | Service Unavailable | CRITICAL | No traffic for 10min (detects complete outage) |
  | **Composite** | Service Degraded | HIGH | Errors AND latency (multi-signal) |

  **All alarms are testable immediately** without requiring weeks of baseline data. Thresholds are initial estimates; tune based on observed patterns.

  Complete runbooks, baseline collection guidance, and testing procedures: [docs/alarms.md](docs/alarms.md)

## Project Structure

```
custom_metrics_logging/
├── fastapi-docker-optimized/
│   ├── server.py             # FastAPI app with EMF middleware
│   └── Dockerfile
├── docs/custom_metrics.md    # Metric definitions and interpretation
├── scripts/generate_traffic.sh
├── static/                   # Result screenshots
├── main.tf                   # Terraform provider
├── variables.tf              # Input variables
├── networking.tf             # Security group
├── ecr.tf                    # ECR repository
├── ecs.tf                    # ECS cluster, task, service
├── monitoring.tf             # Dashboard and alarms
└── outputs.tf
```

## Deployment

Prerequisites: AWS CLI (profile `softserve-lab`), Terraform, Docker.

```bash
# 1. Provision infrastructure
cd custom_metrics_logging
terraform init && terraform apply

# 2. Build and push image to ECR
ECR_URI=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $ECR_URI
docker build -t $ECR_URI:latest -f Dockerfile fastapi-docker-optimized
docker push $ECR_URI:latest

# 3. Force ECS to pull the new image
aws ecs update-service --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service --force-new-deployment
```

## Testing

Get the task public IP from ECS console, then generate traffic:

```bash
./scripts/generate_traffic.sh http://<public-ip>
```

Verify:

1. **Logs**: CloudWatch Logs > `/ecs/custom-metrics-logging` -- EMF JSON lines with `_aws` section.
2. **Metrics**: CloudWatch Metrics > namespace `CustomMetricsLogging/App` -- all five metrics present.
3. **Dashboard**: CloudWatch Dashboards > **szzuk-custom-metrics-logging-dashboard** -- widgets show time-series data.
4. **Alarms**: Test different alarm types:

```bash
# Test Threshold Alarm: High Error Count
for i in {1..6}; do curl http://<public-ip>/error; sleep 1; done
# Expected: high-error-count → ALARM (HIGH severity)

# Test Metric Math Alarm: High Error Rate (percentage-based)
# Send 10 requests with 5 errors (50% error rate)
for i in {1..5}; do curl http://<public-ip>/; sleep 1; done &
for i in {1..5}; do curl http://<public-ip>/error; sleep 0.5; done &
wait
# Expected: high-error-rate → ALARM (50% >> 10% threshold)

# Test Composite Alarm: Service Degraded (requires both errors + latency)
# Terminal 1: Generate errors
while true; do curl http://<public-ip>/error; sleep 1; done &
# Terminal 2: Generate slow requests (requires /slow endpoint)
while true; do curl http://<public-ip>/slow; sleep 0.5; done &
# Expected: service-degraded → ALARM after 2-3 min (HIGH severity)

# Monitor all alarm states and severity
aws cloudwatch describe-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --region eu-central-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

aws cloudwatch describe-composite-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --region eu-central-1
```

Complete testing guide with all alarm types: [docs/alarms.md](docs/alarms.md)

## Results

### ECS Service

![ECS Service](static/ecs.png)

### CloudWatch Dashboard

![CloudWatch Dashboard](static/dashboard.png)

### CloudWatch Alarm

![CloudWatch Alarm](static/alarm.png)

## Cleanup

```bash
terraform destroy
```
