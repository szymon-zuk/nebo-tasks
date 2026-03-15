# Roadmap: DynamoDB NoSQL Infrastructure

## Overview

This roadmap delivers production-grade DynamoDB infrastructure through four phases: establishing the foundation with Terraform-managed table provisioning and proper partition key design, extending access patterns with a Global Secondary Index for efficient price queries, implementing operational workflows through shell scripts demonstrating CRUD and query patterns, and completing the infrastructure with automated validation and comprehensive documentation. Each phase builds on the previous, progressing from infrastructure provisioning to operational readiness.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Terraform infrastructure with DynamoDB table, partition/sort keys, encryption, and tagging (completed 2026-03-14)
- [x] **Phase 2: Access Patterns** - Global Secondary Index for price queries and e-commerce data model documentation (in progress)
- [ ] **Phase 3: Operations** - Shell scripts for CRUD operations, queries, data loading, and cleanup
- [ ] **Phase 4: Validation & Documentation** - Automated validation workflow and comprehensive README

## Phase Details

### Phase 1: Foundation
**Goal**: DynamoDB table is provisioned via Terraform with proper partition key design, provisioned capacity, encryption, and resource tagging
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05, INFRA-06, INFRA-07, INFRA-08, MODEL-03
**Success Criteria** (what must be TRUE):
  1. Terraform apply provisions DynamoDB table named szzuk-dev-products in ACTIVE status
  2. Table has ProductID as partition key (HASH) and Category as sort key (RANGE), both type String
  3. Table uses provisioned capacity mode with 25 RCU and 25 WCU (free-tier limits)
  4. Encryption at rest is enabled using AWS-managed keys (default)
  5. All required tags present: Owner (szzuk@softserveinc.com), Environment (dev), Project (databases-nosql-instance), ManagedBy (terraform)
**Plans**: 2 plans
- [x] 01-01: Create Terraform Configuration Files (completed 2026-03-14)
- [x] 01-02: Provision DynamoDB Table Infrastructure (completed 2026-03-14)

### Phase 2: Access Patterns
**Goal**: Global Secondary Index enables efficient price range queries and e-commerce data model is documented with sample data
**Depends on**: Phase 1
**Requirements**: GSI-01, GSI-02, GSI-03, GSI-04, GSI-05, MODEL-01, MODEL-02, MODEL-04
**Success Criteria** (what must be TRUE):
  1. Global Secondary Index named PriceIndex exists on table in ACTIVE status
  2. PriceIndex uses Category as partition key and Price (Number) as sort key
  3. PriceIndex has provisioned capacity of 25 RCU and 25 WCU (matches base table to avoid write throttling)
  4. PriceIndex projection type is ALL (all attributes projected)
  5. E-commerce data model documented with attributes: ProductID (UUID), Category (string), Price (number), Name (string), Stock (number), Description (string)
  6. Sample data file (data/sample-products.json) contains 10-15 realistic e-commerce products
  7. Item size and RCU/WCU capacity calculations documented
**Plans**: 2 plans
- [x] 02-01: Add Global Secondary Index for Price Queries (completed 2026-03-15)
- [ ] 02-02: Document E-Commerce Data Model and Create Sample Data

### Phase 3: Operations
**Goal**: Shell scripts demonstrate all DynamoDB operations including CRUD, queries, data loading, and cleanup workflows
**Depends on**: Phase 2
**Requirements**: CRUD-01, CRUD-02, CRUD-03, CRUD-04, CRUD-05, CRUD-06, QUERY-01, QUERY-02, QUERY-03, QUERY-04, QUERY-05, LOAD-01, LOAD-02, LOAD-03, LOAD-04, CLEAN-01, CLEAN-02, CLEAN-03, CLEAN-04
**Success Criteria** (what must be TRUE):
  1. Script scripts/crud-operations.sh successfully creates, reads, updates, and deletes test items using AWS CLI
  2. Script scripts/query-examples.sh demonstrates Query on primary key (ProductID), Query on GSI (price range), and Scan with FilterExpression
  3. Query examples script documents capacity consumption differences between Query (efficient) and Scan (expensive)
  4. Script scripts/load-sample-data.sh populates table with sample products from data/sample-products.json using BatchWriteItem
  5. Script scripts/cleanup-data.sh removes all test data without destroying table or GSI structure
  6. All scripts are executable (chmod +x), include --profile softserve-lab --region eu-central-1 flags, and have usage instructions in comments
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — CRUD and query operations scripts
- [ ] 03-02-PLAN.md — Data loading and cleanup scripts

### Phase 4: Validation & Documentation
**Goal**: Automated validation confirms end-to-end infrastructure functionality and comprehensive documentation enables reproducibility
**Depends on**: Phase 3
**Requirements**: VAL-01, VAL-02, VAL-03, VAL-04, VAL-05, DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, DOC-07, DOC-08
**Success Criteria** (what must be TRUE):
  1. Script scripts/validate-infra.sh runs complete workflow: load data, CRUD operations, query GSI, cleanup, verify zero items
  2. Validation script uses terraform output to get table name dynamically and exits with non-zero status on any failure
  3. README includes project overview, architecture description, setup instructions (terraform init/plan/apply), and usage examples for all scripts
  4. README documents query patterns: primary key lookup (GetItem), category query (Query with sort key), price range query (GSI Query)
  5. README includes capacity calculations showing RCU/WCU math for average item sizes
  6. README includes CloudWatch monitoring guidance (ConsumedReadCapacityUnits, ConsumedWriteCapacityUnits, UserErrors for throttling)
  7. README includes troubleshooting section for common DynamoDB issues (throttling, attribute definition errors, capacity exhaustion)
  8. Manual validation checklist documents all acceptance criteria for project completion sign-off
**Plans**: TBD

Plans:
- [ ] TBD (to be created during plan-phase)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete    | 2026-03-14 |
| 2. Access Patterns | 1/2 | In progress | - |
| 3. Operations | 0/2 | Not started | - |
| 4. Validation & Documentation | 0/TBD | Not started | - |
