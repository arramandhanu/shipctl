#!/usr/bin/env bash
#==============================================================================
# CHECKS.SH - Pre-flight check functions
#==============================================================================

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

#------------------------------------------------------------------------------
# Check: Git working directory is clean
#------------------------------------------------------------------------------
check_git_clean() {
    local target_dir="${1:-.}"
    
    if ! git -C "$target_dir" diff --quiet HEAD 2>/dev/null; then
        log_warn "Git working directory has uncommitted changes"
        return 1
    fi
    
    if [[ -n "$(git -C "$target_dir" status --porcelain 2>/dev/null)" ]]; then
        log_warn "Git working directory has untracked files"
        return 1
    fi
    
    log_success "Git working directory is clean"
    return 0
}

#------------------------------------------------------------------------------
# Check: Docker daemon is running
#------------------------------------------------------------------------------
check_docker_running() {
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    log_success "Docker daemon is running"
    return 0
}

#------------------------------------------------------------------------------
# Check: DockerHub credentials are valid
#------------------------------------------------------------------------------
check_docker_login() {
    local username="${DOCKERHUB_USERNAME:-}"
    local password="${DOCKERHUB_PASSWORD:-}"
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "DOCKERHUB_USERNAME or DOCKERHUB_PASSWORD not set"
        return 1
    fi
    
    if echo "$password" | docker login -u "$username" --password-stdin &>/dev/null; then
        log_success "DockerHub credentials validated"
        return 0
    else
        log_error "DockerHub login failed"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Check: SSH key exists and is readable
#------------------------------------------------------------------------------
check_ssh_key() {
    local ssh_key="${1:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    if [[ ! -f "$ssh_key" ]]; then
        log_error "SSH key not found: $ssh_key"
        return 1
    fi
    
    if [[ ! -r "$ssh_key" ]]; then
        log_error "SSH key not readable: $ssh_key"
        return 1
    fi
    
    log_success "SSH key found: $ssh_key"
    return 0
}

#------------------------------------------------------------------------------
# Check: SSH connection to remote server
#------------------------------------------------------------------------------
check_ssh_connection() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local timeout="${4:-10}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    if [[ -z "$remote_host" || -z "$remote_user" ]]; then
        log_error "REMOTE_HOST or REMOTE_USER not set"
        return 1
    fi
    
    if ssh -i "$ssh_key" -o ConnectTimeout="$timeout" -o BatchMode=yes \
           "${remote_user}@${remote_host}" "exit 0" 2>/dev/null; then
        log_success "Remote server is reachable: $remote_host"
        return 0
    else
        log_error "Cannot connect to remote server: $remote_host"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Check: Required environment variables are set
#------------------------------------------------------------------------------
check_env_vars() {
    local missing=()
    local required_vars=("$@")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing[*]}"
        return 1
    fi
    
    log_success "Required environment variables are set"
    return 0
}

#------------------------------------------------------------------------------
# Check: Dockerfile exists in target directory
#------------------------------------------------------------------------------
check_dockerfile() {
    local target_dir="${1:-.}"
    local dockerfile="${target_dir}/Dockerfile"
    
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile not found in: $target_dir"
        return 1
    fi
    
    log_success "Dockerfile found in: $target_dir"
    return 0
}

#------------------------------------------------------------------------------
# Check: Required commands exist
#------------------------------------------------------------------------------
check_commands() {
    local missing=()
    local required_cmds=("$@")
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi
    
    log_success "Required commands are available"
    return 0
}

#------------------------------------------------------------------------------
# Check: Remote docker-compose file exists
#------------------------------------------------------------------------------
check_remote_compose() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local remote_compose_dir="${3:-${REMOTE_COMPOSE_DIR:-}}"
    local ssh_key="${4:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    if ssh -i "$ssh_key" -o BatchMode=yes "${remote_user}@${remote_host}" \
           "test -f '${remote_compose_dir}/docker-compose.yaml' || test -f '${remote_compose_dir}/docker-compose.yml'" 2>/dev/null; then
        log_success "Remote docker-compose file exists"
        return 0
    else
        log_error "Remote docker-compose file not found in: $remote_compose_dir"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Check: Disk space on remote server
#------------------------------------------------------------------------------
check_remote_disk_space() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local min_space_mb="${4:-1024}"  # Default 1GB minimum
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    local available_kb
    available_kb=$(ssh -i "$ssh_key" -o BatchMode=yes "${remote_user}@${remote_host}" \
                   "df -k / | tail -1 | awk '{print \$4}'" 2>/dev/null)
    
    if [[ -z "$available_kb" ]]; then
        log_warn "Could not check remote disk space"
        return 0
    fi
    
    local available_mb=$((available_kb / 1024))
    
    if ((available_mb < min_space_mb)); then
        log_warn "Low disk space on remote: ${available_mb}MB available (min: ${min_space_mb}MB)"
        return 1
    fi
    
    log_success "Remote disk space OK: ${available_mb}MB available"
    return 0
}

#------------------------------------------------------------------------------
# Run all pre-flight checks
#------------------------------------------------------------------------------
run_preflight_checks() {
    local service_dir="${1:-.}"
    local skip_git="${2:-false}"
    local git_url="${3:-}"
    local failed=0
    
    print_section "PRE-FLIGHT CHECKS"
    
    # Required commands
    check_commands docker git ssh || ((failed++))
    
    # Docker
    check_docker_running || ((failed++))
    check_docker_login || ((failed++))
    
    # Git (optional - check working directory clean)
    if [[ "$skip_git" != "true" ]]; then
        check_git_clean "$service_dir" || true  # Warning only
    fi
    
    # Git URL validation (if using Git source)
    if [[ -n "$git_url" ]]; then
        check_git_url "$git_url" || ((failed++))
    fi
    
    # SSH checks (skip in LOCAL_MODE)
    if [[ "${LOCAL_MODE:-false}" != "true" ]]; then
        check_ssh_key || ((failed++))
        check_ssh_connection || ((failed++))
        check_remote_compose || ((failed++))
        check_remote_disk_space || true  # Warning only
    fi
    
    # Dockerfile check (only for folder mode, Git mode checks during prepare)
    if [[ -z "$git_url" ]]; then
        check_dockerfile "$service_dir" || ((failed++))
    fi
    
    echo ""
    
    if ((failed > 0)); then
        log_error "Pre-flight checks failed: $failed error(s)"
        return 1
    fi
    
    log_success "All pre-flight checks passed"
    return 0
}
