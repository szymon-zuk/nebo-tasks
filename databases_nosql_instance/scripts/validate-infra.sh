#!/usr/bin/env bash

################################################################################
# validate-infra.sh - End-to-End DynamoDB Infrastructure Validation
#
# Purpose: Automated validation that orchestrates all operational scripts to
#          prove DynamoDB infrastructure is fully functional. Executes complete
#          workflow from data loading through cleanup, verifying table and GSI
#          status throughout.
#
# Usage:
#   cd databases_nosql_instance
#   ./scripts/validate-infra.sh                    # Read table name from terraform output
#   ./scripts/validate-infra.sh TABLE_NAME         # Provide table name directly
#
# Description:
#   Runs a complete end-to-end validation workflow:
#     1. Load sample data (13 products)
#     2. Execute CRUD operations
#     3. Test query patterns (primary key and GSI)
#     4. Cleanup all data
#     5. Verify zero items remain
#     6. Verify table and GSI remain ACTIVE
#
#   Script exits with status 0 on success, 1 on any failure.
#   All steps are fully automated (no interactive prompts).
#
# Requirements:
#   - terraform CLI (to read table name from outputs)
#   - aws CLI configured (profile from AWS_PROFILE, default softserve-lab)
#   - jq for JSON processing
#   - All operational scripts exist and are executable:
#     - scripts/load-sample-data.sh
#     - scripts/crud-operations.sh
#     - scripts/query-examples.sh
#     - scripts/cleanup-data.sh
#
# Exit Codes:
#   0 - All validation steps passed
#   1 - Validation failed (prerequisite missing, script failed, or verification failed)
#
# Integration:
#   Suitable for CI/CD pipelines, automated testing, and infrastructure validation.
#
# Example:
#   ./scripts/validate-infra.sh
#   echo "Validation status: $?"
#
################################################################################

set -euo pipefail

# Configuration
readonly PROFILE="${AWS_PROFILE:-softserve-lab}"
readonly REGION="eu-central-1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $*"
}

print_separator() {
    echo "============================================================"
}

################################################################################
# Prerequisite Checks
################################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_deps=()

    # Check for required CLI tools
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi

    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Install missing tools and try again"
        exit 1
    fi

    # Check for required scripts
    local required_scripts=(
        "load-sample-data.sh"
        "crud-operations.sh"
        "query-examples.sh"
        "cleanup-data.sh"
    )

    local missing_scripts=()

    for script in "${required_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ ! -f "$script_path" ]]; then
            missing_scripts+=("$script")
        elif [[ ! -x "$script_path" ]]; then
            log_error "Script exists but is not executable: $script"
            log_error "Run: chmod +x $script_path"
            exit 1
        fi
    done

    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing required scripts: ${missing_scripts[*]}"
        log_error "Scripts must be in: $SCRIPT_DIR"
        exit 1
    fi

    log_success "All prerequisites satisfied"
    echo
}

################################################################################
# Table Name Resolution
################################################################################

