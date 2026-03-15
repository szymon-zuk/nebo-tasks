# DynamoDB NoSQL Infrastructure

**Production-ready DynamoDB table provisioned with Terraform, demonstrating e-commerce data model, Global Secondary Index, and operational workflows using AWS CLI.**

## Overview

This project demonstrates DynamoDB infrastructure patterns for DevOps/SRE learning: proper partition key design, GSI for alternative access patterns, free-tier configuration, and operational best practices.

### Key Features

- **Terraform-managed infrastructure** with modular configuration
- **E-commerce product catalog data model** with realistic attributes
- **Global Secondary Index (PriceIndex)** for price range queries
- **Free-tier provisioned capacity** (25 RCU/25 WCU)
- **AWS-managed encryption** at rest (default)
- **Comprehensive operational scripts** (CRUD, query, batch operations)
- **Automated end-to-end validation** workflow

## Architecture

### Table Structure

```
Base Table: szzuk-dev-products
├── Partition Key: ProductID (String, UUID)
├── Sort Key: Category (String)
├── Attributes: Price (Number), Name (String), Stock (Number), Description (String)
└── Global Secondary Index: PriceIndex
    ├── Partition Key: Category (String)
    ├── Sort Key: Price (Number)
    └── Projection: ALL attributes
```

### Design Rationale

**Partition Key Design (ProductID):**
- Uses UUID for high cardinality (even distribution across partitions)
- Prevents hot partitions that would throttle operations
- Enables efficient single-item lookups by product ID

**Composite Key (ProductID + Category):**
- Allows querying all products by category
- Supports additional access patterns beyond primary key lookup
- Sort key enables range queries on category

**Global Secondary Index (PriceIndex):**
- Enables efficient price range queries within categories
- Example: "Find all Electronics priced between $500 and $1000"
- Projection type ALL eliminates need for additional GetItem calls
- Independent capacity allocation (25 RCU/25 WCU)

### Capacity Configuration

**Base Table:**
- Read Capacity: 25 RCU (strongly consistent reads)
- Write Capacity: 25 WCU
- Billing Mode: PROVISIONED

**Global Secondary Index:**
- Read Capacity: 25 RCU
- Write Capacity: 25 WCU
- Ensures GSI doesn't become query bottleneck

**Encryption:**
- AWS-managed keys (default, no explicit configuration)
- AES-256 encryption at rest
- No additional cost

**Tags:**
- Owner: szzuk@softserveinc.com
- Environment: dev
- Project: databases-nosql-instance
- ManagedBy: terraform

## Prerequisites

- **Terraform:** >= 1.0
- **AWS CLI:** Configured with `softserve-lab` profile
- **AWS Credentials:** DynamoDB permissions (PutItem, GetItem, UpdateItem, DeleteItem, Query, Scan, DescribeTable)
- **jq:** JSON processor for script operations
- **bash:** Shell for operational scripts

## Setup Instructions

### 1. Clone and Navigate

```bash
cd databases_nosql_instance
```

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider (~> 5.0) and initializes the working directory.

### 3. Validate Configuration

```bash
terraform validate
```

Checks syntax and validates resource configuration.

### 4. Preview Changes

```bash
terraform plan
```

Shows what resources will be created. Expected output:
- 1 resource to add: `aws_dynamodb_table.products`
- Table name: `szzuk-dev-products`
- Keys: ProductID (HASH), Category (RANGE)
- GSI: PriceIndex with Category (HASH), Price (RANGE)

### 5. Provision Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Table creation takes 5-10 seconds.

### 6. Verify Outputs

```bash
terraform output
```

Expected outputs:
- `dynamodb_table_name`: "szzuk-dev-products"
- `dynamodb_table_arn`: "arn:aws:dynamodb:eu-central-1:...:table/szzuk-dev-products"

### 7. Verify Table in AWS

```bash
aws dynamodb describe-table \
  --table-name szzuk-dev-products \
  --profile softserve-lab \
  --region eu-central-1 \
  --query 'Table.{Name:TableName,Status:TableStatus,RCU:ProvisionedThroughput.ReadCapacityUnits,WCU:ProvisionedThroughput.WriteCapacityUnits}'
```

