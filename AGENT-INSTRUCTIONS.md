# Agent instructions

This repository publishes three reusable Dev Container features from
`src/<feature-id>`:

| ID | Lifecycle hook |
|---|---|
| `git-identity-from-github` | `postStartCommand` |
| `devbox` | build-time only |
| `oh-my-zsh` | build-time only |

Each feature has metadata and `install.sh` under `src/`, integration coverage
under `test/<feature-id>`, and a Docker-free unit test under `test/unit`.

## Required conventions

1. Use tabs in shell scripts and pass `shfmt`.
2. Pass ShellCheck at warning severity.
3. Use `set -e` for POSIX shell and `set -euo pipefail` for Bash.
4. Keep install and lifecycle scripts idempotent.
5. Runtime lifecycle failures must warn and allow the container to start.
6. Increment the feature patch version for functional changes.
7. Use command environment-variable hooks when external commands need mocking.

## Validation

```bash
for test_file in test/unit/test_*.sh; do bash "$test_file"; done
shellcheck --severity=warning src/*/*.sh test/unit/*.sh
shfmt --diff src/*/*.sh test/unit/*.sh
devcontainer features test --skip-scenarios -f <feature> \
  -i mcr.microsoft.com/devcontainers/base:ubuntu-22.04 .
```

Consult upstream Dev Container and tool documentation before changing installer
behavior. Important references include the Dev Container Features specification,
Jetify's install action, Devbox's Nix installer, and the Nix installer docs.
