# Network infrastructure (AWS)

Terraform in **eu-central-1** (profile `softserve-lab`): new VPC (default), two public and two private subnets, Internet Gateway, NAT Gateway, route tables, security groups, NACLs, Flow Logs, EC2 client (public) / server (private), SSM test scripts.

**Demo:** **8080** allowed by SG and NACL; **9090** allowed by SG from client but denied by server subnet NACL. See [`variables.tf`](variables.tf).

## Deploy

```bash
cd network_infrastructure
terraform init && terraform validate && terraform fmt && terraform plan && terraform apply
```

Raise `lab_subnet_netnum_start` if four `/24`s collide in an existing VPC (`create_vpc = false`). Architecture: [`docs/NETWORK_ARCHITECTURE.md`](docs/NETWORK_ARCHITECTURE.md).

## Validate (after SSM Online)

The server is in a **private** subnet: wait until **user_data** has finished (systemd demo HTTP services) before running the scripts—if `curl` fails, wait a minute and retry (same idea as [`network_traffic_controls`](../network_traffic_controls)).

```bash
./scripts/test-allowed.sh
./scripts/test-denied.sh
./scripts/show-flow-samples.sh 30
```

## Cleanup

```bash
terraform destroy
```

Related lab: [`network_traffic_controls`](../network_traffic_controls).
