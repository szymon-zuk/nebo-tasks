#!/usr/bin/env bash

################################################################################
# DynamoDB Query Patterns Demo Script
#
# Purpose: Demonstrates DynamoDB query patterns and compares the efficiency of
#          Query operations versus Scan operations with capacity consumption
#          tracking for educational purposes.
#
# Usage:
#   ./scripts/query-examples.sh [TABLE_NAME]
#
#   If TABLE_NAME is not provided, script reads it from terraform output.
#
# Requirements:
#   - AWS CLI configured with softserve-lab profile
#   - DynamoDB table provisioned via terraform with sample data loaded
#   - PriceIndex GSI configured on the table
#   - jq for JSON parsing
#
# Example:
#   cd databases_nosql_instance
#   ./scripts/query-examples.sh
#   # or
#   ./scripts/query-examples.sh szzuk-dev-products
#
# Operations Demonstrated:
#   1. Query on PriceIndex GSI by Category (partition key only)
#   2. Query on PriceIndex GSI with price range conditions
#   3. Query with sort order control
#   4. Query with projection expressions
#   5. Query with pagination (limit)
#   6. Scan with FilterExpression (for comparison)
#
# Each operation includes:
#   - Capacity consumption tracking
#   - Educational comments about efficiency
#   - Best practices and anti-patterns
#
################################################################################

set -euo pipefail

# AWS Configuration
readonly PROFILE="softserve-lab"
readonly REGION="eu-central-1"

# Get table name from terraform output or command line argument
if [[ $# -gt 0 ]]; then
    TABLE_NAME="$1"
else
    echo "Reading table name from terraform output..."
    TABLE_NAME=$(terraform output -raw dynamodb_table_name 2>/dev/null || true)
    if [[ -z "$TABLE_NAME" ]]; then
        echo "ERROR: Could not determine table name. Please provide as argument or run from terraform directory."
        echo "Usage: $0 [TABLE_NAME]"
        exit 1
    fi
fi

echo "Using DynamoDB table: $TABLE_NAME"
echo ""

################################################################################
# IMPORTANT: Query-First Pattern
################################################################################
#
# **Always prefer Query over Scan when possible**
#
# Why Query is Efficient:
#   • Reads only the specific partition(s) you request
#   • Capacity consumption is predictable and based on items returned
#   • Can use range key conditions to further filter within a partition
#   • Supports GSI for alternative access patterns
#
# Why Scan is Expensive:
#   • Reads the ENTIRE table, every single item
#   • Capacity consumption based on table size, NOT result size
#   • FilterExpression applied AFTER reading all items (doesn't reduce capacity)
#   • Should only be used when you truly need all items or no Query option exists
#
# Capacity Formula:
#   Query:  Capacity = (size of returned items / 4KB) rounded up
#   Scan:   Capacity = (total table size / 4KB) regardless of filter results
#
# Rule of Thumb:
#   If you can express your access pattern using a key (partition or sort key),
#   use Query. If you need to filter on non-key attributes with no GSI, consider
#   adding a GSI before resorting to Scan.
#
################################################################################

################################################################################
# OPERATION 1: Query on GSI (Partition Key Only)
################################################################################

echo "============================================================"
echo "OPERATION 1: Query on GSI by Category"
echo "============================================================"
echo ""
echo "Query for all products in 'Electronics' category"
echo "Uses: PriceIndex GSI with Category partition key only"
echo ""

QUERY1_RESULT=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --index-name PriceIndex \
    --key-condition-expression "Category = :cat" \
    --expression-attribute-values "{\":cat\": {\"S\": \"Electronics\"}}" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

QUERY1_CAPACITY=$(echo "$QUERY1_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
QUERY1_COUNT=$(echo "$QUERY1_RESULT" | jq -r '.Count')

echo "✓ Query completed successfully"
echo "  Items returned: $QUERY1_COUNT"
echo "  Consumed capacity: $QUERY1_CAPACITY read capacity units"
echo ""
echo "Sample items (first 3):"
echo "$QUERY1_RESULT" | jq -r '.Items[0:3] | .[] | {
    ProductID: .ProductID.S,
    Category: .Category.S,
    Name: .Name.S,
    Price: .Price.N,
    Stock: .Stock.N
}'
echo ""

################################################################################
# OPERATION 2: Query on PriceIndex GSI with Range Condition
################################################################################

echo "============================================================"
echo "OPERATION 2: Query on PriceIndex GSI (Price Range)"
echo "============================================================"
echo ""
echo "Query for Electronics products priced between $100 and $500"
echo "Uses: GSI PriceIndex with Category (HASH) and Price (RANGE)"
echo ""

QUERY2_RESULT=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --index-name PriceIndex \
    --key-condition-expression "Category = :cat AND Price BETWEEN :minprice AND :maxprice" \
    --expression-attribute-values "{
        \":cat\": {\"S\": \"Electronics\"},
        \":minprice\": {\"N\": \"100\"},
        \":maxprice\": {\"N\": \"500\"}
    }" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

QUERY2_CAPACITY=$(echo "$QUERY2_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
QUERY2_COUNT=$(echo "$QUERY2_RESULT" | jq -r '.Count')

echo "✓ GSI Query completed successfully"
echo "  Items returned: $QUERY2_COUNT"
echo "  Consumed capacity: $QUERY2_CAPACITY read capacity units"
echo ""
echo "Items are automatically sorted by Price (GSI sort key):"
echo "$QUERY2_RESULT" | jq -r '.Items[] | {
    Name: .Name.S,
    Category: .Category.S,
    Price: .Price.N,
    Stock: .Stock.N
}'
echo ""

################################################################################
# OPERATION 3: Query with >= and <= Operators (Alternative Range Syntax)
################################################################################

echo "============================================================"
echo "OPERATION 3: Query with >= and <= Operators"
echo "============================================================"
echo ""
echo "Query for Books priced >= $20 and <= $30"
echo "Demonstrates alternative range condition syntax"
echo ""

QUERY3_RESULT=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --index-name PriceIndex \
    --key-condition-expression "Category = :cat AND Price >= :minprice AND Price <= :maxprice" \
    --expression-attribute-values "{
        \":cat\": {\"S\": \"Books\"},
        \":minprice\": {\"N\": \"20\"},
        \":maxprice\": {\"N\": \"30\"}
    }" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

