#!/usr/bin/env bash

################################################################################
# DynamoDB CRUD Operations Demo Script
#
# Purpose: Demonstrates all four DynamoDB CRUD operations (Create, Read, Update,
#          Delete) using AWS CLI with proper DynamoDB JSON format and capacity
#          tracking for educational purposes.
#
# Usage:
#   ./scripts/crud-operations.sh [TABLE_NAME]
#
#   If TABLE_NAME is not provided, script reads it from terraform output.
#
# Requirements:
#   - AWS CLI configured with softserve-lab profile
#   - DynamoDB table provisioned via terraform
#   - jq for JSON parsing
#
# Example:
#   cd databases_nosql_instance
#   ./scripts/crud-operations.sh
#   # or
#   ./scripts/crud-operations.sh szzuk-dev-products
#
# Operations Demonstrated:
#   1. PutItem   - Create a new product in the table
#   2. GetItem   - Retrieve the product using composite key
#   3. UpdateItem - Update product attributes (stock and name)
#   4. DeleteItem - Remove the product from the table
#
# Each operation includes:
#   - Proper DynamoDB JSON format with type descriptors
#   - --return-consumed-capacity TOTAL for capacity tracking
#   - Error handling and verification
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
# OPERATION 1: PutItem - Create a new product
################################################################################

echo "============================================================"
echo "OPERATION 1: PutItem - Create New Product"
echo "============================================================"

# Generate unique ProductID
PRODUCT_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
CATEGORY="Electronics"
PRICE="199.99"
PRODUCT_NAME="Demo Wireless Keyboard"
STOCK="25"
DESCRIPTION="Full-size wireless keyboard with mechanical switches and RGB backlight"

echo "Creating product with:"
echo "  ProductID: $PRODUCT_ID"
echo "  Category: $CATEGORY"
echo "  Name: $PRODUCT_NAME"
echo "  Price: $PRICE"
echo "  Stock: $STOCK"

# Create item using DynamoDB JSON format
PUT_RESULT=$(aws dynamodb put-item \
    --table-name "$TABLE_NAME" \
    --item "{
        \"ProductID\": {\"S\": \"$PRODUCT_ID\"},
        \"Category\": {\"S\": \"$CATEGORY\"},
        \"Price\": {\"N\": \"$PRICE\"},
        \"Name\": {\"S\": \"$PRODUCT_NAME\"},
        \"Stock\": {\"N\": \"$STOCK\"},
        \"Description\": {\"S\": \"$DESCRIPTION\"}
    }" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

# Extract and display capacity consumed
PUT_CAPACITY=$(echo "$PUT_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')
echo ""
echo "✓ Product created successfully"
echo "  Consumed capacity: $PUT_CAPACITY write capacity units"
echo ""

################################################################################
# OPERATION 2: GetItem - Retrieve the product
################################################################################

echo "============================================================"
echo "OPERATION 2: GetItem - Retrieve Product"
echo "============================================================"

echo "Retrieving product with composite key:"
echo "  ProductID: $PRODUCT_ID"
echo "  Category: $CATEGORY"

# Retrieve item using both partition and sort key
GET_RESULT=$(aws dynamodb get-item \
    --table-name "$TABLE_NAME" \
    --key "{
        \"ProductID\": {\"S\": \"$PRODUCT_ID\"},
        \"Category\": {\"S\": \"$CATEGORY\"}
    }" \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

# Extract and display capacity consumed
GET_CAPACITY=$(echo "$GET_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')

# Parse and display item in readable format
ITEM=$(echo "$GET_RESULT" | jq -r '.Item')
if [[ "$ITEM" == "null" || -z "$ITEM" ]]; then
    echo "ERROR: Item not found!"
    exit 1
fi

echo ""
echo "✓ Product retrieved successfully:"
echo "$GET_RESULT" | jq '.Item | {
    ProductID: .ProductID.S,
    Category: .Category.S,
    Name: .Name.S,
    Price: .Price.N,
    Stock: .Stock.N,
    Description: .Description.S
}'
echo "  Consumed capacity: $GET_CAPACITY read capacity units"
echo ""

################################################################################
# OPERATION 3: UpdateItem - Update product attributes
################################################################################

echo "============================================================"
echo "OPERATION 3: UpdateItem - Update Product"
echo "============================================================"

echo "Updating product:"
echo "  Decrementing Stock by 5 (simulating sales)"
echo "  Updating Name to add 'BEST SELLER' tag"

# Update item using UpdateExpression
# Note: Use expression attribute names for reserved word "Name"
UPDATE_RESULT=$(aws dynamodb update-item \
    --table-name "$TABLE_NAME" \
    --key "{
        \"ProductID\": {\"S\": \"$PRODUCT_ID\"},
        \"Category\": {\"S\": \"$CATEGORY\"}
    }" \
    --update-expression "SET Stock = Stock - :dec, #n = :newname" \
    --expression-attribute-names "{\"#n\": \"Name\"}" \
    --expression-attribute-values "{
        \":dec\": {\"N\": \"5\"},
        \":newname\": {\"S\": \"Demo Wireless Keyboard [BEST SELLER]\"}
    }" \
    --return-values ALL_NEW \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

