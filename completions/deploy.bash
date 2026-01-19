#!/usr/bin/env bash
#==============================================================================
# DEPLOY CLI - SHELL AUTOCOMPLETION
#
# Installation:
#   Bash:  source /path/to/deploy-cli/completions/deploy.bash
#   Zsh:   source /path/to/deploy-cli/completions/deploy.bash
#
# Add to your shell profile (~/.bashrc, ~/.zshrc) for persistent completion.
#==============================================================================

_deploy_completions() {
    local cur prev opts services config_file deploy_root
    
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Find deploy root (where deploy.sh is located)
    deploy_root=""
    for word in "${COMP_WORDS[@]}"; do
        if [[ "$word" == *deploy.sh ]]; then
            deploy_root=$(dirname "$word")
            break
        fi
    done
    
    # Fallback: check current directory
    if [[ -z "$deploy_root" && -f "./deploy.sh" ]]; then
        deploy_root="."
    fi
    
    # All available options
    opts="-h --help -v --version -l --list -a --all -e --env -t --tag -n --dry-run -y --yes --skip-checks --build-only --deploy-only --rollback --no-logs --local"
    
    # Handle option arguments
    case "${prev}" in
        -e|--env)
            COMPREPLY=( $(compgen -W "staging production development" -- "${cur}") )
            return 0
            ;;
        -t|--tag)
            # Suggest git tags or recent commits
            if command -v git &>/dev/null; then
                local tags=$(git tag -l 2>/dev/null | head -20)
                local commits=$(git log --oneline -10 2>/dev/null | awk '{print $1}')
                COMPREPLY=( $(compgen -W "${tags} ${commits}" -- "${cur}") )
            fi
            return 0
            ;;
    esac
    
    # If current word starts with dash, complete options
    if [[ "${cur}" == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi
    
    # Try to load services from config
    services=""
    config_file="${deploy_root}/config/services.env"
    
    if [[ -f "$config_file" ]]; then
        services=$(grep -E "^SERVICES=" "$config_file" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr ',' ' ')
    fi
    
    # Fallback services if config not found
    if [[ -z "$services" ]]; then
        services="frontend backend api"
    fi
    
    # Complete service names
    COMPREPLY=( $(compgen -W "${services}" -- "${cur}") )
    return 0
}

# Register completion for deploy.sh and common invocation patterns
complete -F _deploy_completions deploy.sh
complete -F _deploy_completions ./deploy.sh

# Also register for 'deploy' if user has aliased it
complete -F _deploy_completions deploy
