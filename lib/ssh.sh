#!/usr/bin/env bash
#==============================================================================
# SSH.SH - SSH deployment operations
#==============================================================================

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

#------------------------------------------------------------------------------
# Execute command on remote server
#------------------------------------------------------------------------------
ssh_exec() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local command="$4"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    ssh -i "$ssh_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        "${remote_user}@${remote_host}" "$command"
}

#------------------------------------------------------------------------------
# Deploy service via docker-compose
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Deploy service via SSH (delegates to Compose or Swarm)
#------------------------------------------------------------------------------
ssh_deploy() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local remote_compose_dir="${3:-${REMOTE_COMPOSE_DIR:-}}"
    local ssh_key="${4:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local image_name="$5"
    local tag="$6"
    local service_name="$7"
    local container_name="$8"
    local orchestrator="${9:-${ORCHESTRATOR:-compose}}"
    local stack_name="${10:-${STACK_NAME:-shipctl}}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    if [[ "$orchestrator" == "swarm" ]]; then
        ssh_deploy_swarm "$remote_host" "$remote_user" "$remote_compose_dir" "$ssh_key" \
                        "$image_name" "$tag" "$service_name" "$stack_name"
    else
        ssh_deploy_compose "$remote_host" "$remote_user" "$remote_compose_dir" "$ssh_key" \
                          "$image_name" "$tag" "$service_name" "$container_name"
    fi
}