Expected: Status=ACTIVE, RCU=25, WCU=25

## Usage Examples

### CRUD Operations

Demonstrates PutItem, GetItem, UpdateItem, DeleteItem operations:

```bash
./scripts/crud-operations.sh
```

This script:
1. Creates a test product with auto-generated UUID
2. Retrieves the product by composite key (ProductID + Category)
3. Updates the Stock attribute and Name (reserved word handling)
4. Deletes the product
5. Logs consumed capacity for each operation

**Safe to run multiple times** - creates and deletes its own test item.

### Query Examples

Demonstrates Query on primary key, GSI queries, and Scan (requires sample data loaded):

```bash
./scripts/query-examples.sh
```

This script shows:
1. Query by Category (primary key)
2. Query on PriceIndex GSI with price range (BETWEEN operator)
3. Query with >= and <= operators (alternative syntax)
4. Query with reverse sort order (`--no-scan-index-forward`)
5. Query with projection expression (specific attributes only)
6. Query with limit (pagination)
7. Scan with FilterExpression (anti-pattern demonstration)

**Read-only operations** - does not modify data.

### Load Sample Data

Loads 13 sample products from `data/sample-products.json`:

```bash
./scripts/load-sample-data.sh
```

This script:
1. Reads products from JSON file
2. Transforms to BatchWriteItem format
3. Writes in batches of max 25 items
4. Handles UnprocessedItems with exponential backoff retry
5. Validates final item count matches expected

**Idempotent** - can be run multiple times (uses fixed UUIDs).

### Cleanup Data

Removes all items while preserving table structure:

```bash
./scripts/cleanup-data.sh
```

You'll be prompted to type 'yes' to confirm. For automation, use:

```bash
./scripts/cleanup-data.sh --force
```

This script:
1. Scans all items with pagination support
2. Extracts keys (ProductID + Category)
3. Deletes in batches of max 25 items
4. Verifies zero items remain
5. Confirms table and GSI remain ACTIVE

**Irreversible operation** - deleted data cannot be recovered.

### End-to-End Validation

Runs complete validation workflow:

```bash
./scripts/validate-infra.sh
```

Workflow sequence:
1. Loads sample data (13 products)
2. Tests CRUD operations
3. Tests query patterns (primary key and GSI)
4. Cleans up data (--force mode)
5. Verifies zero items remain
6. Verifies table and GSI status are ACTIVE

Exit code 0 on success, 1 on any failure. **Fully automated** - no interactive prompts.

## Query Patterns

### Pattern 1: Primary Key Lookup (GetItem)

**Purpose:** Retrieve single product by ID (most efficient)

**Efficiency:** 1 RCU per item (300-byte item rounds to 4 KB)

**Example:**

```bash
aws dynamodb get-item \
  --table-name szzuk-dev-products \
  --key '{"ProductID": {"S": "550e8400-e29b-41d4-a716-446655440001"}, "Category": {"S": "Electronics"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

**Use when:** You know the exact ProductID and Category.

### Pattern 2: Category Query (Query with sort key)

**Purpose:** Retrieve all products in a specific category

**Efficiency:** Reads only items matching the category (efficient)

**Example:**

```bash
aws dynamodb query \
  --table-name szzuk-dev-products \
  --key-condition-expression "Category = :cat" \
  --expression-attribute-values '{":cat": {"S": "Electronics"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

**Use when:** You need all products in a category.

### Pattern 3: Price Range Query (GSI Query)

**Purpose:** Find products in a price range within a category

**Efficiency:** Efficient (GSI with ALL projection, no additional GetItem calls)

**Example:**

```bash
aws dynamodb query \
  --table-name szzuk-dev-products \
  --index-name PriceIndex \
  --key-condition-expression "Category = :cat AND Price BETWEEN :min AND :max" \
  --expression-attribute-values '{":cat": {"S": "Electronics"}, ":min": {"N": "500"}, ":max": {"N": "1000"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

**Alternative syntax using >= and <=:**

```bash
aws dynamodb query \
  --table-name szzuk-dev-products \
  --index-name PriceIndex \
  --key-condition-expression "Category = :cat AND Price >= :min AND Price <= :max" \
  --expression-attribute-values '{":cat": {"S": "Electronics"}, ":min": {"N": "500"}, ":max": {"N": "1000"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

