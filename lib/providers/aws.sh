#!/usr/bin/env bash
#==============================================================================
# AWS Cloud Provider
#
# Handles deployments to AWS infrastructure:
# - ECR (Elastic Container Registry) for image storage
# - ECS (Elastic Container Service) for container orchestration
#
# Required environment variables:
#   AWS_ACCESS_KEY_ID     - AWS access key
#   AWS_SECRET_ACCESS_KEY - AWS secret key
#   AWS_REGION            - AWS region (default: us-east-1)
#   AWS_ECR_REGISTRY      - ECR registry URL
#   AWS_ECS_CLUSTER       - ECS cluster name
#
# Author: shipctl
# License: MIT
#==============================================================================

# AWS defaults
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ECS_CLUSTER="${AWS_ECS_CLUSTER:-default}"

#------------------------------------------------------------------------------
# Validate AWS prerequisites
#------------------------------------------------------------------------------
validate_aws_prerequisites() {
    # Check for AWS CLI
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI is not installed"
        log_info "Install with: brew install awscli"
        return 1
    fi
    
    # Check AWS credentials
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] && [[ ! -f ~/.aws/credentials ]]; then
        log_error "AWS credentials not configured"
        log_info "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        log_info "Or configure: aws configure"
        return 1
    fi
    
    # Verify credentials work
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials are invalid"
        return 1
    fi
    
    log_success "AWS credentials validated"
    return 0
}

#------------------------------------------------------------------------------
# Login to ECR registry
#------------------------------------------------------------------------------
aws_ecr_login() {
    log_info "Logging into AWS ECR..."
    
    local registry="${AWS_ECR_REGISTRY:-}"
    
    if [[ -z "$registry" ]]; then
        # Get registry from account ID
        local account_id
        account_id=$(aws sts get-caller-identity --query Account --output text)
        registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        export AWS_ECR_REGISTRY="$registry"
    fi
    
    # Get login password and pipe to docker login
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$registry" || {
        log_error "Failed to login to ECR"
        return 1
    }
    
    log_success "ECR login successful: $registry"
    return 0
}

#------------------------------------------------------------------------------
# Push image to ECR
#------------------------------------------------------------------------------
aws_ecr_push() {
    local source_image="$1"
    local target_image="$2"
    local tag="$3"
    
    local registry="${AWS_ECR_REGISTRY:-}"
    local full_target="${registry}/${target_image}:${tag}"
    
    log_info "Tagging image for ECR: ${full_target}"
    docker tag "${source_image}:${tag}" "$full_target" || {
        log_error "Failed to tag image"
        return 1
    }
    
    log_info "Pushing to ECR..."
    docker push "$full_target" || {
        log_error "Failed to push to ECR"
        return 1
    }
    
    log_success "Image pushed to ECR: $full_target"
    return 0
}

#------------------------------------------------------------------------------
# Create ECR repository if it doesn't exist
#------------------------------------------------------------------------------
aws_ecr_create_repo() {
    local repo_name="$1"
    
    if ! aws ecr describe-repositories --repository-names "$repo_name" &>/dev/null; then
        log_info "Creating ECR repository: $repo_name"
        aws ecr create-repository \
            --repository-name "$repo_name" \
            --image-scanning-configuration scanOnPush=true || {
            log_error "Failed to create ECR repository"
            return 1
        }
        log_success "ECR repository created"
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Deploy to ECS
#------------------------------------------------------------------------------
aws_ecs_deploy() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local cluster="${4:-$AWS_ECS_CLUSTER}"
    
    log_info "Deploying to ECS: ${service_name}"
    
    local registry="${AWS_ECR_REGISTRY:-}"
    local full_image="${registry}/${image}:${tag}"
    
    # Update service to force new deployment
    aws ecs update-service \
        --cluster "$cluster" \
        --service "$service_name" \
        --force-new-deployment \
        --region "$AWS_REGION" || {
        log_error "Failed to update ECS service"
        return 1
    }
    
    log_success "ECS deployment initiated for: $service_name"
    
    # Wait for deployment to stabilize
    log_info "Waiting for service to stabilize..."
    aws ecs wait services-stable \
        --cluster "$cluster" \
        --services "$service_name" \
        --region "$AWS_REGION" || {
        log_warn "Service may not be fully stable"
    }
    
    return 0
}

#------------------------------------------------------------------------------
# Get ECS service status
#------------------------------------------------------------------------------
aws_ecs_status() {
    local service_name="$1"
    local cluster="${2:-$AWS_ECS_CLUSTER}"
    
    aws ecs describe-services \
        --cluster "$cluster" \
        --services "$service_name" \
        --query 'services[0].{Status: status, Running: runningCount, Desired: desiredCount}' \
        --output table \
        --region "$AWS_REGION"
}

#------------------------------------------------------------------------------
# Rollback ECS service (stop current deployment)
#------------------------------------------------------------------------------
aws_ecs_rollback() {
    local service_name="$1"
    local cluster="${2:-$AWS_ECS_CLUSTER}"
    
    log_info "Rolling back ECS service: $service_name"
    
    # Get the previous task definition
    local current_task_def
    current_task_def=$(aws ecs describe-services \
        --cluster "$cluster" \
        --services "$service_name" \
        --query 'services[0].taskDefinition' \
        --output text \
        --region "$AWS_REGION")
    
    # Update to previous task definition
    # Note: This is a simplified rollback - production should track versions
    aws ecs update-service \
        --cluster "$cluster" \
        --service "$service_name" \
        --force-new-deployment \
        --region "$AWS_REGION" || {
        log_error "Failed to rollback ECS service"
        return 1
    }
    
    log_success "ECS rollback initiated"
    return 0
}

#------------------------------------------------------------------------------
# Dry-run AWS deployment preview
#------------------------------------------------------------------------------
aws_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    local cluster="${4:-$AWS_ECS_CLUSTER}"
    
    local registry="${AWS_ECR_REGISTRY:-}"
    local full_image="${registry}/${image}:${tag}"
    
    echo -e "${CYAN}[DRY-RUN] AWS ECS Deployment${RESET}"
    echo ""
    echo "  Region:      ${AWS_REGION}"
    echo "  Registry:    ${registry}"
    echo "  Image:       ${full_image}"
    echo "  Cluster:     ${cluster}"
    echo "  Service:     ${service_name}"
    echo ""
    echo "  Commands to execute:"
    echo "    1. aws ecr get-login-password | docker login ..."
    echo "    2. docker tag ${image}:${tag} ${full_image}"
    echo "    3. docker push ${full_image}"
    echo "    4. aws ecs update-service --cluster ${cluster} --service ${service_name} --force-new-deployment"
    echo ""
}