#------------------------------------------------------------------------------
# Deploy service via docker-compose (SSH)
#------------------------------------------------------------------------------
ssh_deploy_compose() {
    local remote_host="$1"
    local remote_user="$2"
    local remote_compose_dir="$3"
    local ssh_key="$4"
    local image_name="$5"
    local tag="$6"
    local service_name="$7"
    local container_name="$8"
    
    log_info "Deploying to ${remote_host} (Compose)..."
    
    local deploy_script="
set -euo pipefail

cd '${remote_compose_dir}'

# Update image tag in docker-compose.yaml
if [[ -f docker-compose.yaml ]]; then
    sed -i 's|image: ${image_name}:.*|image: ${image_name}:${tag}|' docker-compose.yaml
elif [[ -f docker-compose.yml ]]; then
    sed -i 's|image: ${image_name}:.*|image: ${image_name}:${tag}|' docker-compose.yml
fi

# Pull and recreate
docker compose pull ${service_name}
docker compose up -d --no-deps --force-recreate ${service_name}

# Show status
echo '=== Container Status ==='
docker ps --filter 'name=${container_name}' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ''
echo '=== Recent Logs ==='
docker logs --tail=50 ${container_name} 2>&1 || true
"
    
    if ssh -i "$ssh_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
           "${remote_user}@${remote_host}" "$deploy_script"; then
        log_success "Deployment completed successfully"
        return 0
    else
        log_error "Deployment failed"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Deploy service via Docker Swarm (SSH)
#------------------------------------------------------------------------------
ssh_deploy_swarm() {
    local remote_host="$1"
    local remote_user="$2"
    local remote_compose_dir="$3"
    local ssh_key="$4"
    local image_name="$5"
    local tag="$6"
    local service_name="$7"
    local stack_name="$8"
    
    log_info "Deploying to ${remote_host} (Swarm: ${stack_name})..."
    
    local deploy_script="
set -euo pipefail

# Check if service exists for update
full_service_name=\"${stack_name}_${service_name}\"

if docker service ls --format '{{.Name}}' | grep -q \"^\${full_service_name}$\"; then
    echo \"Updating existing service: \${full_service_name}\"
    docker service update --image \"${image_name}:${tag}\" --force \"\${full_service_name}\"
else
    # Deploy stack
    echo \"Deploying stack: ${stack_name}\"
    
    cd '${remote_compose_dir}'
    
    # Update image tag
    export IMAGE_TAG=\"${tag}\"
    
    if [[ -f docker-compose.yaml ]]; then
        sed -i 's|image: ${image_name}:.*|image: ${image_name}:${tag}|' docker-compose.yaml
    elif [[ -f docker-compose.yml ]]; then
        sed -i 's|image: ${image_name}:.*|image: ${image_name}:${tag}|' docker-compose.yml
    fi
    
    docker stack deploy --compose-file docker-compose.yaml --with-registry-auth \"${stack_name}\"
fi

echo \"Waiting for service...\"
sleep 5
docker service ps \"\${full_service_name}\" --no-trunc
"
    
    if ssh -i "$ssh_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
           "${remote_user}@${remote_host}" "$deploy_script"; then
        log_success "Swarm deployment initiated successfully"
        return 0
    else
        log_error "Swarm deployment failed"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Rollback to previous version
#------------------------------------------------------------------------------
ssh_rollback() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local remote_compose_dir="${3:-${REMOTE_COMPOSE_DIR:-}}"
    local ssh_key="${4:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local image_name="$5"
    local rollback_tag="$6"
    local service_name="$7"
    local container_name="$8"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    log_info "Rolling back to ${image_name}:${rollback_tag}..."
    
    local rollback_script="
set -euo pipefail

cd '${remote_compose_dir}'

# Update image tag in docker-compose.yaml
if [[ -f docker-compose.yaml ]]; then
    sed -i 's|image: ${image_name}:.*|image: ${image_name}:${rollback_tag}|' docker-compose.yaml
elif [[ -f docker-compose.yml ]]; then
    sed -i 's|image: ${image_name}:.*|image: ${image_name}:${rollback_tag}|' docker-compose.yml
fi

# Pull and recreate
docker compose pull ${service_name}
docker compose up -d --no-deps --force-recreate ${service_name}

# Show status
docker ps --filter 'name=${container_name}'
"
    
    if ssh -i "$ssh_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
           "${remote_user}@${remote_host}" "$rollback_script"; then
        log_success "Rollback completed successfully"
        return 0
    else
        log_error "Rollback failed"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Health check via HTTP
#------------------------------------------------------------------------------
ssh_health_check_http() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local health_port="$4"
    local health_path="${5:-/health}"
    local timeout="${6:-30}"
    local container_name="${7:-}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    log_info "Waiting for service to be healthy..."
    
    local check_script="
for i in \$(seq 1 ${timeout}); do
    if curl -sf 'http://localhost:${health_port}${health_path}' > /dev/null 2>&1; then
        echo 'OK'
        exit 0
    fi
    sleep 1
done
echo 'TIMEOUT'
exit 1
"
    
    local result
    result=$(ssh -i "$ssh_key" -o BatchMode=yes "${remote_user}@${remote_host}" "$check_script" 2>/dev/null)
    
    if [[ "$result" == "OK" ]]; then
        log_success "Service is healthy (HTTP ${health_port}${health_path})"
        return 0
    else
        log_error "Health check failed after ${timeout}s"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Health check via TCP port
#------------------------------------------------------------------------------
ssh_health_check_tcp() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local health_port="$4"
    local timeout="${5:-30}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    log_info "Checking if port ${health_port} is listening..."
    
    local check_script="
for i in \$(seq 1 ${timeout}); do
    if nc -z localhost ${health_port} 2>/dev/null || ss -ln | grep -q ':${health_port} '; then
        echo 'OK'
        exit 0
    fi
    sleep 1
done
echo 'TIMEOUT'
exit 1
"
    
    local result
    result=$(ssh -i "$ssh_key" -o BatchMode=yes "${remote_user}@${remote_host}" "$check_script" 2>/dev/null)
    
    if [[ "$result" == "OK" ]]; then
        log_success "Service is listening on port ${health_port}"
        return 0
    else
        log_error "Health check failed: port ${health_port} not listening"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Get container logs
#------------------------------------------------------------------------------
ssh_get_logs() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local container_name="$4"
    local lines="${5:-100}"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    ssh -i "$ssh_key" -o BatchMode=yes "${remote_user}@${remote_host}" \
        "docker logs --tail=${lines} ${container_name} 2>&1"
}

#------------------------------------------------------------------------------
# Get current running image tag
#------------------------------------------------------------------------------
ssh_get_current_tag() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_user="${2:-${REMOTE_USER:-}}"
    local ssh_key="${3:-${SSH_KEY:-${HOME}/.ssh/id_rsa}}"
    local container_name="$4"
    
    # Expand ~ if present
    ssh_key="${ssh_key/#\~/$HOME}"
    
    ssh -i "$ssh_key" -o BatchMode=yes "${remote_user}@${remote_host}" \
        "docker inspect --format='{{.Config.Image}}' ${container_name} 2>/dev/null | cut -d: -f2" 2>/dev/null
}

#------------------------------------------------------------------------------
# Dry-run: Show what would be executed
#------------------------------------------------------------------------------
ssh_deploy_dry_run() {
    local remote_host="${1:-${REMOTE_HOST:-}}"
    local remote_compose_dir="${2:-${REMOTE_COMPOSE_DIR:-}}"
    local image_name="$3"
    local tag="$4"
    local service_name="$5"
    local local_mode="${6:-false}"
    
    echo ""
    if [[ "$local_mode" == "true" ]]; then
        log_dry "LOCAL MODE (no SSH)"
        log_dry "  cd ${remote_compose_dir}"
    else
        log_dry "ssh ${remote_host}"
        log_dry "  cd ${remote_compose_dir}"
    fi
    log_dry "  sed -i 's|image: ${image_name}:.*|image: ${image_name}:${tag}|' docker-compose.yaml"
    log_dry "  docker compose pull ${service_name}"
    log_dry "  docker compose up -d --no-deps --force-recreate ${service_name}"
}

