#!/usr/bin/env bash
#==============================================================================
# Azure Cloud Provider
#
# Handles deployments to Azure infrastructure:
# - ACR (Azure Container Registry) for image storage
# - ACI (Azure Container Instances) for container deployments
#
# Required environment variables:
#   AZURE_SUBSCRIPTION_ID - Azure subscription ID  
#   AZURE_RESOURCE_GROUP  - Resource group name
#   AZURE_REGISTRY        - ACR registry name (without .azurecr.io)
#   AZURE_LOCATION        - Azure region (default: eastus)
#
# Author: shipctl
# License: MIT
#==============================================================================

# Azure defaults
AZURE_LOCATION="${AZURE_LOCATION:-eastus}"

#------------------------------------------------------------------------------
# Validate Azure prerequisites
#------------------------------------------------------------------------------
validate_azure_prerequisites() {
    # Check for Azure CLI
    if ! command -v az &>/dev/null; then
        log_error "Azure CLI (az) is not installed"
        log_info "Install with: brew install azure-cli"
        return 1
    fi
    
    # Check if logged in
    if ! az account show &>/dev/null; then
        log_error "Azure CLI not logged in"
        log_info "Run: az login"
        return 1
    fi
    
    # Validate required variables
    if [[ -z "${AZURE_RESOURCE_GROUP:-}" ]]; then
        log_error "AZURE_RESOURCE_GROUP is required"
        return 1
    fi
    
    if [[ -z "${AZURE_REGISTRY:-}" ]]; then
        log_error "AZURE_REGISTRY is required"
        return 1
    fi
    
    log_success "Azure credentials validated"
    return 0
}

#------------------------------------------------------------------------------
# Login to ACR
#------------------------------------------------------------------------------
azure_acr_login() {
    log_info "Logging into Azure Container Registry..."
    
    az acr login --name "$AZURE_REGISTRY" || {
        log_error "Failed to login to ACR"
        return 1
    }
    
    log_success "ACR login successful: ${AZURE_REGISTRY}.azurecr.io"
    return 0
}

#------------------------------------------------------------------------------
# Push image to ACR
#------------------------------------------------------------------------------
azure_acr_push() {
    local source_image="$1"
    local target_image="$2"
    local tag="$3"
    
    local registry="${AZURE_REGISTRY}.azurecr.io"
    local full_target="${registry}/${target_image}:${tag}"
    
    log_info "Tagging image for ACR: ${full_target}"
    docker tag "${source_image}:${tag}" "$full_target" || {
        log_error "Failed to tag image"
        return 1
    }
    
    log_info "Pushing to ACR..."
    docker push "$full_target" || {
        log_error "Failed to push to ACR"
        return 1
    }
    
    log_success "Image pushed: $full_target"
    return 0
}

#------------------------------------------------------------------------------
# Deploy to Azure Container Instances
#------------------------------------------------------------------------------
azure_aci_deploy() {
    local image="$1"
    local tag="$2"
    local container_name="$3"
    
    log_info "Deploying to Azure Container Instances: ${container_name}"
    
    local registry="${AZURE_REGISTRY}.azurecr.io"
    local full_image="${registry}/${image}:${tag}"
    
    # Get ACR credentials
    local acr_username acr_password
    acr_username=$(az acr credential show --name "$AZURE_REGISTRY" --query "username" -o tsv)
    acr_password=$(az acr credential show --name "$AZURE_REGISTRY" --query "passwords[0].value" -o tsv)
    
    # Check if container exists
    if az container show --resource-group "$AZURE_RESOURCE_GROUP" --name "$container_name" &>/dev/null; then
        # Delete existing container
        log_info "Removing existing container..."
        az container delete \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$container_name" \
            --yes || {
            log_error "Failed to delete existing container"
            return 1
        }
    fi
    
    # Create new container
    az container create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$container_name" \
        --image "$full_image" \
        --registry-login-server "$registry" \
        --registry-username "$acr_username" \
        --registry-password "$acr_password" \
        --location "$AZURE_LOCATION" \
        --cpu 1 \
        --memory 1.5 \
        --restart-policy Always \
        --ip-address Public \
        --ports 80 443 || {
        log_error "Failed to create container instance"
        return 1
    }
    
    # Get container IP
    local ip_address
    ip_address=$(az container show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$container_name" \
        --query "ipAddress.ip" -o tsv)
    
    log_success "Deployed to ACI: http://${ip_address}"
    return 0
}

#------------------------------------------------------------------------------
# Get ACI status
#------------------------------------------------------------------------------
azure_aci_status() {
    local container_name="$1"
    
    az container show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$container_name" \
        --query "{Name:name, State:instanceView.state, IP:ipAddress.ip}" \
        -o table
}

#------------------------------------------------------------------------------
# Stop ACI container
#------------------------------------------------------------------------------
azure_aci_stop() {
    local container_name="$1"
    
    log_info "Stopping container: $container_name"
    az container stop \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$container_name" || {
        log_error "Failed to stop container"
        return 1
    }
    
    log_success "Container stopped"
    return 0
}

#------------------------------------------------------------------------------
# Delete ACI container
#------------------------------------------------------------------------------
azure_aci_delete() {
    local container_name="$1"
    
    log_warn "Deleting container: $container_name"
    az container delete \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$container_name" \
        --yes || {
        log_error "Failed to delete container"
        return 1
    }
    
    log_success "Container deleted"
    return 0
}

#------------------------------------------------------------------------------
# Rollback ACI (redeploy with previous tag)
#------------------------------------------------------------------------------
azure_aci_rollback() {
    local image="$1"
    local previous_tag="$2"
    local container_name="$3"
    
    log_info "Rolling back to: ${image}:${previous_tag}"
    azure_aci_deploy "$image" "$previous_tag" "$container_name"
}

#------------------------------------------------------------------------------
# Dry-run Azure deployment preview
#------------------------------------------------------------------------------
azure_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local container_name="$3"
    
    local registry="${AZURE_REGISTRY}.azurecr.io"
    local full_image="${registry}/${image}:${tag}"
    
    echo -e "${CYAN}[DRY-RUN] Azure Container Instances Deployment${RESET}"
    echo ""
    echo "  Resource Group: ${AZURE_RESOURCE_GROUP}"
    echo "  Location:       ${AZURE_LOCATION}"
    echo "  Registry:       ${registry}"
    echo "  Image:          ${full_image}"
    echo "  Container:      ${container_name}"
    echo ""
    echo "  Commands to execute:"
    echo "    1. az acr login --name ${AZURE_REGISTRY}"
    echo "    2. docker tag ${image}:${tag} ${full_image}"
    echo "    3. docker push ${full_image}"
    echo "    4. az container create --resource-group ${AZURE_RESOURCE_GROUP} --name ${container_name} --image ${full_image}"
    echo ""
}