get_table_name() {
    if [[ $# -gt 0 ]]; then
        echo "$1"
    else
        log_info "Reading table name from terraform output..." >&2
        cd "$PROJECT_DIR" || exit 1

        local table_name
        table_name=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")

        if [[ -z "$table_name" ]]; then
            log_error "Cannot determine table name"
            log_error "Run from databases_nosql_instance directory or provide table name as argument"
            log_error "Usage: $0 [TABLE_NAME]"
            exit 1
        fi

        echo "$table_name"
    fi
}

################################################################################
# Workflow Orchestration
################################################################################

step_load_sample_data() {
    local table_name="$1"

    print_separator
    log_step "Step 1/6: Loading sample data..."
    print_separator
    echo

    if ! "$SCRIPT_DIR/load-sample-data.sh" "$table_name"; then
        log_error "Failed to load sample data"
        exit 1
    fi

    echo
    log_success "Step 1/6 completed: Sample data loaded successfully"
    echo
}

step_crud_operations() {
    local table_name="$1"

    print_separator
    log_step "Step 2/6: Testing CRUD operations..."
    print_separator
    echo

    if ! "$SCRIPT_DIR/crud-operations.sh" "$table_name"; then
        log_error "Failed to execute CRUD operations"
        exit 1
    fi

    echo
    log_success "Step 2/6 completed: CRUD operations verified"
    echo
}

step_query_patterns() {
    local table_name="$1"

    print_separator
    log_step "Step 3/6: Testing query patterns and GSI..."
    print_separator
    echo

    if ! "$SCRIPT_DIR/query-examples.sh" "$table_name"; then
        log_error "Failed to execute query patterns"
        exit 1
    fi

    echo
    log_success "Step 3/6 completed: Query patterns tested successfully"
    echo
}

step_cleanup_data() {
    local table_name="$1"

    print_separator
    log_step "Step 4/6: Cleaning up test data..."
    print_separator
    echo

    log_info "Running cleanup with --force flag (non-interactive)..."

    if ! "$SCRIPT_DIR/cleanup-data.sh" "$table_name" --force; then
        log_error "Failed to cleanup data"
        exit 1
    fi

    echo
    log_success "Step 4/6 completed: Test data cleaned up"
    echo
}

step_verify_zero_items() {
    local table_name="$1"

    print_separator
    log_step "Step 5/6: Verifying table is empty..."
    print_separator
    echo

    log_info "Scanning table to verify item count is zero..."

    local scan_result
    scan_result=$(aws dynamodb scan \
        --table-name "$table_name" \
        --select COUNT \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json 2>&1)

    if [[ $? -ne 0 ]]; then
        log_error "Failed to scan table: $scan_result"
        exit 1
    fi

    local item_count
    item_count=$(echo "$scan_result" | jq -r '.Count')

    log_info "Item count: $item_count"

    if [[ "$item_count" -ne 0 ]]; then
        log_error "Verification failed: Expected 0 items but found $item_count"
        exit 1
    fi

    log_success "Verification passed: Table is empty (0 items)"
    echo
    log_success "Step 5/6 completed: Zero items confirmed"
    echo
}

step_verify_infrastructure() {
    local table_name="$1"

    print_separator
    log_step "Step 6/6: Verifying table and GSI status..."
    print_separator
    echo

    log_info "Describing table to verify infrastructure status..."

    local describe_result
    describe_result=$(aws dynamodb describe-table \
        --table-name "$table_name" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json 2>&1)

    if [[ $? -ne 0 ]]; then
        log_error "Failed to describe table: $describe_result"
        exit 1
    fi

    # Extract table status
    local table_status
    table_status=$(echo "$describe_result" | jq -r '.Table.TableStatus')

    log_info "Table status: $table_status"

    if [[ "$table_status" != "ACTIVE" ]]; then
        log_error "Table status is not ACTIVE: $table_status"
        exit 1
    fi

    log_success "Table is ACTIVE"

    # Extract GSI status
    local gsi_status
    gsi_status=$(echo "$describe_result" | jq -r '.Table.GlobalSecondaryIndexes[0].IndexStatus // "N/A"')

    log_info "GSI status: $gsi_status"

    if [[ "$gsi_status" == "N/A" ]]; then
        log_warning "No GSI found on table"
    elif [[ "$gsi_status" != "ACTIVE" ]]; then
        log_error "GSI status is not ACTIVE: $gsi_status"
        exit 1
    else
        log_success "GSI is ACTIVE"
    fi

    echo
    log_success "Step 6/6 completed: Infrastructure status verified"
    echo
}

################################################################################
# Main Execution
################################################################################

main() {
    echo
    print_separator
    echo "  DynamoDB Infrastructure Validation"
    echo "  End-to-End Automated Testing"
    print_separator
    echo

    # Check prerequisites
    check_prerequisites

    # Get table name
    local table_name
    table_name=$(get_table_name "$@")
    log_info "Target table: $table_name"
    echo

    # Execute validation workflow
    step_load_sample_data "$table_name"
    step_crud_operations "$table_name"
    step_query_patterns "$table_name"
    step_cleanup_data "$table_name"
    step_verify_zero_items "$table_name"
    step_verify_infrastructure "$table_name"

    # Final success report
    print_separator
    log_success "✓ VALIDATION SUCCESSFUL - All infrastructure tests passed"
    print_separator
    echo
    echo "Validation Summary:"
    echo "  ✓ Sample data loaded and cleaned"
    echo "  ✓ CRUD operations verified (Create, Read, Update, Delete)"
    echo "  ✓ Query patterns tested (primary key and GSI)"
    echo "  ✓ Table and GSI remain ACTIVE"
    echo "  ✓ Zero items remain after cleanup"
    echo
    log_success "Infrastructure is fully functional and ready for use"
    echo
    print_separator

    exit 0
}

# Run main function
main "$@"
