# Custom Metrics Specification

This document defines the custom metrics emitted by the FastAPI application using AWS Embedded Metric Format (EMF) for CloudWatch.

## Namespace

- **Namespace**: `CustomMetricsLogging/App`
- All custom metrics are published under this namespace for consistent discovery and dashboards.

## Metric Definitions

### 1. RequestCount

| Attribute   | Value        |
| ----------- | ------------ |
| **Name**    | RequestCount |
| **Type**    | Counter      |
| **Unit**    | Count        |
| **Purpose** | Total HTTP requests received; correlates with traffic volume. |
| **Calculation** | Incremented by 1 for every completed request (any path, any method). |
| **Expected range** | Non-negative; grows with traffic. In low-traffic tests, tens to hundreds per minute. |
| **Anomalies** | Sudden drop to zero may indicate task failure or network issues. Unexpected spikes may indicate a traffic surge or attack. |

### 2. RequestLatencyMs

| Attribute   | Value        |
| ----------- | ------------ |
| **Name**    | RequestLatencyMs |
| **Type**    | Gauge (per request) |
| **Unit**    | Milliseconds |
| **Purpose** | Response time per request; use CloudWatch statistics (Average, p99) for trend analysis. |
| **Calculation** | Elapsed time from request start to response completion, in milliseconds. |
| **Expected range** | Typically tens to low hundreds of ms for healthy endpoints. |
| **Anomalies** | Sustained high average or p99 indicates slow dependencies or overload. |

### 3. ErrorCount

| Attribute   | Value        |
| ----------- | ------------ |
| **Name**    | ErrorCount   |
| **Type**    | Counter      |
| **Unit**    | Count        |
| **Purpose** | Count of HTTP responses with status code >= 400 (client and server errors). |
| **Calculation** | Incremented by 1 when response status >= 400. |
| **Expected range** | Zero or low in normal operation. |
| **Anomalies** | Rise in errors correlates with application or dependency failures; used for alerting. |

### 4. ActiveRequests

| Attribute   | Value        |
| ----------- | ------------ |
| **Name**    | ActiveRequests |
| **Type**    | Gauge        |
| **Unit**    | Count        |
| **Purpose** | Number of requests currently in flight; indicates concurrency. |
| **Calculation** | Incremented at request start, decremented at request end. |
| **Expected range** | Depends on traffic; usually low for single-task deployment. |
| **Anomalies** | Sustained high value may indicate slow requests or backlog. |

### 5. EndpointInvocations

| Attribute   | Value        |
| ----------- | ------------ |
| **Name**    | EndpointInvocations |
| **Type**    | Counter (with dimension `Endpoint`) |
| **Unit**    | Count        |
| **Purpose** | Per-route invocation count; business relevance by path (e.g. root vs Welcome). |
| **Calculation** | Incremented by 1 per request with dimension `Endpoint` set to the path template (e.g. `/`, `/Welcome`). |
| **Expected range** | Non-negative; distribution depends on usage patterns. |
| **Anomalies** | Shift in distribution may indicate changed usage or broken links. |

## Dimensions

- **Service** (optional): Application or service name (e.g. `fastapi-custom-metrics`).
- **Endpoint**: Used only for `EndpointInvocations`; low cardinality (one value per route).

High-cardinality data (e.g. request ID) is attached via `set_property` so it remains in CloudWatch Logs and is not used as metric dimensions (to avoid metric explosion and cost).

## Implementation

- Metrics are emitted via the `aws-embedded-metrics` Python library.
- Each request is instrumented in a middleware that records the metrics above and flushes EMF to stdout.
- CloudWatch Logs receives the EMF payload via the ECS awslogs driver; CloudWatch automatically extracts metrics into the namespace `CustomMetricsLogging/App`.
