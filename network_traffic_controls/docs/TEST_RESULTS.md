# Connectivity and flow log test results (template)

Fill this in after you run `terraform apply` and the helper scripts. Replace placeholder values; avoid pasting sensitive account details if sharing externally.

## Environment

| Field | Value |
|-------|--------|
| Date | YYYY-MM-DD |
| Region | eu-central-1 |
| AWS profile | softserve-lab |
| VPC ID | `vpc-...` |
| Client instance | `i-...` |
| Server instance | `i-...` |

## Positive test (allowed port)

Command:

```bash
./scripts/test-allowed.sh
```

Expected: SSM command **Success**; stdout contains `ALLOWED` (or similar) from `http://<server-private-ip>:8080/index.txt`.

Actual stdout / status:

```
(paste aws ssm get-command-invocation output)
```

## Negative test (NACL-denied port)

Command:

```bash
./scripts/test-denied.sh
```

Expected: **curl** failure (timeout / connection refused) even though the security group allows the port; demonstrates subnet NACL **deny** overriding path for that port.

Actual stdout / status:

```
(paste output)
```

## Flow logs sample

Command:

```bash
./scripts/show-flow-samples.sh 30
```

Sample lines (sanitized):

```
(paste a few log lines; note REJECT vs ACCEPT if using custom format fields)
```

## Before / after (optional)

If you changed rules (e.g. temporarily opened `0.0.0.0/0` on SSH), document old vs new CIDRs and why the stricter rule is required for least privilege.

| Change | Before | After | Justification |
|--------|--------|-------|----------------|
| Example | `0.0.0.0/0` on `tcp/22` | `198.51.100.10/32` | SSH only from bastion / office |
