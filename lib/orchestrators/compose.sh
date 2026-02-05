#!/usr/bin/env bash
#==============================================================================
# Docker Compose Orchestrator
#
# Handles deployments using docker-compose or docker compose plugin.
# This is the default orchestrator for shipctl.
#
# Author: shipctl
# License: MIT
#==============================================================================

#------------------------------------------------------------------------------
# Get the docker-compose command (handles both v1 and v2)
#------------------------------------------------------------------------------
get_compose_cmd() {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null 2>&1; then
        echo "docker compose"
    else
        echo ""
    fi
}

#------------------------------------------------------------------------------
# Deploy service using docker-compose
#------------------------------------------------------------------------------
compose_deploy() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local compose_file="$4"
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    if [[ -z "$compose_cmd" ]]; then
        log_error "docker-compose is not available"
        return 1
    fi
    
    log_info "Pulling latest image: ${image}:${tag}"
    docker pull "${image}:${tag}" || {
        log_error "Failed to pull image"
        return 1
    }
    
    log_info "Deploying ${service_name} via docker-compose"
    
    # Use environment variable for image tag
    export IMAGE_TAG="$tag"
    
    if [[ -f "$compose_file" ]]; then
        $compose_cmd -f "$compose_file" up -d --no-deps --force-recreate "$service_name" || {
            log_error "docker-compose deployment failed"
            return 1
        }
    else
        log_error "Compose file not found: $compose_file"
        return 1
    fi
    
    log_success "Service ${service_name} deployed successfully"
    return 0
}

#------------------------------------------------------------------------------
# Rollback service to previous version
#------------------------------------------------------------------------------
compose_rollback() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local compose_file="$4"
    
    log_info "Rolling back ${service_name} to ${image}:${tag}"
    
    # Rollback is essentially a deploy with the previous tag
    compose_deploy "$image" "$tag" "$service_name" "$compose_file"
}

#------------------------------------------------------------------------------
# Get service status
#------------------------------------------------------------------------------
compose_status() {
    local service_name="$1"
    
    local container_status
    container_status=$(docker ps --filter "name=${service_name}" --format "{{.Status}}" 2>/dev/null)
    
    if [[ -n "$container_status" ]]; then
        echo "$container_status"
        return 0
    else
        echo "Not running"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Scale service replicas
#------------------------------------------------------------------------------
compose_scale() {
    local service_name="$1"
    local replicas="$2"
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    if [[ -z "$compose_cmd" ]]; then
        log_error "docker-compose is not available"
        return 1
    fi
    
    log_info "Scaling ${service_name} to ${replicas} replicas"
    $compose_cmd up -d --scale "${service_name}=${replicas}" "$service_name" || {
        log_error "Failed to scale service"
        return 1
    }
    
    log_success "Service scaled to ${replicas} replicas"
    return 0
}

#------------------------------------------------------------------------------
# Get current running tag for a container
#------------------------------------------------------------------------------
compose_get_current_tag() {
    local container_name="$1"
    
    local current_image
    current_image=$(docker inspect --format='{{.Config.Image}}' "$container_name" 2>/dev/null)
    
    if [[ -n "$current_image" ]]; then
        # Extract tag from image name
        echo "${current_image##*:}"
        return 0
    fi
    
    return 1
}

#------------------------------------------------------------------------------
# Dry-run deployment preview
#------------------------------------------------------------------------------
compose_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local compose_file="$4"
    
    echo -e "${CYAN}[DRY-RUN] Docker Compose Deployment${RESET}"
    echo ""
    echo "  Image:         ${image}:${tag}"
    echo "  Service:       ${service_name}"
    echo "  Compose File:  ${compose_file}"
    echo ""
    echo "  Commands to execute:"
    echo "    docker pull ${image}:${tag}"
    echo "    docker-compose -f ${compose_file} up -d --no-deps --force-recreate ${service_name}"
    echo ""
}
