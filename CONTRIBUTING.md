# Contributing to shipctl

Thank you for considering contributing to shipctl! This document provides guidelines and best practices for contributing.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Branch Naming](#branch-naming)
- [Code Style](#code-style)

---

## 📜 Code of Conduct

Please be respectful and constructive in all interactions. We're building something useful together.

---

## 🚀 Getting Started

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/shipctl.git
   cd shipctl
   ```

2. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/arramandhanu/shipctl.git
   ```

3. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Set up for testing**
   ```bash
   chmod +x shipctl
   ./shipctl --help
   ./shipctl init  # Create test config
   ```

---

## 🤝 How to Contribute

### Reporting Bugs

1. Check existing issues first
2. Create a new issue with:
   - Clear title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment (OS, bash version)

### Suggesting Features

1. Open an issue with `[Feature]` prefix
2. Describe the use case
3. Explain why it would benefit users

### Submitting Code

1. Fork & create a branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

---

## 📝 Commit Convention

We follow **Conventional Commits** for clear, meaningful git history.

### Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|:-----|:------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code change that neither fixes nor adds |
| `perf` | Performance improvement |
| `test` | Adding tests |
| `chore` | Maintenance tasks |

### Examples

```bash
# Feature
git commit -m "feat(docker): add multi-stage build support"

# Bug fix
git commit -m "fix(ssh): handle connection timeout properly"

# Documentation
git commit -m "docs(readme): add troubleshooting section"

# Refactor
git commit -m "refactor(checks): extract common validation logic"

# With scope
git commit -m "feat(cli): add --verbose flag for debug output"

# Breaking change
git commit -m "feat(config)!: rename SERVICES to SERVICE_LIST

BREAKING CHANGE: users must update their services.env files"
```

### Rules

- Use **imperative mood**: "add feature" not "added feature"
- Keep subject line under **50 characters**
- No period at the end of subject
- Capitalize first letter
- Body should explain **why**, not just **what**

---

## 🔀 Pull Request Process

### Before Submitting

1. **Sync with upstream**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Test your changes**
   ```bash
   ./shipctl --help
   ./shipctl --list
   ./shipctl frontend --dry-run  # with a test config
   ```

3. **Check for shellcheck warnings** (optional but recommended)
   ```bash
   shellcheck shipctl lib/*.sh
   ```

### PR Guidelines

1. **Title**: Use conventional commit format
   ```
   feat(docker): add support for custom Dockerfile path
   ```

2. **Description**: Use the template
   ```markdown
   ## What does this PR do?
   Brief description of changes.

   ## Why is this needed?
   Explain the motivation.

   ## How to test?
   Steps to verify the changes work.

   ## Checklist
   - [ ] I've tested on macOS
   - [ ] I've tested on Linux
   - [ ] I've updated documentation if needed
   - [ ] My code follows the project style
   ```

3. **Size**: Keep PRs focused and small
   - One feature or fix per PR
   - Split large changes into multiple PRs

### Review Process

1. Maintainer reviews within 48 hours
2. Address feedback with new commits
3. Squash commits before merge (if requested)
4. PR merged by maintainer

---

## 🌿 Branch Naming

Use descriptive branch names with prefixes:

| Prefix | Use Case | Example |
|:-------|:---------|:--------|
| `feature/` | New features | `feature/add-slack-notifications` |
| `fix/` | Bug fixes | `fix/ssh-timeout-handling` |
| `docs/` | Documentation | `docs/update-configuration-guide` |
| `refactor/` | Code refactoring | `refactor/modularize-docker-lib` |
| `chore/` | Maintenance | `chore/update-gitignore` |

---

## 🎨 Code Style

### Shell Script Guidelines

1. **Shebang**: Always use `#!/usr/bin/env bash`

2. **Strict mode**: All scripts should start with:
   ```bash
   set -euo pipefail
   ```

3. **Variables**:
   - Use `UPPER_CASE` for constants/exports
   - Use `lower_case` for local variables
   - Always quote variables: `"$variable"`

4. **Functions**:
   ```bash
   # Good
   my_function() {
       local arg1="$1"
       local arg2="$2"
       
       # function body
   }
   ```

5. **Comments**:
   ```bash
   # Single line comment
   
   #------------------------------------------------------------------------------
   # Section header for grouping related code
   #------------------------------------------------------------------------------
   ```

6. **Error handling**:
   ```bash
   if ! some_command; then
       log_error "Command failed"
       return 1
   fi
   ```

7. **macOS compatibility**: 
   - Avoid bash 4+ features (like `${var^^}`)
   - Use `tr` for case conversion
   - Test on both macOS and Linux

---

## 🙏 Thank You!

Your contributions make this tool better for everyone. Whether it's a bug report, feature suggestion, or code contribution - we appreciate it!

---

<p align="center">
  <sub>Questions? Open an issue or reach out on <a href="https://linkedin.com/in/arya-ramandhanu">LinkedIn</a></sub>
</p>