#==============================================================================
# LOCAL DEPLOYMENT FUNCTIONS (no SSH required)
#==============================================================================

#------------------------------------------------------------------------------
# Deploy service locally (for running on the server itself)
#------------------------------------------------------------------------------
local_deploy() {
    local compose_dir="${1:-${REMOTE_COMPOSE_DIR:-}}"
    local image_name="$2"
    local tag="$3"
    local service_name="$4"
    local container_name="$5"
    
    log_info "Deploying locally in ${compose_dir}..."
    
    if [[ ! -d "$compose_dir" ]]; then
        log_error "Compose directory not found: $compose_dir"
        return 1
    fi
    
    cd "$compose_dir" || return 1
    
    # Update image tag in docker-compose.yaml
    if [[ -f docker-compose.yaml ]]; then
        sed -i "s|image: ${image_name}:.*|image: ${image_name}:${tag}|" docker-compose.yaml
    elif [[ -f docker-compose.yml ]]; then
        sed -i "s|image: ${image_name}:.*|image: ${image_name}:${tag}|" docker-compose.yml
    else
        log_error "No docker-compose.yaml or docker-compose.yml found in ${compose_dir}"
        return 1
    fi
    
    # Pull and recreate
    if ! docker compose pull "$service_name"; then
        log_error "Docker pull failed"
        return 1
    fi
    
    if ! docker compose up -d --no-deps --force-recreate "$service_name"; then
        log_error "Docker compose up failed"
        return 1
    fi
    
    # Show status
    echo ""
    log_info "Container Status:"
    docker ps --filter "name=${container_name}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    
    echo ""
    log_info "Recent Logs:"
    docker logs --tail=50 "$container_name" 2>&1 || true
    
    log_success "Local deployment completed successfully"
    return 0
}

#------------------------------------------------------------------------------
# Local rollback
#------------------------------------------------------------------------------
local_rollback() {
    local compose_dir="${1:-${REMOTE_COMPOSE_DIR:-}}"
    local image_name="$2"
    local rollback_tag="$3"
    local service_name="$4"
    local container_name="$5"
    
    log_info "Rolling back locally to ${image_name}:${rollback_tag}..."
    
    cd "$compose_dir" || return 1
    
    # Update image tag
    if [[ -f docker-compose.yaml ]]; then
        sed -i "s|image: ${image_name}:.*|image: ${image_name}:${rollback_tag}|" docker-compose.yaml
    elif [[ -f docker-compose.yml ]]; then
        sed -i "s|image: ${image_name}:.*|image: ${image_name}:${rollback_tag}|" docker-compose.yml
    fi
    
    docker compose pull "$service_name"
    docker compose up -d --no-deps --force-recreate "$service_name"
    
    docker ps --filter "name=${container_name}"
    
    log_success "Local rollback completed successfully"
    return 0
}

#------------------------------------------------------------------------------
# Local health check HTTP
#------------------------------------------------------------------------------
local_health_check_http() {
    local health_port="$1"
    local health_path="${2:-/health}"
    local timeout="${3:-30}"
    
    log_info "Waiting for service to be healthy..."
    
    for ((i=1; i<=timeout; i++)); do
        if curl -sf "http://localhost:${health_port}${health_path}" > /dev/null 2>&1; then
            log_success "Service is healthy (HTTP ${health_port}${health_path})"
            return 0
        fi
        sleep 1
    done
    
    log_error "Health check failed after ${timeout}s"
    return 1
}

#------------------------------------------------------------------------------
# Local health check TCP
#------------------------------------------------------------------------------
local_health_check_tcp() {
    local health_port="$1"
    local timeout="${2:-30}"
    
    log_info "Checking if port ${health_port} is listening..."
    
    for ((i=1; i<=timeout; i++)); do
        if nc -z localhost "$health_port" 2>/dev/null || ss -ln | grep -q ":${health_port} "; then
            log_success "Service is listening on port ${health_port}"
            return 0
        fi
        sleep 1
    done
    
    log_error "Health check failed: port ${health_port} not listening"
    return 1
}

#------------------------------------------------------------------------------
# Get current running image tag locally
#------------------------------------------------------------------------------
local_get_current_tag() {
    local container_name="$1"
    
    docker inspect --format='{{.Config.Image}}' "$container_name" 2>/dev/null | cut -d: -f2
}
