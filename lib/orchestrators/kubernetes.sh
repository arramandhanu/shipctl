#!/usr/bin/env bash
#==============================================================================
# Kubernetes Orchestrator
#
# Handles deployments using Kubernetes via kubectl.
# Supports deployment updates, rollback, and scaling.
#
# Author: shipctl
# License: MIT
#==============================================================================

# Default namespace
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"

# Default context (uses current context if not set)
K8S_CONTEXT="${K8S_CONTEXT:-}"

#------------------------------------------------------------------------------
# Get kubectl command with context if specified
#------------------------------------------------------------------------------
k8s_kubectl() {
    local cmd="kubectl"
    
    if [[ -n "$K8S_CONTEXT" ]]; then
        cmd="kubectl --context=$K8S_CONTEXT"
    fi
    
    if [[ -n "$K8S_NAMESPACE" ]]; then
        cmd="$cmd --namespace=$K8S_NAMESPACE"
    fi
    
    echo "$cmd"
}

#------------------------------------------------------------------------------
# Validate Kubernetes prerequisites
#------------------------------------------------------------------------------
k8s_validate() {
    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl is not installed"
        log_info "Install from: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    # Check if cluster is accessible
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    if ! $kubectl_cmd cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Check your kubeconfig and context"
        return 1
    fi
    
    log_info "Kubernetes cluster connection validated"
    return 0
}

#------------------------------------------------------------------------------
# Deploy service using Kubernetes
#------------------------------------------------------------------------------
k8s_deploy() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local manifest_path="$4"
    local namespace="${5:-$K8S_NAMESPACE}"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    log_info "Deploying ${service_name} to Kubernetes namespace: ${namespace}"
    
    # Check if deployment exists
    if $kubectl_cmd get deployment "$service_name" &>/dev/null; then
        # Update existing deployment
        log_info "Updating existing deployment: ${service_name}"
        
        $kubectl_cmd set image deployment/"$service_name" \
            "$service_name=${image}:${tag}" || {
            log_error "Failed to update deployment image"
            return 1
        }
    else
        # Apply manifest file if provided
        if [[ -n "$manifest_path" ]] && [[ -f "$manifest_path" ]]; then
            log_info "Applying manifest: ${manifest_path}"
            
            # Substitute image tag in manifest
            local temp_manifest
            temp_manifest=$(mktemp)
            
            # Replace image tag placeholder
            sed "s|\${IMAGE_TAG}|${tag}|g; s|\${IMAGE}|${image}|g" \
                "$manifest_path" > "$temp_manifest"
            
            $kubectl_cmd apply -f "$temp_manifest" || {
                rm -f "$temp_manifest"
                log_error "Failed to apply manifest"
                return 1
            }
            
            rm -f "$temp_manifest"
        else
            # Create basic deployment
            log_info "Creating new deployment with kubectl"
            
            $kubectl_cmd create deployment "$service_name" \
                --image="${image}:${tag}" || {
                log_error "Failed to create deployment"
                return 1
            }
        fi
    fi
    
    # Wait for rollout to complete
    log_info "Waiting for rollout to complete..."
    k8s_wait_for_rollout "$service_name" 120 || {
        log_warn "Rollout may not have completed fully"
    }
    
    log_success "Deployment '${service_name}' updated successfully"
    return 0
}

#------------------------------------------------------------------------------
# Wait for deployment rollout to complete
#------------------------------------------------------------------------------
k8s_wait_for_rollout() {
    local deployment="$1"
    local timeout="${2:-120}"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    $kubectl_cmd rollout status deployment/"$deployment" \
        --timeout="${timeout}s" || {
        return 1
    }
    
    return 0
}

#------------------------------------------------------------------------------
# Rollback deployment to previous version
#------------------------------------------------------------------------------
k8s_rollback() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local revision="${4:-}"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    log_info "Rolling back deployment: ${service_name}"
    
    if [[ -n "$revision" ]]; then
        # Rollback to specific revision
        $kubectl_cmd rollout undo deployment/"$service_name" \
            --to-revision="$revision" || {
            log_error "Failed to rollback to revision $revision"
            return 1
        }
    else
        # Rollback to previous revision
        $kubectl_cmd rollout undo deployment/"$service_name" || {
            log_error "Failed to rollback deployment"
            return 1
        }
    fi
    
    # Wait for rollback to complete
    log_info "Waiting for rollback to complete..."
    k8s_wait_for_rollout "$service_name" 120 || {
        log_warn "Rollback may not have completed fully"
    }
    
    log_success "Deployment rolled back successfully"
    return 0
}