QUERY3_CAPACITY=$(echo "$QUERY3_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
QUERY3_COUNT=$(echo "$QUERY3_RESULT" | jq -r '.Count')

echo "✓ Query with >= and <= completed successfully"
echo "  Items returned: $QUERY3_COUNT"
echo "  Consumed capacity: $QUERY3_CAPACITY read capacity units"
echo ""
if [[ "$QUERY3_COUNT" -gt 0 ]]; then
    echo "$QUERY3_RESULT" | jq -r '.Items[] | {Name: .Name.S, Price: .Price.N}'
else
    echo "  (No items found in this price range)"
fi
echo ""

################################################################################
# OPERATION 4: Query with Sort Order Control
################################################################################

echo "============================================================"
echo "OPERATION 4: Query with Sort Order Control"
echo "============================================================"
echo ""
echo "Query Home category, sorted by Price descending (highest first)"
echo "Uses: --no-scan-index-forward flag to reverse GSI sort order"
echo ""

QUERY4_RESULT=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --index-name PriceIndex \
    --key-condition-expression "Category = :cat" \
    --expression-attribute-values "{\":cat\": {\"S\": \"Home\"}}" \
    --no-scan-index-forward \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

QUERY4_CAPACITY=$(echo "$QUERY4_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
QUERY4_COUNT=$(echo "$QUERY4_RESULT" | jq -r '.Count')

echo "✓ Query with reverse sort completed successfully"
echo "  Items returned: $QUERY4_COUNT (sorted by price descending)"
echo "  Consumed capacity: $QUERY4_CAPACITY read capacity units"
echo ""
if [[ "$QUERY4_COUNT" -gt 0 ]]; then
    echo "$QUERY4_RESULT" | jq -r '.Items[] | {Name: .Name.S, Price: .Price.N}'
else
    echo "  (No items found in Home category)"
fi
echo ""

################################################################################
# OPERATION 5: Query with Projection Expression
################################################################################

echo "============================================================"
echo "OPERATION 5: Query with Projection Expression"
echo "============================================================"
echo ""
echo "Query Clothing category, retrieve only Name and Price attributes"
echo "Uses: --projection-expression to reduce data transfer"
echo ""

QUERY5_RESULT=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --index-name PriceIndex \
    --key-condition-expression "Category = :cat" \
    --expression-attribute-values "{\":cat\": {\"S\": \"Clothing\"}}" \
    --projection-expression "#n, Price" \
    --expression-attribute-names "{\"#n\": \"Name\"}" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

QUERY5_CAPACITY=$(echo "$QUERY5_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
QUERY5_COUNT=$(echo "$QUERY5_RESULT" | jq -r '.Count')

echo "✓ Query with projection completed successfully"
echo "  Items returned: $QUERY5_COUNT (only Name and Price attributes)"
echo "  Consumed capacity: $QUERY5_CAPACITY read capacity units"
echo "  Note: Projection reduces network transfer but NOT capacity consumption"
echo ""
if [[ "$QUERY5_COUNT" -gt 0 ]]; then
    echo "$QUERY5_RESULT" | jq -r '.Items[] | {Name: .Name.S, Price: .Price.N}'
else
    echo "  (No items found in Clothing category)"
fi
echo ""

################################################################################
# OPERATION 6: Query with Limit (Pagination)
################################################################################

echo "============================================================"
echo "OPERATION 6: Query with Limit (Pagination)"
echo "============================================================"
echo ""
echo "Query Electronics, return first 3 items only"
echo "Uses: --limit flag for pagination demonstration"
echo ""

QUERY6_RESULT=$(aws dynamodb query \
    --table-name "$TABLE_NAME" \
    --key-condition-expression "Category = :cat" \
    --expression-attribute-values "{\":cat\": {\"S\": \"Electronics\"}}" \
    --limit 3 \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

QUERY6_CAPACITY=$(echo "$QUERY6_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
QUERY6_COUNT=$(echo "$QUERY6_RESULT" | jq -r '.Count')
QUERY6_HAS_MORE=$(echo "$QUERY6_RESULT" | jq -r 'has("LastEvaluatedKey")')

echo "✓ Query with limit completed successfully"
echo "  Items returned: $QUERY6_COUNT"
echo "  Consumed capacity: $QUERY6_CAPACITY read capacity units"
echo "  More results available: $QUERY6_HAS_MORE"
echo ""
echo "$QUERY6_RESULT" | jq -r '.Items[] | {Name: .Name.S, Price: .Price.N}'
echo ""

################################################################################
# OPERATION 7: Scan with FilterExpression (ANTI-PATTERN for comparison)
################################################################################

echo "============================================================"
echo "OPERATION 7: Scan with FilterExpression (FOR COMPARISON)"
echo "============================================================"
echo ""
echo "⚠️  WARNING: Scan operation reads ENTIRE table"
echo "⚠️  This is an ANTI-PATTERN shown for educational purposes only"
echo ""
echo "Scanning table for products with Stock < 10 (low inventory)"
echo "Uses: Scan with --filter-expression (applied AFTER reading all items)"
echo ""

SCAN_RESULT=$(aws dynamodb scan \
    --table-name "$TABLE_NAME" \
    --filter-expression "Stock < :threshold" \
    --expression-attribute-values "{\":threshold\": {\"N\": \"10\"}}" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

SCAN_CAPACITY=$(echo "$SCAN_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
SCAN_SCANNED=$(echo "$SCAN_RESULT" | jq -r '.ScannedCount')
SCAN_RETURNED=$(echo "$SCAN_RESULT" | jq -r '.Count')

echo "✓ Scan completed"
echo "  Items scanned: $SCAN_SCANNED (entire table)"
echo "  Items returned: $SCAN_RETURNED (after filter applied)"
echo "  Consumed capacity: $SCAN_CAPACITY read capacity units"
echo ""
echo "⚠️  IMPORTANT: Capacity charged for ALL $SCAN_SCANNED items scanned,"
echo "   even though only $SCAN_RETURNED items matched the filter!"
echo ""
if [[ "$SCAN_RETURNED" -gt 0 ]]; then
    echo "Low stock items found:"
    echo "$SCAN_RESULT" | jq -r '.Items[] | {
        Name: .Name.S,
        Category: .Category.S,
        Stock: .Stock.N
    }'
else
    echo "  (No low stock items found)"
fi
echo ""

################################################################################
# Capacity Comparison Summary
################################################################################

echo "============================================================"
echo "CAPACITY CONSUMPTION COMPARISON"
echo "============================================================"
echo ""
echo "Query Operations (EFFICIENT):"
echo "  1. Query on primary key (Category):           $QUERY1_CAPACITY RCU"
echo "  2. Query on GSI with range (Price BETWEEN):   $QUERY2_CAPACITY RCU"
echo "  3. Query with >= and <=:                      $QUERY3_CAPACITY RCU"
echo "  4. Query with reverse sort order:             $QUERY4_CAPACITY RCU"
echo "  5. Query with projection expression:          $QUERY5_CAPACITY RCU"
echo "  6. Query with limit (3 items):                $QUERY6_CAPACITY RCU"
echo ""
echo "Scan Operation (EXPENSIVE):"
echo "  7. Scan entire table with filter:             $SCAN_CAPACITY RCU"
echo "     (Scanned $SCAN_SCANNED items, returned $SCAN_RETURNED items)"
echo ""

# Calculate total Query capacity
TOTAL_QUERY_CAPACITY=$(echo "$QUERY1_CAPACITY + $QUERY2_CAPACITY + $QUERY3_CAPACITY + $QUERY4_CAPACITY + $QUERY5_CAPACITY + $QUERY6_CAPACITY" | bc)

echo "Total Query capacity: $TOTAL_QUERY_CAPACITY RCU (6 targeted operations)"
echo "Single Scan capacity: $SCAN_CAPACITY RCU (1 operation reading entire table)"
echo ""
echo "============================================================"
echo "KEY TAKEAWAYS"
echo "============================================================"
echo ""
echo "1. QUERY IS EFFICIENT"
echo "   • Reads only the partition(s) you specify"
echo "   • Capacity = (returned item size / 4KB)"
echo "   • Predictable and cost-effective"
echo "   • Can filter further with range key conditions"
echo ""
echo "2. SCAN IS EXPENSIVE"
echo "   • Reads EVERY item in the table"
echo "   • Capacity = (entire table size / 4KB)"
echo "   • FilterExpression applied AFTER reading (doesn't save capacity)"
echo "   • Use only when truly necessary (e.g., analytics, backups)"
echo ""
echo "3. DESIGN FOR QUERY"
echo "   • Define access patterns before creating table"
echo "   • Choose partition/sort keys to support Query operations"
echo "   • Add GSIs for alternative access patterns"
echo "   • Avoid Scan in production application code paths"
echo ""
echo "4. CAPACITY MATH"
echo "   • 1 RCU = 4KB strongly consistent read (or 2 x 4KB eventually consistent)"
echo "   • Query capacity depends on items returned"
echo "   • Scan capacity depends on table size (regardless of filter)"
echo "   • GSI queries consume capacity from GSI's provisioned capacity"
echo ""
echo "5. RANGE KEY OPERATORS"
echo "   • = (equals)"
echo "   • < > <= >= (comparison)"
echo "   • BETWEEN :min AND :max (inclusive range)"
echo "   • begins_with (for strings)"
echo "   • Use these to narrow Query results efficiently"
echo ""
echo "============================================================"
echo ""
echo "Best Practice: Always prefer Query over Scan"
echo "Exception: Scan is acceptable for infrequent batch operations,"
echo "           analytics, or backups where you genuinely need all items."
echo ""
echo "============================================================"
