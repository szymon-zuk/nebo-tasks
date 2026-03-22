# DynamoDB data model (products table)

## Table

| | |
|--|--|
| **Name** | `${project_name}-${environment}-products` (default `szzuk-dev-products`) |
| **Billing** | On-demand (`PAY_PER_REQUEST`) |
| **Region** | `eu-central-1` |
| **Encryption** | AWS-owned key at rest (default) |

## Attributes (logical)

| Attribute | Type | Role |
|-----------|------|------|
| ProductID | String | Partition key (HASH) |
| Category | String | Sort key (RANGE) |
| Price | Number | GSI sort key |
| Name, Stock, Description | String/Number | Application attributes (not declared in Terraform except keys) |

DynamoDB is schemaless for non-key attributes. Terraform `attribute` blocks only list attributes used in the table or index key schemas.

## Primary key

- **HASH:** `ProductID` (UUID-style strings in sample data)
- **RANGE:** `Category`

**Typical access:** `GetItem` with both keys; `Query` when you know `ProductID` and want to constrain `Category`.

## Global secondary index: `PriceIndex`

- **HASH:** `Category`
- **RANGE:** `Price`
- **Projection:** `ALL`

**Typical access:** `Query` on `PriceIndex` with `Category = :c` and a condition on `Price` (e.g. `BETWEEN`, `<`).

Example:

```bash
aws dynamodb query \
  --table-name szzuk-dev-products \
  --index-name PriceIndex \
  --key-condition-expression "Category = :cat AND Price BETWEEN :low AND :high" \
  --expression-attribute-values '{":cat":{"S":"Electronics"},":low":{"N":"100"},":high":{"N":"500"}}' \
  --profile softserve-lab \
  --region eu-central-1
```

## Item size and capacity units (conceptual)

Rough rules (see [AWS: capacity unit calculations](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CapacityUnitCalculations.html)):

- **WCU:** 1 WCU = 1 KB of write; item size rounds up.
- **RCU:** 1 RCU = 4 KB strongly consistent read (2 × 4 KB eventually consistent).

Sample rows are ~300 bytes → about **1 RCU / 1 WCU** per simple read/write. Writes that affect GSI key attributes also consume write capacity on the index (on-demand pricing still applies per request).

## Design choices (short)

1. **High-cardinality partition key** (`ProductID`) spreads load on the base table.
2. **GSI on `Category` + `Price`** supports “browse by category with price filter” without scanning the whole table.
3. **On-demand billing** avoids tuning RCU/WCU for a teaching lab.

## Related files

- [../dynamodb.tf](../dynamodb.tf) — table and GSI
- [../data/sample-products.json](../data/sample-products.json) — seed data
- [../provision_dynamodb.md](../provision_dynamodb.md) — CLI-only tutorial (separate from Terraform)
