#!/usr/bin/env bash
#==============================================================================
#
#   ███████╗██╗  ██╗██╗██████╗  ██████╗████████╗██╗
#   ██╔════╝██║  ██║██║██╔══██╗██╔════╝╚══██╔══╝██║
#   ███████╗███████║██║██████╔╝██║        ██║   ██║
#   ╚════██║██╔══██║██║██╔═══╝ ██║        ██║   ██║
#   ███████║██║  ██║██║██║     ╚██████╗   ██║   ███████╗
#   ╚══════╝╚═╝  ╚═╝╚═╝╚═╝      ╚═════╝   ╚═╝   ╚══════╝
#
#   shipctl - Professional Docker Deployment Tool
#   https://github.com/arramandhanu/shipctl
#
#   Usage: shipctl [OPTIONS] [SERVICE...]
#
#
#==============================================================================
set -euo pipefail

# Script directory
readonly DEPLOY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEPLOY_ROOT

# Source libraries
source "${DEPLOY_ROOT}/lib/colors.sh"
source "${DEPLOY_ROOT}/lib/utils.sh"
source "${DEPLOY_ROOT}/lib/checks.sh"
source "${DEPLOY_ROOT}/lib/docker.sh"
source "${DEPLOY_ROOT}/lib/ssh.sh"
source "${DEPLOY_ROOT}/lib/git.sh"

#------------------------------------------------------------------------------
# Version
#------------------------------------------------------------------------------
readonly VERSION="1.0.0"

#------------------------------------------------------------------------------
# Default options
#------------------------------------------------------------------------------
DRY_RUN=false
SKIP_CHECKS=false
SKIP_BUILD=false
SKIP_DEPLOY=false
SKIP_CONFIRM=false
SHOW_LOGS=true
CUSTOM_TAG=""
ENVIRONMENT="production"
ROLLBACK=false
LOCAL_MODE=false
CUSTOM_CONFIG=""

# Config directories
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/shipctl"