**Use when:** Filtering products by price range within a category.

### Anti-Pattern: Scan (Avoid in Production)

**Purpose:** Educational demonstration only

**Efficiency:** Reads entire table regardless of filter (EXPENSIVE)

**Example:**

```bash
aws dynamodb scan \
  --table-name szzuk-dev-products \
  --filter-expression "Price > :min" \
  --expression-attribute-values '{":min": {"N": "100"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

**Why avoid:**
- Consumes capacity for ALL items, even those filtered out
- FilterExpression applied AFTER reading entire table
- Expensive at scale (10,000 items scanned = 10,000 RCU consumed, even if filter returns 10 items)

**When to use Scan:**
- Batch analytics jobs
- Backup operations
- Infrequent full-table exports
- **Never** for application query patterns

**Query-First Design Pattern:**
1. Define access patterns before creating table
2. Choose partition/sort keys to support Query operations
3. Add GSIs for alternative Query patterns
4. Use Scan only for batch operations

## Capacity Calculations

### Item Size Calculation

**Average Product Item:**
- Base attributes (ProductID, Category, Price, Name, Stock, Description): ~200 bytes
- DynamoDB overhead (attribute names, metadata): ~100 bytes per item
- **Total average item size:** ~300 bytes

### Read Capacity Units (RCU)

**Definition:** 1 RCU = 1 strongly consistent read up to 4 KB/sec

**Calculations:**
- 300-byte item requires 1 RCU (rounds up to 4 KB)
- Query returning 10 items = 10 RCU consumed
- GetItem on single item = 1 RCU

**Provisioned:** 25 RCU = 25 strongly consistent reads/sec

**Example workload:**
- 20 GetItem requests/sec × 1 RCU = 20 RCU/sec (within limit)
- 5 Query requests returning 3 items each/sec = 15 RCU/sec (within limit)
- Total: 35 RCU/sec would cause throttling (exceeds 25 RCU limit)

### Write Capacity Units (WCU)

**Definition:** 1 WCU = 1 write up to 1 KB/sec

**Calculations:**
- 300-byte item requires 1 WCU (rounds up to 1 KB)
- BatchWriteItem with 13 items = 13 WCU consumed
- PutItem on single item = 1 WCU

**Provisioned:** 25 WCU = 25 writes/sec

**Example workload:**
- 20 PutItem requests/sec × 1 WCU = 20 WCU/sec (within limit)
- 10 UpdateItem requests/sec × 1 WCU = 10 WCU/sec
- Total: 30 WCU/sec would cause throttling (exceeds 25 WCU limit)

### Free-Tier Limits

**AWS Free Tier includes:**
- 25 RCU and 25 WCU (provisioned capacity)
- 25 GB storage
- 25 GB backup storage

**Current usage:**
- Sample data: 13 items × 300 bytes = ~4 KB
- Storage used: 0.0002% of free tier
- GSI storage: duplicates base table (~4 KB)
- **Estimated monthly cost: $0.00** (within free tier)

### Capacity Exhaustion Scenario

**What happens when you exceed provisioned capacity?**

Example: 26 writes/sec with 25 WCU provisioned:
1. First 25 writes succeed
2. 26th write returns `ProvisionedThroughputExceededException`
3. UserErrors CloudWatch metric increases
4. Application should implement exponential backoff retry

**Solutions:**
- Implement retry logic with exponential backoff in application code
- Increase provisioned capacity: update `variables.tf` and `terraform apply`
- Enable auto-scaling (scales capacity automatically based on utilization)
- Switch to on-demand billing mode (no provisioned capacity, pay per request)

## CloudWatch Monitoring

### Key Metrics to Monitor

#### ConsumedReadCapacityUnits

**What it measures:** Actual RCU usage per period

**Alert threshold:** > 20 (80% of provisioned capacity)

**Why monitor:** Indicates approaching capacity limit, may cause throttling

**CloudWatch namespace:** AWS/DynamoDB

**Dimensions:** TableName=szzuk-dev-products

#### ConsumedWriteCapacityUnits

**What it measures:** Actual WCU usage per period

**Alert threshold:** > 20 (80% of provisioned capacity)

**Why monitor:** Indicates approaching capacity limit, may cause throttling

**CloudWatch namespace:** AWS/DynamoDB

**Dimensions:** TableName=szzuk-dev-products

#### UserErrors

**What it measures:** Throttling events (ProvisionedThroughputExceededException)

**Alert threshold:** > 0 (any throttling is bad for user experience)

**Why monitor:** Indicates capacity exhaustion, immediate action required

**Action:** Increase provisioned capacity or enable auto-scaling

#### SuccessfulRequestLatency

**What it measures:** Response time for successful requests

**Baseline:** Single-digit milliseconds (p50), sub-20ms (p99)

**Alert threshold:** p99 > 50ms

**Why monitor:** Spike indicates performance degradation or hot partition

### Viewing Metrics in AWS Console

1. Navigate to **CloudWatch** → **Metrics** → **DynamoDB**
2. Select table: **szzuk-dev-products**
3. View metrics:
   - ConsumedReadCapacityUnits
   - ConsumedWriteCapacityUnits
   - UserErrors
   - SuccessfulRequestLatency
4. Create dashboard with key metrics for ongoing monitoring

### CLI Example: Query Metrics

Get read capacity consumption for the last 24 hours:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=szzuk-dev-products \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum Average Maximum \
  --profile softserve-lab \
  --region eu-central-1
```

