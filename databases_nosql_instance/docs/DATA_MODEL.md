# DynamoDB E-Commerce Data Model

## Overview

This document describes the e-commerce data model implemented in the `szzuk-dev-products` DynamoDB table, including schema structure, capacity calculations, and supported access patterns.

## Table Structure

**Table Name:** `szzuk-dev-products`

**Billing Mode:** PROVISIONED
- Read Capacity Units (RCU): 25
- Write Capacity Units (WCU): 25
- Free-tier eligible (no cost up to 25 RCU/WCU)

**Region:** eu-central-1

**Encryption:** AWS-managed (AES-256)

## Schema

The e-commerce schema consists of 6 attributes:

| Attribute   | Type   | Purpose                              | Key Role         |
|-------------|--------|--------------------------------------|------------------|
| ProductID   | String | Unique product identifier (UUID v4)  | Partition Key    |
| Category    | String | Product category                     | Sort Key, GSI PK |
| Price       | Number | Product price (decimal)              | GSI Sort Key     |
| Name        | String | Product name                         | -                |
| Stock       | Number | Available inventory quantity         | -                |
| Description | String | Product description                  | -                |

**Note:** DynamoDB is schemaless for non-key attributes. Only key attributes (ProductID, Category, Price) are defined in the Terraform schema.

## Keys

### Primary Key Structure

- **Partition Key (HASH):** ProductID
  - Format: UUID v4 (e.g., `550e8400-e29b-41d4-a716-446655440001`)
  - Guarantees unique items across the table

- **Sort Key (RANGE):** Category
  - Values: Electronics, Books, Home, Clothing, etc.
  - Enables sorting and filtering by category

**Access Pattern:** `GetItem` by ProductID, or `Query` by ProductID with Category filter

### Global Secondary Index (GSI)

**Index Name:** PriceIndex

- **Partition Key (HASH):** Category
- **Sort Key (RANGE):** Price
- **Projection Type:** ALL (all attributes projected)
- **Capacity:** 25 RCU / 25 WCU (matches base table)

**Access Pattern:** Query products within a category by price range

**Example Query:** Find all Electronics between $100-$500:
```bash
aws dynamodb query \
  --table-name szzuk-dev-products \
  --index-name PriceIndex \
  --key-condition-expression "Category = :cat AND Price BETWEEN :low AND :high" \
  --expression-attribute-values '{":cat":{"S":"Electronics"},":low":{"N":"100"},":high":{"N":"500"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

## Item Size Calculation

DynamoDB calculates item size to determine read and write capacity consumption.

### Formula

```
Item Size = 100 bytes (overhead)
          + sum(UTF-8 bytes of attribute names)
          + sum(attribute value sizes)
