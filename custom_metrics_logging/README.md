# ECS Fargate + Custom Metrics (EMF) with FastAPI

This project deploys a FastAPI application on AWS ECS Fargate with **custom metrics** using the **Embedded Metric Format (EMF)**. Metrics are emitted by the app, sent to CloudWatch Logs via the ECS awslogs driver, and automatically extracted by CloudWatch for dashboards and alarms.

Deployment is managed with Terraform (ECS cluster, task definition, log group, dashboard, and alarms). The app runs in a Fargate Spot task.

## Project Structure

```
custom_metrics_logging/
├── docs/
│   └── custom_metrics.md    # Metric definitions, purpose, and interpretation
├── fastapi-docker-optimized/
│   ├── server.py           # FastAPI app with EMF middleware
│   ├── Dockerfile
│   └── pyproject.toml
├── scripts/
│   └── generate_traffic.sh # Optional: generate load for testing metrics
├── main.tf                 # Terraform: ECS, log group, dashboard, alarms
├── Dockerfile              # Alternative Dockerfile (build context = fastapi-docker-optimized)
└── README.md
```

## Prerequisites

- AWS CLI installed and configured with profile **softserve-lab** (or set `AWS_PROFILE`).
- Terraform installed.
- Docker installed for building the container image.
- AWS account with permissions for ECS, IAM, CloudWatch, and VPC.

## Custom Metrics Defined

All metrics are published under the namespace **`CustomMetricsLogging/App`**.

| Metric                  | Type    | Unit         | Purpose                                                                   |
| ----------------------- | ------- | ------------ | ------------------------------------------------------------------------- |
| **RequestCount**        | Counter | Count        | Total HTTP requests; correlates with traffic volume.                      |
| **RequestLatencyMs**    | Gauge   | Milliseconds | Response time per request; use CloudWatch Average/p99 for trends.         |
| **ErrorCount**          | Counter | Count        | Responses with status code ≥ 400; for error rate and alerting.            |
| **ActiveRequests**      | Gauge   | Count        | Requests in flight; indicates concurrency.                                |
| **EndpointInvocations** | Counter | Count        | Per-route invocations (dimension: `Endpoint`: `/`, `/Welcome`, `/error`). |

Detailed definitions, expected ranges, and how to interpret anomalies are in [docs/custom_metrics.md](docs/custom_metrics.md).

## Implementation

