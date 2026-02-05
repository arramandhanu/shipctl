#!/usr/bin/env bash
#==============================================================================
# Alibaba Cloud Provider
#
# Handles deployments to Alibaba Cloud infrastructure:
# - ACR (Alibaba Container Registry) for image storage
# - ECI (Elastic Container Instance) for container deployments
#
# Required environment variables:
#   ALICLOUD_ACCESS_KEY    - Alibaba Cloud access key
#   ALICLOUD_SECRET_KEY    - Alibaba Cloud secret key
#   ALICLOUD_REGION        - Region (default: cn-hangzhou)
#   ALICLOUD_NAMESPACE     - ACR namespace
#   ALICLOUD_REGISTRY      - ACR registry instance ID
#
# Author: shipctl
# License: MIT
#==============================================================================

# Alibaba Cloud defaults
ALICLOUD_REGION="${ALICLOUD_REGION:-cn-hangzhou}"

#------------------------------------------------------------------------------
# Validate Alibaba Cloud prerequisites
#------------------------------------------------------------------------------
validate_alibaba_prerequisites() {
    # Check for Alibaba Cloud CLI
    if ! command -v aliyun &>/dev/null; then
        log_error "Alibaba Cloud CLI (aliyun) is not installed"
        log_info "Install with: brew install aliyun-cli"
        return 1
    fi
    
    # Check credentials
    if [[ -z "${ALICLOUD_ACCESS_KEY:-}" ]] && ! aliyun configure list &>/dev/null; then
        log_error "Alibaba Cloud credentials not configured"
        log_info "Set ALICLOUD_ACCESS_KEY and ALICLOUD_SECRET_KEY"
        log_info "Or run: aliyun configure"
        return 1
    fi
    
    # Validate required variables
    if [[ -z "${ALICLOUD_NAMESPACE:-}" ]]; then
        log_error "ALICLOUD_NAMESPACE is required"
        return 1
    fi
    
    log_success "Alibaba Cloud credentials validated"
    return 0
}

#------------------------------------------------------------------------------
# Login to Alibaba Container Registry
#------------------------------------------------------------------------------
alibaba_acr_login() {
    log_info "Logging into Alibaba Container Registry..."
    
    local registry="registry.${ALICLOUD_REGION}.aliyuncs.com"
    
    # Use access key for Docker login
    if [[ -n "${ALICLOUD_ACCESS_KEY:-}" ]]; then
        echo "${ALICLOUD_SECRET_KEY}" | docker login \
            --username "${ALICLOUD_ACCESS_KEY}" \
            --password-stdin "$registry" || {
            log_error "Failed to login to Alibaba ACR"
            return 1
        }
    else
        # Use aliyun CLI to get credentials
        local password
        password=$(aliyun cr GetAuthorizationToken --query "data.authorizationToken" --output text)
        echo "$password" | docker login \
            --username "aliyun" \
            --password-stdin "$registry" || {
            log_error "Failed to login to Alibaba ACR"
            return 1
        }
    fi
    
    log_success "Alibaba ACR login successful: $registry"
    return 0
}

#------------------------------------------------------------------------------
# Push image to Alibaba ACR
#------------------------------------------------------------------------------
alibaba_acr_push() {
    local source_image="$1"
    local target_image="$2"
    local tag="$3"
    
    local registry="registry.${ALICLOUD_REGION}.aliyuncs.com/${ALICLOUD_NAMESPACE}"
    local full_target="${registry}/${target_image}:${tag}"
    
    log_info "Tagging image for Alibaba ACR: ${full_target}"
    docker tag "${source_image}:${tag}" "$full_target" || {
        log_error "Failed to tag image"
        return 1
    }
    
    log_info "Pushing to Alibaba ACR..."
    docker push "$full_target" || {
        log_error "Failed to push to Alibaba ACR"
        return 1
    }
    
    log_success "Image pushed: $full_target"
    return 0
}

#------------------------------------------------------------------------------
# Deploy to Elastic Container Instance
#------------------------------------------------------------------------------
alibaba_eci_deploy() {
    local image="$1"
    local tag="$2"
    local container_name="$3"
    
    log_info "Deploying to Alibaba ECI: ${container_name}"
    
    local registry="registry.${ALICLOUD_REGION}.aliyuncs.com/${ALICLOUD_NAMESPACE}"
    local full_image="${registry}/${image}:${tag}"
    
    # Create or update ECI container group
    aliyun eci CreateContainerGroup \
        --RegionId "$ALICLOUD_REGION" \
        --ContainerGroupName "$container_name" \
        --Container.1.Name "$container_name" \
        --Container.1.Image "$full_image" \
        --Container.1.Cpu "1" \
        --Container.1.Memory "2" \
        --RestartPolicy "Always" || {
        log_error "Failed to create ECI container group"
        return 1
    }
    
    log_success "Deployed to ECI: $container_name"
    return 0
}

#------------------------------------------------------------------------------
# Get ECI status
#------------------------------------------------------------------------------
alibaba_eci_status() {
    local container_name="$1"
    
    aliyun eci DescribeContainerGroups \
        --RegionId "$ALICLOUD_REGION" \
        --ContainerGroupName "$container_name" \
        --output cols=ContainerGroupName,Status
}

#------------------------------------------------------------------------------
# Stop ECI container group
#------------------------------------------------------------------------------
alibaba_eci_stop() {
    local container_name="$1"
    
    log_info "Stopping container group: $container_name"
    
    # Get container group ID
    local group_id
    group_id=$(aliyun eci DescribeContainerGroups \
        --RegionId "$ALICLOUD_REGION" \
        --ContainerGroupName "$container_name" \
        --query "ContainerGroups[0].ContainerGroupId" --output text)
    
    if [[ -n "$group_id" ]]; then
        aliyun eci DeleteContainerGroup \
            --RegionId "$ALICLOUD_REGION" \
            --ContainerGroupId "$group_id" || {
            log_error "Failed to stop container group"
            return 1
        }
    fi
    
    log_success "Container group stopped"
    return 0
}

#------------------------------------------------------------------------------
# Rollback ECI (redeploy with previous tag)
#------------------------------------------------------------------------------
alibaba_eci_rollback() {
    local image="$1"
    local previous_tag="$2"
    local container_name="$3"
    
    log_info "Rolling back to: ${image}:${previous_tag}"
    
    # Stop current instance
    alibaba_eci_stop "$container_name"
    
    # Deploy with previous tag
    alibaba_eci_deploy "$image" "$previous_tag" "$container_name"
}

#------------------------------------------------------------------------------
# Dry-run Alibaba deployment preview
#------------------------------------------------------------------------------
alibaba_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local container_name="$3"
    
    local registry="registry.${ALICLOUD_REGION}.aliyuncs.com/${ALICLOUD_NAMESPACE}"
    local full_image="${registry}/${image}:${tag}"
    
    echo -e "${CYAN}[DRY-RUN] Alibaba Cloud ECI Deployment${RESET}"
    echo ""
    echo "  Region:     ${ALICLOUD_REGION}"
    echo "  Namespace:  ${ALICLOUD_NAMESPACE}"
    echo "  Registry:   ${registry}"
    echo "  Image:      ${full_image}"
    echo "  Container:  ${container_name}"
    echo ""
    echo "  Commands to execute:"
    echo "    1. docker login registry.${ALICLOUD_REGION}.aliyuncs.com"
    echo "    2. docker tag ${image}:${tag} ${full_image}"
    echo "    3. docker push ${full_image}"
    echo "    4. aliyun eci CreateContainerGroup --ContainerGroupName ${container_name} --Container.1.Image ${full_image}"
    echo ""
}