Get throttling events (UserErrors):

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=szzuk-dev-products \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --profile softserve-lab \
  --region eu-central-1
```

## Troubleshooting

### Issue 1: Throttling (ProvisionedThroughputExceededException)

**Symptom:** UserErrors metric increasing, 400 errors in application logs, requests failing

**Cause:** Request rate exceeds provisioned capacity (> 25 RCU or > 25 WCU)

**Solutions:**

1. **Implement exponential backoff retry in application code:**
   ```python
   import time
   max_retries = 5
   for attempt in range(max_retries):
       try:
           response = dynamodb.put_item(...)
           break
       except ClientError as e:
           if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
               sleep_time = (2 ** attempt) * 0.1  # 0.1s, 0.2s, 0.4s, 0.8s, 1.6s
               time.sleep(sleep_time)
           else:
               raise
   ```

2. **Increase provisioned capacity:**
   - Edit `databases_nosql_instance/variables.tf`
   - Add variables for read/write capacity or increase defaults in `dynamodb.tf`
   - Run `terraform apply`

3. **Enable auto-scaling (future enhancement):**
   - Add `aws_appautoscaling_target` and `aws_appautoscaling_policy` resources
   - Define min/max capacity and target utilization (70-80%)

4. **Optimize query patterns:**
   - Use Query instead of Scan
   - Reduce item sizes (remove unused attributes)
   - Use projection expressions to fetch only needed attributes

### Issue 2: ValidationException (Attribute definition errors)

**Symptom:** "Attribute X is not defined in KeySchema or AttributeDefinitions"

**Cause:** Trying to define non-key attributes in Terraform attribute blocks

**Solution:**
- DynamoDB only requires key attributes in schema definition
- Only define: partition key, sort key, and GSI keys
- Non-key attributes (Name, Stock, Description) are schemaless, no definition needed
- Example from `dynamodb.tf`: only ProductID, Category, and Price are defined

**Correct:**
```hcl
attribute {
  name = "ProductID"  # partition key
  type = "S"
}
attribute {
  name = "Category"   # sort key
  type = "S"
}
attribute {
  name = "Price"      # GSI sort key
  type = "N"
}
# Name, Stock, Description NOT defined (schemaless)
```

**Incorrect:**
```hcl
attribute {
  name = "Name"       # ERROR: not a key attribute
  type = "S"
}
```

### Issue 3: ResourceNotFoundException (Table not found)

**Symptom:** Scripts fail with "Requested resource not found"

**Cause:** Table not provisioned or wrong table name

**Solutions:**

1. **Verify table exists:**
   ```bash
   terraform output dynamodb_table_name
   ```
   Expected: "szzuk-dev-products"

2. **Check correct region:**
   ```bash
   aws dynamodb list-tables \
     --profile softserve-lab \
     --region eu-central-1
   ```
   Must use `eu-central-1` (not us-east-1 or other regions)

3. **Provision table if missing:**
   ```bash
   cd databases_nosql_instance
   terraform apply
   ```

### Issue 4: AccessDeniedException (IAM permissions)

**Symptom:** "User is not authorized to perform: dynamodb:PutItem"

**Cause:** AWS profile lacks DynamoDB permissions

**Solutions:**

1. **Verify profile identity:**
   ```bash
   aws sts get-caller-identity --profile softserve-lab
   ```

2. **Check IAM policy includes DynamoDB permissions:**
   - Navigate to IAM console → Users/Roles
   - Verify attached policies include `dynamodb:*` or specific permissions:
     - dynamodb:PutItem
     - dynamodb:GetItem
     - dynamodb:UpdateItem
     - dynamodb:DeleteItem
     - dynamodb:Query
     - dynamodb:Scan
     - dynamodb:DescribeTable

3. **Use correct profile flag:**
   ```bash
   aws dynamodb describe-table \
     --table-name szzuk-dev-products \
     --profile softserve-lab \
     --region eu-central-1
   ```

### Issue 5: Empty Query Results

**Symptom:** Query returns 0 items when data exists

**Cause:** Key condition expression doesn't match data

**Solutions:**

1. **Verify partition key value matches exactly (case-sensitive):**
   ```bash
   # Wrong: lowercase
   --expression-attribute-values '{":cat": {"S": "electronics"}}'

   # Correct: matches data
   --expression-attribute-values '{":cat": {"S": "Electronics"}}'
   ```

2. **Check sort key condition for range queries:**
   - BETWEEN values must be inclusive
   - Price is stored as Number type, use {"N": "500"} not {"S": "500"}

3. **Use Scan temporarily to see all items and verify keys:**
   ```bash
   aws dynamodb scan \
     --table-name szzuk-dev-products \
     --profile softserve-lab \
     --region eu-central-1 \
     --max-items 5
   ```

4. **Verify data is loaded:**
   ```bash
   aws dynamodb scan \
     --table-name szzuk-dev-products \
     --select COUNT \
     --profile softserve-lab \
     --region eu-central-1
   ```
   Expected: Count > 0

### Issue 6: High Costs Despite Free-Tier

**Symptom:** Unexpected AWS charges on billing dashboard

**Cause:** Exceeded free-tier limits or wrong billing mode

**Solutions:**

1. **Verify provisioned capacity is 25 RCU/25 WCU:**
   ```bash
   aws dynamodb describe-table \
     --table-name szzuk-dev-products \
     --query 'Table.ProvisionedThroughput' \
     --profile softserve-lab \
     --region eu-central-1
   ```
   Expected: ReadCapacityUnits=25, WriteCapacityUnits=25

2. **Check billing mode is PROVISIONED:**
   ```bash
   aws dynamodb describe-table \
     --table-name szzuk-dev-products \
     --query 'Table.BillingModeSummary' \
     --profile softserve-lab \
     --region eu-central-1
   ```
   Expected: BillingMode=PROVISIONED (not PAY_PER_REQUEST)

3. **Monitor storage usage:**
   - Must be < 25 GB for free tier
   - Check in DynamoDB console → Table → Metrics tab
   - Sample data uses ~4 KB (well within limit)

4. **Use Cost Explorer to identify charge source:**
   - Navigate to Billing → Cost Explorer
   - Filter by Service: DynamoDB
   - Check for unexpected on-demand billing or exceeded capacity

## Cost Information

### Free-Tier Coverage

**AWS Free Tier includes (always free):**
- 25 RCU and 25 WCU provisioned capacity
- 25 GB storage
- 25 GB backup storage
- Applies to both base table and GSIs

### Current Usage

**Sample data:**
- 13 items × 300 bytes = ~4 KB
- GSI storage: ~4 KB (duplicates base table with ALL projection)
- Total storage: ~8 KB
- Percentage of free tier: 0.00003% (8 KB / 25 GB)

**Estimated monthly cost:** $0.00 (within free tier)

### Cost Breakdown (if exceeding free tier)

**Provisioned capacity pricing (eu-central-1):**
- Write capacity: $0.000742 per WCU-hour
- Read capacity: $0.000148 per RCU-hour

**Example (25 WCU/25 RCU for 730 hours/month):**
- Write: 25 WCU × 730 hours × $0.000742 = $13.54/month
- Read: 25 RCU × 730 hours × $0.000148 = $2.70/month
- **Total: $16.24/month** (but covered by free tier)

**Storage pricing:**
- First 25 GB: Free (free tier)
- Additional storage: $0.283/GB/month

**Data transfer:**
- In: Free
- Out: First 1 GB/month free, then $0.09/GB

### Cost Optimization Tips

1. **Stay within free tier:** Keep provisioned capacity at 25 RCU/25 WCU
2. **Use AWS-managed encryption:** Free (KMS would cost $1/month per key)
3. **Delete unused tables:** Run `terraform destroy` when not in use
4. **Monitor storage:** Use scripts to clean up test data regularly
5. **Avoid on-demand billing mode:** More expensive for consistent workloads

## Cleanup

### Remove Data Only (Preserve Table)

```bash
cd databases_nosql_instance
./scripts/cleanup-data.sh --force
```

This removes all items but keeps table and GSI structure intact.

### Destroy Infrastructure (Complete Removal)

```bash
cd databases_nosql_instance
terraform destroy
```

Type `yes` when prompted. This:
- Deletes the DynamoDB table
- Removes the GSI
- Deletes all data (irreversible)
- Table deletion takes 5-10 seconds

### Verify Removal

```bash
aws dynamodb list-tables \
  --profile softserve-lab \
  --region eu-central-1 \
  --query 'TableNames[?contains(@, `szzuk`)]'
