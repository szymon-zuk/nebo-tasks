# DynamoDB Infrastructure Validation Checklist

**Purpose:** Use this checklist to verify all acceptance criteria are met before project sign-off.

**Instructions:** Check each item manually. All items must be checked for project completion.

---

## Infrastructure (Phase 1)

- [ ] **INFRA-01**: DynamoDB table provisioned via Terraform
  ```bash
  # Verify table exists in Terraform state
  terraform state list | grep aws_dynamodb_table
  ```
  Expected: `aws_dynamodb_table.products`

- [ ] **INFRA-02**: ProductID is partition key (HASH) with type String
  ```bash
  # Verify partition key configuration
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.KeySchema[?KeyType==`HASH`]' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `[{"AttributeName": "ProductID", "KeyType": "HASH"}]`

- [ ] **INFRA-03**: Category is sort key (RANGE) with type String
  ```bash
  # Verify sort key configuration
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.KeySchema[?KeyType==`RANGE`]' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `[{"AttributeName": "Category", "KeyType": "RANGE"}]`

- [ ] **INFRA-04**: Provisioned capacity is 25 RCU and 25 WCU
  ```bash
  # Verify provisioned throughput
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.ProvisionedThroughput' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `{"ReadCapacityUnits": 25, "WriteCapacityUnits": 25}`

- [ ] **INFRA-05**: Encryption at rest enabled (AWS-managed keys)
  ```bash
  # Verify encryption configuration
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.SSEDescription' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `null` or SSEDescription with Status=ENABLED (AWS-managed encryption is default)

- [ ] **INFRA-06**: All required tags present (Owner, Environment, Project, ManagedBy)
  ```bash
  # Verify tags
  aws dynamodb list-tags-of-resource \
    --resource-arn $(terraform output -raw dynamodb_table_arn) \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: Tags include Owner, Environment, Project, ManagedBy

- [ ] **INFRA-07**: Table name follows convention: szzuk-dev-products
  ```bash
  # Verify table name
  terraform output dynamodb_table_name
  ```
  Expected: `"szzuk-dev-products"`

- [ ] **INFRA-08**: Terraform outputs expose table ARN and name
  ```bash
  # Verify outputs
  terraform output
  ```
  Expected: Both `dynamodb_table_arn` and `dynamodb_table_name` shown

---

## Global Secondary Index (Phase 2)

- [ ] **GSI-01**: PriceIndex exists on table in ACTIVE status
  ```bash
  # Verify GSI exists and is active
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.GlobalSecondaryIndexes[0].{Name:IndexName,Status:IndexStatus}' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `{"Name": "PriceIndex", "Status": "ACTIVE"}`

- [ ] **GSI-02**: PriceIndex uses Category as partition key
  ```bash
  # Verify GSI partition key
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.GlobalSecondaryIndexes[0].KeySchema[?KeyType==`HASH`]' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `[{"AttributeName": "Category", "KeyType": "HASH"}]`

- [ ] **GSI-03**: PriceIndex uses Price as sort key with type Number
  ```bash
  # Verify GSI sort key
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.GlobalSecondaryIndexes[0].KeySchema[?KeyType==`RANGE`]' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `[{"AttributeName": "Price", "KeyType": "RANGE"}]`

- [ ] **GSI-04**: PriceIndex provisioned capacity is 25 RCU and 25 WCU
  ```bash
  # Verify GSI throughput
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.GlobalSecondaryIndexes[0].ProvisionedThroughput' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `{"ReadCapacityUnits": 25, "WriteCapacityUnits": 25}`

- [ ] **GSI-05**: PriceIndex projection type is ALL
  ```bash
  # Verify GSI projection
  aws dynamodb describe-table \
    --table-name szzuk-dev-products \
    --query 'Table.GlobalSecondaryIndexes[0].Projection' \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `{"ProjectionType": "ALL"}`

---

## Data Model (Phase 2)

- [ ] **MODEL-01**: E-commerce schema documented in README.md
  ```bash
  # Verify README documents schema
  grep -i "ProductID\|Category\|Price" databases_nosql_instance/README.md
  ```
  Expected: README contains schema documentation