#------------------------------------------------------------------------------
# Get deployment status
#------------------------------------------------------------------------------
k8s_status() {
    local service_name="$1"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    local status
    status=$($kubectl_cmd get deployment "$service_name" \
        -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null)
    
    if [[ -n "$status" ]]; then
        echo "$status"
        return 0
    else
        echo "Not found"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Scale deployment replicas
#------------------------------------------------------------------------------
k8s_scale() {
    local service_name="$1"
    local replicas="$2"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    log_info "Scaling ${service_name} to ${replicas} replicas"
    
    $kubectl_cmd scale deployment/"$service_name" \
        --replicas="$replicas" || {
        log_error "Failed to scale deployment"
        return 1
    }
    
    log_success "Deployment scaled to ${replicas} replicas"
    return 0
}

#------------------------------------------------------------------------------
# Get current running image tag for a deployment
#------------------------------------------------------------------------------
k8s_get_current_tag() {
    local service_name="$1"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    local current_image
    current_image=$($kubectl_cmd get deployment "$service_name" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    
    if [[ -n "$current_image" ]]; then
        # Extract tag from image name
        echo "${current_image##*:}"
        return 0
    fi
    
    return 1
}

#------------------------------------------------------------------------------
# List all deployments in namespace
#------------------------------------------------------------------------------
k8s_list_deployments() {
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    $kubectl_cmd get deployments -o wide 2>/dev/null || {
        log_error "Failed to list deployments"
        return 1
    }
}

#------------------------------------------------------------------------------
# Delete a deployment
#------------------------------------------------------------------------------
k8s_delete() {
    local service_name="$1"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    log_warn "Deleting deployment: ${service_name}"
    
    $kubectl_cmd delete deployment "$service_name" || {
        log_error "Failed to delete deployment"
        return 1
    }
    
    log_success "Deployment deleted"
    return 0
}

#------------------------------------------------------------------------------
# Get rollout history
#------------------------------------------------------------------------------
k8s_history() {
    local service_name="$1"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    $kubectl_cmd rollout history deployment/"$service_name" || {
        log_error "Failed to get rollout history"
        return 1
    }
}

#------------------------------------------------------------------------------
# Restart deployment (rolling restart)
#------------------------------------------------------------------------------
k8s_restart() {
    local service_name="$1"
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    log_info "Restarting deployment: ${service_name}"
    
    $kubectl_cmd rollout restart deployment/"$service_name" || {
        log_error "Failed to restart deployment"
        return 1
    }
    
    log_success "Deployment restart initiated"
    return 0
}

#------------------------------------------------------------------------------
# Dry-run deployment preview
#------------------------------------------------------------------------------
k8s_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local manifest_path="$4"
    local namespace="${5:-$K8S_NAMESPACE}"
    
    echo -e "${CYAN}[DRY-RUN] Kubernetes Deployment${RESET}"
    echo ""
    echo "  Namespace:     ${namespace}"
    echo "  Context:       ${K8S_CONTEXT:-current}"
    echo "  Deployment:    ${service_name}"
    echo "  Image:         ${image}:${tag}"
    
    if [[ -n "$manifest_path" ]]; then
        echo "  Manifest:      ${manifest_path}"
    fi
    echo ""
    
    local kubectl_cmd
    kubectl_cmd=$(k8s_kubectl)
    
    # Check if deployment exists
    if $kubectl_cmd get deployment "$service_name" &>/dev/null; then
        echo "  Mode:          Deployment Update"
        echo "  Command:       kubectl set image deployment/${service_name} ${service_name}=${image}:${tag}"
    else
        echo "  Mode:          New Deployment"
        if [[ -n "$manifest_path" ]]; then
            echo "  Command:       kubectl apply -f ${manifest_path}"
        else
            echo "  Command:       kubectl create deployment ${service_name} --image=${image}:${tag}"
        fi
    fi
    echo ""
}
