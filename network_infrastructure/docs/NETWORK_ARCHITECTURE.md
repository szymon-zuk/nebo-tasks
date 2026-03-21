# Network architecture (network_infrastructure)

This project provisions a **dedicated VPC** by default (`create_vpc = true` in [`variables.tf`](../variables.tf)): **two public** and **two private** `/24` subnets, an **Internet Gateway**, a **NAT Gateway** for private outbound internet, **custom NACLs** and **security groups**, **VPC Flow Logs**, and an EC2 **client** (public) / **server** (private) pair validated via **SSM**.

Default VPC CIDR is **`10.43.0.0/16`** so it does not overlap the [`network_traffic_controls`](../network_traffic_controls) lab default (`10.42.0.0/16`) when both exist in the same account.

## CIDR layout

With `new_vpc_cidr = 10.43.0.0/16` and `lab_subnet_netnum_start = 210`:

| Index | CIDR | Tier | AZ (typical) | Role |
|-------|------|------|----------------|------|
| +0 | 10.43.210.0/24 | Public | AZ0 | Client EC2, NAT Gateway, Flow Logs |
| +1 | 10.43.211.0/24 | Public | AZ1 | Second public subnet (no compute by default) |
| +2 | 10.43.212.0/24 | Private | AZ0 | Reserved private subnet |
| +3 | 10.43.213.0/24 | Private | AZ1 | Server EC2, server NACL, Flow Logs |

## Routing

- **Public route table**: `0.0.0.0/0` to Internet Gateway (both public subnets).
- **Private route table**: `0.0.0.0/0` to NAT Gateway (both private subnets).

## NAT

Single NAT Gateway in the **client** public subnet (single-AZ cost trade-off; private workloads in AZ1 use cross-AZ NAT path).

## Connectivity demo

- **8080** (configurable): allowed by SG and server subnet NACL.
- **9090** (configurable): allowed by SG from client, **denied** by server subnet NACL.

## Cost

NAT Gateway, EC2, Flow Logs ingestion, and Elastic IP incur charges. Run `terraform destroy` when finished.

## Validation

From [`scripts/`](../scripts/): `test-allowed.sh`, `test-denied.sh`, `show-flow-samples.sh` after SSM shows instances **Online**.
