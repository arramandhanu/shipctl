#!/usr/bin/env bash
#==============================================================================
# RETRY.SH - Retry and timeout utilities
#
# Provides retry logic with exponential backoff and configurable timeouts
# for unreliable operations (network, SSH, Docker push).
#
# Author: shipctl
# License: MIT
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

# Default retry configuration
RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"
RETRY_BACKOFF="${RETRY_BACKOFF:-2}"
RETRY_MAX_DELAY="${RETRY_MAX_DELAY:-60}"

# Default timeout configuration
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-10}"
SSH_COMMAND_TIMEOUT="${SSH_COMMAND_TIMEOUT:-300}"
DOCKER_BUILD_TIMEOUT="${DOCKER_BUILD_TIMEOUT:-600}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-60}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}"

#------------------------------------------------------------------------------
# Retry a command with exponential backoff
#
# Usage: retry [options] -- command [args...]
#   --attempts N     Max attempts (default: 3)
#   --delay N        Initial delay in seconds (default: 5)
#   --backoff N      Backoff multiplier (default: 2)
#   --max-delay N    Maximum delay between retries (default: 60)
#   --on-retry CMD   Command to run before each retry
#------------------------------------------------------------------------------
retry() {
    local max_attempts="$RETRY_MAX_ATTEMPTS"
    local delay="$RETRY_DELAY"
    local backoff="$RETRY_BACKOFF"
    local max_delay="$RETRY_MAX_DELAY"
    local on_retry=""
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --attempts)  max_attempts="$2"; shift 2 ;;
            --delay)     delay="$2"; shift 2 ;;
            --backoff)   backoff="$2"; shift 2 ;;
            --max-delay) max_delay="$2"; shift 2 ;;
            --on-retry)  on_retry="$2"; shift 2 ;;
            --)          shift; break ;;
            *)           break ;;
        esac
    done
    
    local attempt=1
    local current_delay="$delay"
    
    while [[ $attempt -le $max_attempts ]]; do
        # Run the command and capture exit code
        local exit_code=0
        "$@" || exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Command failed after ${max_attempts} attempts: $*"
            return $exit_code
        fi
        
        log_warn "Attempt ${attempt}/${max_attempts} failed (exit: ${exit_code}). Retrying in ${current_delay}s..."
        
        # Run on-retry hook if set
        if [[ -n "$on_retry" ]]; then
            eval "$on_retry"
        fi
        
        sleep "$current_delay"
        
        # Calculate next delay with backoff (capped at max)
        current_delay=$((current_delay * backoff))
        if [[ $current_delay -gt $max_delay ]]; then
            current_delay=$max_delay
        fi
        
        ((attempt++))
    done
    
    return 1
}

#------------------------------------------------------------------------------
# Run a command with a timeout
#
# Usage: with_timeout <seconds> <command> [args...]
#------------------------------------------------------------------------------
with_timeout() {
    local timeout_secs="$1"
    shift
    
    if command -v timeout &>/dev/null; then
        # GNU coreutils timeout
        timeout "$timeout_secs" "$@"
    elif command -v gtimeout &>/dev/null; then
        # macOS with coreutils installed
        gtimeout "$timeout_secs" "$@"
    else
        # Fallback: background process with kill
        "$@" &
        local pid=$!
        
        (
            sleep "$timeout_secs"
            kill -TERM "$pid" 2>/dev/null
        ) &
        local watchdog=$!
        
        wait "$pid"
        local exit_code=$?
        
        kill "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null
        
        return $exit_code
    fi
}

#------------------------------------------------------------------------------
# Retry Docker push with exponential backoff
#------------------------------------------------------------------------------
retry_docker_push() {
    local image="$1"
    local tag="$2"
    
    retry --attempts 3 --delay 5 --backoff 2 -- \
        docker push "${image}:${tag}"
}

#------------------------------------------------------------------------------
# SSH exec with timeout
#------------------------------------------------------------------------------
ssh_with_timeout() {
    local host="$1"
    local user="$2"
    local key="$3"
    shift 3
    
    ssh -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        -o StrictHostKeyChecking=accept-new \
        -i "$key" \
        "${user}@${host}" \
        "$@"
}

#------------------------------------------------------------------------------
# Health check with retry
#------------------------------------------------------------------------------
wait_for_healthy() {
    local check_type="$1"    # http or tcp
    local target="$2"        # URL or host:port
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"
    local interval="${4:-$HEALTH_CHECK_INTERVAL}"
    
    local elapsed=0
    
    log_info "Waiting for service to be healthy (timeout: ${timeout}s)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        case "$check_type" in
            http)
                if curl -sf -o /dev/null --connect-timeout 5 "$target" 2>/dev/null; then
                    log_success "Health check passed: $target"
                    return 0
                fi
                ;;
            tcp)
                local host="${target%%:*}"
                local port="${target##*:}"
                if (echo > "/dev/tcp/${host}/${port}") 2>/dev/null; then
                    log_success "Health check passed: $target"
                    return 0
                fi
                ;;
        esac
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    log_error "Health check timed out after ${timeout}s: $target"
    return 1
}
