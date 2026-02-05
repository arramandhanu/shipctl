#!/usr/bin/env bash
#==============================================================================
# Cloud Provider Interface
#
# Provides a unified interface for different cloud providers.
# Supports: local (default), AWS, GCP, Azure, Alibaba Cloud
#
# Author: shipctl
# License: MIT
#==============================================================================

# Available cloud providers
readonly PROVIDER_LOCAL="local"
readonly PROVIDER_AWS="aws"
readonly PROVIDER_GCP="gcp"
readonly PROVIDER_AZURE="azure"
readonly PROVIDER_ALIBABA="alibaba"

# Default provider
CLOUD_PROVIDER="${CLOUD_PROVIDER:-local}"

#------------------------------------------------------------------------------
# Validate cloud provider prerequisites
#------------------------------------------------------------------------------
provider_validate() {
    local provider="$1"
    
    case "$provider" in
        local)
            return 0
            ;;
        aws)
            validate_aws_prerequisites
            ;;
        gcp)
            validate_gcp_prerequisites
            ;;
        azure)
            validate_azure_prerequisites
            ;;
        alibaba)
            validate_alibaba_prerequisites
            ;;
        *)
            log_error "Unknown cloud provider: $provider"
            log_info "Supported providers: local, aws, gcp, azure, alibaba"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Login to container registry for the cloud provider
#------------------------------------------------------------------------------
provider_registry_login() {
    local provider="$1"
    
    case "$provider" in
        local)
            # Use DockerHub login (handled by docker.sh)
            return 0
            ;;
        aws)
            aws_ecr_login
            ;;
        gcp)
            gcp_gcr_login
            ;;
        azure)
            azure_acr_login
            ;;
        alibaba)
            alibaba_acr_login
            ;;
        *)
            log_error "Unknown cloud provider: $provider"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Push image to cloud provider registry
#------------------------------------------------------------------------------
provider_push_image() {
    local provider="$1"
    local source_image="$2"
    local target_image="$3"
    local tag="$4"
    
    case "$provider" in
        local)
            # Push to DockerHub (handled by docker.sh)
            docker_push "$source_image" "$tag"
            ;;
        aws)
            aws_ecr_push "$source_image" "$target_image" "$tag"
            ;;
        gcp)
            gcp_gcr_push "$source_image" "$target_image" "$tag"
            ;;
        azure)
            azure_acr_push "$source_image" "$target_image" "$tag"
            ;;
        alibaba)
            alibaba_acr_push "$source_image" "$target_image" "$tag"
            ;;
        *)
            log_error "Unknown cloud provider: $provider"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Deploy to cloud provider
#------------------------------------------------------------------------------
provider_deploy() {
    local provider="$1"
    local image="$2"
    local tag="$3"
    local service_name="$4"
    shift 4
    local extra_args=("$@")
    
    case "$provider" in
        local)
            # Handled by orchestrator (compose/swarm)
            return 0
            ;;
        aws)
            aws_ecs_deploy "$image" "$tag" "$service_name" "${extra_args[@]}"
            ;;
        gcp)
            gcp_cloudrun_deploy "$image" "$tag" "$service_name" "${extra_args[@]}"
            ;;
        azure)
            azure_aci_deploy "$image" "$tag" "$service_name" "${extra_args[@]}"
            ;;
        alibaba)
            alibaba_eci_deploy "$image" "$tag" "$service_name" "${extra_args[@]}"
            ;;
        *)
            log_error "Unknown cloud provider: $provider"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Get registry URL for cloud provider
#------------------------------------------------------------------------------
provider_get_registry_url() {
    local provider="$1"
    
    case "$provider" in
        local)
            echo ""
            ;;
        aws)
            echo "${AWS_ECR_REGISTRY:-}"
            ;;
        gcp)
            echo "${GCP_REGION:-us}-docker.pkg.dev/${GCP_PROJECT_ID:-}/${GCP_REPOSITORY:-}"
            ;;
        azure)
            echo "${AZURE_REGISTRY:-}.azurecr.io"
            ;;
        alibaba)
            echo "registry.${ALICLOUD_REGION:-cn-hangzhou}.aliyuncs.com/${ALICLOUD_NAMESPACE:-}"
            ;;
        *)
            echo ""
            ;;
    esac
}

#------------------------------------------------------------------------------
# Check if provider requires cloud deployment (vs local orchestrator)
#------------------------------------------------------------------------------
provider_is_cloud() {
    local provider="$1"
    
    case "$provider" in
        local)
            return 1
            ;;
        aws|gcp|azure|alibaba)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
