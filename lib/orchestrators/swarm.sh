#!/usr/bin/env bash
#==============================================================================
# Docker Swarm Orchestrator
#
# Handles deployments using Docker Swarm stacks.
# Supports stack deploy, service updates, rollback, and scaling.
#
# Author: shipctl
# License: MIT
#==============================================================================

# Default stack name if not provided
SWARM_STACK_NAME="${SWARM_STACK_NAME:-shipctl}"

#------------------------------------------------------------------------------
# Initialize Docker Swarm (if not already initialized)
#------------------------------------------------------------------------------
swarm_init() {
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        log_info "Docker Swarm is already active"
        return 0
    fi
    
    log_info "Initializing Docker Swarm..."
    docker swarm init || {
        log_error "Failed to initialize Docker Swarm"
        log_info "If this is a worker node, use: docker swarm join ..."
        return 1
    }
    
    log_success "Docker Swarm initialized"
    return 0
}

#------------------------------------------------------------------------------
# Deploy service using Docker Swarm stack
#------------------------------------------------------------------------------
swarm_deploy() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local compose_file="$4"
    local stack_name="${5:-$SWARM_STACK_NAME}"
    
    # Validate swarm is active
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        log_error "Docker Swarm is not active"
        log_info "Initialize with: docker swarm init"
        return 1
    fi
    
    log_info "Deploying stack '${stack_name}' via Docker Swarm"
    
    # Check if this is a stack deploy or service update
    local full_service_name="${stack_name}_${service_name}"
    
    if docker service ls --format '{{.Name}}' | grep -q "^${full_service_name}$"; then
        # Service exists, update it
        log_info "Updating existing service: ${full_service_name}"
        docker service update \
            --image "${image}:${tag}" \
            --force \
            "${full_service_name}" || {
            log_error "Failed to update service"
            return 1
        }
    else
        # Deploy entire stack
        log_info "Deploying stack: ${stack_name}"
        
        if [[ ! -f "$compose_file" ]]; then
            log_error "Compose file not found: $compose_file"
            return 1
        fi
        
        # Set image tag as environment variable
        export IMAGE_TAG="$tag"
        
        docker stack deploy \
            --compose-file "$compose_file" \
            --with-registry-auth \
            "$stack_name" || {
            log_error "Failed to deploy stack"
            return 1
        }
    fi
    
    # Wait for service to be ready
    log_info "Waiting for service to be ready..."
    swarm_wait_for_service "$full_service_name" 60 || {
        log_warn "Service may not be fully ready"
    }
    
    log_success "Stack '${stack_name}' deployed successfully"
    return 0
}

#------------------------------------------------------------------------------
# Wait for service to be ready
#------------------------------------------------------------------------------
swarm_wait_for_service() {
    local service_name="$1"
    local timeout="${2:-60}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local replicas
        replicas=$(docker service ls --filter "name=${service_name}" --format "{{.Replicas}}" 2>/dev/null)
        
        if [[ -n "$replicas" ]]; then
            local running desired
            running=$(echo "$replicas" | cut -d'/' -f1)
            desired=$(echo "$replicas" | cut -d'/' -f2)
            
            if [[ "$running" == "$desired" ]] && [[ "$running" != "0" ]]; then
                log_success "Service ${service_name}: ${replicas}"
                return 0
            fi
            
            echo -ne "\r  Waiting: ${replicas} ($elapsed/${timeout}s)"
        fi
        
        sleep 2
        ((elapsed+=2))
    done
    
    echo ""
    log_warn "Timeout waiting for service to be ready"
    return 1
}

#------------------------------------------------------------------------------
# Rollback service to previous version
#------------------------------------------------------------------------------
swarm_rollback() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local stack_name="${4:-$SWARM_STACK_NAME}"
    
    local full_service_name="${stack_name}_${service_name}"
    
    log_info "Rolling back service: ${full_service_name}"
    
    # Use docker service rollback if available, otherwise update with previous tag
    if docker service rollback --help &>/dev/null; then
        docker service rollback "$full_service_name" || {
            # Fallback to manual update
            log_info "Using manual rollback to ${image}:${tag}"
            docker service update --image "${image}:${tag}" "$full_service_name"
        }
    else
        docker service update --image "${image}:${tag}" "$full_service_name" || {
            log_error "Failed to rollback service"
            return 1
        }
    fi
    
    log_success "Service rolled back successfully"
    return 0
}

#------------------------------------------------------------------------------
# Get service status
#------------------------------------------------------------------------------
swarm_status() {
    local service_name="$1"
    local stack_name="${2:-$SWARM_STACK_NAME}"
    
    local full_service_name="${stack_name}_${service_name}"
    
    local status
    status=$(docker service ls --filter "name=${full_service_name}" --format "{{.Replicas}}" 2>/dev/null)
    
    if [[ -n "$status" ]]; then
        echo "$status"
        return 0
    else
        echo "Not found"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Scale service replicas
#------------------------------------------------------------------------------
swarm_scale() {
    local service_name="$1"
    local replicas="$2"
    local stack_name="${3:-$SWARM_STACK_NAME}"
    
    local full_service_name="${stack_name}_${service_name}"
    
    log_info "Scaling ${full_service_name} to ${replicas} replicas"
    
    docker service scale "${full_service_name}=${replicas}" || {
        log_error "Failed to scale service"
        return 1
    }
    
    log_success "Service scaled to ${replicas} replicas"
    return 0
}

#------------------------------------------------------------------------------
# Get current running tag for a service
#------------------------------------------------------------------------------
swarm_get_current_tag() {
    local service_name="$1"
    local stack_name="${2:-$SWARM_STACK_NAME}"
    
    local full_service_name="${stack_name}_${service_name}"
    
    local current_image
    current_image=$(docker service inspect --format='{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$full_service_name" 2>/dev/null)
    
    if [[ -n "$current_image" ]]; then
        # Extract tag from image name
        echo "${current_image##*:}"
        return 0
    fi
    
    return 1
}

#------------------------------------------------------------------------------
# List all services in a stack
#------------------------------------------------------------------------------
swarm_list_services() {
    local stack_name="${1:-$SWARM_STACK_NAME}"
    
    docker stack services "$stack_name" 2>/dev/null || {
        log_error "Stack not found: $stack_name"
        return 1
    }
}

#------------------------------------------------------------------------------
# Remove a stack
#------------------------------------------------------------------------------
swarm_remove_stack() {
    local stack_name="${1:-$SWARM_STACK_NAME}"
    
    log_warn "Removing stack: ${stack_name}"
    docker stack rm "$stack_name" || {
        log_error "Failed to remove stack"
        return 1
    }
    
    log_success "Stack removed"
    return 0
}

#------------------------------------------------------------------------------
# Dry-run deployment preview
#------------------------------------------------------------------------------
swarm_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local compose_file="$4"
    local stack_name="${5:-$SWARM_STACK_NAME}"
    
    local full_service_name="${stack_name}_${service_name}"
    
    echo -e "${CYAN}[DRY-RUN] Docker Swarm Deployment${RESET}"
    echo ""
    echo "  Stack:         ${stack_name}"
    echo "  Service:       ${full_service_name}"
    echo "  Image:         ${image}:${tag}"
    echo "  Compose File:  ${compose_file}"
    echo ""
    
    # Check if service exists
    if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^${full_service_name}$"; then
        echo "  Mode:          Service Update"
        echo "  Command:       docker service update --image ${image}:${tag} ${full_service_name}"
    else
        echo "  Mode:          Stack Deploy (new)"
        echo "  Command:       docker stack deploy -c ${compose_file} ${stack_name}"
    fi
    echo ""
}