- [ ] **MODEL-02**: Sample data file contains 10-15 realistic products
  ```bash
  # Verify sample data count
  jq 'length' databases_nosql_instance/data/sample-products.json
  ```
  Expected: `13`

- [ ] **MODEL-03**: Partition key uses UUID (good cardinality)
  ```bash
  # Verify README documents UUID partition key design
  grep -i "UUID" databases_nosql_instance/README.md
  ```
  Expected: README explains ProductID as UUID for high cardinality

- [ ] **MODEL-04**: Item size and capacity calculations documented
  ```bash
  # Verify README includes capacity calculations
  grep -i "RCU\|WCU\|capacity" databases_nosql_instance/README.md
  ```
  Expected: README includes RCU/WCU math and item size calculations

---

## CRUD Operations (Phase 3)

- [ ] **CRUD-01 to CRUD-06**: scripts/crud-operations.sh demonstrates all CRUD operations
  ```bash
  # Verify script is executable
  test -x databases_nosql_instance/scripts/crud-operations.sh && echo "PASS: Script is executable"

  # Run CRUD operations script
  cd databases_nosql_instance && ./scripts/crud-operations.sh
  ```
  **Manual checks:**
  - [ ] Script completes successfully (exit code 0)
  - [ ] Script includes PutItem operation (creates test item)
  - [ ] Script includes GetItem operation (retrieves item by key)
  - [ ] Script includes UpdateItem operation (modifies attributes)
  - [ ] Script includes DeleteItem operation (removes item)
  - [ ] Script uses `--profile softserve-lab --region eu-central-1`
  - [ ] Script logs consumed capacity for each operation

---

## Query Operations (Phase 3)

- [ ] **QUERY-01 to QUERY-05**: scripts/query-examples.sh demonstrates query patterns
  ```bash
  # Load sample data first
  cd databases_nosql_instance && ./scripts/load-sample-data.sh

  # Run query examples script
  ./scripts/query-examples.sh
  ```
  **Manual checks:**
  - [ ] Script completes successfully (exit code 0)
  - [ ] Script includes Query on primary key (Category)
  - [ ] Script includes Query on GSI (PriceIndex) with price range
  - [ ] Script includes Scan with FilterExpression
  - [ ] Script documents capacity differences between Query and Scan
  - [ ] Script shows Query-first design pattern best practices
  - [ ] Script includes prominent warnings about Scan anti-pattern

---

## Data Loading (Phase 3)

- [ ] **LOAD-01 to LOAD-04**: scripts/load-sample-data.sh loads sample data
  ```bash
  # Run load script
  cd databases_nosql_instance && ./scripts/load-sample-data.sh
  ```
  **Manual checks:**
  - [ ] Script completes successfully (exit code 0)
  - [ ] Script uses BatchWriteItem (verify with `grep -i BatchWriteItem scripts/load-sample-data.sh`)
  - [ ] Script validates item count after load (13 items expected)
  - [ ] Script includes error handling for UnprocessedItems
  - [ ] Script implements exponential backoff retry logic
  - [ ] Script uses terraform output for table name resolution

---

## Data Cleanup (Phase 3)

- [ ] **CLEAN-01 to CLEAN-04**: scripts/cleanup-data.sh removes test data
  ```bash
  # Run cleanup script with force flag
  cd databases_nosql_instance && ./scripts/cleanup-data.sh --force
  ```
  **Manual checks:**
  - [ ] Script completes successfully (exit code 0)
  - [ ] Script uses Scan to find all items
  - [ ] Script uses batch delete operations (max 25 items per batch)
  - [ ] Script preserves table structure (table still exists after cleanup)
  - [ ] Script confirms zero items remain
  - [ ] Script verifies table and GSI status remain ACTIVE
  - [ ] Script includes safety confirmation prompt (bypassed by --force)

  **Verify zero items remain:**
  ```bash
  aws dynamodb scan \
    --table-name szzuk-dev-products \
    --select COUNT \
    --profile softserve-lab \
    --region eu-central-1
  ```
  Expected: `{"Count": 0, "ScannedCount": 0}`

---

## Automated Validation (Phase 4)

