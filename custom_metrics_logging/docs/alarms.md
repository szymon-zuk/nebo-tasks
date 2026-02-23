# CloudWatch Alarms Configuration

This document describes all CloudWatch alarms configured for the custom metrics logging infrastructure. The implementation includes 5 alarm types covering threshold-based, anomaly detection, and composite scenarios.

## Alarm Summary

| # | Alarm Name | Type | Severity | Metric | Purpose |
|---|------------|------|----------|--------|---------|
| 1 | **high-error-count** | Threshold | HIGH | ErrorCount | Detects error spikes (all endpoints) |
| 2 | **performance-degradation** | Threshold | MEDIUM | RequestLatencyMs (avg) | Detects sustained slowness |
| 3 | **latency-p99-spike** | Threshold | MEDIUM | RequestLatencyMs (p99) | Detects tail latency issues |
| 4 | **high-error-rate** | Metric Math | HIGH | ErrorCount / RequestCount | Error rate >10% of requests |
| 5 | **service-unavailable** | Threshold | CRITICAL | RequestCount | Detects complete service outage |
| 6 | **service-degraded** | Composite | HIGH | Combined | Errors AND latency together |

**Alarm Type Coverage**:
- Static Threshold: 4 alarms (absolute error count, latency avg/p99, availability)
- Metric Math: 1 alarm (calculated error rate percentage)
- Composite: 1 alarm (multi-signal correlation)

**Total**: 6 alarms covering 3 alarm types (all testable without baseline data)

---

## Severity Levels

| Level | Response Time | Impact | Action |
|-------|---------------|--------|--------|
| **CRITICAL** | Immediate (< 5 min) | Service completely down | Page on-call engineer, start incident |
| **HIGH** | < 15 minutes | User-facing errors or degradation | Investigate immediately, escalate if needed |
| **MEDIUM** | < 30 minutes | Performance degradation | Investigate during business hours |
| **INFO** | < 2 hours | Potential issue or capacity planning | Review and monitor trends |

## Baseline Collection & Threshold Tuning

**Important**: The current thresholds are **initial estimates** based on application characteristics. For production use, you **must** collect baseline data and tune thresholds accordingly.

### Phase 1: Baseline Collection (Week 1-2)

1. Deploy application with alarms **disabled** or in **INFO** mode
2. Generate representative load (normal operations, not just test traffic)
3. Collect metrics for 1-2 weeks to capture:
   - Daily patterns (business hours vs off-hours)
   - Weekly patterns (weekdays vs weekends)
   - Error rates during normal operation
   - Latency percentiles (p50, p95, p99, p99.9)

### Phase 2: Analysis & Threshold Setting (Week 3)

Analyze collected baseline data:

```bash
# Example: Get latency baseline
aws cloudwatch get-metric-statistics \
  --namespace CustomMetricsLogging/App \
  --metric-name RequestLatencyMs \
  --dimensions Name=Service,Value=fastapi-custom-metrics \
  --start-time $(date -u -d '14 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average,Maximum \
  --extended-statistics p95,p99
```

**Threshold Recommendation Formula**:
- **Latency**: Set threshold at p95 or p99 during normal operation + 50% buffer
- **Errors**: Set threshold at maximum_normal_errors_per_period × 2-3
- **Traffic**: Let anomaly detection learn for 2 weeks before enabling

### Phase 3: Enable & Monitor (Week 4+)

1. Update thresholds in `monitoring.tf` based on baseline analysis
2. Enable alarm actions (SNS notifications)
3. Monitor false positive rate (target: <5%)
4. Tune thresholds if excessive noise

### Current Thresholds (Demo/Initial)

| Metric | Current Threshold | Reasoning | Needs Tuning? |
|--------|-------------------|-----------|---------------|
| ErrorCount | ≥5 in 2 min | Based on demo app ~2 req/sec | Yes - tune after baseline |
| Error Rate | >10% | Conservative threshold for demo | May need adjustment based on acceptable error rate |
| Avg Latency | >100ms | Estimated 2-3x normal (30-50ms) | Yes - measure actual p95 |
| P99 Latency | >200ms | Estimated 3-4x normal p99 | Yes - measure actual p99 |
| RequestCount | <1 in 10min | Zero traffic = down | May be OK for availability |

