#!/bin/bash

# Automated Daily Resource Cleanup Script
# This script performs complete resource decommissioning at the end of each development day
# Designed to minimize Azure costs during non-development hours

# set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME=$(basename "$0")
LOG_DIR="$SCRIPT_DIR/logs"
CONFIG_FILE="$SCRIPT_DIR/daily-cleanup-config.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
ENABLED_ENVIRONMENTS=("dev" "sit")  # Only cleanup dev and sit environments
NOTIFICATION_EMAIL=""
SLACK_WEBHOOK=""
DRY_RUN=false
FORCE=false

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function

log() {
load_config() {
send_notification() {
should_cleanup_environment() {
get_resource_groups() {
cleanup_resource_group() {
perform_daily_cleanup() {
health_check() {
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -e|--environments)
                IFS=',' read -ra ENABLED_ENVIRONMENTS <<< "$2"
                shift 2
                ;;
            --email)
                NOTIFICATION_EMAIL="$2"
                shift 2
                ;;
            --slack)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            --health-check)
                health_check
                exit $?
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                SUBSCRIPTION_ID="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$SUBSCRIPTION_ID" ]]; then
        log "ERROR" "Subscription ID is required"
        usage
        exit 1
    fi
}
usage() {
    cat << EOF
Automated Daily Resource Cleanup Script

This script performs complete resource decommissioning for development environments
to minimize Azure costs during non-development hours.

USAGE:
    $SCRIPT_NAME [OPTIONS] <subscription-id>

OPTIONS:
    -c, --config FILE       Configuration file (default: daily-cleanup-config.yml)
    -d, --dry-run          Show what would be cleaned without actually doing it
    -f, --force           Skip confirmation prompts
    -e, --environments ENV Comma-separated list of environments to clean (default: dev,sit)
    --email EMAIL         Email address for notifications
    --slack WEBHOOK       Slack webhook URL for notifications
    --health-check        Run health check only
    -h, --help            Show this help message

CONFIGURATION FILE:
    Create a file named 'daily-cleanup-config.yml' with:
    enabledEnvironments: dev,sit
    notificationEmail: your-email@example.com
    slackWebhook: https://hooks.slack.com/...
    dryRun: false

EXAMPLES:
    # Run cleanup with default settings
    $SCRIPT_NAME 12345678-1234-1234-1234-123456789012

    # Dry run to see what would be cleaned
    $SCRIPT_NAME --dry-run 12345678-1234-1234-1234-123456789012

    # Clean only dev environment with notifications
    $SCRIPT_NAME --environments dev --email admin@example.com 12345678-1234-1234-1234-123456789012

SCHEDULING:
    # Add to crontab for daily execution at 6 PM
    0 18 * * 1-5 $SCRIPT_DIR/$SCRIPT_NAME 12345678-1234-1234-1234-123456789012

    # Or use systemd timer for more reliable scheduling
    log "INFO" "Performing health check"

    # Check Azure CLI
    if ! command -v az &>/dev/null; then
        log "ERROR" "Azure CLI not found"
        return 1
    fi

    # Check if logged in
    if ! az account show &>/dev/null; then
        log "ERROR" "Not logged in to Azure CLI"
        return 1
    fi

    # Check decommission script
    if [[ ! -f "$SCRIPT_DIR/decommission-resources.sh" ]]; then
        log "ERROR" "Decommission script not found"
        return 1
    fi

    log "INFO" "Health check passed"
    return 0
}
    local subscription_id=$1

    log "INFO" "Starting daily cleanup for subscription: $subscription_id"

    # Validate Azure CLI login
    if ! az account show &>/dev/null; then
        log "ERROR" "Not logged in to Azure CLI. Please run 'az login' first."
        return 1
    fi

    # Set subscription
    if ! az account set --subscription "$subscription_id" &>/dev/null; then
        log "ERROR" "Failed to set subscription: $subscription_id"
        return 1
    fi

    local total_cleaned=0
    local failed_cleanups=0
    local cleanup_report=""

    # Process each enabled environment
    for env in "${ENABLED_ENVIRONMENTS[@]}"; do
        log "INFO" "Processing environment: $env"

        # Get resource groups for this environment
        local resource_groups
        resource_groups=$(get_resource_groups "$subscription_id" "$env")

        if [[ -z "$resource_groups" ]]; then
            log "INFO" "No resource groups found for environment: $env"
            continue
        fi

        # Process each resource group
        while IFS= read -r rg; do
            if [[ -n "$rg" ]]; then
                if cleanup_resource_group "$subscription_id" "$rg" "$env"; then
                    ((total_cleaned++))
                    cleanup_report+="✅ $rg (cleaned successfully)\\n"
                else
                    ((failed_cleanups++))
                    cleanup_report+="❌ $rg (cleanup failed)\\n"
                fi
            fi
        done <<< "$resource_groups"
    done

    # Generate summary
    local summary="Daily Cleanup Summary\\n"
    summary+="Date: $(date)\\n"
    summary+="Subscription: $subscription_id\\n"
    summary+="Resource Groups Cleaned: $total_cleaned\\n"
    summary+="Failed Cleanups: $failed_cleanups\\n"
    summary+="\\nDetails:\\n$cleanup_report"

    if [[ $failed_cleanups -eq 0 ]]; then
        send_notification "✅ Daily Resource Cleanup Completed" "$summary"
    else
        send_notification "⚠️ Daily Resource Cleanup Completed with Issues" "$summary"
    fi

    log "INFO" "Daily cleanup completed. Cleaned: $total_cleaned, Failed: $failed_cleanups"
}
    local subscription_id=$1
    local resource_group=$2
    local environment=$3

    log "INFO" "Starting cleanup for resource group: $resource_group"

    # Determine environment from resource group name
    if [[ "$resource_group" == *"prod"* ]]; then
        log "WARN" "Skipping production resource group: $resource_group"
        return 0
    fi

    # Run the decommissioning script
    local decommission_script="$SCRIPT_DIR/decommission-resources.sh"

    if [[ ! -f "$decommission_script" ]]; then
        log "ERROR" "Decommission script not found: $decommission_script"
        return 1
    fi

    local cmd=("$decommission_script" "$subscription_id" "$resource_group" "$environment")

    if [[ "$DRY_RUN" == "true" ]]; then
        cmd+=("--dry-run")
        log "INFO" "Running in DRY RUN mode"
    fi

    if [[ "$FORCE" == "true" ]]; then
        cmd+=("--force")
    fi

    log "INFO" "Executing: ${cmd[*]}"

    if "${cmd[@]}"; then
        log "INFO" "Successfully cleaned up resource group: $resource_group"
        return 0
    else
        log "ERROR" "Failed to clean up resource group: $resource_group"
        return 1
    fi
}
    local subscription_id=$1
    local env=$2

    log "INFO" "Finding resource groups for environment: $env"

    # Get resource groups that match the environment pattern
    az group list \
        --subscription "$subscription_id" \
        --query "[?contains(name, '$env') && contains(name, 'gptdata')].name" \
        --output tsv 2>/dev/null || echo ""
}
    local env=$1
    for enabled_env in "${ENABLED_ENVIRONMENTS[@]}"; do
        if [[ "$env" == "$enabled_env" ]]; then
            return 0
        fi
    done
    return 1
}
    local subject=$1
    local message=$2

    log "INFO" "Sending notification: $subject"

    # Email notification
    if [[ -n "$NOTIFICATION_EMAIL" ]]; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL" 2>/dev/null || \
        log "WARN" "Failed to send email notification"
    fi

    # Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"$subject\\n$message\"}" \
             "$SLACK_WEBHOOK" 2>/dev/null || \
        log "WARN" "Failed to send Slack notification"
    fi
}
    if [[ -f "$CONFIG_FILE" ]]; then
        log "INFO" "Loading configuration from $CONFIG_FILE"
        # Simplified config loading for now
    else
        log "WARN" "Configuration file not found: $CONFIG_FILE. Using defaults."
    fi
}
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/daily-cleanup-$(date +%Y%m%d).log"

    echo "[$timestamp] [$level] $message" >> "$log_file"
    echo "[$timestamp] [$level] $message"

    # Also log to stdout with colors for console output
    case $level in
        "ERROR")   echo -e "${RED}[$timestamp] ERROR: $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}[$timestamp] WARNING: $message${NC}" ;;
        "INFO")    echo -e "${GREEN}[$timestamp] INFO: $message${NC}" ;;
        "DEBUG")   echo -e "${BLUE}[$timestamp] DEBUG: $message${NC}" ;;
    esac
}

