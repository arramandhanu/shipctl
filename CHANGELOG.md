# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-20

### Added
- Initial release of shipctl
- Multi-service deployment with single command
- Pre-flight checks (Docker, SSH, Git, Dockerfile)
- Dry-run mode for previewing deployments
- Rollback capability to previous versions
- Multi-environment support (staging, production)
- HTTP and TCP health checks after deployment
- Git repository URL support for service configuration
  - SSH and HTTPS URL support
  - Branch/tag/commit checkout
  - Monorepo subdirectory support
- Flexible configuration system
  - Per-project config (./deploy.env)
  - Global user config (~/.config/shipctl/)
  - Custom config path (--config flag)
  - `shipctl init` command for setup
- Shell autocompletion for Bash and Zsh
- Local deployment mode (no SSH required)
- Homebrew package support
- Quick install script
- CI/CD integration templates
  - GitHub Actions
  - GitLab CI
  - Bitbucket Pipelines