---

## Detailed Alarm Specifications

### Alarm 1: High Error Count (HIGH)

**Type**: Static Threshold
**Resource**: `aws_cloudwatch_metric_alarm.high_error_count`

| Property | Value |
|----------|-------|
| **Alarm Name** | szzuk-custom-metrics-logging-high-error-count |
| **Severity** | HIGH |
| **Metric** | ErrorCount |
| **Statistic** | Sum |
| **Threshold** | 5 errors |
| **Period** | 120 seconds (2 minutes) |
| **Evaluation Periods** | 1 |
| **Comparison** | GreaterThanOrEqualToThreshold |
| **Dimensions** | Service=fastapi-custom-metrics, Endpoint=/error |

**Purpose**: Detects spikes in application errors (HTTP status ≥ 400).

**Business Impact**:
- Users experiencing errors (400-level client errors or 500-level server errors)
- May indicate application bugs, dependency failures, or invalid requests
- High error rates directly impact user experience

**Baseline Analysis**:
- Normal operation: 0-1 errors per 2 minutes
- Threshold set at 5 errors (5x normal)
- Based on demo app expected behavior

**Testing**:
```bash
# Trigger alarm
for i in {1..6}; do
  curl http://<task-ip>/error
  echo "Error request $i"
  sleep 1
done

# Verify alarm triggered
aws cloudwatch describe-alarms \
  --alarm-names "szzuk-custom-metrics-logging-high-error-count" \
  --query 'MetricAlarms[0].StateValue'
```

**Testing**:
```bash
# Trigger alarm by generating errors on ANY endpoint
for i in {1..6}; do
  curl http://<task-ip>/error
  echo "Error request $i"
  sleep 1
done

# Verify alarm triggered
aws cloudwatch describe-alarms \
  --alarm-names "szzuk-custom-metrics-logging-high-error-count" \
  --query 'MetricAlarms[0].StateValue'
```

**Key Fix Applied**: Originally this alarm only monitored the `/error` endpoint (narrow scope). Now monitors **all endpoints** by removing the Endpoint dimension, catching errors anywhere in the application.