```

Expected: Empty list after `terraform destroy`

## Project Structure

```
databases_nosql_instance/
├── main.tf                      # Provider configuration (AWS profile, region, tags)
├── variables.tf                 # Input variables (environment, project_name)
├── outputs.tf                   # Output values (table ARN, table name)
├── dynamodb.tf                  # Table and GSI configuration
├── terraform.tfstate            # Terraform state (tracked for learning project)
├── .terraform.lock.hcl          # Provider version lock file
├── data/
│   └── sample-products.json     # 13 sample e-commerce products (DynamoDB JSON format)
├── scripts/
│   ├── crud-operations.sh       # CRUD examples (PutItem, GetItem, UpdateItem, DeleteItem)
│   ├── query-examples.sh        # Query patterns (primary key, GSI, Scan)
│   ├── load-sample-data.sh      # Bulk data loading with BatchWriteItem
│   ├── cleanup-data.sh          # Data removal with batch delete
│   └── validate-infra.sh        # End-to-end validation workflow
└── README.md                    # This file
```

## References

- **AWS DynamoDB Documentation:** https://docs.aws.amazon.com/dynamodb/
- **DynamoDB Best Practices:** https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
- **Project conventions:** ../CLAUDE.md

## Next Steps

**After completing this project, you should understand:**
1. How to provision DynamoDB tables with Terraform
2. Partition key design for even data distribution
3. When and how to use Global Secondary Indexes
4. DynamoDB capacity planning and RCU/WCU calculations
5. Query-first design pattern (avoid Scan in production)
6. Batch operations with retry logic
7. CloudWatch monitoring for DynamoDB
8. Common troubleshooting scenarios

**Future enhancements (out of scope for this milestone):**
- Auto-scaling policies for dynamic capacity adjustment
- DynamoDB Streams for change data capture
- Point-in-time recovery (PITR) for backup
- Transaction support for multi-item operations
- Conditional writes for optimistic locking
- TTL (Time To Live) for automatic item expiration
