# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Behavioral unit tests for core modules
- Test fixtures and mock helpers

## [0.0.1] - 2026-03-02

### Added
- Multi-service deployment with single `shipctl` command
- Pre-flight checks (Docker, SSH, Git, Dockerfile, disk space)
- Dry-run mode for previewing deployments
- Rollback capability to previous versions
- Multi-environment support (staging, production, custom)
- HTTP and TCP health checks after deployment
- Git repository URL support (SSH/HTTPS, branch/tag/commit, monorepo subdirectory)
- Flexible configuration system
  - Per-project config (`./deploy.env`)
  - Global user config (`~/.config/shipctl/`)
  - System-wide config (`/etc/shipctl/`)
  - Custom config path (`--config` flag)
  - `shipctl init` command for setup
- Shell autocompletion for Bash and Zsh
- Local deployment mode (no SSH required)
- Multi-orchestration support
  - Docker Compose (default)
  - Docker Swarm
  - Kubernetes
- Cloud provider support
  - AWS (ECR + ECS)
  - GCP (Artifact Registry + Cloud Run)
  - Azure (ACR + ACI)
  - Alibaba Cloud (ACR + ECI)
- Homebrew package support
- Quick install script (`install.sh`)
- CI installer for pipelines (`scripts/ci-install.sh`)
- CI/CD integration templates
  - GitHub Actions (deploy + CI test workflows)
  - GitLab CI (with release automation)
  - Bitbucket Pipelines (with release automation)
- Test suite with syntax and function existence checks