**Runbook**: See [Error Spike Runbook](#runbook-error-spike) below.

---

### Alarm 2: Performance Degradation (MEDIUM)

**Type**: Static Threshold
**Resource**: `aws_cloudwatch_metric_alarm.performance_degradation`

| Property | Value |
|----------|-------|
| **Alarm Name** | szzuk-custom-metrics-logging-performance-degradation |
| **Severity** | MEDIUM |
| **Metric** | RequestLatencyMs |
| **Statistic** | Average |
| **Threshold** | 100 milliseconds |
| **Period** | 60 seconds (1 minute) |
| **Evaluation Periods** | 2 consecutive periods |
| **Comparison** | GreaterThanThreshold |
| **Dimensions** | Service=fastapi-custom-metrics |

**Purpose**: Detects sustained increases in average response time.

**Business Impact**:
- All users experience slower responses
- May indicate overload, slow dependencies, or resource exhaustion
- Degrades user experience but not catastrophic

**Baseline Analysis**:
- Normal operation: 20-50ms average latency
- Threshold set at 100ms (2-3x normal)
- Requires 2 consecutive periods (2 minutes total) to reduce noise

**Testing**:
```python
# Add to server.py for testing
@app.get("/slow")
def slow_endpoint():
    import time
    time.sleep(0.15)  # 150ms delay
    return {"message": "Slow response"}
```

```bash
# Generate sustained slow traffic
for i in {1..150}; do
  curl http://<task-ip>/slow
  sleep 0.5
done
```

**Runbook**: See [High Latency Runbook](#runbook-high-latency) below.

---

### Alarm 3: Latency P99 Spike (MEDIUM)

**Type**: Static Threshold (Extended Statistic)
**Resource**: `aws_cloudwatch_metric_alarm.latency_p99_spike`

| Property | Value |
|----------|-------|
| **Alarm Name** | szzuk-custom-metrics-logging-latency-p99-spike |
| **Severity** | MEDIUM |
| **Metric** | RequestLatencyMs |
| **Statistic** | p99 (99th percentile) |
| **Threshold** | 200 milliseconds |
| **Period** | 300 seconds (5 minutes) |
| **Evaluation Periods** | 1 |
| **Comparison** | GreaterThanThreshold |
| **Dimensions** | Service=fastapi-custom-metrics |

**Purpose**: Monitors tail latency to catch issues affecting the slowest 1% of requests.

**Business Impact**:
- A subset of users (1%) experiencing poor performance
- May not be visible in average metrics
- Can indicate database slow queries, external API timeouts, or resource contention

**Baseline Analysis**:
- Normal operation: p99 latency 50-80ms
- Threshold set at 200ms (2.5-4x normal p99)
- Single evaluation period to catch spikes quickly

**Why This Matters**: Average latency can be good (50ms) while p99 is bad (500ms), meaning some users have terrible experience while most are fine.

**Testing**: Requires intermittent slow requests mixed with fast ones. See [Tail Latency Runbook](#runbook-tail-latency) for testing procedures.

**Runbook**: See [Tail Latency Runbook](#runbook-tail-latency) below.

---

### Alarm 4: High Error Rate Percentage (HIGH)

**Type**: Metric Math (Calculated Metric)
**Resource**: `aws_cloudwatch_metric_alarm.high_error_rate`

| Property | Value |
|----------|-------|
| **Alarm Name** | szzuk-custom-metrics-logging-high-error-rate |
| **Severity** | HIGH |
| **Calculation** | (ErrorCount / RequestCount) × 100 |
| **Threshold** | 10% |
| **Period** | 60 seconds (1 minute) |
| **Evaluation Periods** | 2 consecutive periods |
| **Comparison** | GreaterThanThreshold |
| **Dimensions** | Service=fastapi-custom-metrics |

**Purpose**: Calculates error rate as a percentage of total requests to detect when error proportion is high, regardless of absolute traffic volume.

**Business Impact**:
- Catches scenarios where absolute error count is "normal" but traffic is low (5 errors out of 10 requests = 50% failure rate!)
- More meaningful than absolute counts during traffic variations
- Indicates systematic issues rather than random errors

**Why Metric Math Matters**:

**Example 1 - High Error Rate Alarm Fires**
- Scenario: 5 errors out of 10 requests = 50% error rate
- Absolute error alarm: Won't fire (threshold is 5 errors)
- Error rate alarm: **FIRES** (50% >> 10% threshold)
- Verdict: Real issue - half the requests are failing!

**Example 2 - Only Absolute Alarm Fires**
- Scenario: 5 errors out of 500 requests = 1% error rate
- Absolute error alarm: **FIRES** (≥5 errors)
- Error rate alarm: Won't fire (1% < 10% threshold)
- Verdict: Minor issue - 99% success rate is acceptable

**Baseline Analysis**:
- Normal operation: <1% error rate
- Threshold set at 10% (significant degradation)
- Detects when 1 in 10 requests fail

**Testing**:
```bash
# Trigger high error rate with mixed traffic
# Send 10 requests: 2 errors (20% error rate) will trigger alarm

# Terminal 1: Generate normal traffic
for i in {1..4}; do curl http://<task-ip>/; sleep 1; done &

# Terminal 2: Generate errors (20% of total)
for i in {1..2}; do curl http://<task-ip>/error; sleep 1; done &

# Wait and check - error rate should exceed 10%
wait
sleep 120

aws cloudwatch describe-alarms \
  --alarm-names "szzuk-custom-metrics-logging-high-error-rate"
```

**Key Advantage Over Absolute Count**:
- During low traffic: 2 errors out of 5 requests (40% rate) triggers alarm
- During high traffic: 10 errors out of 1000 requests (1% rate) won't trigger
- Focuses on proportion, not volume

**Runbook**: See [High Error Rate Runbook](#runbook-high-error-rate) below.

---

### Alarm 5: Service Unavailable (CRITICAL)

**Type**: Static Threshold
**Resource**: `aws_cloudwatch_metric_alarm.service_unavailable`

| Property | Value |
|----------|-------|
| **Alarm Name** | szzuk-custom-metrics-logging-service-unavailable |
| **Severity** | CRITICAL |
| **Metric** | RequestCount |
| **Statistic** | Sum |
| **Threshold** | 1 request |
| **Period** | 300 seconds (5 minutes) |
| **Evaluation Periods** | 2 consecutive periods |
| **Comparison** | LessThanThreshold |
| **Missing Data** | Treat as breaching (ALARM) |
| **Dimensions** | Service=fastapi-custom-metrics |

**Purpose**: Detects complete service outage when no traffic is received for 10 minutes.

**Business Impact**:
- Service is completely unavailable
- No requests being processed (could be task crash, network failure, DNS issue)
- Most severe alarm - indicates total outage
- `treat_missing_data = breaching` ensures alarm fires even if metrics stop being published

**Why This Is Critical**:
Other alarms require metrics to be published (high errors, high latency). If the service is completely crashed and not responding at all, those alarms won't fire. This alarm catches that scenario.

**Testing**:
```bash
# 1. Establish baseline traffic
./scripts/generate_traffic.sh http://<task-ip>

# 2. Stop all traffic and wait 10 minutes
sleep 600

# 3. Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names "szzuk-custom-metrics-logging-service-unavailable"
```

**For Demo Apps**: You may want to disable this alarm when not actively testing:
```bash
aws cloudwatch disable-alarm-actions \
  --alarm-names "szzuk-custom-metrics-logging-service-unavailable"
```

**Runbook**: See [Service Down Runbook](#runbook-service-down) below.

---

### Alarm 6: Service Degraded (HIGH)

**Type**: Composite Alarm
**Resource**: `aws_cloudwatch_composite_alarm.service_degraded`

| Property | Value |
|----------|-------|
| **Alarm Name** | szzuk-custom-metrics-logging-service-degraded |
| **Severity** | HIGH |
| **Alarm Rule** | `high-error-count` AND `performance-degradation` |
| **Logic** | Both child alarms must be in ALARM state |

**Purpose**: Detects service degradation when **both** errors are high **and** performance is degraded.

**Business Impact**:
- Service is degraded but not completely down
- Users experiencing both errors AND slow responses
- Indicates systemic issue (not isolated problem)
- Requires urgent investigation

**Why Composite Alarms Matter**:
- Single signal can be noisy (brief latency spike might be OK, single error batch might be OK)
- Multiple simultaneous issues = real problem
- Reduces alert fatigue while catching critical scenarios
- More specific than individual alarms

**Alarm Logic**:
```
HIGH = (ErrorCount >= 5 in 2min) AND (AvgLatency > 100ms for 2min)
```

**Scenarios That Trigger**:
- Database connection pool exhausted - errors + slow responses
- Dependency failure - errors from timeouts + retries slowing everything
- Memory leak - gradually degrading performance + OOM errors

**Scenarios That Don't Trigger** (by design):
- Service completely down (no metrics) - service-unavailable fires (CRITICAL)
- Brief latency spike without errors - Only performance alarm fires (MEDIUM)
- Single error batch with good latency - Only error alarm fires (HIGH)
- Anomalous traffic with no impact - Only anomaly alarm fires (INFO)

**Testing**:
```bash
# Must trigger BOTH underlying alarms simultaneously

# Terminal 1: Generate errors
while true; do curl http://<task-ip>/error; sleep 1; done &

# Terminal 2: Generate slow requests (if /slow endpoint exists)
while true; do curl http://<task-ip>/slow; sleep 0.5; done &

# Wait 2-3 minutes and check composite alarm
aws cloudwatch describe-alarms \
  --alarm-names "szzuk-custom-metrics-logging-service-degraded" \
  --query 'CompositeAlarms[0].StateValue'

# Stop background jobs
kill %1 %2
```

**Runbook**: See [Service Degraded Runbook](#runbook-service-degraded) below.

---

## Runbooks

### Runbook: Error Spike

**Alarm**: `high-error-count`
**Severity**: HIGH

#### Investigation Steps

1. **Check error distribution** in CloudWatch Logs:
   ```bash
   aws logs filter-log-events \
     --log-group-name /ecs/custom-metrics-logging \
     --start-time $(($(date +%s) - 600))000 \
     --filter-pattern "500" \
     --limit 20
   ```

2. **Identify error types**:
   - 4xx errors (400-499): Client errors (bad requests, auth failures)
   - 5xx errors (500-599): Server errors (application bugs, dependency failures)

3. **Check recent deployments**:
   ```bash
   aws ecs describe-services \
     --cluster custom-metrics-logging-cluster \
     --services fastapi-fargate-service \
     --query 'services[0].deployments'
   ```

4. **Review application logs** for exceptions and stack traces

#### Common Causes & Fixes

| Cause | Symptoms | Fix |
|-------|----------|-----|
| Recent deployment bug | Errors started after deployment | Rollback deployment |
| Dependency failure | 500 errors with timeout messages | Check external service health |
| Invalid client requests | 400 errors | Review request validation |
| Database connection issues | 500 errors with DB exceptions | Check database connectivity |

#### Escalation

- If errors persist >15 minutes: Page senior engineer
- If caused by deployment: Rollback immediately
- If external dependency: Contact dependency team

---

### Runbook: High Latency

**Alarm**: `performance-degradation`
**Severity**: MEDIUM

#### Investigation Steps

1. **Check ECS task metrics**:
   ```bash
   # CPU utilization
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name CPUUtilization \
     --dimensions Name=ServiceName,Value=fastapi-fargate-service Name=ClusterName,Value=custom-metrics-logging-cluster \
     --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 60 \
     --statistics Average
   ```

2. **Check concurrent requests**:
   - Look at ActiveRequests metric in dashboard
   - High concurrency = need to scale

3. **Review slow endpoints**:
   - Check RequestLatencyMs by Endpoint dimension
   - Identify which routes are slow

4. **Check database performance** (if applicable)

#### Common Causes & Fixes

| Cause | Symptoms | Fix |
|-------|----------|-----|
| High traffic volume | High ActiveRequests | Scale ECS service (increase desired_count) |
| Slow database queries | Consistent latency across all endpoints | Optimize queries, add indexes |
| External API delays | Specific endpoints slow | Add timeouts, implement circuit breaker |
| Resource exhaustion | High CPU/memory | Increase task size or scale horizontally |

#### Mitigation

```bash
# Quick fix: Scale up
aws ecs update-service \
  --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service \
  --desired-count 2
```

---

### Runbook: Tail Latency

**Alarm**: `latency-p99-spike`
**Severity**: MEDIUM

#### Investigation Steps

1. **Compare p99 vs average latency**:
   - If p99 is high but average is low: Intermittent slow requests
   - If both high: See High Latency runbook

2. **Look for outliers** in CloudWatch Logs:
   ```bash
   # Find requests taking >200ms
   aws logs filter-log-events \
     --log-group-name /ecs/custom-metrics-logging \
     --start-time $(($(date +%s) - 600))000 \
     --filter-pattern "RequestLatencyMs" | jq 'select(.RequestLatencyMs > 200)'
   ```

3. **Check for**:
   - Periodic slow queries (cold start, cache miss)
   - Garbage collection pauses
   - External API timeouts (99% fast, 1% timeout)

#### Common Causes

- **Database query variance**: Some queries hit slow path (no index, full table scan)
- **Cold starts**: First request to new task is slow
- **External API timeouts**: 99% respond in 50ms, 1% timeout at 5000ms
- **Resource contention**: Occasional CPU/memory spike

#### Mitigation

- Add caching for slow queries
- Pre-warm connections and caches
- Set aggressive timeouts on external calls
- Implement circuit breakers

---

### Runbook: High Error Rate

**Alarm**: `high_error_rate`
**Severity**: HIGH

#### Investigation Steps

1. **Check current error rate**:
   ```bash
   # Get recent error rate calculation
   aws cloudwatch get-metric-statistics \
     --namespace CustomMetricsLogging/App \
     --metric-name ErrorCount \
     --dimensions Name=Service,Value=fastapi-custom-metrics \
     --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 60 \
     --statistics Sum

   # Compare with RequestCount
   ```

2. **Determine if low traffic or high errors**:
   - **Low traffic scenario**: 5 errors out of 10 requests (50% rate)
   - **High error scenario**: 100 errors out of 500 requests (20% rate)

3. **Check error types** in CloudWatch Logs:
   ```bash
   aws logs filter-log-events \
     --log-group-name /ecs/custom-metrics-logging \
     --start-time $(($(date +%s) - 600))000 \
     --filter-pattern "ErrorCount" \
     --limit 50 | jq '.events[].message' | jq 'select(.ErrorCount == 1)'
   ```

4. **Identify patterns**:
   - All errors from one endpoint? Endpoint-specific issue
   - Errors across all endpoints? Systemic issue (database, dependency)
   - Errors started after deployment? Application bug

#### Common Causes & Fixes

| Cause | Symptoms | Fix |
|-------|----------|-----|
| Recent deployment bug | High error rate after deploy | Rollback deployment immediately |
| Dependency timeout | Mix of successes/failures | Check dependency health, adjust timeouts |
| Database connection exhaustion | Intermittent errors | Increase connection pool size |
| Invalid input validation | 400 errors | Review request validation logic |
| Low traffic + normal errors | High % but low absolute count | May be false alarm if traffic legitimately low |

#### Decision Tree

```
Is traffic currently low (<20 req/min)?
- Yes: Check if errors are acceptable in absolute terms
       (2 errors out of 5 requests might be OK if investigating)
- No: High error rate with normal traffic = real issue
      Follow Error Spike runbook + investigate systematic cause
```

#### Mitigation

```bash
# If deployment-related, rollback
aws ecs update-service \
  --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service \
  --task-definition custom-metrics-logging-task:PREVIOUS_VERSION

# If dependency-related, implement circuit breaker or failover
```

#### Why This Alarm Matters

This alarm catches issues that absolute thresholds miss:
- **Scenario A**: 5 errors during high traffic (1000 req/min) = 0.3% rate - Acceptable
- **Scenario B**: 5 errors during low traffic (10 req/min) = 50% rate - Critical issue!

The error rate alarm fires for Scenario B, while absolute alarm treats both the same.

---

### Runbook: Service Down

**Alarm**: `service-unavailable`
**Severity**: CRITICAL

#### Immediate Actions (< 5 minutes)

1. **Verify no metrics are being published**:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace CustomMetricsLogging/App \
     --metric-name RequestCount \
     --dimensions Name=Service,Value=fastapi-custom-metrics \
     --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 60 \
     --statistics Sum
   ```

2. **Check ECS task status**:
   ```bash
   aws ecs describe-services \
     --cluster custom-metrics-logging-cluster \
     --services fastapi-fargate-service

   aws ecs list-tasks \
     --cluster custom-metrics-logging-cluster \
     --service-name fastapi-fargate-service
   ```

3. **Check for stopped tasks**:
   ```bash
   aws ecs list-tasks \
     --cluster custom-metrics-logging-cluster \
     --desired-status STOPPED \
     --query 'taskArns[0]' \
     --output text | xargs -I {} aws ecs describe-tasks --cluster custom-metrics-logging-cluster --tasks {}
   ```

#### Common Causes

| Cause | Symptoms | Fix |
|-------|----------|-----|
| Task crashed | No running tasks | Check logs, restart service |
| Security group change | Tasks running but no traffic | Verify security group allows inbound traffic |
| Task definition error | Tasks fail to start | Check CloudWatch Logs for startup errors |
| Resource exhaustion | Tasks being killed | Increase task CPU/memory limits |

#### Emergency Mitigation

```bash
# Restart service
aws ecs update-service \
  --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service \
  --force-new-deployment

# Check service events for errors
aws ecs describe-services \
  --cluster custom-metrics-logging-cluster \
  --services fastapi-fargate-service \
  --query 'services[0].events[:5]'
```

---

### Runbook: Service Degraded

**Alarm**: `service-degraded` (Composite)
**Severity**: HIGH

#### Immediate Actions (< 5 minutes)

1. **Check ECS service health**:
   ```bash
   aws ecs describe-services \
     --cluster custom-metrics-logging-cluster \
     --services fastapi-fargate-service
   ```

2. **Check task status**:
   ```bash
   aws ecs list-tasks \
     --cluster custom-metrics-logging-cluster \
     --service-name fastapi-fargate-service
   ```

3. **Review recent changes**: Deployments, config changes, infrastructure updates

4. **Check CloudWatch dashboard**: Look for correlated issues

#### Decision Tree

```
Is service running?
- No: Check task stopped reason, restart service
- Yes: Are errors happening?
  - Yes: Follow Error Spike runbook
  - No: False alarm, check alarm thresholds
```

#### Emergency Mitigation

```bash
# Option 1: Rollback deployment
aws ecs update-service \
  --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service \
  --task-definition custom-metrics-logging-task:PREVIOUS_VERSION

# Option 2: Force new deployment (if rollback not available)
aws ecs update-service \
  --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service \
  --force-new-deployment

# Option 3: Scale up (if capacity issue)
aws ecs update-service \
  --cluster custom-metrics-logging-cluster \
  --service fastapi-fargate-service \
  --desired-count 3
```

#### Post-Incident

- Document root cause
- Update runbooks
- Implement preventive measures
- Tune alarm thresholds if needed

---

## Alert Suppression During Maintenance

### Disabling Alarms Temporarily

When performing scheduled maintenance, disable alarm actions to prevent false alerts:

```bash
# Disable all alarms
aws cloudwatch disable-alarm-actions \
  --alarm-names \
    szzuk-custom-metrics-logging-high-error-count \
    szzuk-custom-metrics-logging-performance-degradation \
    szzuk-custom-metrics-logging-latency-p99-spike \
    szzuk-custom-metrics-logging-traffic-anomaly \
    szzuk-custom-metrics-logging-service-unhealthy

# Perform maintenance...

# Re-enable alarms
aws cloudwatch enable-alarm-actions \
  --alarm-names \
    szzuk-custom-metrics-logging-high-error-count \
    szzuk-custom-metrics-logging-performance-degradation \
    szzuk-custom-metrics-logging-latency-p99-spike \
    szzuk-custom-metrics-logging-traffic-anomaly \
    szzuk-custom-metrics-logging-service-unhealthy
```

### Terraform-Based Suppression

```hcl
variable "maintenance_mode" {
  type    = bool
  default = false
}

resource "aws_cloudwatch_metric_alarm" "high_error_count" {
  # ... existing config ...
  actions_enabled = !var.maintenance_mode
}
```

Apply maintenance mode:
```bash
terraform apply -var="maintenance_mode=true"
# Perform maintenance
terraform apply -var="maintenance_mode=false"
```

### Scheduled Maintenance Windows

For recurring maintenance, use AWS Systems Manager Maintenance Windows to automatically suppress alarms.

---

## Testing All Alarms

### Complete Test Suite

```bash
#!/bin/bash
# test_alarms.sh - Comprehensive alarm testing

TASK_IP="<your-task-ip>"

echo "=== Test 1: High Error Count Alarm ==="
for i in {1..6}; do curl http://$TASK_IP/error; sleep 1; done
echo "Expected: high-error-count - ALARM"
sleep 120

echo "=== Test 2: Performance Degradation Alarm ==="
echo "Requires /slow endpoint (add to server.py)"
for i in {1..150}; do curl http://$TASK_IP/slow; sleep 0.5; done
echo "Expected: performance-degradation - ALARM"
sleep 120

echo "=== Test 3: P99 Latency Spike Alarm ==="
echo "Mix of fast and slow requests"
for i in {1..100}; do
  curl http://$TASK_IP/
  [[ $((i % 10)) -eq 0 ]] && curl http://$TASK_IP/slow
  sleep 0.5
done
echo "Expected: latency-p99-spike - ALARM if slow requests common enough"
sleep 300

echo "=== Test 4: High Error Rate Alarm ==="
echo "Send mixed traffic with high error proportion"
# Send 5 normal requests and 5 error requests (50% error rate)
(for i in {1..5}; do curl http://$TASK_IP/; sleep 1; done) &
(for i in {1..5}; do curl http://$TASK_IP/error; sleep 0.5; done) &
wait
echo "Expected: high-error-rate - ALARM (50% > 10% threshold)"
sleep 120

echo "=== Test 5: Service Unavailable Alarm ==="
echo "Stop all traffic and wait 10 minutes"
echo "Expected: service-unavailable - ALARM"
echo "Note: May want to run this test separately"

echo "=== Test 6: Service Degraded Composite Alarm ==="
echo "Must trigger BOTH error AND latency alarms"
(for i in {1..20}; do curl http://$TASK_IP/error; sleep 5; done) &
(for i in {1..60}; do curl http://$TASK_IP/slow; sleep 1; done) &
wait
echo "Expected: service-degraded - ALARM after both children in ALARM"
sleep 180

echo "=== Checking All Alarm States ==="
aws cloudwatch describe-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

aws cloudwatch describe-composite-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --output table
```

---

## Avoiding Alert Fatigue

### Best Practices Implemented

1. **Severity-based Response Times**: Not all alarms require immediate action
2. **Evaluation Periods**: Multiple datapoints required to reduce noise
3. **Composite Alarms**: Combine signals to reduce false positives
4. **Anomaly Detection**: ML adapts to normal patterns
5. **Missing Data Handling**: Appropriate for each alarm type

### Signs of Alert Fatigue

- Alarms constantly firing and recovering
- Team ignoring alarms
- High false positive rate (>20%)

### Tuning Recommendations

If experiencing alert fatigue:
1. Increase thresholds (5 to 10 errors)
2. Add more evaluation periods (1 to 2)
3. Use composite alarms to require multiple signals
4. Review and adjust anomaly detection sensitivity
5. Disable low-value alarms

---

## Cost Analysis

| Component | Count | Monthly Cost |
|-----------|-------|--------------|
| Standard metric alarms | 4 | $0.00 (within free tier) |
| Metric math alarms | 1 | $0.00 (within free tier) |
| Composite alarms | 1 | $0.50/month |
| **Total** | **6** | **$0.50/month** |

**Free tier**:
- First 10 standard alarms: Free
- First 10 metric math alarms: Free (same pricing as standard)
- Composite alarms: $0.50/alarm/month (no free tier)

**Breakdown**:
- High Error Count: Free
- Performance Degradation: Free
- P99 Latency Spike: Free
- High Error Rate (metric math): Free
- Service Unavailable: Free
- Service Degraded (composite): $0.50/month

**Cost Savings**: Replaced anomaly detection ($0.10/month) with metric math ($0.00), reducing monthly cost from $0.60 to $0.50.

---

## Monitoring the Monitors

### Verify Alarms Are Working

```bash
# Check alarm evaluation (are they receiving metrics?)
aws cloudwatch describe-alarms \
  --alarm-name-prefix "szzuk-custom-metrics-logging" \
  --query 'MetricAlarms[?StateValue==`INSUFFICIENT_DATA`].[AlarmName]' \
  --output text

# If any alarms show INSUFFICIENT_DATA, metrics aren't flowing
```

### Track Alarm Effectiveness

- **True positives**: Alarm fires for real issue
- **False positives**: Alarm fires but no real issue
- **False negatives**: Real issue but alarm doesn't fire
- **True negatives**: No alarm, no issue (ideal)

Target: <5% false positive rate, 0% false negative rate

---

## Related Documentation

- [Custom Metrics Specification](custom_metrics.md) - Metric definitions and calculations
- [Main README](../README.md) - Project overview and deployment
- [monitoring.tf](../monitoring.tf) - Terraform alarm configuration

---

**Last Updated**: 2026-02-23
**Alarm Count**: 6 alarms across 3 types
- Static Threshold: 4 (error count, latency avg, latency p99, availability)
- Metric Math: 1 (error rate percentage)
- Composite: 1 (degraded service state)

**Coverage**: Error detection (absolute + rate), performance monitoring (avg + tail latency), availability monitoring (complete outage detection), metric calculations (error rate %), multi-signal correlation (composite)

**All alarms are immediately testable without requiring baseline data collection.**
