#!/usr/bin/env bash

# load-sample-data.sh - Load sample products into DynamoDB table using BatchWriteItem
#
# Usage:
#   ./scripts/load-sample-data.sh                    # Read table name from terraform output
#   ./scripts/load-sample-data.sh TABLE_NAME         # Provide table name directly
#
# Description:
#   Loads sample products from data/sample-products.json into DynamoDB table using
#   BatchWriteItem API with proper chunking (max 25 items per batch) and retry logic
#   for UnprocessedItems with exponential backoff.
#
# Requirements:
#   - aws CLI configured with profile softserve-lab
#   - jq for JSON processing
#   - terraform (if using terraform output to get table name)
#   - data/sample-products.json file with product data

set -euo pipefail

# Configuration
readonly PROFILE="softserve-lab"
readonly REGION="eu-central-1"
readonly CHUNK_SIZE=25
readonly MAX_RETRIES=5
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly DATA_FILE="$PROJECT_DIR/data/sample-products.json"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check prerequisites
check_prerequisites() {
    local missing_deps=()

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Install with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Get table name from terraform output or argument
get_table_name() {
    if [[ $# -gt 0 ]]; then
        echo "$1"
    else
        log_info "Reading table name from terraform output..."
        cd "$PROJECT_DIR" || exit 1
        if ! terraform output -raw dynamodb_table_name 2>/dev/null; then
            log_error "Failed to read table name from terraform output"
            log_error "Usage: $0 [TABLE_NAME]"
            exit 1
        fi
    fi
}

# Verify data file exists and is valid JSON
verify_data_file() {
    if [[ ! -f "$DATA_FILE" ]]; then
        log_error "Data file not found: $DATA_FILE"
        exit 1
    fi

    if ! jq empty "$DATA_FILE" 2>/dev/null; then
        log_error "Invalid JSON in data file: $DATA_FILE"
        exit 1
    fi

    log_info "Data file verified: $DATA_FILE"
}

# Process batch with retry logic for UnprocessedItems
process_batch() {
    local table_name="$1"
    local batch_json="$2"
    local batch_num="$3"
    local retry_count=0
    local unprocessed_items="$batch_json"

    while [[ $retry_count -le $MAX_RETRIES ]]; do
        log_info "Processing batch $batch_num (attempt $((retry_count + 1))/$((MAX_RETRIES + 1)))"

        # Execute batch-write-item
        local response
        response=$(aws dynamodb batch-write-item \
            --request-items "$unprocessed_items" \
            --return-consumed-capacity TOTAL \
            --profile "$PROFILE" \
            --region "$REGION" \
            2>&1)

        if [[ $? -ne 0 ]]; then
            log_error "AWS CLI error: $response"
            return 1
        fi

        # Check for UnprocessedItems
        local unprocessed_count
        unprocessed_count=$(echo "$response" | jq '.UnprocessedItems | length')

        # Log consumed capacity
        local consumed_capacity
        consumed_capacity=$(echo "$response" | jq -r '.ConsumedCapacity[]? | "Table: \(.TableName), Capacity: \(.CapacityUnits)"')
        if [[ -n "$consumed_capacity" ]]; then
            log_info "$consumed_capacity"
        fi

        if [[ "$unprocessed_count" -eq 0 ]]; then
            log_success "Batch $batch_num completed successfully"
            return 0
        fi

        # Handle UnprocessedItems with exponential backoff
        log_warning "Batch $batch_num has $unprocessed_count unprocessed items"

        if [[ $retry_count -eq $MAX_RETRIES ]]; then
            log_error "Max retries ($MAX_RETRIES) reached for batch $batch_num"
            return 1
        fi

        # Exponential backoff: 2^retry seconds (1s, 2s, 4s, 8s, 16s)
        local sleep_time=$((2 ** retry_count))
        log_info "Retrying in $sleep_time seconds..."
        sleep "$sleep_time"

        # Prepare UnprocessedItems for retry
        unprocessed_items=$(echo "$response" | jq -c '.UnprocessedItems')
        retry_count=$((retry_count + 1))
    done

    return 1
}

# Load data into DynamoDB
load_data() {
    local table_name="$1"

    log_info "Starting data load to table: $table_name"

    # Read and validate JSON array
    local items
    items=$(jq -c '.' "$DATA_FILE")

    # Count total items
    local total_items
    total_items=$(echo "$items" | jq 'length')
    log_info "Found $total_items items to load"

    # Calculate number of batches
    local total_batches=$(( (total_items + CHUNK_SIZE - 1) / CHUNK_SIZE ))
    log_info "Will process $total_batches batch(es) (max $CHUNK_SIZE items per batch)"

    # Process items in chunks
    local batch_num=1
    for ((i=0; i<total_items; i+=CHUNK_SIZE)); do
        local end=$((i + CHUNK_SIZE))

        log_info "Preparing batch $batch_num/$total_batches (items $((i + 1))-$(( end < total_items ? end : total_items )))"

        # Extract chunk and transform to BatchWriteItem format
        local chunk
        chunk=$(echo "$items" | jq -c ".[$i:$end]")

        # Wrap items in PutRequest format
        local put_requests
        put_requests=$(echo "$chunk" | jq -c 'map({"PutRequest": {"Item": .}})')

        # Create request-items JSON with table name as key
        local request_items
        request_items=$(jq -n --arg table "$table_name" --argjson items "$put_requests" '{($table): $items}')

        # Process batch with retry logic
        if ! process_batch "$table_name" "$request_items" "$batch_num"; then
            log_error "Failed to process batch $batch_num"
            return 1
        fi

        batch_num=$((batch_num + 1))
    done

    log_success "All batches processed successfully"
    return 0
}

# Validate item count after load
validate_item_count() {
    local table_name="$1"
    local expected_count="$2"

    log_info "Validating item count..."

    # Use scan with COUNT to get accurate real-time count
    local actual_count
    actual_count=$(aws dynamodb scan \
        --table-name "$table_name" \
        --select COUNT \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query 'Count' \
        --output text 2>&1)

    if [[ $? -ne 0 ]]; then
        log_error "Failed to get item count: $actual_count"
        return 1
    fi

    log_info "Expected: $expected_count items, Actual: $actual_count items"

    if [[ "$actual_count" -eq "$expected_count" ]]; then
        log_success "Item count validation passed!"
        return 0
    else
        log_error "Item count mismatch! Expected $expected_count but found $actual_count"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== DynamoDB Sample Data Loader ==="
    echo

    # Check prerequisites
    check_prerequisites

    # Verify data file
    verify_data_file

    # Get table name
    local table_name
    table_name=$(get_table_name "$@")
    log_info "Target table: $table_name"
    echo

    # Count expected items
    local expected_count
    expected_count=$(jq 'length' "$DATA_FILE")

    # Load data
    if ! load_data "$table_name"; then
        log_error "Data load failed"
        exit 1
    fi

    echo

    # Validate item count
    if ! validate_item_count "$table_name" "$expected_count"; then
        log_error "Validation failed"
        exit 1
    fi

    echo
    log_success "=== Data load completed successfully ==="
    log_success "Loaded $expected_count items into $table_name"
    exit 0
}

# Run main function
main "$@"
