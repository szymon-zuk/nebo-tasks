# Requirements: DynamoDB NoSQL Infrastructure

**Defined:** 2026-03-14
**Core Value:** DynamoDB table is properly provisioned with an e-commerce-appropriate data model and validated through automated CRUD operations.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Infrastructure

- [x] **INFRA-01**: DynamoDB table provisioned via Terraform with aws_dynamodb_table resource
- [x] **INFRA-02**: ProductID defined as partition key (HASH) with type String
- [x] **INFRA-03**: Category defined as sort key (RANGE) with type String
- [x] **INFRA-04**: Provisioned billing mode with 25 RCU and 25 WCU capacity
- [x] **INFRA-05**: Encryption at rest enabled using AWS-managed keys (default)
- [x] **INFRA-06**: Resource tags include Owner (szzuk@softserveinc.com), Environment (dev), Project (databases-nosql-instance), ManagedBy (terraform)
- [x] **INFRA-07**: Table name follows naming convention: szzuk-dev-products
- [x] **INFRA-08**: Terraform outputs expose table ARN and table name

### Global Secondary Index

- [x] **GSI-01**: Global Secondary Index named PriceIndex created on table
- [x] **GSI-02**: PriceIndex uses Category as partition key (HASH)
- [x] **GSI-03**: PriceIndex uses Price as sort key (RANGE) with type Number
- [x] **GSI-04**: PriceIndex configured with provisioned capacity: 25 RCU, 25 WCU
- [x] **GSI-05**: PriceIndex projection type set to ALL (all attributes projected)

### Data Model

- [x] **MODEL-01**: E-commerce schema documented with ProductID (UUID), Category (string), Price (number), Name (string), Stock (number), Description (string)
- [x] **MODEL-02**: Sample data file (data/sample-products.json) contains 10-15 realistic products
- [x] **MODEL-03**: Partition key cardinality validated to avoid hot partitions (ProductID is UUID)
- [x] **MODEL-04**: Item size documented with RCU/WCU capacity calculations

### CRUD Operations

- [x] **CRUD-01**: Script scripts/crud-operations.sh demonstrates PutItem operation
- [x] **CRUD-02**: Script scripts/crud-operations.sh demonstrates GetItem operation
- [x] **CRUD-03**: Script scripts/crud-operations.sh demonstrates UpdateItem operation
- [x] **CRUD-04**: Script scripts/crud-operations.sh demonstrates DeleteItem operation
- [x] **CRUD-05**: Script includes --profile softserve-lab --region eu-central-1 flags on all AWS CLI commands
- [x] **CRUD-06**: Script is executable (chmod +x) with usage instructions in comments

### Query Operations

- [x] **QUERY-01**: Script scripts/query-examples.sh demonstrates Query operation on primary key (ProductID)
- [x] **QUERY-02**: Script scripts/query-examples.sh demonstrates Query operation on GSI (price range)
- [x] **QUERY-03**: Script scripts/query-examples.sh demonstrates Scan operation with FilterExpression for comparison
- [x] **QUERY-04**: Script documents capacity consumption differences between Query and Scan
- [x] **QUERY-05**: Script enforces Query-first pattern (Scan only for demonstration purposes)

### Data Loading

- [x] **LOAD-01**: Script scripts/load-sample-data.sh loads data from data/sample-products.json
- [x] **LOAD-02**: Script uses BatchWriteItem for efficient bulk loading (max 25 items per batch)
- [x] **LOAD-03**: Script validates successful writes by counting items after load
- [x] **LOAD-04**: Script includes error handling for batch failures

### Data Cleanup

- [x] **CLEAN-01**: Script scripts/cleanup-data.sh removes all test data from table
- [x] **CLEAN-02**: Script uses Scan to retrieve all items followed by batch delete
- [x] **CLEAN-03**: Script preserves table and GSI structure (no terraform destroy)
- [x] **CLEAN-04**: Script confirms zero items remain after cleanup

### Validation

- [x] **VAL-01**: Script scripts/validate-infra.sh runs end-to-end test workflow
- [x] **VAL-02**: Validation workflow: load data → CRUD operations → query GSI → cleanup → verify
- [x] **VAL-03**: Script uses terraform output values to get table name dynamically
- [x] **VAL-04**: Script exits with non-zero status code on any failure
- [x] **VAL-05**: Manual validation checklist documents all acceptance criteria

### Documentation

- [x] **DOC-01**: README includes project overview with use case description
- [x] **DOC-02**: README includes architecture diagram or description of table structure and GSI
- [x] **DOC-03**: README includes setup instructions (terraform init/plan/apply)
- [x] **DOC-04**: README includes usage examples for all scripts
- [x] **DOC-05**: README documents query patterns (primary key lookup, category query, price range query)
- [x] **DOC-06**: README includes capacity calculations (RCU/WCU math for item sizes)
- [x] **DOC-07**: README includes CloudWatch monitoring guidance (key metrics to watch)
- [x] **DOC-08**: README includes troubleshooting section for common issues

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Features