#------------------------------------------------------------------------------
# Show usage/help
#------------------------------------------------------------------------------
show_help() {
    # Load config to get PROJECT_NAME and services list
    local config_file="${DEPLOY_ROOT}/config/services.env"
    local project_name="shipctl"
    local services_list=""
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        local project_name="${PROJECT_NAME:-shipctl}"
        services_list="${SERVICES:-}"
    fi
    
    echo ""
    # Build header with dynamic centering
    local title="${project_name} DEPLOYMENT TOOL v${VERSION}"
    local box_width=63
    local title_len=${#title}
    local padding=$(( (box_width - title_len) / 2 ))
    local padding_left=""
    local padding_right=""
    for ((i=0; i<padding; i++)); do padding_left+=" "; done
    for ((i=0; i<(box_width - title_len - padding); i++)); do padding_right+=" "; done
    
    local border_line=""
    for ((i=0; i<box_width; i++)); do border_line+="═"; done
    
    echo -e "${CYAN}╔${border_line}╗${RESET}"
    echo -e "${CYAN}║${RESET}${padding_left}${BOLD}${WHITE}${title}${RESET}${padding_right}${CYAN}║${RESET}"
    echo -e "${CYAN}╚${border_line}╝${RESET}"
    echo ""
    echo -e "${BOLD}${YELLOW}USAGE${RESET}"
    echo -e "    ${GREEN}./deploy.sh${RESET} ${GRAY}[OPTIONS]${RESET} ${CYAN}[SERVICE...]${RESET}"
    echo ""
    echo -e "${BOLD}${YELLOW}SERVICES${RESET}"
    if [[ -n "$services_list" ]]; then
        IFS=',' read -ra svc_array <<< "$services_list"
        for svc in "${svc_array[@]}"; do
            echo -e "    ${CYAN}${svc}${RESET}"
        done
    else
        echo -e "    ${GRAY}(configure in config/services.env)${RESET}"
    fi
    echo ""
    echo -e "${BOLD}${YELLOW}OPTIONS${RESET}"
    echo -e "    ${GREEN}-h${RESET}, ${GREEN}--help${RESET}          Show this help message"
    echo -e "    ${GREEN}-v${RESET}, ${GREEN}--version${RESET}       Show version"
    echo -e "    ${GREEN}-l${RESET}, ${GREEN}--list${RESET}          List available services"
    echo -e "    ${GREEN}-a${RESET}, ${GREEN}--all${RESET}           Deploy all services"
    echo -e "    ${GREEN}-e${RESET}, ${GREEN}--env${RESET} ${GRAY}ENV${RESET}       Environment (staging|production) ${GRAY}[default: production]${RESET}"
    echo -e "    ${GREEN}-t${RESET}, ${GREEN}--tag${RESET} ${GRAY}TAG${RESET}       Use custom image tag instead of git commit SHA"
    echo -e "    ${GREEN}-c${RESET}, ${GREEN}--config${RESET} ${GRAY}FILE${RESET}  Use custom config file"
    echo -e "    ${GREEN}-n${RESET}, ${GREEN}--dry-run${RESET}       Preview what would be executed (no changes)"
    echo -e "    ${GREEN}-y${RESET}, ${GREEN}--yes${RESET}           Skip confirmation prompts"
    echo -e "    ${GRAY}--skip-checks${RESET}       Skip pre-flight checks (not recommended)"
    echo -e "    ${GRAY}--build-only${RESET}        Build and push only, skip deployment"
    echo -e "    ${GRAY}--deploy-only${RESET}       Deploy only, skip build (requires --tag)"
    echo -e "    ${GRAY}--rollback${RESET}          Rollback to previous version"
    echo -e "    ${GRAY}--no-logs${RESET}           Don't show container logs after deploy"
    echo -e "    ${GREEN}--local${RESET}             Run locally on server (no SSH, for server-side deployment)"
    echo ""
    echo -e "${BOLD}${YELLOW}COMMANDS${RESET}"
    echo -e "    ${GREEN}init${RESET}                Create config template in current directory"
    echo ""
    echo -e "${BOLD}${YELLOW}EXAMPLES${RESET}"
    echo -e "    ${GRAY}# Initialize config in current project${RESET}"
    echo -e "    ${WHITE}deploy init${RESET}"
    echo ""
    echo -e "    ${GRAY}# Deploy a single service${RESET}"
    echo -e "    ${WHITE}./deploy.sh my-service${RESET}"
    echo ""
    echo -e "    ${GRAY}# Deploy multiple services${RESET}"
    echo -e "    ${WHITE}./deploy.sh frontend backend${RESET}"
    echo ""
    echo -e "    ${GRAY}# Deploy all services${RESET}"
    echo -e "    ${WHITE}./deploy.sh --all${RESET}"
    echo ""
    echo -e "    ${GRAY}# Use custom config file${RESET}"
    echo -e "    ${WHITE}./deploy.sh --config /path/to/config.env frontend${RESET}"
    echo ""
    echo -e "    ${GRAY}# Preview deployment (dry-run)${RESET}"
    echo -e "    ${WHITE}./deploy.sh my-service --dry-run${RESET}"
    echo ""
    echo -e "    ${GRAY}# Deploy to staging environment${RESET}"
    echo -e "    ${WHITE}./deploy.sh my-service --env staging${RESET}"
    echo ""
    echo -e "    ${GRAY}# Rollback to previous version${RESET}"
    echo -e "    ${WHITE}./deploy.sh my-service --rollback${RESET}"
    echo ""
    echo -e "    ${GRAY}# Deploy locally on server (no SSH needed)${RESET}"
    echo -e "    ${WHITE}./deploy.sh my-service --local${RESET}"
    echo ""
    echo -e "${BOLD}${YELLOW}CONFIG LOCATIONS${RESET} (in order of priority)"
    echo -e "    1. ${CYAN}--config FILE${RESET}           Custom path"
    echo -e "    2. ${CYAN}./deploy.env${RESET}            Per-project config"
    echo -e "    3. ${CYAN}~/.config/shipctl/${RESET}   Global user config"
    echo -e "    4. ${CYAN}DEPLOY_ROOT/config/${RESET}     Installation default"
    echo ""
    echo -e "${BOLD}${YELLOW}ENVIRONMENT${RESET}"
    echo -e "    ${CYAN}DOCKERHUB_USERNAME${RESET}  DockerHub username ${RED}(required)${RESET}"
    echo -e "    ${CYAN}DOCKERHUB_PASSWORD${RESET}  DockerHub password/token ${RED}(required)${RESET}"
    echo ""
    echo -e "    ${GRAY}Configure credentials in .env file or export as environment variables.${RESET}"
    echo ""
}

#------------------------------------------------------------------------------
# Show version
#------------------------------------------------------------------------------
show_version() {
    echo "shipctl version ${VERSION}"
}

#------------------------------------------------------------------------------
# Helper: Convert string to uppercase (bash 3.x compatible)
#------------------------------------------------------------------------------
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

#------------------------------------------------------------------------------
# List available services
#------------------------------------------------------------------------------
list_available_services() {
    local project_name="${PROJECT_NAME:-Deploy CLI}"
    print_header "${project_name} - AVAILABLE SERVICES"
    
    local config_file="${DEPLOY_ROOT}/config/services.env"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        log_info "Please copy config/services.env.template to config/services.env and configure it."
        exit 1
    fi
    
    source "$config_file"
    
    echo -e "${BOLD}Services:${RESET}"
    echo ""
    
    IFS=',' read -ra services <<< "$SERVICES"
    for service in "${services[@]}"; do
        local upper_service
        upper_service=$(to_upper "$service")
        local image_var="${upper_service}_IMAGE"
        local image="${!image_var:-unknown}"
        
        printf "  ${GREEN}%-20s${RESET} %s\n" "$service" "$image"
    done
    
    echo ""
    echo -e "${GRAY}Use: ./deploy.sh <service> to deploy${RESET}"
}

#------------------------------------------------------------------------------
# Resolve configuration file path
# Priority: 1. --config flag  2. ./deploy.env  3. ~/.config/shipctl/  4. DEPLOY_ROOT/config/
#------------------------------------------------------------------------------
resolve_config_path() {
    local config_file=""
    
    # 1. Custom config via --config flag or DEPLOY_CONFIG env
    if [[ -n "$CUSTOM_CONFIG" ]]; then
        if [[ -f "$CUSTOM_CONFIG" ]]; then
            echo "$CUSTOM_CONFIG"
            return 0
        else
            log_error "Config file not found: $CUSTOM_CONFIG"
            return 1
        fi
    fi
    
    # 2. Per-project config in current directory
    if [[ -f "./deploy.env" ]]; then
        echo "./deploy.env"
        return 0
    fi
    
    # 3. Global user config
    if [[ -f "${CONFIG_DIR}/services.env" ]]; then
        echo "${CONFIG_DIR}/services.env"
        return 0
    fi
    
    # 4. Default: DEPLOY_ROOT/config (for development/manual installs)
    if [[ -f "${DEPLOY_ROOT}/config/services.env" ]]; then
        echo "${DEPLOY_ROOT}/config/services.env"
        return 0
    fi
    
    # No config found
    return 1
}

#------------------------------------------------------------------------------
# Load configuration
#------------------------------------------------------------------------------
load_config() {
    local config_file
    config_file=$(resolve_config_path)
    
    if [[ $? -ne 0 ]] || [[ -z "$config_file" ]]; then
        log_error "No configuration file found"
        echo ""
        echo "Create a config file in one of these locations:"
        echo "  1. ./deploy.env                    (per-project)"
        echo "  2. ${CONFIG_DIR}/services.env      (global)"
        echo "  3. ${DEPLOY_ROOT}/config/services.env"
        echo ""
        echo "Or run: deploy init"
        exit 1
    fi
    
    local config_dir
    config_dir=$(dirname "$config_file")
    
    # Load main .env if exists (check multiple locations)
    local env_file=""
    if [[ -f "${config_dir}/.env" ]]; then
        env_file="${config_dir}/.env"
    elif [[ -f "./.env" ]]; then
        env_file="./.env"
    elif [[ -f "${DEPLOY_ROOT}/.env" ]]; then
        env_file="${DEPLOY_ROOT}/.env"
    fi
    
    if [[ -n "$env_file" ]]; then
        log_info "Loading credentials from $(basename "$env_file")"
        load_env_file "$env_file"
    fi
    
    # Load environment-specific .env if exists
    local env_specific_file="${config_dir}/.env.${ENVIRONMENT}"
    if [[ -f "$env_specific_file" ]]; then
        log_info "Loading environment: ${ENVIRONMENT}"
        load_env_file "$env_specific_file"
    fi
    
    log_info "Using config: $config_file"
    source "$config_file"
}

#------------------------------------------------------------------------------
# Get service configuration
#------------------------------------------------------------------------------
get_service_var() {
    local service="$1"
    local var_suffix="$2"
    
    local upper_service
    upper_service=$(to_upper "$service")
    local var_name="${upper_service}_${var_suffix}"
    
    echo "${!var_name:-}"
}

#------------------------------------------------------------------------------
# Deploy a single service
#------------------------------------------------------------------------------
deploy_service() {
    local service="$1"
    local tag="$2"
    
    # Get service config
    local image
    image=$(get_service_var "$service" "IMAGE")
    local service_name
    service_name=$(get_service_var "$service" "SERVICE_NAME")
    local container_name
    container_name=$(get_service_var "$service" "CONTAINER_NAME")
    local directory
    directory=$(get_service_var "$service" "DIRECTORY")
    local git_url
    git_url=$(get_service_var "$service" "GIT_URL")
    local git_ref
    git_ref=$(get_service_var "$service" "GIT_REF")
    local git_subdir
    git_subdir=$(get_service_var "$service" "GIT_SUBDIR")
    local build_args_str
    build_args_str=$(get_service_var "$service" "BUILD_ARGS")
    local env_file
    env_file=$(get_service_var "$service" "ENV_FILE")
    local health_type
    health_type=$(get_service_var "$service" "HEALTH_TYPE")
    local health_port
    health_port=$(get_service_var "$service" "HEALTH_PORT")
    local health_path
    health_path=$(get_service_var "$service" "HEALTH_PATH")
    
    # Validate config
    if [[ -z "$image" || -z "$service_name" ]]; then
        log_error "Service '$service' not properly configured"
        return 1
    fi
    
    # Resolve build directory
    # Priority: DIRECTORY (folder) takes precedence over GIT_URL
    if [[ -n "$directory" ]]; then
        # Folder mode - use local directory
        if [[ "$directory" != /* ]]; then
            directory=$(cd "${DEPLOY_ROOT}" && cd "${directory}" 2>/dev/null && pwd)
            if [[ -z "$directory" ]]; then
                directory="${DEPLOY_ROOT}/${directory}"
            fi
        fi
    elif [[ -n "$git_url" ]]; then
        # Git mode - clone repository first
        local git_result
        git_result=$(prepare_git_repo "$service" "$git_url" "$git_ref" "$git_subdir")
        if [[ $? -ne 0 ]]; then
            log_error "Failed to prepare Git repository"
            return 1
        fi
        directory="$git_result"
    else
        # Default to DEPLOY_ROOT if nothing specified
        directory="${DEPLOY_ROOT}"
    fi
    
    print_section "DEPLOYING: ${service}"
    
    print_status "Image" "$image"
    print_status "Tag" "$tag"
    print_status "Service" "$service_name"
    print_status "Container" "$container_name"
    print_status "Directory" "$directory"
    print_status "Environment" "$ENVIRONMENT" "$YELLOW"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        print_status "Mode" "LOCAL (no SSH)" "$GREEN"
    else
        print_status "Mode" "REMOTE via SSH" "$CYAN"
    fi
    
    echo ""
    
    # Dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${MAGENTA}⚡ DRY-RUN MODE - No changes will be made${RESET}"
        echo ""
        
        if [[ "$SKIP_BUILD" != "true" ]]; then
            docker_build_dry_run "$image" "$tag" "$directory" "Dockerfile"
        fi
        
        if [[ "$SKIP_DEPLOY" != "true" ]]; then
            ssh_deploy_dry_run "$REMOTE_HOST" "$REMOTE_COMPOSE_DIR" "$image" "$tag" "$service_name" "$LOCAL_MODE"
        fi
        
        return 0
    fi
    
    # Pre-flight checks
    if [[ "$SKIP_CHECKS" != "true" ]]; then
        if ! run_preflight_checks "$directory" "false" "$git_url"; then
            log_error "Pre-flight checks failed"
            return 1
        fi
    fi
    
    # Confirmation
    if [[ "$SKIP_CONFIRM" != "true" && "$ENVIRONMENT" == "production" ]]; then
        echo ""
        echo -e "${YELLOW}${ICON_WARN}${RESET} ${BOLD}You are deploying to PRODUCTION${RESET}"
        if ! confirm "Continue with deployment?"; then
            log_info "Deployment cancelled"
            return 0
        fi
    fi
    
    # Get current tag for rollback
    local current_tag=""
    if [[ "$ROLLBACK" != "true" ]]; then
        if [[ "$LOCAL_MODE" == "true" ]]; then
            current_tag=$(local_get_current_tag "$container_name" 2>/dev/null || echo "")
        else
            current_tag=$(ssh_get_current_tag "$REMOTE_HOST" "$REMOTE_USER" "$SSH_KEY" "$container_name" 2>/dev/null || echo "")
        fi
        if [[ -n "$current_tag" ]]; then
            log_info "Current running tag: $current_tag (saved for rollback)"
            echo "$current_tag" > "${DEPLOY_ROOT}/.deploy-backups/${service}.last"
        fi
    fi
    
    local start_time
    start_time=$(date +%s)
    
    # Build & Push
    if [[ "$SKIP_BUILD" != "true" ]]; then
        print_section "BUILD & PUSH"
        
        # Load service-specific env file if specified
        if [[ -n "$env_file" && -f "${directory}/${env_file}" ]]; then
            log_info "Loading build environment from ${env_file}"
            load_env_file "${directory}/${env_file}"
        fi
        
        # Parse build args
        local build_args=()
        if [[ -n "$build_args_str" ]]; then
            IFS=',' read -ra arg_names <<< "$build_args_str"
            for arg_name in "${arg_names[@]}"; do
                arg_name=$(echo "$arg_name" | xargs)  # trim
                local arg_value="${!arg_name:-}"
                if [[ -n "$arg_value" ]]; then
                    build_args+=("${arg_name}=${arg_value}")
                fi
            done
        fi
        
        # Build
        if ! docker_build "$image" "$tag" "$directory" "Dockerfile" "${build_args[@]}"; then
            log_error "Build failed"
            return 1
        fi
        
        # Push
        if ! docker_push "$image" "$tag"; then
            log_error "Push failed"
            return 1
        fi
    fi
    
    # Deploy
    if [[ "$SKIP_DEPLOY" != "true" ]]; then
        print_section "DEPLOY"
        
        if [[ "$LOCAL_MODE" == "true" ]]; then
            # Local deployment (no SSH)
            if ! local_deploy "$REMOTE_COMPOSE_DIR" "$image" "$tag" "$service_name" "$container_name"; then
                log_error "Local deployment failed"
                return 1
            fi
        else
            # Remote deployment via SSH
            if ! ssh_deploy "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_COMPOSE_DIR" "$SSH_KEY" \
                           "$image" "$tag" "$service_name" "$container_name"; then
                log_error "Deployment failed"
                return 1
            fi
        fi
        
        # Health check
        if [[ -n "$health_type" && -n "$health_port" ]]; then
            print_section "HEALTH CHECK"
            
            if [[ "$LOCAL_MODE" == "true" ]]; then
                # Local health check
                case "$health_type" in
                    http)
                        local_health_check_http "$health_port" "${health_path:-/health}" 30 || true
                        ;;
                    tcp)
                        local_health_check_tcp "$health_port" 30 || true
                        ;;
                esac
            else
                # Remote health check
                case "$health_type" in
                    http)
                        ssh_health_check_http "$REMOTE_HOST" "$REMOTE_USER" "$SSH_KEY" \
                                             "$health_port" "${health_path:-/health}" 30 "$container_name" || true
                        ;;
                    tcp)
                        ssh_health_check_tcp "$REMOTE_HOST" "$REMOTE_USER" "$SSH_KEY" \
                                            "$health_port" 30 || true
                        ;;
                esac
            fi
        fi
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_done "Deployment completed in $(relative_time $duration)"
    print_status "Image" "${image}:${tag}"
    if [[ -n "$current_tag" ]]; then
        print_status "Previous" "$current_tag" "$GRAY"
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Rollback a service
#------------------------------------------------------------------------------
rollback_service() {
    local service="$1"
    
    # Get service config
    local image
    image=$(get_service_var "$service" "IMAGE")
    local service_name
    service_name=$(get_service_var "$service" "SERVICE_NAME")
    local container_name
    container_name=$(get_service_var "$service" "CONTAINER_NAME")
    
    # Get rollback tag
    local rollback_tag=""
    local backup_file="${DEPLOY_ROOT}/.deploy-backups/${service}.last"
    
    if [[ -f "$backup_file" ]]; then
        rollback_tag=$(cat "$backup_file")
    fi
    
    if [[ -z "$rollback_tag" ]]; then
        log_error "No previous version found for rollback"
        log_info "Backup file not found: $backup_file"
        return 1
    fi
    
    print_section "ROLLBACK: ${service}"
    
    print_status "Image" "$image"
    print_status "Rollback to" "$rollback_tag" "$YELLOW"
    print_status "Service" "$service_name"
    
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${MAGENTA}⚡ DRY-RUN MODE - No changes will be made${RESET}"
        ssh_deploy_dry_run "$REMOTE_HOST" "$REMOTE_COMPOSE_DIR" "$image" "$rollback_tag" "$service_name"
        return 0
    fi
    
    if [[ "$SKIP_CONFIRM" != "true" ]]; then
        if ! confirm "Rollback to ${rollback_tag}?"; then
            log_info "Rollback cancelled"
            return 0
        fi
    fi
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        # Local rollback (no SSH)
        if ! local_rollback "$REMOTE_COMPOSE_DIR" "$image" "$rollback_tag" "$service_name" "$container_name"; then
            log_error "Local rollback failed"
            return 1
        fi
    else
        # Remote rollback via SSH
        if ! ssh_rollback "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_COMPOSE_DIR" "$SSH_KEY" \
                         "$image" "$rollback_tag" "$service_name" "$container_name"; then
            log_error "Rollback failed"
            return 1
        fi
    fi
    
    log_done "Rollback completed: ${image}:${rollback_tag}"
    return 0
}

#------------------------------------------------------------------------------
# Initialize configuration
#------------------------------------------------------------------------------
cmd_init() {
    local target_dir="."
    local target_file="deploy.env"
    local global_mode=false
    
    echo ""
    echo -e "${BOLD}shipctl - Configuration Setup${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if config already exists
    if [[ -f "./${target_file}" ]]; then
        log_warn "Config already exists: ./${target_file}"
        if ! confirm "Overwrite existing config?"; then
            log_info "Cancelled"
            return 0
        fi
    fi
    
    # Create config from template
    local template="${DEPLOY_ROOT}/config/services.env.template"
    
    if [[ ! -f "$template" ]]; then
        log_error "Template not found: $template"
        return 1
    fi
    
    # Copy template
    cp "$template" "./${target_file}"
    
    log_success "Created: ./${target_file}"
    echo ""
    echo -e "${BOLD}Next steps:${RESET}"
    echo ""
    echo "  1. Edit the configuration:"
    echo -e "     ${CYAN}nano ./${target_file}${RESET}"
    echo ""
    echo "  2. Create credentials file:"
    echo -e "     ${CYAN}cp ${DEPLOY_ROOT}/.env.template ./.env${RESET}"
    echo -e "     ${CYAN}nano ./.env${RESET}"
    echo ""
    echo "  3. Run a deployment:"
    echo -e "     ${CYAN}deploy frontend --dry-run${RESET}"
    echo ""
    
    # Optionally create global config
    echo -e "${GRAY}Tip: For global config, run:${RESET}"
    echo -e "     ${CYAN}mkdir -p ${CONFIG_DIR} && cp ./${target_file} ${CONFIG_DIR}/services.env${RESET}"
    echo ""
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    local services=()
    local deploy_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -l|--list)
                load_config
                list_available_services
                exit 0
                ;;
            -a|--all)
                deploy_all=true
                shift
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--tag)
                CUSTOM_TAG="$2"
                shift 2
                ;;
            -c|--config)
                CUSTOM_CONFIG="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRM=true
                shift
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            --build-only)
                SKIP_DEPLOY=true
                shift
                ;;
            --deploy-only)
                SKIP_BUILD=true
                shift
                ;;
            --rollback)
                ROLLBACK=true
                shift
                ;;
            --no-logs)
                SHOW_LOGS=false
                shift
                ;;
            --local)
                LOCAL_MODE=true
                shift
                ;;
            init)
                cmd_init
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                services+=("$1")
                shift
                ;;
        esac
    done
    
    # Load configuration first (to get PROJECT_NAME)
    load_config
    
    # Show header with project name
    local project_name="${PROJECT_NAME:-Deploy CLI}"
    print_header "${project_name} DEPLOY v${VERSION}"
    
    # Create backup directory
    mkdir -p "${DEPLOY_ROOT}/.deploy-backups"
    
    # Validate --deploy-only requires --tag
    if [[ "$SKIP_BUILD" == "true" && -z "$CUSTOM_TAG" ]]; then
        log_error "--deploy-only requires --tag to be specified"
        exit 1
    fi
    
    # Get services to deploy
    if [[ "$deploy_all" == "true" ]]; then
        IFS=',' read -ra services <<< "$SERVICES"
    fi
    
    if [[ ${#services[@]} -eq 0 ]]; then
        log_error "No services specified"
        echo ""
        echo "Usage: ./deploy.sh [OPTIONS] [SERVICE...]"
        echo "       ./deploy.sh --list    # to see available services"
        echo "       ./deploy.sh --help    # for more information"
        exit 1
    fi
    
    # Validate services
    IFS=',' read -ra available_services <<< "$SERVICES"
    for service in "${services[@]}"; do
        local found=false
        for available in "${available_services[@]}"; do
            if [[ "$service" == "$available" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != "true" ]]; then
            log_error "Unknown service: $service"
            log_info "Available services: ${SERVICES}"
            exit 1
        fi
    done
    
    # Determine tag
    local tag="${CUSTOM_TAG:-$(get_git_sha)}"
    
    # Show deployment info
    print_status "Services" "${services[*]}"
    print_status "Environment" "$ENVIRONMENT"
    print_status "Tag" "$tag"
    print_status "Mode" "$(if [[ "$DRY_RUN" == "true" ]]; then echo 'DRY-RUN'; elif [[ "$ROLLBACK" == "true" ]]; then echo 'ROLLBACK'; else echo 'DEPLOY'; fi)"
    
    echo ""
    
    # Deploy each service
    local failed=0
    for service in "${services[@]}"; do
        if [[ "$ROLLBACK" == "true" ]]; then
            rollback_service "$service" || ((failed++))
        else
            deploy_service "$service" "$tag" || ((failed++))
        fi
    done
    
    # Summary
    echo ""
    print_divider
    
    if ((failed > 0)); then
        log_error "Deployment completed with ${failed} error(s)"
        exit 1
    else
        log_done "All deployments completed successfully!"
    fi
}

# Run main
main "$@"
