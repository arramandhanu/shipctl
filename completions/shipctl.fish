# shipctl Fish Shell Completions
#
# Installation:
#   cp completions/shipctl.fish ~/.config/fish/completions/

# Disable file completions by default
complete -c shipctl -f

# Subcommands
complete -c shipctl -n "__fish_use_subcommand" -a "init" -d "Initialize configuration"

# General options
complete -c shipctl -s h -l help    -d "Show help message"
complete -c shipctl -s v -l version -d "Show version"
complete -c shipctl -s l -l list    -d "List available services"
complete -c shipctl -s a -l all     -d "Deploy all services"
complete -c shipctl -s n -l dry-run -d "Preview without changes"
complete -c shipctl -s y -l yes     -d "Skip confirmation prompts"

# Options with arguments
complete -c shipctl -s e -l env    -x -a "staging production development" -d "Target environment"
complete -c shipctl -s t -l tag    -x -d "Docker image tag"
complete -c shipctl -s c -l config -r -d "Custom config file"

# Orchestrator & provider
complete -c shipctl -l orchestrator -x -a "compose swarm kubernetes k8s" -d "Container orchestrator"
complete -c shipctl -l provider     -x -a "local aws gcp azure alibaba"  -d "Cloud provider"
complete -c shipctl -l stack        -x -d "Stack name (Swarm)"
complete -c shipctl -l cluster      -x -d "Kubernetes cluster"

# Flags
complete -c shipctl -l skip-checks  -d "Skip pre-flight checks"
complete -c shipctl -l build-only   -d "Build only, do not deploy"
complete -c shipctl -l deploy-only  -d "Deploy only, do not build"
complete -c shipctl -l rollback     -d "Rollback to previous version"
complete -c shipctl -l no-logs      -d "Disable log output"
complete -c shipctl -l local        -d "Local mode (no SSH)"
complete -c shipctl -l verbose      -d "Enable verbose output"

# Dynamic: suggest git tags for --tag
complete -c shipctl -l tag -a "(git tag -l 2>/dev/null | head -20)"

# Dynamic: suggest kubectl contexts for --cluster
complete -c shipctl -l cluster -a "(kubectl config get-contexts -o name 2>/dev/null)"