- [ ] **VAL-01**: scripts/validate-infra.sh exists and is executable
  ```bash
  # Verify validation script exists
  test -x databases_nosql_instance/scripts/validate-infra.sh && echo "PASS"
  ```
  Expected: `PASS`

- [ ] **VAL-02**: Validation workflow runs complete sequence
  ```bash
  # Run end-to-end validation
  cd databases_nosql_instance && ./scripts/validate-infra.sh
  ```
  **Workflow should execute:**
  1. Load sample data (13 products)
  2. Execute CRUD operations (create and delete test item)
  3. Test query patterns (primary key, GSI, Scan)
  4. Cleanup data (remove all items)
  5. Verify zero items remain
  6. Verify table and GSI status are ACTIVE

  **Expected:** Exit code 0, all steps pass

- [ ] **VAL-03**: Script uses terraform output for table name
  ```bash
  # Verify terraform integration
  grep "terraform output" databases_nosql_instance/scripts/validate-infra.sh
  ```
  Expected: Script includes terraform output command

- [ ] **VAL-04**: Script exits with non-zero status on failure
  ```bash
  # Verify error handling
  grep "exit 1" databases_nosql_instance/scripts/validate-infra.sh
  ```
  Expected: Script includes `exit 1` for error cases

- [ ] **VAL-05**: Manual validation checklist exists (this file)
  **Status:** You are reading it now

---

## Documentation (Phase 4)

- [ ] **DOC-01**: README includes project overview
  ```bash
  # Verify README has overview section
  head -50 databases_nosql_instance/README.md | grep -i "overview\|DynamoDB NoSQL Infrastructure"
  ```
  Expected: README includes introductory section describing the project

- [ ] **DOC-02**: README includes architecture description
  ```bash
  # Verify README documents architecture
  grep -A 20 "Architecture" databases_nosql_instance/README.md | grep -i "Table Structure\|GSI\|PriceIndex"
  ```
  Expected: README documents table structure, keys, and GSI

- [ ] **DOC-03**: README includes setup instructions
  ```bash
  # Verify README includes Terraform workflow
  grep -i "terraform init\|terraform apply" databases_nosql_instance/README.md
  ```
  Expected: README documents complete terraform setup workflow

- [ ] **DOC-04**: README includes usage examples for all scripts
  ```bash
  # Verify README documents script usage
  grep -i "crud-operations.sh\|query-examples.sh\|load-sample-data.sh\|cleanup-data.sh\|validate-infra.sh" databases_nosql_instance/README.md
  ```
  Expected: README shows how to run each script

- [ ] **DOC-05**: README documents query patterns
  ```bash
  # Verify README explains query patterns
  grep -A 10 "Query Patterns" databases_nosql_instance/README.md | grep -i "GetItem\|Query\|Scan"
  ```
  Expected: README explains GetItem, Query (primary key and GSI), and Scan patterns

- [ ] **DOC-06**: README includes capacity calculations
  ```bash
  # Verify README shows RCU/WCU math
  grep -A 30 "Capacity Calculations" databases_nosql_instance/README.md | grep -i "RCU\|WCU\|300 bytes"
  ```
  Expected: README shows RCU/WCU math with real item sizes (~300 bytes)

- [ ] **DOC-07**: README includes CloudWatch monitoring guidance
  ```bash
  # Verify README lists key metrics
  grep -A 20 "CloudWatch Monitoring" databases_nosql_instance/README.md | grep -i "ConsumedReadCapacityUnits\|ConsumedWriteCapacityUnits\|UserErrors"
  ```
  Expected: README lists key CloudWatch metrics to monitor

- [ ] **DOC-08**: README includes troubleshooting section
  ```bash
  # Verify README covers common issues
  grep -A 50 "Troubleshooting" databases_nosql_instance/README.md | grep -i "Throttling\|ValidationException\|ResourceNotFoundException"
  ```
  Expected: README covers common DynamoDB issues and solutions

---

## End-to-End Manual Test

Execute the following sequence manually to verify complete functionality:

### 1. Provision Infrastructure

```bash
cd databases_nosql_instance
terraform plan
terraform apply
```

**Verify:**
- [ ] Terraform apply completes successfully
- [ ] Table created: szzuk-dev-products
- [ ] Outputs shown: dynamodb_table_arn and dynamodb_table_name

