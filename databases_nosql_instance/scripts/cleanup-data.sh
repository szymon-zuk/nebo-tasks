#!/usr/bin/env bash

# cleanup-data.sh - Remove all data from DynamoDB table while preserving table structure
#
# Usage:
#   ./scripts/cleanup-data.sh                    # Read table name from terraform output
#   ./scripts/cleanup-data.sh TABLE_NAME         # Provide table name directly
#   ./scripts/cleanup-data.sh --force            # Skip confirmation prompt
#   ./scripts/cleanup-data.sh TABLE_NAME --force # Combine table name and force
#
# Description:
#   Removes ALL items from DynamoDB table using Scan (with pagination) and BatchWriteItem
#   with DeleteRequest operations. Preserves table and GSI structure (no terraform destroy).
#   Verifies zero items remain after cleanup and confirms table remains ACTIVE.
#
# WARNING: This will delete ALL data from the table. Use with caution!
#
# Requirements:
#   - aws CLI configured with profile softserve-lab
#   - jq for JSON processing
#   - terraform (if using terraform output to get table name)

set -euo pipefail

# Configuration
readonly PROFILE="softserve-lab"
readonly REGION="eu-central-1"
readonly CHUNK_SIZE=25
readonly MAX_RETRIES=5
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

# Parse arguments
parse_arguments() {
    local force_flag=false
    local table_name=""

    for arg in "$@"; do
        case $arg in
            --force)
                force_flag=true
                ;;
            *)
                if [[ -z "$table_name" ]]; then
                    table_name="$arg"
                fi
                ;;
        esac
    done

    echo "$force_flag|$table_name"
}

# Get table name from terraform output or argument
get_table_name() {
    local table_name="$1"

    if [[ -n "$table_name" ]]; then
        echo "$table_name"
    else
        log_info "Reading table name from terraform output..."
        cd "$PROJECT_DIR" || exit 1
        if ! terraform output -raw dynamodb_table_name 2>/dev/null; then
            log_error "Failed to read table name from terraform output"
            log_error "Usage: $0 [TABLE_NAME] [--force]"
            exit 1
        fi
    fi
}

# Safety confirmation prompt
confirm_deletion() {
    local table_name="$1"
    local force="$2"

    if [[ "$force" == "true" ]]; then
        log_warning "Running in force mode - skipping confirmation"
        return 0
    fi

    echo
    log_warning "WARNING: This will delete ALL items from table: $table_name"
    log_warning "This operation cannot be undone!"
    echo -n "Type 'yes' to continue: "
    read -r confirmation

    if [[ "$confirmation" != "yes" ]]; then
        log_info "Operation cancelled by user"
        exit 2
    fi

    log_info "Confirmation received, proceeding with cleanup..."
}

# Scan all items with pagination
scan_all_items() {
    local table_name="$1"

    log_info "Scanning table for all items (keys only)..."

    local all_items="[]"
    local last_key="null"
    local page_count=0
    local total_scanned=0

    while true; do
        page_count=$((page_count + 1))

        # Build scan command
        local scan_cmd=(
            aws dynamodb scan
            --table-name "$table_name"
            --projection-expression "ProductID, Category"
            --profile "$PROFILE"
            --region "$REGION"
        )

        # Add exclusive-start-key for pagination
        if [[ "$last_key" != "null" ]]; then
            scan_cmd+=(--exclusive-start-key "$last_key")
        fi

        # Execute scan
        local response
        response=$("${scan_cmd[@]}" 2>&1)

        if [[ $? -ne 0 ]]; then
            log_error "Scan failed: $response"
            return 1
        fi

        # Extract items from response
        local items
        items=$(echo "$response" | jq -c '.Items')
        local items_count
        items_count=$(echo "$items" | jq 'length')

        # Accumulate items
        all_items=$(echo "$all_items $items" | jq -s 'add')
        total_scanned=$((total_scanned + items_count))

        log_info "Page $page_count: scanned $items_count items (total: $total_scanned)"

        # Check for pagination
        last_key=$(echo "$response" | jq -c '.LastEvaluatedKey // null')

        if [[ "$last_key" == "null" ]]; then
            break
        fi
    done

    log_info "Scan completed: found $total_scanned items total"

    echo "$all_items"
    return 0
}

# Process delete batch with retry logic
process_delete_batch() {
    local table_name="$1"
    local batch_json="$2"
    local batch_num="$3"
    local retry_count=0
    local unprocessed_items="$batch_json"

    while [[ $retry_count -le $MAX_RETRIES ]]; do
        log_info "Deleting batch $batch_num (attempt $((retry_count + 1))/$((MAX_RETRIES + 1)))"

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
            log_success "Batch $batch_num deleted successfully"
            return 0
        fi

        # Handle UnprocessedItems with exponential backoff
        log_warning "Batch $batch_num has $unprocessed_count unprocessed items"

        if [[ $retry_count -eq $MAX_RETRIES ]]; then
            log_error "Max retries ($MAX_RETRIES) reached for batch $batch_num"
            return 1
        fi

        # Exponential backoff: 2^retry seconds
        local sleep_time=$((2 ** retry_count))
        log_info "Retrying in $sleep_time seconds..."
        sleep "$sleep_time"

        # Prepare UnprocessedItems for retry
        unprocessed_items=$(echo "$response" | jq -c '.UnprocessedItems')
        retry_count=$((retry_count + 1))
    done

    return 1
}

