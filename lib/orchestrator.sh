#!/usr/bin/env bash
#==============================================================================
# Orchestrator Interface
#
# Provides a unified interface for different container orchestration systems.
# Supports: docker-compose (default), Docker Swarm
#
# Author: shipctl
# License: MIT
#==============================================================================

# Available orchestrators
readonly ORCHESTRATOR_COMPOSE="compose"
readonly ORCHESTRATOR_SWARM="swarm"
readonly ORCHESTRATOR_KUBERNETES="kubernetes"
readonly ORCHESTRATOR_K8S="k8s"  # Alias

# Default orchestrator
ORCHESTRATOR="${ORCHESTRATOR:-compose}"

#------------------------------------------------------------------------------
# Detect orchestrator from config or environment
#------------------------------------------------------------------------------
orchestrator_detect() {
    local orchestrator="${ORCHESTRATOR:-compose}"
    
    # Check if running in a swarm
    if [[ "$orchestrator" == "auto" ]]; then
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            orchestrator="swarm"
        else
            orchestrator="compose"
        fi
    fi
    
    echo "$orchestrator"
}

#------------------------------------------------------------------------------
# Validate orchestrator prerequisites
#------------------------------------------------------------------------------
orchestrator_validate() {
    local orchestrator="$1"
    
    case "$orchestrator" in
        compose)
            validate_compose_prerequisites
            ;;
        swarm)
            validate_swarm_prerequisites
            ;;
        kubernetes|k8s)
            validate_kubernetes_prerequisites
            ;;
        *)
            log_error "Unknown orchestrator: $orchestrator"
            log_info "Supported orchestrators: compose, swarm, kubernetes"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Validate docker-compose prerequisites
#------------------------------------------------------------------------------
validate_compose_prerequisites() {
    # Check for docker-compose or docker compose
    if command -v docker-compose &>/dev/null; then
        return 0
    elif docker compose version &>/dev/null 2>&1; then
        return 0
    else
        log_error "docker-compose is not installed"
        log_info "Install with: brew install docker-compose"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Validate Docker Swarm prerequisites
#------------------------------------------------------------------------------
validate_swarm_prerequisites() {
    # Check if Docker is available
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    
    # Check if swarm is initialized (for local mode)
    if [[ "$LOCAL_MODE" == "true" ]]; then
        if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
            log_warn "Docker Swarm is not initialized on this node"
            log_info "Initialize with: docker swarm init"
            return 1
        fi
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Validate Kubernetes prerequisites
#------------------------------------------------------------------------------
validate_kubernetes_prerequisites() {
    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl is not installed"
        log_info "Install from: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    # For local mode, verify cluster connectivity
    if [[ "${LOCAL_MODE:-false}" == "true" ]]; then
        if ! kubectl cluster-info &>/dev/null; then
            log_warn "Cannot connect to Kubernetes cluster"
            log_info "Check your kubeconfig and context"
            return 1
        fi
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Deploy using the specified orchestrator
#------------------------------------------------------------------------------
orchestrator_deploy() {
    local orchestrator="$1"
    local image="$2"
    local tag="$3"
    local service_name="$4"
    local compose_file="$5"
    local stack_name="${6:-}"
    
    case "$orchestrator" in
        compose)
            compose_deploy "$image" "$tag" "$service_name" "$compose_file"
            ;;
        swarm)
            swarm_deploy "$image" "$tag" "$service_name" "$compose_file" "$stack_name"
            ;;
        kubernetes|k8s)
            k8s_deploy "$image" "$tag" "$service_name" "$compose_file" "$stack_name"
            ;;
        *)
            log_error "Unknown orchestrator: $orchestrator"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Rollback using the specified orchestrator
#------------------------------------------------------------------------------
orchestrator_rollback() {
    local orchestrator="$1"
    local image="$2"
    local tag="$3"
    local service_name="$4"
    local compose_file="$5"
    local stack_name="${6:-}"
    
    case "$orchestrator" in
        compose)
            compose_rollback "$image" "$tag" "$service_name" "$compose_file"
            ;;
        swarm)
            swarm_rollback "$image" "$tag" "$service_name" "$stack_name"
            ;;
        kubernetes|k8s)
            k8s_rollback "$image" "$tag" "$service_name"
            ;;
        *)
            log_error "Unknown orchestrator: $orchestrator"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Get deployment status
#------------------------------------------------------------------------------
orchestrator_status() {
    local orchestrator="$1"
    local service_name="$2"
    local stack_name="${3:-}"
    
    case "$orchestrator" in
        compose)
            compose_status "$service_name"
            ;;
        swarm)
            swarm_status "$service_name" "$stack_name"
            ;;
        kubernetes|k8s)
            k8s_status "$service_name"
            ;;
        *)
            log_error "Unknown orchestrator: $orchestrator"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Scale service replicas
#------------------------------------------------------------------------------
orchestrator_scale() {
    local orchestrator="$1"
    local service_name="$2"
    local replicas="$3"
    local stack_name="${4:-}"
    
    case "$orchestrator" in
        compose)
            compose_scale "$service_name" "$replicas"
            ;;
        swarm)
            swarm_scale "$service_name" "$replicas" "$stack_name"
            ;;
        kubernetes|k8s)
            k8s_scale "$service_name" "$replicas"
            ;;
        *)
            log_error "Unknown orchestrator: $orchestrator"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Get current running tag for a service
#------------------------------------------------------------------------------
orchestrator_get_current_tag() {
    local orchestrator="$1"
    local container_name="$2"
    local stack_name="${3:-}"
    
    case "$orchestrator" in
        compose)
            compose_get_current_tag "$container_name"
            ;;
        swarm)
            swarm_get_current_tag "$container_name" "$stack_name"
            ;;
        kubernetes|k8s)
            k8s_get_current_tag "$container_name"
            ;;
        *)
            log_error "Unknown orchestrator: $orchestrator"
            return 1
            ;;
    esac
}
