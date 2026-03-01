#!/usr/bin/env bash
#==============================================================================
# HISTORY.SH - Deployment history tracking
#
# Records deployment events to a local log file for audit trail and
# provides commands to view deployment history.
#
# Storage: ~/.shipctl/history.log (one JSON line per deployment)
#
# Author: shipctl
# License: MIT
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

# History configuration
HISTORY_DIR="${SHIPCTL_HISTORY_DIR:-${HOME}/.shipctl}"
HISTORY_FILE="${HISTORY_DIR}/history.log"
HISTORY_MAX_ENTRIES="${HISTORY_MAX_ENTRIES:-500}"

#------------------------------------------------------------------------------
# Initialize history directory
#------------------------------------------------------------------------------
history_init() {
    if [[ ! -d "$HISTORY_DIR" ]]; then
        mkdir -p "$HISTORY_DIR"
    fi
    if [[ ! -f "$HISTORY_FILE" ]]; then
        touch "$HISTORY_FILE"
    fi
}

#------------------------------------------------------------------------------
# Record a deployment event
#
# Usage: history_record <service> <status> <environment> [image_tag] [duration_secs]
#------------------------------------------------------------------------------
history_record() {
    local service="$1"
    local status="$2"         # success | failure | rollback
    local environment="$3"
    local image_tag="${4:-}"
    local duration="${5:-0}"
    
    history_init
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local git_branch="unknown"
    local git_commit="unknown"
    local git_author="unknown"
    if command -v git &>/dev/null; then
        git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        git_author=$(git config user.name 2>/dev/null || echo "unknown")
    fi
    
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    
    # Write JSON line
    printf '{"timestamp":"%s","service":"%s","status":"%s","environment":"%s","image_tag":"%s","duration":%s,"git_branch":"%s","git_commit":"%s","git_author":"%s","hostname":"%s"}\n' \
        "$timestamp" \
        "$service" \
        "$status" \
        "$environment" \
        "$image_tag" \
        "$duration" \
        "$git_branch" \
        "$git_commit" \
        "$git_author" \
        "$hostname" \
        >> "$HISTORY_FILE"
    
    # Rotate if exceeds max entries
    history_rotate
}

#------------------------------------------------------------------------------
# Rotate history file (keep latest N entries)
#------------------------------------------------------------------------------
history_rotate() {
    local line_count
    line_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
    
    if [[ $line_count -gt $HISTORY_MAX_ENTRIES ]]; then
        local keep=$((HISTORY_MAX_ENTRIES / 2))
        local temp_file="${HISTORY_FILE}.tmp"
        tail -n "$keep" "$HISTORY_FILE" > "$temp_file"
        mv "$temp_file" "$HISTORY_FILE"
        log_info "History rotated: kept last ${keep} entries"
    fi
}

