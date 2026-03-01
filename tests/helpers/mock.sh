#!/usr/bin/env bash
#==============================================================================
# Test Mock Helpers
#
# Provides utilities for mocking external commands in tests.
#==============================================================================

# Create a mock command that returns a specific output/exit code
mock_command() {
    local cmd_name="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    
    local mock_dir="/tmp/shipctl-test-mocks"
    mkdir -p "$mock_dir"
    
    cat > "${mock_dir}/${cmd_name}" <<EOF
#!/usr/bin/env bash
echo "$output"
exit $exit_code
EOF
    chmod +x "${mock_dir}/${cmd_name}"
    
    # Prepend mock dir to PATH
    export PATH="${mock_dir}:${PATH}"
}

# Remove all mock commands
cleanup_mocks() {
    rm -rf /tmp/shipctl-test-mocks
}

# Create a temporary directory for tests
create_test_dir() {
    local dir
    dir=$(mktemp -d /tmp/shipctl-test-XXXXXX)
    echo "$dir"
}

# Clean up temporary test directory
cleanup_test_dir() {
    local dir="$1"
    [[ -d "$dir" ]] && rm -rf "$dir"
}

# Create a temporary config file
create_test_config() {
    local dir="$1"
    local content="${2:-}"
    
    local config_file="${dir}/deploy.env"
    
    if [[ -n "$content" ]]; then
        echo "$content" > "$config_file"
    else
        cat > "$config_file" <<'EOF'
PROJECT_NAME="Test Project"
SERVICES="frontend,backend"
FRONTEND_IMAGE="test/frontend"
FRONTEND_SERVICE_NAME="frontend"
BACKEND_IMAGE="test/backend"
BACKEND_SERVICE_NAME="backend"
EOF
    fi
    
    echo "$config_file"
}
