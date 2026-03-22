# nebo-tasks

Standalone AWS lab projects for DevOps/SRE practice: each folder is its own Terraform (and sometimes app) stack with a clear learning goal. Typical lab defaults: **AWS profile** `softserve-lab`, **region** `eu-central-1`, naming prefix **`szzuk`**. Deploy steps, scripts, troubleshooting, and AWS CLI examples are documented in each project’s README.

---

## Projects

### [`iaac_secret_management/`](iaac_secret_management/)

**What it shows:** Secrets Manager as the source of truth for structured secrets (DB creds, API keys, SSH material, app config), provisioned and wired with Terraform.

**Design choices:** Split **reader** vs **admin** IAM roles so apps get least privilege while operators retain lifecycle control; EC2 with instance profile proves runtime retrieval; resource policies and SGs reinforce boundary and auditability (CloudTrail).

---

### [`observability_custom_metrics_logging/`](observability_custom_metrics_logging/)

**What it shows:** FastAPI on **ECS Fargate** publishing **custom CloudWatch metrics** from application code (**`PutMetricData` via boto3**), plus logs to CloudWatch, a dashboard, and varied alarms (threshold, metric math, anomaly, composite).

**Design choices:** Metrics stay explicit in code (latency, errors, business counters) instead of log parsing; task IAM limits `PutMetricData` to the lab namespace; alarms mix simple and advanced patterns to mirror real ops tuning.

---

### [`databases_nosql_instance/`](databases_nosql_instance/)

**What it shows:** **DynamoDB** with composite keys and a **GSI** for alternate access patterns, **on-demand** billing, and an **IAM user** scoped only to that table/index for CLI-style app access.

**Design choices:** Table + GSI model the “query by category and price” pattern; scripts exercise load, CRUD, queries, and cleanup so the data model is demonstrable without a separate app; Terraform avoids long-lived access keys (you create keys when needed).

---

### [`compute_autoscaling/`](compute_autoscaling/)

**What it shows:** **ALB**-fronted **Auto Scaling Group** with **target tracking** (CPU), **step scaling** (request load), **scheduled** capacity (business hours), **SNS** scaling signals, and a **CloudWatch dashboard**.

**Design choices:** Contrasts AWS-managed target tracking with hand-tuned step policies; conservative cooldowns and scale-in delay reduce flapping; IMDSv2 and launch template patterns align with current EC2 practice.

---

### [`compute_custom_ami/`](compute_custom_ami/)

**What it shows:** **Packer** builds a **Ubuntu 24.04** AMI with nginx, observability/agents, Vault client, Python tooling, and **hardening**; **Terraform** resolves the latest image via **`data.aws_ami`** tags.

**Design choices:** Immutable image = repeatable launches and no boot-time package storms; security baseline (SSH, auditd, services) lives in the artifact; scripts automate build and AMI teardown for lab hygiene.

---

### [`compute_serverless/`](compute_serverless/)

**What it shows:** **Lambda** (Python) on a **EventBridge** schedule scans **EBS** inventory and publishes **custom metrics** (unattached/unencrypted volumes and snapshots); **CloudWatch** dashboard/alarms, **SNS** alerts, **SQS** DLQ.

**Design choices:** Serverless fits periodic, bounded scans; IAM narrows `PutMetricData` to a dedicated namespace and logging to the function’s log group; DLQ + alarms make failure modes observable without silent drops.

---

### [`network_traffic_controls/`](network_traffic_controls/)

**What it shows:** **Security groups** vs **NACLs** on a small VPC (or attach to existing): two instances, **8080** allowed end-to-end, **9090** open in SG but **blocked by NACL** to prove layer ordering; **VPC Flow Logs** to CloudWatch; **SSM**-driven test scripts.

**Design choices:** One deliberately “misleading” port proves *both* SG and NACL must allow traffic; optional new VPC keeps the resource map readable; flow logs tie decisions to evidence.

---

### [`network_infrastructure/`](network_infrastructure/)

**What it shows:** Full **VPC layout**: public + private subnets, **IGW**, **NAT**, routes, SGs, NACLs, flow logs, **EC2 client (public)** and **server (private)** with the same **8080 / 9090** SG-vs-NACL story as the traffic-controls lab.

**Design choices:** Demonstrates private subnet reachability via NAT and SSM while keeping the NACL demo comparable to [`network_traffic_controls/`](network_traffic_controls/); architecture detail in `docs/NETWORK_ARCHITECTURE.md`.

---

## How to use this repo

1. Open the project folder you care about.
2. Run `terraform init` → `terraform plan` → `terraform apply` (see each project’s README for prerequisites and outputs).
3. Destroy when finished to avoid ongoing charges (`terraform destroy`).

For per-project scripts, metrics namespaces, and alarm names, follow the README inside each directory.