main() {
    echo "Hello"
}

main "$@"

usage() {
    cat << 'END_OF_USAGE'
Automated Daily Resource Cleanup Script

This script performs complete resource decommissioning for development environments
to minimize Azure costs during non-development hours.

USAGE:
    $SCRIPT_NAME [OPTIONS] <subscription-id>

OPTIONS:
    -c, --config FILE       Configuration file (default: daily-cleanup-config.yml)
    -d, --dry-run          Show what would be cleaned without actually doing it
    -f, --force           Skip confirmation prompts
    -e, --environments ENV Comma-separated list of environments to clean (default: dev,sit)
    --email EMAIL         Email address for notifications
    --slack WEBHOOK       Slack webhook URL for notifications
    --health-check        Run health check only
    -h, --help            Show this help message

CONFIGURATION FILE:
    Create a file named 'daily-cleanup-config.yml' with:
    enabledEnvironments: dev,sit
    notificationEmail: your-email@example.com
    slackWebhook: https://hooks.slack.com/...
    dryRun: false

EXAMPLES:
    # Run cleanup with default settings
    $SCRIPT_NAME 12345678-1234-1234-1234-123456789012

    # Dry run to see what would be cleaned
    $SCRIPT_NAME --dry-run 12345678-1234-1234-1234-123456789012

    # Clean only dev environment with notifications
    $SCRIPT_NAME --environments dev --email admin@example.com 12345678-1234-1234-1234-123456789012

SCHEDULING:
    # Add to crontab for daily execution at 6 PM
    0 18 * * 1-5 $SCRIPT_DIR/$SCRIPT_NAME 12345678-1234-1234-1234-123456789012

    # Or use systemd timer for more reliable scheduling
END_OF_USAGE
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -e|--environments)
                ENABLED_ENVIRONMENTS="$2"
                shift 2
                ;;
            --email)
                NOTIFICATION_EMAIL="$2"
                shift 2
                ;;
            --slack)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            --health-check)
                health_check
                exit $?
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                SUBSCRIPTION_ID="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$SUBSCRIPTION_ID" ]]; then
        log "ERROR" "Subscription ID is required"
        usage
        exit 1
    fi
}

main() {
    log "INFO" "Starting Automated Daily Resource Cleanup Script v1.0"

    # Parse command line arguments
    parse_args "$@"

    # Load configuration
    load_config

    # Override config with command line options
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN MODE ENABLED - No resources will be deleted"
    fi

    # Perform cleanup
    if perform_daily_cleanup "$SUBSCRIPTION_ID"; then
        log "INFO" "Script completed successfully"
        exit 0
    else
        log "ERROR" "Script completed with errors"
        exit 1
    fi
}

main "$@"