# Extract and display capacity consumed
UPDATE_CAPACITY=$(echo "$UPDATE_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')

# Display updated item
echo ""
echo "✓ Product updated successfully:"
echo "$UPDATE_RESULT" | jq '.Attributes | {
    ProductID: .ProductID.S,
    Category: .Category.S,
    Name: .Name.S,
    Price: .Price.N,
    Stock: .Stock.N,
    Description: .Description.S
}'
echo "  Consumed capacity: $UPDATE_CAPACITY write capacity units"
echo ""

################################################################################
# OPERATION 4: DeleteItem - Remove the product
################################################################################

echo "============================================================"
echo "OPERATION 4: DeleteItem - Delete Product"
echo "============================================================"

echo "Deleting product:"
echo "  ProductID: $PRODUCT_ID"
echo "  Category: $CATEGORY"

# Delete item using composite key
DELETE_RESULT=$(aws dynamodb delete-item \
    --table-name "$TABLE_NAME" \
    --key "{
        \"ProductID\": {\"S\": \"$PRODUCT_ID\"},
        \"Category\": {\"S\": \"$CATEGORY\"}
    }" \
    --return-values ALL_OLD \
    --return-consumed-capacity TOTAL \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json)

# Extract and display capacity consumed
DELETE_CAPACITY=$(echo "$DELETE_RESULT" | jq -r '.ConsumedCapacity.CapacityUnits // 0')

# Display deleted item for confirmation
echo ""
echo "✓ Product deleted successfully:"
echo "$DELETE_RESULT" | jq '.Attributes | {
    ProductID: .ProductID.S,
    Category: .Category.S,
    Name: .Name.S,
    Price: .Price.N,
    Stock: .Stock.N
}'
echo "  Consumed capacity: $DELETE_CAPACITY write capacity units"
echo ""

################################################################################
# Verification: Confirm deletion
################################################################################

echo "============================================================"
echo "VERIFICATION: Confirm Deletion"
echo "============================================================"

echo "Attempting to retrieve deleted item (should fail)..."

# Try to get item - should not exist
VERIFY_RESULT=$(aws dynamodb get-item \
    --table-name "$TABLE_NAME" \
    --key "{
        \"ProductID\": {\"S\": \"$PRODUCT_ID\"},
        \"Category\": {\"S\": \"$CATEGORY\"}
    }" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output json 2>&1) || true

# Check if item is gone
VERIFY_ITEM=$(echo "$VERIFY_RESULT" | jq -r '.Item // empty' 2>/dev/null || echo "")
if [[ -z "$VERIFY_ITEM" ]]; then
    echo "✓ Deletion confirmed - item no longer exists in table"
else
    echo "WARNING: Item still exists in table"
fi

echo ""

################################################################################
# Summary
################################################################################

echo "============================================================"
echo "CRUD OPERATIONS SUMMARY"
echo "============================================================"
echo ""
echo "All four DynamoDB CRUD operations completed successfully:"
echo ""
echo "  ✓ CREATE (PutItem)   - $PUT_CAPACITY WCU"
echo "  ✓ READ   (GetItem)   - $GET_CAPACITY RCU"
echo "  ✓ UPDATE (UpdateItem) - $UPDATE_CAPACITY WCU"
echo "  ✓ DELETE (DeleteItem) - $DELETE_CAPACITY WCU"
echo ""
echo "Total capacity consumed: $(echo "$PUT_CAPACITY + $GET_CAPACITY + $UPDATE_CAPACITY + $DELETE_CAPACITY" | bc) units"
echo ""
echo "Key Patterns Demonstrated:"
echo "  • DynamoDB JSON format with type descriptors ({\"S\": \"...\"}, {\"N\": \"...\"})"
echo "  • Composite key usage (ProductID + Category) for all single-item operations"
echo "  • UpdateExpression syntax for atomic attribute updates"
echo "  • Expression attribute names for reserved words (e.g., Name)"
echo "  • Capacity tracking with --return-consumed-capacity TOTAL"
echo "  • Return values (ALL_OLD, ALL_NEW) for confirmation"
echo ""
echo "============================================================"
