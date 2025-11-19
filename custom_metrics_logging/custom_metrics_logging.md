# AWS Custom Metrics Monitoring

## 1. Overview

This document summarizes all steps taken to complete the task:

- Provision AWS infrastructure using AWS CLI
- Configure EC2 access (SSH, security groups)
- Create Resource Group for Application Insights
- Deploy a monitoring script on EC2
- Schedule it using cron
- Publish custom metrics to CloudWatch
- Create CloudWatch dashboards
- Create CloudWatch alarms
- Create SNS topic, confirm subscription, and attach to alarms

---

## 2. AWS Infrastructure Setup

### 2.1 Configure AWS CLI

```bash
aws configure
```

### 2.2 Create Key Pair

```bash
KEY_NAME="my-ec2-key"

aws ec2 create-key-pair \
  --region eu-central-1 \
  --key-name "$KEY_NAME" \
  --query "KeyMaterial" \
  --output text > ${KEY_NAME}.pem

chmod 400 ${KEY_NAME}.pem
```

### 2.3 Create Security Group

```bash
SEC_GRP_NAME="my-ec2-sg"

VPC_ID=$(aws ec2 describe-vpcs \
  --region eu-central-1 \
  --query "Vpcs[0].VpcId" \
  --output text)

SG_ID=$(aws ec2 create-security-group \
  --region eu-central-1 \
  --group-name "$SEC_GRP_NAME" \
  --description "Security group for monitoring demo EC2" \
  --vpc-id "$VPC_ID" \
  --query "GroupId" \
  --output text)

# Allow SSH
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"

aws ec2 authorize-security-group-ingress \
  --region eu-central-1 \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_IP"

# Allow HTTP
aws ec2 authorize-security-group-ingress \
  --region eu-central-1 \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

### 2.4 Launch EC2 Instance

**Find the latest Amazon Linux 2 AMI:**

```bash
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --region eu-central-1 \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
  --output text)
```

**Launch instance:**

```bash
INSTANCE_NAME="monitoring-demo-ec2"

INSTANCE_ID=$(aws ec2 run-instances \
  --region eu-central-1 \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Environment,Value=demo}]" \
  --query "Instances[0].InstanceId" \
  --output text)
```

**Wait until ready:**

```bash
aws ec2 wait instance-running \
  --region eu-central-1 \
  --instance-ids "$INSTANCE_ID"
```

**Get public IP:**

```bash
PUBLIC_IP=$(aws ec2 describe-instances \
  --region eu-central-1 \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)
```

**SSH into instance:**

```bash
ssh -i my-ec2-key.pem ec2-user@$PUBLIC_IP
```

---

## 3. Resource Group Setup

```bash
aws resource-groups create-group \
  --region eu-central-1 \
  --name monitoring-demo-rg \
  --resource-query '{
    "Type": "TAG_FILTERS_1_0",
    "Query": "{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"Environment\",\"Values\":[\"demo\"]}]}"
  }'
```

**Verify:**

```bash
aws resource-groups get-group \
  --region eu-central-1 \
  --group-name monitoring-demo-rg
```

---

## 4. EC2 Preparation

**Install tools:**

```bash
sudo yum update -y
sudo yum install -y python3 amazon-cloudwatch-agent
```

**Create directory:**

```bash
sudo mkdir -p /opt/monitoring
sudo chown ec2-user:ec2-user /opt/monitoring
```

**Copy monitoring script from repository into:**

```
/opt/monitoring/monitoring.py
```

**Make executable:**

```bash
chmod +x /opt/monitoring/monitoring.py
```

**Test:**

```bash
python3 /opt/monitoring/monitoring.py
```

---

## 5. Cron Scheduling

```bash
crontab -e
```

**Add:**

```bash
*/5 * * * * /usr/bin/python3 /opt/monitoring/monitoring.py >> /var/log/custom-metrics.log 2>&1
```

**Verify:**

```bash
crontab -l
```

---

## 6. CloudWatch Metrics (Console)

**Navigate:**

```
CloudWatch → Metrics → Custom → Custom/EC2Monitoring
```

**Metrics expected:**

- `MemoryUsedPercent`
- `MemoryUsedMB`
- `MemoryTotalMB`
- `DiskUsedPercent`
- `DiskUsedGB`
- `DiskTotalGB`

## **Dimension:** `InstanceId`

## 7. CloudWatch Dashboard (Console)

**Steps:**

1. Open CloudWatch
2. Go to Dashboards
3. Click Create dashboard
4. Name: `EC2-Custom-Metrics`
5. Add Line widgets
6. Select namespace `Custom/EC2Monitoring`
7. Add memory and disk metrics
8. Save dashboard

---

## 8. SNS Topic Setup (Console)

**Create Topic:**

1. SNS → Topics → Create topic
2. Type: Standard
3. Name: `ec2-custom-metrics-alerts`

**Create Subscription:**

1. Protocol: Email
2. Endpoint: your email
3. Confirm subscription via email by clicking the confirmation link

**Verify:**

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:eu-central-1:<ACCOUNT_ID>:ec2-custom-metrics-alerts
```

---

## 9. CloudWatch Alarms (Console)

**Steps:**

1. CloudWatch → Alarms → Create alarm
2. Select metric:
   - Custom → Custom/EC2Monitoring
   - e.g., `MemoryUsedPercent`
3. Set threshold (example: ≥ 80%)
4. Under Notifications:
   - Select SNS Topic: `ec2-custom-metrics-alerts`
5. Name alarm, e.g.: `EC2-Memory-High-Usage`
6. Create alarm

---

## 10. Completion Summary

**Completed:**

 - EC2 instance provisioning  
 - Key pair + security group configuration  
 - Resource Group created  
 - Monitoring script deployed to `/opt/monitoring/monitoring.py`  
 - Cron job pushing custom metrics every 5 minutes  
 - CloudWatch metrics visible under `Custom/EC2Monitoring`  
 - CloudWatch dashboard created  
 - SNS topic created and confirmed  
 - CloudWatch alarms configured and connected to SNS

**All acceptance criteria met:**

✅ Custom metrics are available in CloudWatch Dashboard.
