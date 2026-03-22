# PostgreSQL on Amazon RDS (simplified lab)

Terraform in **eu-central-1** / profile **softserve-lab** deploys **RDS PostgreSQL** in your account’s **default VPC**, with **5432 open only to your public IP** (`trusted_client_cidr`). The instance is **publicly reachable** so you run **`psql`**, **`pg_dump`**, and the shell scripts **from your laptop**—no jump host, SSM, or S3.

RDS enforces **TLS** (`rds.force_ssl=1`). Passwords live in **Secrets Manager**.

## Prerequisites

- **Default VPC** with subnets in **at least two** availability zones (normal for AWS accounts).
- Your **current public IPv4** for the security group (use `/32`), e.g. `curl -sSf https://checkip.amazonaws.com`
- **Terraform** `>= 1.0`, **AWS CLI**, **jq**, **PostgreSQL client** (`psql`, `pg_dump`) matching your RDS **major** version (e.g. 16).

## Deploy

```bash
cd databases_sql_instance
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set trusted_client_cidr to your public IP (with or without /32)

terraform init
terraform plan
terraform apply
terraform output
```

If your IP changes, update `terraform.tfvars` and run `terraform apply` again.

## Scripts (run from this directory)

| Script | Purpose |
|--------|---------|
| [`scripts/bootstrap-db.sh`](scripts/bootstrap-db.sh) | Wait for RDS; create **`app_rw`**; apply [`sql/01_schema.sql`](sql/01_schema.sql); grants |
| [`scripts/load-sample-data.sh`](scripts/load-sample-data.sh) | [`sql/02_seed.sql`](sql/02_seed.sql) as **`app_rw`** |
| [`scripts/run-queries.sh`](scripts/run-queries.sh) | [`sql/03_queries.sql`](sql/03_queries.sql) |
| [`scripts/backup.sh`](scripts/backup.sh) | **RDS snapshot** (recommended); optional **`--no-wait`** |
| [`scripts/backup-snapshot.sh`](scripts/backup-snapshot.sh) | Alias for **`backup.sh`** |
| [`scripts/backup-pgdump.sh`](scripts/backup-pgdump.sh) | Local **`pg_dump`** → [`backups/`](backups/) |
| [`scripts/validate-sql-lab.sh`](scripts/validate-sql-lab.sh) | bootstrap → load → queries → **`backup.sh`** (pass args through, e.g. **`--no-wait`**) |

**Typical order:** `bootstrap-db.sh` → `load-sample-data.sh` → `run-queries.sh` → `backup.sh`.

Use **`AWS_PROFILE`** / **`AWS_REGION`** as needed (defaults: `softserve-lab`, `eu-central-1`).

## Connection strings (no passwords)

Passwords: **Secrets Manager** (`master_secret_arn`, `app_secret_arn`).

```text
postgresql://app_rw:<PASSWORD>@<RDS_ENDPOINT>:5432/<DB_NAME>?sslmode=require
postgresql://dbadmin:<PASSWORD>@<RDS_ENDPOINT>:5432/<DB_NAME>?sslmode=require
```

Use `terraform output -raw rds_endpoint` and `terraform output -raw db_name`.

## Tradeoff (why this is simpler)

RDS is **not** on a private subnet behind a bastion. Access is **restricted by security group CIDR** and **TLS**. For a lab and for “remote client from my machine,” this is the smallest footprint.

## Variables

See [`variables.tf`](variables.tf). **`trusted_client_cidr` is required.**

## Cost / cleanup

RDS + storage run until **`terraform destroy`**. Snapshot storage costs extra if you keep manual snapshots.

## Layout

Terraform: `main.tf`, `variables.tf`, `outputs.tf`, `networking.tf`, `security_groups.tf`, `rds.tf`, `secrets.tf`; `sql/`; `scripts/`; `terraform.tfvars.example`.