### 2. Run Validation Script

```bash
./scripts/validate-infra.sh
```

**Verify:**
- [ ] Script completes successfully (exit code 0)
- [ ] All 6 validation steps pass:
  - [ ] Step 1: Load sample data
  - [ ] Step 2: CRUD operations
  - [ ] Step 3: Query patterns
  - [ ] Step 4: Cleanup data
  - [ ] Step 5: Verify zero items
  - [ ] Step 6: Verify infrastructure status
- [ ] Final success message displayed

### 3. Verify in AWS Console

Navigate to AWS Console → DynamoDB:

- [ ] Table **szzuk-dev-products** exists
- [ ] Table status is **ACTIVE**
- [ ] Partition key: **ProductID** (String)
- [ ] Sort key: **Category** (String)
- [ ] Provisioned capacity: **25 RCU / 25 WCU**
- [ ] GSI **PriceIndex** exists
- [ ] GSI status is **ACTIVE**
- [ ] GSI keys: **Category** (HASH), **Price** (RANGE)
- [ ] GSI projection type: **ALL**
- [ ] Table is empty (0 items) after validation

### 4. Load and Query Data Manually

```bash
# Load sample data
./scripts/load-sample-data.sh

# Run queries
./scripts/query-examples.sh

# Clean up
./scripts/cleanup-data.sh --force
```

**Verify:**
- [ ] Load script loads 13 items successfully
- [ ] Query script returns expected results (Electronics, Books, Home, Clothing categories)
- [ ] GSI queries filter by price range correctly
- [ ] Cleanup script removes all items
- [ ] Final item count is 0

### 5. Review Documentation

- [ ] README.md is comprehensive and clear (300+ lines)
- [ ] All scripts have usage instructions in README
- [ ] Examples in README are accurate and runnable
- [ ] Troubleshooting section covers common scenarios
- [ ] Architecture section explains table design decisions
- [ ] Capacity calculations include real numbers
- [ ] Cost information is documented

---

## Project Completion Sign-Off

**All checklist items above must be checked before signing off.**

### Summary

**Total Requirements Verified:**
- Infrastructure: 8 items (INFRA-01 through INFRA-08)
- Global Secondary Index: 5 items (GSI-01 through GSI-05)
- Data Model: 4 items (MODEL-01 through MODEL-04)
- CRUD Operations: 6 items (CRUD-01 through CRUD-06)
- Query Operations: 5 items (QUERY-01 through QUERY-05)
- Data Loading: 4 items (LOAD-01 through LOAD-04)
- Data Cleanup: 4 items (CLEAN-01 through CLEAN-04)
- Automated Validation: 5 items (VAL-01 through VAL-05)
- Documentation: 8 items (DOC-01 through DOC-08)

**Total:** 51 requirements

### Sign-Off

**Validated by:** _______________________

**Date:** _______________________

**Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

### Project Status

- [ ] **COMPLETE** - All requirements met, ready for production
- [ ] **INCOMPLETE** - Outstanding items listed below

**If incomplete, list outstanding items:**
-
-
-

---

## Additional Verification Commands

### Infrastructure Health Check

```bash
# Check table status
aws dynamodb describe-table \
  --table-name szzuk-dev-products \
  --query 'Table.{Status:TableStatus,GSI:GlobalSecondaryIndexes[0].IndexStatus,Items:ItemCount}' \
  --profile softserve-lab \
  --region eu-central-1
```

### Cost Verification

```bash
# Verify free-tier configuration
aws dynamodb describe-table \
  --table-name szzuk-dev-products \
  --query 'Table.{Billing:BillingModeSummary.BillingMode,RCU:ProvisionedThroughput.ReadCapacityUnits,WCU:ProvisionedThroughput.WriteCapacityUnits}' \
  --profile softserve-lab \
  --region eu-central-1
```

Expected: `BillingMode=PROVISIONED, RCU=25, WCU=25`

### CloudWatch Metrics Check

```bash
# Check for throttling in last hour
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name UserErrors \
  --dimensions Name=TableName,Value=szzuk-dev-products \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --profile softserve-lab \
  --region eu-central-1
```

Expected: Sum=0 (no throttling)

---

**End of Validation Checklist**
