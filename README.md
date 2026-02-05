<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/bash-4.0+-green.svg?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/docker-required-2496ED.svg?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/license-MIT-brightgreen.svg?style=for-the-badge" alt="License">
</p>

<h1 align="center">🚀 shipctl</h1>

<p align="center">
  <strong>Professional Docker Deployment Automation Tool</strong>
</p>

<p align="center">
  A unified, configurable CLI tool for deploying Docker-based microservices with automated pre-flight checks, multi-environment support, rollback capability, and CI/CD integration.
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-configuration">Configuration</a>
</p>

---

## ✨ Features

| Feature | Description |
|:--------|:------------|
| 🎯 **Unified CLI** | Single `shipctl` command for all deployment operations |
| 📦 **Multi-Service** | Deploy one, multiple, or all services at once |
| 🔧 **Flexible Config** | Per-project, global, or custom config paths |
| 🔍 **Pre-flight Checks** | Validates Docker, SSH, Git before any deployment |
| 👀 **Dry-Run Mode** | Preview changes without executing anything |
| ⏪ **Rollback** | Instantly revert to the previous deployed version |
| 🌍 **Multi-Environment** | Support for staging, production, or custom environments |
| 🏥 **Health Checks** | HTTP and TCP verification after deployment |
| 📂 **Git Repository Support** | Clone and build from Git URLs (SSH or HTTPS) |
| ⌨️ **Tab Autocompletion** | Shell completion for commands, options, and services |
| 🎨 **Beautiful Output** | Colored terminal UI with status icons |
| 🐳 **Multi-Orchestration** | Docker Compose, Docker Swarm, and Kubernetes |
| ☁️ **Cloud Providers** | AWS ECS, GCP Cloud Run, Azure ACI, Alibaba ECI |

---

## 📦 Installation

### Homebrew (Recommended)

```bash
brew install arramandhanu/tap/shipctl
```

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/arramandhanu/shipctl/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/arramandhanu/shipctl.git
cd shipctl
chmod +x shipctl
ln -s $(pwd)/shipctl /usr/local/bin/shipctl
```

---

## 🚀 Quick Start

### 1. Initialize Config

```bash
cd /path/to/your/project
shipctl init
```

This creates `deploy.env` in your project directory.

### 2. Configure Services

```bash
nano deploy.env
```

Key settings:
```bash
PROJECT_NAME="My Project"
REMOTE_HOST="your-server-ip"
REMOTE_USER="deploy"
SERVICES="frontend,backend,api"

FRONTEND_IMAGE="yourname/myproject-frontend"
FRONTEND_SERVICE_NAME="frontend"
FRONTEND_DIRECTORY="../frontend"
```

### 3. Set Credentials

```bash
# Create .env in your project
cat > .env << EOF
DOCKERHUB_USERNAME=your_username
DOCKERHUB_PASSWORD=your_access_token
EOF
```

### 4. Enable Tab Completion (Optional)

```bash
# Add to ~/.bashrc or ~/.zshrc
source /path/to/shipctl/completions/shipctl.bash
```

### 5. Deploy!

```bash
# Preview first
shipctl frontend --dry-run

# Deploy
shipctl frontend
```

### 3. Deploy!

```bash
# Standard Docker Compose (via SSH)
shipctl frontend

# Docker Swarm
shipctl frontend --orchestrator swarm

# Kubernetes
shipctl frontend --orchestrator kubernetes

# AWS ECS
shipctl frontend --provider aws --cluster my-cluster

# GCP Cloud Run
shipctl frontend --provider gcp
```

## 📖 Cloud Providers

### AWS
Requires `aws-cli`.
```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1

shipctl my-service --provider aws
```

### Google Cloud (GCP)
Requires `gcloud`.
```bash
export GCP_PROJECT_ID=my-project
export GOOGLE_APPLICATION_CREDENTIALS=...

shipctl my-service --provider gcp
```

### Azure
Requires `az`.
```bash
export AZURE_SUBSCRIPTION_ID=...

shipctl my-service --provider azure
```

---

## 📖 Usage

### Basic Commands

```bash
# Show help
shipctl --help

# List available services
shipctl --list

# Deploy a single service
shipctl frontend

# Deploy multiple services
shipctl frontend backend api

# Deploy all configured services
shipctl --all
```

### Deployment Options

```bash
# Preview what would happen
shipctl frontend --dry-run

# Deploy to staging
shipctl frontend --env staging

# Deploy with custom tag
shipctl frontend --tag v1.2.3

# Use custom config file
shipctl --config /path/to/config.env frontend

# Rollback to previous version
shipctl frontend --rollback
```

### Deployment Modes

| Mode | Command | Description |
|:-----|:--------|:------------|
| **Remote** (default) | `shipctl frontend` | Deploy via SSH to server |
| **Local** | `shipctl frontend --local` | Run directly on server |

---

## ⚙️ Configuration

### Config Locations (Priority Order)

| Priority | Location | Use Case |
|:---------|:---------|:---------|
| 1 | `--config FILE` | Custom path via flag |
| 2 | `./deploy.env` | Per-project config |
| 3 | `~/.config/shipctl/` | User global config |
| 4 | `/etc/shipctl/` | System-wide (Linux) |
| 5 | Installation default | Development only |



### Service Configuration

| Variable | Required | Description |
|:---------|:--------:|:------------|
| `{SERVICE}_IMAGE` | ✅ | Docker image name |
| `{SERVICE}_SERVICE_NAME` | ✅ | Service name in docker-compose |
| `{SERVICE}_DIRECTORY` | ❌ | Path to Dockerfile (folder mode) |
| `{SERVICE}_GIT_URL` | ❌ | Git repository URL (Git mode) |
| `{SERVICE}_GIT_REF` | ❌ | Branch, tag, or commit |
| `{SERVICE}_BUILD_ARGS` | ❌ | Comma-separated build args |
| `{SERVICE}_HEALTH_TYPE` | ❌ | `http` or `tcp` |
| `{SERVICE}_HEALTH_PORT` | ❌ | Port for health check |

---

## 🔄 CI/CD Integration

Pre-configured workflows available for:
- **GitHub Actions** (`.github/workflows/deploy.yml`)
- **GitLab CI** (`.gitlab-ci.yml`)
- **Bitbucket Pipelines** (`bitbucket-pipelines.yml`)

---

## 🧪 Testing

Run the test suite to verify all modules:

```bash
# Run all tests
./tests/run_tests.sh

# Syntax checks only
./tests/run_tests.sh --syntax

# Unit tests only
./tests/run_tests.sh --unit
```

Tests include:
- Syntax verification for all orchestrator and provider modules
- Function existence checks
- CLI help validation
- Configuration template verification

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ❤️ by <a href="https://github.com/arramandhanu">Arya Ramandhanu</a></sub>
</p>