- **Library**: [aws-embedded-metrics](https://github.com/awslabs/aws-embedded-metrics-python). Metrics are written as EMF JSON to **stdout**.
- **Instrumentation**: A FastAPI middleware records each request (path, status code, latency, active-request count) and flushes one EMF payload per request.
- **Configuration**: Namespace and service name can be overridden with env vars:
  - `AWS_EMF_NAMESPACE` (default in code: `CustomMetricsLogging/App`)
  - `AWS_EMF_SERVICE_NAME` (default in code: `fastapi-custom-metrics`)

## Collection Mechanism

1. The app writes EMF log lines to **stdout**.
2. The ECS **awslogs** log driver sends container stdout to **CloudWatch Logs** (log group: `/ecs/custom-metrics-logging`).
3. **CloudWatch** automatically parses EMF and creates metrics in the namespace `CustomMetricsLogging/App`.
4. No CloudWatch Agent or `PutMetricData` IAM permission is required; the task **execution role** (with `logs:PutLogEvents`) is sufficient.

## Deployment

Subnet IDs, security group IDs, and the container image are **not** hardcoded for your account—you must supply them (or replace the defaults in `main.tf`). This project uses **ECR** for the container image: Terraform creates an ECR repository; you build and push the image there, then ECS pulls from it.

### Where to get subnet and security group IDs

- **Subnets**: AWS Console → **VPC** → **Subnets**, or:
  ```bash
  aws ec2 describe-subnets --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" --output table
  ```
  Use subnets where your ECS tasks can run (e.g. public subnets if you use `assign_public_ip = true`).
- **Security group**: AWS Console → **VPC** → **Security groups**. Create or pick one that allows:
  - **Inbound**: port 80 (for the FastAPI app).
  - **Outbound**: all (or at least HTTPS for ECR and CloudWatch).
- Override the defaults in `main.tf` or pass variables:
  ```bash
  terraform apply -var="subnet_ids=[subnet-xxx]" -var="security_group_ids=[sg-xxx]"
  ```

### 1. Create infrastructure (including ECR)

Terraform creates the ECR repository **custom-metrics-logging** and the rest of the stack. Apply first so you have the ECR repo URL.

```bash
cd custom_metrics_logging
terraform init
terraform plan -out=tfplan
terraform apply "tfplan"
```

After apply, Terraform creates:

- **ECR repository** `custom-metrics-logging` (used as the task image when `container_image` is not set)
- ECS cluster and service (Fargate Spot)
- Task definition with **logConfiguration** (awslogs → `/ecs/custom-metrics-logging`)
- CloudWatch log group, dashboard **CustomMetricsLogging-App**, and alarm **custom-metrics-logging-high-error-count**

Get the ECR repository URL (used in the next step):

```bash
terraform output -raw ecr_repository_url
# or
aws ecr describe-repositories --repository-names custom-metrics-logging --query "repositories[0].repositoryUri" --output text
```

### 2. Build and push the image to ECR

Authenticate Docker to ECR (use profile **softserve-lab** and region **eu-central-1**), then build and push:

```bash
export AWS_PROFILE=softserve-lab
export AWS_REGION=eu-central-1
ECR_URI=$(aws ecr describe-repositories --repository-names custom-metrics-logging --query "repositories[0].repositoryUri" --output text)

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

# From repo root; build context = fastapi-docker-optimized
docker build -t $ECR_URI:latest -f custom_metrics_logging/Dockerfile custom_metrics_logging/fastapi-docker-optimized
docker push $ECR_URI:latest
```

Or from **custom_metrics_logging**:

```bash
ECR_URI=$(aws ecr describe-repositories --repository-names custom-metrics-logging --query "repositories[0].repositoryUri" --output text)
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $ECR_URI
docker build -t $ECR_URI:latest -f Dockerfile fastapi-docker-optimized
docker push $ECR_URI:latest
```

The task definition is already set to use this ECR image (`repository_url:latest`) when `container_image` is empty.

### 3. Run the service (or force new deployment)

If the ECS service was created before the first push, trigger a new deployment so it pulls the image:

```bash
aws ecs update-service --cluster custom-metrics-logging-cluster --service fastapi-fargate-service --force-new-deployment
```

### Using a different registry (optional)

To use Docker Hub or another registry instead of ECR, set the **container_image** variable and do **not** rely on the ECR repo for the image:

```bash
terraform apply -var="container_image=your-registry/fastapi-fargate:latest"
```

You still need to supply **subnet_ids** and **security_group_ids** for your VPC (override the defaults in `main.tf` or pass them as variables).

## Dashboard

- **Name**: `CustomMetricsLogging-App`
- **Location**: CloudWatch → Dashboards → **CustomMetricsLogging-App**

Widgets:

- **Request Count**: Sum of `RequestCount` over time.
- **Request Latency (ms)**: Average and p99 of `RequestLatencyMs`.
- **Error Count**: Sum of `ErrorCount` over time.
- **Active Requests**: Maximum of `ActiveRequests` (in-flight).
- **Endpoint Invocations**: Sum of `EndpointInvocations` per endpoint (`/`, `/Welcome`, `/error`).

Use the dashboard time range to include the period when you generated traffic. Trends should match request volume and any intentional errors (e.g. calls to `/error`).

## Alerts

- **Alarm**: `custom-metrics-logging-high-error-count`
- **Condition**: Sum of **ErrorCount** over **2 minutes** ≥ **5** (for namespace `CustomMetricsLogging/App`, dimension `Service=fastapi-custom-metrics`).
- **Meaning**: Triggers when the application returns 4xx/5xx at least 5 times in 2 minutes.
- **Tuning**: Change `threshold` or `period`/`evaluation_periods` in the `aws_cloudwatch_metric_alarm.high_error_count` resource in `main.tf`, then re-apply.

Optional: add SNS topic and subscription for notifications (not included in this Terraform).

## Testing Metrics Collection and Dashboard

### 1. Get the app URL and log group

After deployment, get the **public IP** of the Fargate task (ECS console → Cluster → Service → Tasks → Task → Network).

- **App URL**: `http://<public-ip>` (port 80)
- **Log group**: `/ecs/custom-metrics-logging`

### 2. Generate traffic

Use the script (from repo root or `custom_metrics_logging`):

```bash
chmod +x scripts/generate_traffic.sh
./scripts/generate_traffic.sh http://<public-ip>
```

Or run manually for a few minutes:

```bash
# Successful requests
for i in $(seq 1 50); do curl -s -o /dev/null http://<public-ip>/; curl -s -o /dev/null "http://<public-ip>/Welcome?name=Test"; done

# Trigger errors (for ErrorCount and alarm)
for i in $(seq 1 10); do curl -s -o /dev/null http://<public-ip>/error; done
```

### 3. Verify logs (EMF ingestion)

1. CloudWatch → **Log groups** → `/ecs/custom-metrics-logging`.
2. Open a **log stream** (prefix `ecs/custom-metrics-logging-container/...`).
3. Confirm **EMF lines**: JSON with an `_aws` section and metric definitions (e.g. `RequestCount`, `RequestLatencyMs`). This confirms the app is emitting EMF and awslogs is delivering to CloudWatch Logs.

### 4. Verify metrics in CloudWatch Metrics

1. CloudWatch → **Metrics** → **All metrics**.
2. Select namespace **CustomMetricsLogging/App**.
3. Check that **RequestCount**, **RequestLatencyMs**, **ErrorCount**, **ActiveRequests**, **EndpointInvocations** appear and have data for the time range of your traffic.

### 5. Validate the dashboard

1. Open the **CustomMetricsLogging-App** dashboard.
2. Set the time range to include your test run.
3. Confirm widgets show time-series data: request count and endpoint invocations rise with traffic; latency shows average/p99; error count rises only when you hit `/error`.

### 6. Optional: test the alarm

Trigger at least 5 errors within 2 minutes (e.g. multiple calls to `/error`). In CloudWatch → **Alarms**, confirm **custom-metrics-logging-high-error-count** moves to **ALARM**.

## Accessing the Application

- **Root**: `http://<public-ip>/` → `{"message": "Hello, World!"}`
- **Welcome**: `http://<public-ip>/Welcome?name=YourName`
- **Error (for testing)**: `http://<public-ip>/error` → HTTP 500

Ensure the security group allows inbound traffic on port 80.

## Cleanup

```bash
terraform destroy
```

## Notes

- Metric names use PascalCase; dimensions are `Service` and `Endpoint`. This avoids ambiguity and keeps cardinality low.
- Instrumentation adds one EMF flush per request to stdout; overhead is minimal.
- Log retention is set via Terraform variable `log_retention_days` (default 14) for the log group.