# Delete all items using batch delete
delete_items() {
    local table_name="$1"
    local items="$2"

    local total_items
    total_items=$(echo "$items" | jq 'length')

    if [[ $total_items -eq 0 ]]; then
        log_info "No items to delete"
        return 0
    fi

    log_info "Starting batch delete of $total_items items..."

    # Calculate number of batches
    local total_batches=$(( (total_items + CHUNK_SIZE - 1) / CHUNK_SIZE ))
    log_info "Will process $total_batches batch(es) (max $CHUNK_SIZE items per batch)"

    # Process items in chunks
    local batch_num=1
    for ((i=0; i<total_items; i+=CHUNK_SIZE)); do
        local end=$((i + CHUNK_SIZE))

        log_info "Preparing batch $batch_num/$total_batches (items $((i + 1))-$(( end < total_items ? end : total_items )))"

        # Extract chunk
        local chunk
        chunk=$(echo "$items" | jq -c ".[$i:$end]")

        # Transform to DeleteRequest format
        local delete_requests
        delete_requests=$(echo "$chunk" | jq -c 'map({"DeleteRequest": {"Key": .}})')

        # Create request-items JSON with table name as key
        local request_items
        request_items=$(jq -n --arg table "$table_name" --argjson items "$delete_requests" '{($table): $items}')

        # Process batch with retry logic
        if ! process_delete_batch "$table_name" "$request_items" "$batch_num"; then
            log_error "Failed to delete batch $batch_num"
            return 1
        fi

        batch_num=$((batch_num + 1))
    done

    log_success "All delete batches processed successfully"
    return 0
}

# Verify zero items remain
verify_cleanup() {
    local table_name="$1"

    log_info "Verifying cleanup..."

    # Get accurate count using scan
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

    log_info "Items remaining: $actual_count"

    if [[ "$actual_count" -eq 0 ]]; then
        log_success "Cleanup verification passed: 0 items remaining"
        return 0
    else
        log_error "Cleanup verification failed: $actual_count items still exist"
        return 1
    fi
}

# Verify table structure is preserved
verify_table_structure() {
    local table_name="$1"

    log_info "Verifying table structure is preserved..."

    # Get table description
    local table_info
    table_info=$(aws dynamodb describe-table \
        --table-name "$table_name" \
        --profile "$PROFILE" \
        --region "$REGION" \
        2>&1)

    if [[ $? -ne 0 ]]; then
        log_error "Failed to describe table: $table_info"
        return 1
    fi

    # Check table status
    local table_status
    table_status=$(echo "$table_info" | jq -r '.Table.TableStatus')

    # Check GSI status
    local gsi_status
    gsi_status=$(echo "$table_info" | jq -r '.Table.GlobalSecondaryIndexes[0].IndexStatus // "N/A"')

    log_info "Table status: $table_status"
    log_info "GSI status: $gsi_status"

    if [[ "$table_status" == "ACTIVE" ]]; then
        log_success "Table structure preserved: $table_name (ACTIVE)"

        if [[ "$gsi_status" == "ACTIVE" ]]; then
            log_success "GSI status: ACTIVE"
        elif [[ "$gsi_status" == "N/A" ]]; then
            log_info "No GSI found on table"
        else
            log_warning "GSI status: $gsi_status"
        fi

        return 0
    else
        log_error "Table status is not ACTIVE: $table_status"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== DynamoDB Table Cleanup Tool ==="
    echo

    # Check prerequisites
    check_prerequisites

    # Parse arguments
    local args
    args=$(parse_arguments "$@")
    local force_flag
    force_flag=$(echo "$args" | cut -d'|' -f1)
    local table_arg
    table_arg=$(echo "$args" | cut -d'|' -f2)

    # Get table name
    local table_name
    table_name=$(get_table_name "$table_arg")
    log_info "Target table: $table_name"

    # Safety confirmation
    confirm_deletion "$table_name" "$force_flag"
    echo

    # Scan all items
    local items
    items=$(scan_all_items "$table_name")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to scan items"
        exit 1
    fi

    local item_count
    item_count=$(echo "$items" | jq 'length')

    if [[ $item_count -eq 0 ]]; then
        log_info "Table is already empty, nothing to delete"
    else
        echo
        # Delete all items
        if ! delete_items "$table_name" "$items"; then
            log_error "Delete operation failed"
            exit 1
        fi
    fi

    echo

    # Verify cleanup
    if ! verify_cleanup "$table_name"; then
        log_error "Cleanup verification failed"
        exit 1
    fi

    echo

    # Verify table structure
    if ! verify_table_structure "$table_name"; then
        log_error "Table structure verification failed"
        exit 1
    fi

    echo
    log_success "=== Cleanup completed successfully ==="
    log_success "Removed $item_count items from $table_name"
    log_success "Table and GSI structure preserved"
    exit 0
}

# Run main function
main "$@"