#------------------------------------------------------------------------------
# Show deployment history
#
# Usage: history_show [options]
#   --service NAME     Filter by service
#   --env ENV          Filter by environment
#   --status STATUS    Filter by status
#   --last N           Show last N entries (default: 20)
#   --json             Output as raw JSON
#------------------------------------------------------------------------------
history_show() {
    local filter_service=""
    local filter_env=""
    local filter_status=""
    local last_n=20
    local raw_json=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --service)  filter_service="$2"; shift 2 ;;
            --env)      filter_env="$2"; shift 2 ;;
            --status)   filter_status="$2"; shift 2 ;;
            --last)     last_n="$2"; shift 2 ;;
            --json)     raw_json=true; shift ;;
            *)          shift ;;
        esac
    done
    
    history_init
    
    if [[ ! -s "$HISTORY_FILE" ]]; then
        echo "No deployment history found."
        return 0
    fi
    
    local entries
    entries=$(tail -n "$last_n" "$HISTORY_FILE")
    
    # Apply filters
    if [[ -n "$filter_service" ]]; then
        entries=$(echo "$entries" | grep "\"service\":\"${filter_service}\"" || true)
    fi
    if [[ -n "$filter_env" ]]; then
        entries=$(echo "$entries" | grep "\"environment\":\"${filter_env}\"" || true)
    fi
    if [[ -n "$filter_status" ]]; then
        entries=$(echo "$entries" | grep "\"status\":\"${filter_status}\"" || true)
    fi
    
    if [[ -z "$entries" ]]; then
        echo "No matching deployments found."
        return 0
    fi
    
    if [[ "$raw_json" == "true" ]]; then
        echo "$entries"
        return 0
    fi
    
    # Pretty print
    echo ""
    printf "%-20s %-15s %-10s %-12s %-12s %-10s\n" \
        "TIMESTAMP" "SERVICE" "STATUS" "ENVIRONMENT" "TAG" "DURATION"
    printf "%-20s %-15s %-10s %-12s %-12s %-10s\n" \
        "─────────────────" "──────────────" "─────────" "───────────" "───────────" "─────────"
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        
        # Parse JSON fields (simple grep-based, no jq dependency)
        local ts svc stat env tag dur
        ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        svc=$(echo "$line" | grep -o '"service":"[^"]*"' | cut -d'"' -f4)
        stat=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        env=$(echo "$line" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)
        tag=$(echo "$line" | grep -o '"image_tag":"[^"]*"' | cut -d'"' -f4)
        dur=$(echo "$line" | grep -o '"duration":[0-9]*' | cut -d: -f2)
        
        # Short timestamp
        local short_ts="${ts%T*} ${ts#*T}"
        short_ts="${short_ts%Z}"
        
        # Format duration
        local dur_fmt="${dur}s"
        if [[ "$dur" -gt 60 ]]; then
            dur_fmt="$((dur / 60))m $((dur % 60))s"
        fi
        
        # Color status
        local stat_colored
        case "$stat" in
            success)  stat_colored="\033[0;32m${stat}\033[0m" ;;
            failure)  stat_colored="\033[0;31m${stat}\033[0m" ;;
            rollback) stat_colored="\033[1;33m${stat}\033[0m" ;;
            *)        stat_colored="$stat" ;;
        esac
        
        printf "%-20s %-15s %-10b %-12s %-12s %-10s\n" \
            "$short_ts" "$svc" "$stat_colored" "$env" "${tag:-N/A}" "$dur_fmt"
    done <<< "$entries"
    
    echo ""
}

#------------------------------------------------------------------------------
# Get last deployment info for a service
#
# Usage: history_last <service> [environment]
# Returns: JSON line of last deployment, or empty
#------------------------------------------------------------------------------
history_last() {
    local service="$1"
    local environment="${2:-}"
    
    history_init
    
    if [[ ! -s "$HISTORY_FILE" ]]; then
        return 1
    fi
    
    local pattern="\"service\":\"${service}\""
    if [[ -n "$environment" ]]; then
        pattern+=".*\"environment\":\"${environment}\""
    fi
    
    grep "$pattern" "$HISTORY_FILE" | tail -1
}

#------------------------------------------------------------------------------
# Count deployments by service
#
# Usage: history_stats
#------------------------------------------------------------------------------
history_stats() {
    history_init
    
    if [[ ! -s "$HISTORY_FILE" ]]; then
        echo "No deployment history found."
        return 0
    fi
    
    echo ""
    echo "Deployment Statistics"
    echo "════════════════════════════════════════"
    
    local total
    total=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
    echo "  Total deployments: $total"
    
    local success fail
    success=$(grep -c '"status":"success"' "$HISTORY_FILE" || echo "0")
    fail=$(grep -c '"status":"failure"' "$HISTORY_FILE" || echo "0")
    
    echo -e "  Successful: \033[0;32m${success}\033[0m"
    echo -e "  Failed:     \033[0;31m${fail}\033[0m"
    
    if [[ $total -gt 0 ]]; then
        local rate=$(( (success * 100) / total ))
        echo "  Success rate: ${rate}%"
    fi
    
    echo ""
    echo "By Service:"
    echo "────────────────────────────────────────"
    
    # Get unique services and count
    grep -o '"service":"[^"]*"' "$HISTORY_FILE" | sort | uniq -c | sort -rn | while read -r count svc_json; do
        local svc_name
        svc_name=$(echo "$svc_json" | cut -d'"' -f4)
        printf "  %-20s %s deployments\n" "$svc_name" "$count"
    done
    
    echo ""
}

#------------------------------------------------------------------------------
# Clear deployment history
#------------------------------------------------------------------------------
history_clear() {
    history_init
    > "$HISTORY_FILE"
    log_info "Deployment history cleared"
}
