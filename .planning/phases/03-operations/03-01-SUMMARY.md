---
phase: 03-operations
plan: 01
subsystem: DynamoDB Operations Scripts
tags: [dynamodb, crud, query, aws-cli, operations, capacity-tracking]
dependency_graph:
  requires: [02-02]
  provides: [executable-crud-examples, query-pattern-demonstrations]
  affects: [databases_nosql_instance]
tech_stack:
  added: [bash-scripts, aws-cli-dynamodb, jq-json-parsing]
  patterns: [terraform-output-integration, capacity-tracking, gsi-queries]
key_files:
  created:
    - databases_nosql_instance/scripts/crud-operations.sh
    - databases_nosql_instance/scripts/query-examples.sh
  modified: []
decisions:
  - Use uuidgen for ProductID generation in test data
  - Track consumed capacity on all operations for educational visibility
  - Demonstrate both BETWEEN and >= <= syntax for range conditions
  - Include Scan operation as anti-pattern with prominent warnings
  - Use expression attribute names for reserved word "Name"
  - Provide extensive inline documentation for Query-first pattern
metrics:
  duration: 214
  tasks_completed: 2
  files_created: 2
  lines_added: 739
  commits: 2
  completed_date: "2026-03-15T17:41:26Z"
requirements_fulfilled: [CRUD-01, CRUD-02, CRUD-03, CRUD-04, CRUD-05, CRUD-06, QUERY-01, QUERY-02, QUERY-03, QUERY-04, QUERY-05]
---

# Phase 03 Plan 01: DynamoDB CRUD and Query Operations Scripts

**One-liner:** Executable bash scripts demonstrating all DynamoDB CRUD operations and query patterns with GSI usage, capacity tracking, and Query-first best practices documentation.

## Overview

Created two comprehensive shell scripts that demonstrate DynamoDB operations using AWS CLI. The scripts follow project conventions (terraform output integration, AWS profile/region flags, strict error handling) and include extensive educational documentation about DynamoDB capacity consumption and access pattern optimization.

## What Was Built

### 1. CRUD Operations Script (300 lines)
**File:** `databases_nosql_instance/scripts/crud-operations.sh`

Demonstrates all four DynamoDB CRUD operations in sequence:

- **PutItem**: Creates test product with auto-generated UUID, includes all attributes (ProductID, Category, Price, Name, Stock, Description)
- **GetItem**: Retrieves item using composite key (ProductID + Category)
- **UpdateItem**: Updates Stock (atomic decrement) and Name (using expression attribute names for reserved word)
- **DeleteItem**: Removes item and verifies deletion

Each operation:
- Uses proper DynamoDB JSON format with type descriptors (`{"S": "..."}`, `{"N": "..."}`)
- Includes `--return-consumed-capacity TOTAL` for educational capacity tracking
- Logs capacity consumption to stdout
- Follows error handling best practices with `set -euo pipefail`

### 2. Query Examples Script (439 lines)
**File:** `databases_nosql_instance/scripts/query-examples.sh`

Demonstrates efficient and inefficient DynamoDB access patterns:

**Query Operations (Efficient):**
1. Query on primary key (Category partition key) - returns all products in category
2. Query on PriceIndex GSI with BETWEEN operator - price range within category
3. Query with >= and <= operators - alternative range syntax
4. Query with sort order control (`--no-scan-index-forward`) - reverse GSI sort order
5. Query with projection expression - retrieve only specific attributes
6. Query with limit - pagination demonstration

**Scan Operation (Anti-pattern):**
7. Scan with FilterExpression - demonstrates table-wide scan with post-filter

**Educational Content:**
- Extensive documentation on Query vs Scan efficiency
- Capacity formula explanations (Query = returned items, Scan = entire table)
- Query-first pattern best practices
- Prominent warnings about Scan anti-patterns
- Key takeaways section with 5 major lessons

## Requirements Fulfilled

All 11 requirements from plan frontmatter satisfied:

- **CRUD-01 through CRUD-06**: Complete CRUD operations with terraform integration, AWS flags, capacity tracking, error handling
- **QUERY-01 through QUERY-05**: Query on primary key, GSI queries with range conditions, Scan demonstration, capacity comparison, Query-first documentation

## Architecture & Patterns

### Terraform Integration Pattern
```bash
# Read table name from terraform output with fallback
TABLE_NAME=$(terraform output -raw dynamodb_table_name 2>/dev/null || true)
```

### DynamoDB JSON Format Pattern
```bash
aws dynamodb put-item \
    --item "{
        \"ProductID\": {\"S\": \"$PRODUCT_ID\"},
        \"Category\": {\"S\": \"$CATEGORY\"},
        \"Price\": {\"N\": \"$PRICE\"}
    }"
```

### Capacity Tracking Pattern
```bash
--return-consumed-capacity TOTAL
# Extract capacity units
CAPACITY=$(echo "$RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
```

### Reserved Word Handling Pattern
```bash
# Use expression attribute names for reserved word "Name"
--update-expression "SET #n = :newname"
--expression-attribute-names "{\"#n\": \"Name\"}"
```

### GSI Query Pattern
```bash
aws dynamodb query \
    --index-name PriceIndex \
    --key-condition-expression "Category = :cat AND Price BETWEEN :min AND :max"
```

## Technical Decisions

