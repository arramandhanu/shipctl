#!/usr/bin/env bash
#==============================================================================
# GIT.SH - Git repository operations for deployment
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

# Default cache directory
GIT_CACHE_DIR="${DEPLOY_ROOT:-.}/.git-cache"

#------------------------------------------------------------------------------
# Check if a string is a Git URL
#------------------------------------------------------------------------------
is_git_url() {
    local url="$1"
    
    # Match common Git URL patterns
    # - https://github.com/user/repo.git
    # - git@github.com:user/repo.git
    # - ssh://git@github.com/user/repo.git
    # - git://github.com/user/repo.git
    if [[ "$url" =~ ^https?:// ]] || \
       [[ "$url" =~ ^git@ ]] || \
       [[ "$url" =~ ^ssh:// ]] || \
       [[ "$url" =~ ^git:// ]] || \
       [[ "$url" =~ \.git$ ]]; then
        return 0
    fi
    return 1
}

#------------------------------------------------------------------------------
# Get cache directory for a service
#------------------------------------------------------------------------------
get_cache_dir() {
    local service="$1"
    echo "${GIT_CACHE_DIR}/${service}"
}

#------------------------------------------------------------------------------
# Clone or update a Git repository
#------------------------------------------------------------------------------
git_clone_or_update() {
    local git_url="$1"
    local target_dir="$2"
    local git_ref="${3:-}"
    
    if [[ -d "${target_dir}/.git" ]]; then
        log_info "Updating existing repository: ${target_dir}"
        
        if ! git -C "$target_dir" fetch --all --prune 2>&1; then
            log_error "Failed to fetch updates"
            return 1
        fi
        
        # Reset to clean state
        git -C "$target_dir" reset --hard HEAD >/dev/null 2>&1
        git -C "$target_dir" clean -fd >/dev/null 2>&1
        
        if [[ -n "$git_ref" ]]; then
            if ! git -C "$target_dir" checkout "$git_ref" 2>&1; then
                log_error "Failed to checkout: $git_ref"
                return 1
            fi
            
            # If it's a branch, pull latest
            if git -C "$target_dir" rev-parse --verify "origin/${git_ref}" >/dev/null 2>&1; then
                git -C "$target_dir" pull origin "$git_ref" >/dev/null 2>&1 || true
            fi
        fi
        
        log_success "Repository updated"
    else
        log_info "Cloning repository: ${git_url}"
        
        # Create parent directory
        mkdir -p "$(dirname "$target_dir")"
        
        # Clone with specific branch if provided
        local clone_cmd=(git clone)
        if [[ -n "$git_ref" ]]; then
            clone_cmd+=(--branch "$git_ref")
        fi
        clone_cmd+=("$git_url" "$target_dir")
        
        if ! "${clone_cmd[@]}" 2>&1; then
            log_error "Failed to clone repository"
            return 1
        fi
        
        log_success "Repository cloned"
    fi
    
    # Show current commit
    local commit_hash
    commit_hash=$(git -C "$target_dir" rev-parse --short HEAD 2>/dev/null)
    local commit_msg
    commit_msg=$(git -C "$target_dir" log -1 --format="%s" 2>/dev/null | head -c 50)
    
    if [[ -n "$commit_hash" ]]; then
        log_info "Commit: ${commit_hash} - ${commit_msg}"
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Prepare Git repository for build
# Returns the directory path to use for building
#------------------------------------------------------------------------------
prepare_git_repo() {
    local service="$1"
    local git_url="$2"
    local git_ref="${3:-}"
    local git_subdir="${4:-}"
    
    local cache_dir
    cache_dir=$(get_cache_dir "$service")
    
    print_subsection "GIT REPOSITORY"
    print_status "URL" "$git_url"
    [[ -n "$git_ref" ]] && print_status "Ref" "$git_ref"
    [[ -n "$git_subdir" ]] && print_status "Subdirectory" "$git_subdir"
    echo ""
    
    # Clone or update
    if ! git_clone_or_update "$git_url" "$cache_dir" "$git_ref"; then
        return 1
    fi
    
    # Resolve final build directory
    local build_dir="$cache_dir"
    if [[ -n "$git_subdir" ]]; then
        build_dir="${cache_dir}/${git_subdir}"
        if [[ ! -d "$build_dir" ]]; then
            log_error "Subdirectory not found: $git_subdir"
            return 1
        fi
    fi
    
    # Verify Dockerfile exists
    if [[ ! -f "${build_dir}/Dockerfile" ]]; then
        log_error "Dockerfile not found in: $build_dir"
        return 1
    fi
    
    echo "$build_dir"
    return 0
}

#------------------------------------------------------------------------------
# Clean Git cache for a service
#------------------------------------------------------------------------------
clean_git_cache() {
    local service="$1"
    local cache_dir
    cache_dir=$(get_cache_dir "$service")
    
    if [[ -d "$cache_dir" ]]; then
        log_info "Cleaning Git cache: $cache_dir"
        rm -rf "$cache_dir"
        log_success "Cache cleaned"
    fi
}

#------------------------------------------------------------------------------
# Clean all Git cache
#------------------------------------------------------------------------------
clean_all_git_cache() {
    if [[ -d "$GIT_CACHE_DIR" ]]; then
        log_info "Cleaning all Git cache: $GIT_CACHE_DIR"
        rm -rf "$GIT_CACHE_DIR"
        log_success "All cache cleaned"
    fi
}

#------------------------------------------------------------------------------
# Validate Git URL accessibility
#------------------------------------------------------------------------------
check_git_url() {
    local git_url="$1"
    
    if ! is_git_url "$git_url"; then
        log_error "Invalid Git URL format: $git_url"
        return 1
    fi
    
    # Check if git command is available
    if ! command -v git &>/dev/null; then
        log_error "Git command not found"
        return 1
    fi
    
    # Test repository access (ls-remote is lightweight)
    log_info "Checking repository access: $git_url"
    if ! git ls-remote --exit-code "$git_url" HEAD &>/dev/null; then
        log_error "Cannot access repository: $git_url"
        log_info "Check URL and credentials (SSH key or HTTPS token)"
        return 1
    fi
    
    log_success "Repository accessible"
    return 0
}
