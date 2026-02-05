#!/usr/bin/env bash
#==============================================================================
# Google Cloud Provider
#
# Handles deployments to Google Cloud infrastructure:
# - GCR/Artifact Registry for image storage
# - Cloud Run for serverless container deployments
#
# Required environment variables:
#   GCP_PROJECT_ID                 - GCP project ID
#   GCP_REGION                     - GCP region (default: us-central1)
#   GOOGLE_APPLICATION_CREDENTIALS - Path to service account key (optional)
#
# Author: shipctl
# License: MIT
#==============================================================================

# GCP defaults
GCP_REGION="${GCP_REGION:-us-central1}"
GCP_REPOSITORY="${GCP_REPOSITORY:-shipctl}"

#------------------------------------------------------------------------------
# Validate GCP prerequisites
#------------------------------------------------------------------------------
validate_gcp_prerequisites() {
    # Check for gcloud CLI
    if ! command -v gcloud &>/dev/null; then
        log_error "Google Cloud SDK (gcloud) is not installed"
        log_info "Install with: brew install google-cloud-sdk"
        return 1
    fi
    
    # Check GCP project
    if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
        local project
        project=$(gcloud config get-value project 2>/dev/null)
        if [[ -z "$project" ]]; then
            log_error "GCP project not configured"
            log_info "Set GCP_PROJECT_ID or run: gcloud config set project <PROJECT>"
            return 1
        fi
        export GCP_PROJECT_ID="$project"
    fi
    
    # Verify authentication
    if ! gcloud auth print-identity-token &>/dev/null; then
        log_error "GCP authentication not configured"
        log_info "Run: gcloud auth login"
        return 1
    fi
    
    log_success "GCP credentials validated: ${GCP_PROJECT_ID}"
    return 0
}

#------------------------------------------------------------------------------
# Login to GCR/Artifact Registry
#------------------------------------------------------------------------------
gcp_gcr_login() {
    log_info "Configuring Docker for GCP Artifact Registry..."
    
    # Configure Docker to use gcloud as credential helper
    gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet || {
        log_error "Failed to configure Docker for Artifact Registry"
        return 1
    }
    
    log_success "GCR authentication configured"
    return 0
}

#------------------------------------------------------------------------------
# Push image to GCR/Artifact Registry
#------------------------------------------------------------------------------
gcp_gcr_push() {
    local source_image="$1"
    local target_image="$2"
    local tag="$3"
    
    local registry="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPOSITORY}"
    local full_target="${registry}/${target_image}:${tag}"
    
    log_info "Tagging image for Artifact Registry: ${full_target}"
    docker tag "${source_image}:${tag}" "$full_target" || {
        log_error "Failed to tag image"
        return 1
    }
    
    log_info "Pushing to Artifact Registry..."
    docker push "$full_target" || {
        log_error "Failed to push to Artifact Registry"
        return 1
    }
    
    log_success "Image pushed: $full_target"
    return 0
}

#------------------------------------------------------------------------------
# Create Artifact Registry repository if it doesn't exist
#------------------------------------------------------------------------------
gcp_create_repository() {
    local repo_name="${1:-$GCP_REPOSITORY}"
    
    if ! gcloud artifacts repositories describe "$repo_name" \
        --location="$GCP_REGION" &>/dev/null; then
        log_info "Creating Artifact Registry repository: $repo_name"
        gcloud artifacts repositories create "$repo_name" \
            --repository-format=docker \
            --location="$GCP_REGION" \
            --description="Container images for shipctl" || {
            log_error "Failed to create repository"
            return 1
        }
        log_success "Repository created"
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Deploy to Cloud Run
#------------------------------------------------------------------------------
gcp_cloudrun_deploy() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    
    log_info "Deploying to Cloud Run: ${service_name}"
    
    local registry="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPOSITORY}"
    local full_image="${registry}/${image}:${tag}"
    
    gcloud run deploy "$service_name" \
        --image "$full_image" \
        --region "$GCP_REGION" \
        --platform managed \
        --allow-unauthenticated \
        --quiet || {
        log_error "Failed to deploy to Cloud Run"
        return 1
    }
    
    # Get service URL
    local service_url
    service_url=$(gcloud run services describe "$service_name" \
        --region "$GCP_REGION" \
        --format 'value(status.url)')
    
    log_success "Deployed to Cloud Run: $service_url"
    return 0
}

#------------------------------------------------------------------------------
# Get Cloud Run service status
#------------------------------------------------------------------------------
gcp_cloudrun_status() {
    local service_name="$1"
    
    gcloud run services describe "$service_name" \
        --region "$GCP_REGION" \
        --format 'table(status.conditions.type,status.conditions.status)'
}

#------------------------------------------------------------------------------
# Rollback Cloud Run to previous revision
#------------------------------------------------------------------------------
gcp_cloudrun_rollback() {
    local service_name="$1"
    
    log_info "Rolling back Cloud Run service: $service_name"
    
    # Get revisions
    local revisions
    revisions=$(gcloud run revisions list \
        --service "$service_name" \
        --region "$GCP_REGION" \
        --format 'value(name)' \
        --limit 2)
    
    # Get previous revision
    local prev_revision
    prev_revision=$(echo "$revisions" | tail -1)
    
    if [[ -z "$prev_revision" ]]; then
        log_error "No previous revision found"
        return 1
    fi
    
    log_info "Rolling back to: $prev_revision"
    gcloud run services update-traffic "$service_name" \
        --region "$GCP_REGION" \
        --to-revisions "$prev_revision=100" || {
        log_error "Failed to rollback"
        return 1
    }
    
    log_success "Rollback completed"
    return 0
}

#------------------------------------------------------------------------------
# Delete Cloud Run service
#------------------------------------------------------------------------------
gcp_cloudrun_delete() {
    local service_name="$1"
    
    log_warn "Deleting Cloud Run service: $service_name"
    gcloud run services delete "$service_name" \
        --region "$GCP_REGION" \
        --quiet || {
        log_error "Failed to delete service"
        return 1
    }
    
    log_success "Service deleted"
    return 0
}

#------------------------------------------------------------------------------
# Dry-run GCP deployment preview
#------------------------------------------------------------------------------
gcp_deploy_dry_run() {
    local image="$1"
    local tag="$2"
    local service_name="$3"
    
    local registry="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_REPOSITORY}"
    local full_image="${registry}/${image}:${tag}"
    
    echo -e "${CYAN}[DRY-RUN] GCP Cloud Run Deployment${RESET}"
    echo ""
    echo "  Project:     ${GCP_PROJECT_ID}"
    echo "  Region:      ${GCP_REGION}"
    echo "  Registry:    ${registry}"
    echo "  Image:       ${full_image}"
    echo "  Service:     ${service_name}"
    echo ""
    echo "  Commands to execute:"
    echo "    1. gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev"
    echo "    2. docker tag ${image}:${tag} ${full_image}"
    echo "    3. docker push ${full_image}"
    echo "    4. gcloud run deploy ${service_name} --image ${full_image}"
    echo ""
}