1. **UUID Generation**: Used `uuidgen` for ProductID generation rather than hardcoded IDs, ensuring scripts can run multiple times without conflicts

2. **Capacity Tracking**: Included `--return-consumed-capacity TOTAL` on all operations and logged capacity consumption to stdout for educational transparency

3. **Range Condition Syntax**: Demonstrated both `BETWEEN` and `>= <=` syntax for range queries to show alternative approaches

4. **Scan Anti-pattern**: Included Scan operation with prominent warnings and educational context rather than omitting it, ensuring learners understand why it's inefficient

5. **Expression Attribute Names**: Used `#n` for "Name" attribute to demonstrate handling of DynamoDB reserved words

6. **Educational Documentation**: Prioritized extensive inline documentation (100+ lines) explaining Query-first pattern, capacity formulas, and best practices

## Verification Results

All automated checks passed:

```bash
✓ Syntax validation (bash -n)
✓ Executable permissions (chmod +x)
✓ Strict mode (set -euo pipefail)
✓ AWS profile/region flags (--profile softserve-lab --region eu-central-1)
✓ CRUD operations present (put-item, get-item, update-item, delete-item)
✓ Query operations present (query, scan)
✓ GSI usage (--index-name PriceIndex)
✓ Capacity tracking (--return-consumed-capacity TOTAL)
✓ Terraform integration (terraform output dynamodb_table_name)
✓ Efficiency documentation (Query vs Scan comparison)
✓ Line count requirements (300 > 150, 439 > 180)
```

## Deviations from Plan

None - plan executed exactly as written.

## Success Criteria Met

- [x] scripts/crud-operations.sh exists and is executable
- [x] scripts/query-examples.sh exists and is executable
- [x] CRUD script demonstrates PutItem, GetItem, UpdateItem, DeleteItem
- [x] Query script demonstrates Query on primary key
- [x] Query script demonstrates Query on GSI with price range
- [x] Query script demonstrates Scan with FilterExpression
- [x] All operations log consumed capacity units
- [x] Scripts follow project conventions (profile/region flags, terraform output integration, error handling)
- [x] Scripts use proper DynamoDB JSON format with type descriptors
- [x] Scripts include comprehensive usage documentation

## Integration Points

### Upstream Dependencies
- **02-02 (Add GSI)**: PriceIndex GSI required for price range queries in query-examples.sh
- **01-02 (Provision Table)**: DynamoDB table must exist for all operations
- Terraform outputs (`dynamodb_table_name`) for table name resolution

### Downstream Enablers
- Provides executable examples for documentation and testing
- Demonstrates proper AWS CLI patterns for future script development
- Establishes capacity tracking patterns for performance analysis

## Testing Notes

Scripts are designed to be run against the existing `szzuk-dev-products` table:

```bash
cd databases_nosql_instance

# Run CRUD operations (creates and deletes test item, safe to run multiple times)
./scripts/crud-operations.sh

# Run query examples (requires sample data loaded)
./scripts/query-examples.sh
```

**Prerequisites:**
- AWS CLI configured with `softserve-lab` profile
- DynamoDB table provisioned via terraform
- Sample data loaded (for query-examples.sh to return meaningful results)
- `jq` installed for JSON parsing

**Safety:**
- CRUD script creates and deletes its own test item (UUID-based, no conflicts)
- Query script is read-only (no modifications to existing data)
- No destructive operations on production data

## Key Learnings

### Capacity Consumption Patterns
- **Query**: Capacity based on size of items returned (efficient)
- **Scan**: Capacity based on entire table size regardless of filter (expensive)
- FilterExpression on Scan doesn't reduce capacity (applied after reading)

### Query-First Design Pattern
1. Define access patterns before creating table
2. Choose partition/sort keys to support Query operations
3. Add GSIs for alternative access patterns
4. Use Scan only for batch operations (analytics, backups)

### Reserved Words Handling
DynamoDB has many reserved words (e.g., "Name"). Always use expression attribute names (`#n`) for reserved words in expressions.

### GSI Query Efficiency
GSI queries are as efficient as base table queries. With `projection_type: ALL`, no additional GetItem calls needed.

## Files Modified

**Created:**
- `databases_nosql_instance/scripts/crud-operations.sh` (300 lines)
- `databases_nosql_instance/scripts/query-examples.sh` (439 lines)

**Total:** 739 lines of executable bash scripts with comprehensive documentation

## Commits

1. **a945b52** - feat(03-operations-03-01): create CRUD operations script
2. **28abf47** - feat(03-operations-03-01): create query examples script

## Next Steps

Plan 03-02 (if exists) can proceed. These scripts provide:
- Executable examples of all basic DynamoDB operations
- Documentation of best practices for future development
- Capacity tracking patterns for performance optimization
- Testing tools for validating table configuration

## Self-Check

Verifying deliverables exist and commits are recorded:

**Files Created:**
- [x] `/home/szuk/nebo-tasks/databases_nosql_instance/scripts/crud-operations.sh` - EXISTS
- [x] `/home/szuk/nebo-tasks/databases_nosql_instance/scripts/query-examples.sh` - EXISTS

**Commits Recorded:**
- [x] a945b52 - feat(03-operations-03-01): create CRUD operations script
- [x] 28abf47 - feat(03-operations-03-01): create query examples script

**Self-Check: PASSED**
