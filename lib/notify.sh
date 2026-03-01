#!/usr/bin/env bash
#==============================================================================
# NOTIFY.SH - Deployment notification module
#
# Sends deployment status notifications to various channels:
#   - Slack (webhook)
#   - Discord (webhook)
#   - Custom HTTP webhook
#   - Microsoft Teams (webhook)
#
# Configuration via environment variables:
#   NOTIFY_SLACK_WEBHOOK    - Slack incoming webhook URL
#   NOTIFY_DISCORD_WEBHOOK  - Discord webhook URL
#   NOTIFY_TEAMS_WEBHOOK    - Teams incoming webhook URL
#   NOTIFY_WEBHOOK_URL      - Custom webhook URL
#   NOTIFY_ON_SUCCESS       - Send on success (default: true)
#   NOTIFY_ON_FAILURE       - Send on failure (default: true)
#
# Author: shipctl
# License: MIT
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

# Notification configuration
NOTIFY_SLACK_WEBHOOK="${NOTIFY_SLACK_WEBHOOK:-}"
NOTIFY_DISCORD_WEBHOOK="${NOTIFY_DISCORD_WEBHOOK:-}"
NOTIFY_TEAMS_WEBHOOK="${NOTIFY_TEAMS_WEBHOOK:-}"
NOTIFY_WEBHOOK_URL="${NOTIFY_WEBHOOK_URL:-}"
NOTIFY_ON_SUCCESS="${NOTIFY_ON_SUCCESS:-true}"
NOTIFY_ON_FAILURE="${NOTIFY_ON_FAILURE:-true}"

#------------------------------------------------------------------------------
# Check if notifications are configured
#------------------------------------------------------------------------------
notify_is_configured() {
    [[ -n "$NOTIFY_SLACK_WEBHOOK" ]] || \
    [[ -n "$NOTIFY_DISCORD_WEBHOOK" ]] || \
    [[ -n "$NOTIFY_TEAMS_WEBHOOK" ]] || \
    [[ -n "$NOTIFY_WEBHOOK_URL" ]]
}

#------------------------------------------------------------------------------
# Build deployment summary message
#------------------------------------------------------------------------------
notify_build_message() {
    local service="$1"
    local status="$2"       # success | failure
    local environment="$3"
    local image_tag="${4:-}"
    local duration="${5:-}"
    local error_msg="${6:-}"
    
    local emoji="✅"
    local status_text="Success"
    if [[ "$status" == "failure" ]]; then
        emoji="❌"
        status_text="Failed"
    fi
    
    local msg="${emoji} *Deploy ${status_text}*: \`${service}\`"
    msg+="\n• Environment: \`${environment}\`"
    
    if [[ -n "$image_tag" ]]; then
        msg+="\n• Image Tag: \`${image_tag}\`"
    fi
    
    if [[ -n "$duration" ]]; then
        msg+="\n• Duration: ${duration}"
    fi
    
    # Add git info if available
    if command -v git &>/dev/null; then
        local git_branch git_commit
        git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        msg+="\n• Branch: \`${git_branch}\` (\`${git_commit}\`)"
    fi
    
    if [[ -n "$error_msg" ]]; then
        msg+="\n• Error: ${error_msg}"
    fi
    
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    msg+="\n• Host: \`${hostname}\`"
    msg+="\n• Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    echo -e "$msg"
}

#------------------------------------------------------------------------------
# Send Slack notification
#------------------------------------------------------------------------------
notify_slack() {
    local message="$1"
    local webhook="$NOTIFY_SLACK_WEBHOOK"
    
    if [[ -z "$webhook" ]]; then
        return 0
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "text": "${message//\"/\\\"}"
}
EOF
)
    
    if curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook" &>/dev/null; then
        log_info "Slack notification sent"
    else
        log_warn "Failed to send Slack notification"
    fi
}

#------------------------------------------------------------------------------
# Send Discord notification
#------------------------------------------------------------------------------
notify_discord() {
    local message="$1"
    local webhook="$NOTIFY_DISCORD_WEBHOOK"
    
    if [[ -z "$webhook" ]]; then
        return 0
    fi
    
    # Discord uses "content" instead of "text"
    local payload
    payload=$(cat <<EOF
{
    "content": "${message//\"/\\\"}"
}
EOF
)
    
    if curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook" &>/dev/null; then
        log_info "Discord notification sent"
    else
        log_warn "Failed to send Discord notification"
    fi
}

#------------------------------------------------------------------------------
# Send Microsoft Teams notification
#------------------------------------------------------------------------------
notify_teams() {
    local message="$1"
    local webhook="$NOTIFY_TEAMS_WEBHOOK"
    
    if [[ -z "$webhook" ]]; then
        return 0
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "text": "${message//\"/\\\"}"
}
EOF
)
    
    if curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook" &>/dev/null; then
        log_info "Teams notification sent"
    else
        log_warn "Failed to send Teams notification"
    fi
}

#------------------------------------------------------------------------------
# Send custom webhook notification
#------------------------------------------------------------------------------
notify_webhook() {
    local message="$1"
    local webhook="$NOTIFY_WEBHOOK_URL"
    
    if [[ -z "$webhook" ]]; then
        return 0
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "text": "${message//\"/\\\"}",
    "source": "shipctl",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    if curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook" &>/dev/null; then
        log_info "Webhook notification sent"
    else
        log_warn "Failed to send webhook notification"
    fi
}

#------------------------------------------------------------------------------
# Send deployment notification to all configured channels
#
# Usage: notify_deploy <service> <status> <environment> [image_tag] [duration] [error]
#------------------------------------------------------------------------------
notify_deploy() {
    local service="$1"
    local status="$2"
    local environment="$3"
    local image_tag="${4:-}"
    local duration="${5:-}"
    local error_msg="${6:-}"
    
    # Check if we should send based on status
    if [[ "$status" == "success" && "$NOTIFY_ON_SUCCESS" != "true" ]]; then
        return 0
    fi
    if [[ "$status" == "failure" && "$NOTIFY_ON_FAILURE" != "true" ]]; then
        return 0
    fi
    
    if ! notify_is_configured; then
        return 0
    fi
    
    local message
    message=$(notify_build_message "$service" "$status" "$environment" "$image_tag" "$duration" "$error_msg")
    
    # Send to all configured channels
    notify_slack "$message"
    notify_discord "$message"
    notify_teams "$message"
    notify_webhook "$message"
}