- **ADV-01**: Point-in-time recovery (PITR) enabled for production data protection
- **ADV-02**: DynamoDB Streams for change data capture
- **ADV-03**: Auto-scaling policies for dynamic capacity adjustment
- **ADV-04**: Multiple GSIs for additional query patterns (category + stock, category + name)
- **ADV-05**: DynamoDB Accelerator (DAX) for microsecond latency

### Production Readiness

- **PROD-01**: CloudWatch alarms for throttling detection (UserErrors metric)
- **PROD-02**: CloudWatch alarms for capacity consumption (>80% of provisioned)
- **PROD-03**: VPC Endpoints for private connectivity
- **PROD-04**: Customer-managed KMS keys for encryption
- **PROD-05**: Backup and restore procedures documented

### Operational Enhancements

- **OPS-01**: Load testing script with 100+ items to validate partition distribution
- **OPS-02**: Performance benchmarking script measuring Query vs Scan latency
- **OPS-03**: Cost analysis script calculating actual vs projected AWS costs
- **OPS-04**: GSI projection optimization (INCLUDE vs ALL for storage reduction)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Application SDK integration (boto3, JavaScript SDK) | Infrastructure-focused project; shell scripts sufficient for demo |
| On-demand billing mode | Not free-tier eligible; provisioned capacity demonstrates capacity planning |
| Multi-region replication (Global Tables) | Adds $0.02/GB cross-region data transfer; out of free-tier scope |
| DynamoDB Transactions | Complex API for demo; standard CRUD operations sufficient for infrastructure validation |
| TTL (Time to Live) | Not needed for static product catalog; adds complexity without value for demo |
| Custom domain with API Gateway | Infrastructure demo focused on DynamoDB itself, not application layer |
| CI/CD pipeline integration | Manual terraform apply sufficient for demo; production enhancement |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 1 | Complete |
| INFRA-04 | Phase 1 | Complete |
| INFRA-05 | Phase 1 | Complete |
| INFRA-06 | Phase 1 | Complete |
| INFRA-07 | Phase 1 | Complete |
| INFRA-08 | Phase 1 | Complete |
| GSI-01 | Phase 2 | Complete |
| GSI-02 | Phase 2 | Complete |
| GSI-03 | Phase 2 | Complete |
| GSI-04 | Phase 2 | Complete |
| GSI-05 | Phase 2 | Complete |
| MODEL-01 | Phase 2 | Complete |
| MODEL-02 | Phase 2 | Complete |
| MODEL-03 | Phase 1 | Complete |
| MODEL-04 | Phase 2 | Complete |
| CRUD-01 | Phase 3 | Complete |
| CRUD-02 | Phase 3 | Complete |
| CRUD-03 | Phase 3 | Complete |
| CRUD-04 | Phase 3 | Complete |
| CRUD-05 | Phase 3 | Complete |
| CRUD-06 | Phase 3 | Complete |
| QUERY-01 | Phase 3 | Complete |
| QUERY-02 | Phase 3 | Complete |
| QUERY-03 | Phase 3 | Complete |
| QUERY-04 | Phase 3 | Complete |
| QUERY-05 | Phase 3 | Complete |
| LOAD-01 | Phase 3 | Complete |
| LOAD-02 | Phase 3 | Complete |
| LOAD-03 | Phase 3 | Complete |
| LOAD-04 | Phase 3 | Complete |
| CLEAN-01 | Phase 3 | Complete |
| CLEAN-02 | Phase 3 | Complete |
| CLEAN-03 | Phase 3 | Complete |
| CLEAN-04 | Phase 3 | Complete |
| VAL-01 | Phase 4 | Complete |
| VAL-02 | Phase 4 | Complete |
| VAL-03 | Phase 4 | Complete |
| VAL-04 | Phase 4 | Complete |
| VAL-05 | Phase 4 | Complete |
| DOC-01 | Phase 4 | Complete |
| DOC-02 | Phase 4 | Complete |
| DOC-03 | Phase 4 | Complete |
| DOC-04 | Phase 4 | Complete |
| DOC-05 | Phase 4 | Complete |
| DOC-06 | Phase 4 | Complete |
| DOC-07 | Phase 4 | Complete |
| DOC-08 | Phase 4 | Complete |

**Coverage:**
- v1 requirements: 51 total
- Mapped to phases: 51
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-14*
*Last updated: 2026-03-15 after completing Phase 2 Plan 01 (GSI requirements)*