```

### Example Calculation

For the "Wireless Headphones" sample product:

**Attribute Names (UTF-8 bytes):**
- ProductID: 9 bytes
- Category: 8 bytes
- Price: 5 bytes
- Name: 4 bytes
- Stock: 5 bytes
- Description: 11 bytes
- **Total:** 42 bytes

**Attribute Values:**
- ProductID: 36 bytes (`550e8400-e29b-41d4-a716-446655440002`)
- Category: 11 bytes (`Electronics`)
- Price: 6 bytes (`299.99`)
- Name: 19 bytes (`Wireless Headphones`)
- Stock: 2 bytes (`45`)
- Description: 64 bytes (`Premium noise-canceling headphones with active noise cancellation`)
- **Total:** 138 bytes

**Total Item Size:**
- 100 bytes (overhead) + 42 bytes (names) + 138 bytes (values) = **280 bytes**

### Capacity Unit Consumption

**Write Capacity Units (WCU):**
- Formula: `ceiling(item_size / 1 KB)`
- Example: 280 bytes → ceiling(280/1024) = **1 WCU**

**Read Capacity Units (RCU):**
- Formula: `ceiling(item_size / 4 KB)` for strongly consistent reads
- Formula: `ceiling(item_size / 8 KB)` for eventually consistent reads
- Example: 280 bytes → ceiling(280/4096) = **1 RCU** (strongly consistent)

**Note:** All sample products in this schema stay well under 1 KB (280-400 bytes typical), ensuring efficient 1 WCU / 1 RCU consumption per item.

## Capacity Calculations

### Write Operations

**PutItem / UpdateItem:**
- Consumes WCU on both base table and GSI (if indexed attributes change)
- Example: Writing one product → 1 WCU (table) + 1 WCU (PriceIndex) = **2 WCU total**

**BatchWriteItem:**
- Up to 25 items per batch
- Each item consumes WCU individually
- Example: Batch write 13 products → 26 WCU total (13 table + 13 GSI)

### Read Operations

**GetItem (Primary Key Lookup):**
- 1 RCU per item (strongly consistent)
- 0.5 RCU per item (eventually consistent)
- Example: Get product by ProductID → **1 RCU**

**Query (PriceIndex GSI):**
- N RCU for N items returned
- Capacity consumed = sum of all returned item sizes
- Example: Query returns 5 products (280 bytes each) → 1400 bytes → **1 RCU** (under 4 KB)

**Scan (Anti-pattern):**
- Consumes RCU for entire table regardless of filter
- M RCU for M items scanned (not M items matched)
- **Avoid scans** - use GetItem or Query instead

### Provisioned Capacity

**Current Setting:** 25 RCU / 25 WCU

**Free Tier Coverage:**
- AWS Free Tier: 25 RCU + 25 WCU per month (perpetual)
- Our allocation: Exactly matches free tier
- **Cost:** $0/month

**Capacity Planning:**
- 25 RCU = 25 strongly consistent reads/sec (up to 4 KB each)
- 25 WCU = 25 writes/sec (up to 1 KB each)
- Sufficient for demonstration and testing workloads

## Access Patterns

This schema enables three primary access patterns:

### 1. Product Lookup by ID
- **Operation:** GetItem
- **Key:** ProductID (exact match)
- **Latency:** Single-digit milliseconds
- **Use Case:** Product detail page, inventory check

### 2. Products by Category
- **Operation:** Query on base table
- **Key:** ProductID with Category filter
- **Note:** Less efficient than GSI query, requires ProductID
- **Use Case:** Limited - better to use PriceIndex GSI

### 3. Price Range Query within Category
- **Operation:** Query on PriceIndex GSI
- **Keys:** Category (exact) + Price (range)
- **Latency:** Single-digit milliseconds
- **Use Case:** Product filtering, price-based search, catalog browsing

**Example:** Find all Books under $30
```bash
aws dynamodb query \
  --table-name szzuk-dev-products \
  --index-name PriceIndex \
  --key-condition-expression "Category = :cat AND Price < :price" \
  --expression-attribute-values '{":cat":{"S":"Books"},":price":{"N":"30"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

## Sample Data

Sample products are provided in `../data/sample-products.json`:
- 13 products across 4 categories
- Price range: $19.99 - $1,299.99
- Stock levels: 0 - 95 (includes out-of-stock items)
- DynamoDB JSON format with type descriptors ({"S": "value"}, {"N": "value"})

Use with `aws dynamodb batch-write-item` to populate the table for testing.

## References

### Internal Documentation
- [Phase 02 Research](../../../.planning/phases/02-access-patterns/02-RESEARCH.md) - GSI implementation details
- [Terraform Configuration](../dynamodb.tf) - Infrastructure as code
- [Project Guidelines](../../../CLAUDE.md) - AWS profile and region settings

### AWS Documentation
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/latest/developerguide/) - Official reference
- [Item Size Calculation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CapacityUnitCalculations.html) - Capacity formulas
- [Global Secondary Indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html) - GSI best practices

## See Also

- `provision_dynamodb.md` - Setup and deployment instructions
- `data/sample-products.json` - Test dataset
- `.planning/ROADMAP.md` - Project phases and milestones
