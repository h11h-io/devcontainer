# Agent Instructions

Structured reference for AI coding agents working in this repository.

## Repository Purpose

This repository hosts reusable [devcontainer features](https://containers.dev/features) published to GHCR at `ghcr.io/h11h-io/devcontainer/<feature-id>`.

## Repository Structure

```
src/<feature-id>/
  devcontainer-feature.json    # Feature metadata, options, lifecycle hooks
  install.sh                   # Runs as root at image build time
  [helper-script.sh]           # Optional runtime scripts installed to /usr/local/bin/

test/<feature-id>/
  test.sh                      # Integration test (runs inside container, uses dev-container-features-test-lib)
  scenarios.json               # Scenario matrix for parameterised tests
  [scenario-name.sh]           # Per-scenario test script

test/unit/
  test_<feature_id>.sh         # Unit tests (no Docker, must produce "Results: N passed, 0 failed")

.github/workflows/
  lint.yml                     # shellcheck + shfmt + JSON validation
  test.yml                     # Unit tests + integration tests
  release.yaml                 # Lint gate → unit test gate → publish to GHCR
```

## Features Inventory

| ID | GHCR Reference | Lifecycle Hooks |
|----|---------------|-----------------|
| `git-identity-from-github` | `ghcr.io/h11h-io/devcontainer/git-identity-from-github:1` | `postStartCommand: configure-git-identity` |
| `devbox` | `ghcr.io/h11h-io/devcontainer/devbox:1` | `onCreateCommand: devbox-on-create` |
| `oh-my-zsh` | `ghcr.io/h11h-io/devcontainer/oh-my-zsh:1` | (none — build-time only) |
| `supabase-cli` | `ghcr.io/h11h-io/devcontainer/supabase-cli:1` | `postStartCommand: supabase-post-start` |
| `coder` | `ghcr.io/h11h-io/devcontainer/coder:1` | (none — build-time only) |

## Mandatory Rules

1. **Every feature must have unit tests** in `test/unit/test_<id>.sh` that run without Docker.
2. **Code style**: tabs for indentation (shfmt), shellcheck at `--severity=warning`.
3. **Error handling**: `set -e` for sh scripts, `set -euo pipefail` for bash scripts.
4. **BASH_SOURCE guard**: bash scripts with reusable functions use `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then ... fi` so they can be sourced for testing.
5. **Idempotency**: all install and lifecycle scripts must be safe to run repeatedly.
6. **Graceful failures**: runtime scripts (postStartCommand etc.) must never crash the container — warn and exit 0.

## Unit Test Pattern

Tests use PATH manipulation to mock external commands and isolated `$HOME` dirs:

```bash
# Create mock binary
cat >"$MOCK_DIR/curl" <<'EOF'
#!/bin/sh
echo "$@" >> "$MOCK_DIR/curl.log"
printf '{"login":"alice","id":42,"name":"Alice","email":"alice@example.com"}'
EOF
chmod +x "$MOCK_DIR/curl"

# Run script under isolation
HOME="$TEST_HOME" PATH="$MOCK_DIR:$PATH" GITHUB_TOKEN="tok" bash "$SCRIPT"

# Assert result
[ "$(HOME="$TEST_HOME" git config --global user.name)" = "Alice" ] && pass "..." || fail "..."
```

For scripts that check `command -v <tool>`, use env vars like `DOCKER_CMD`, `SUPABASE_CMD`, `CODER_CMD` pointing at sentinel names (`__no_docker_here__`) to guarantee the command is not found without relying on PATH-only isolation.

## Test Harness Convention

Every unit test file follows this pattern:

```bash
PASS=0; FAIL=0; _ERRORS=()
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; _ERRORS+=("$1: $2"); FAIL=$((FAIL + 1)); }
summary() {
  echo "Results: ${PASS} passed, ${FAIL} failed"
  [ "${FAIL}" -gt 0 ] && exit 1
}
# ... tests ...
summary
```

Output format: `Results: N passed, 0 failed` (must match exactly for CI).

## How to Add a New Feature

1. Create `src/<feature-id>/devcontainer-feature.json` and `install.sh`
2. Create `test/<feature-id>/test.sh` and `scenarios.json`
3. Create `test/unit/test_<feature_id>.sh` with comprehensive unit tests
4. Add integration job to `.github/workflows/test.yml`
5. Add unit test step to `.github/workflows/test.yml` and `release.yaml`
6. Run locally:
   ```bash
   bash test/unit/test_<feature_id>.sh                   # Unit tests
   shellcheck --severity=warning src/<feature-id>/*.sh   # Lint
   shfmt --diff src/<feature-id>/*.sh                    # Format check
   ```

## Running All Checks Locally

```bash
# Unit tests (no Docker)
for t in test/unit/test_*.sh; do bash "$t"; done

# Lint
find . -not -path './.git/*' -name '*.sh' -print0 | xargs -0 shellcheck --severity=warning
find . -not -path './.git/*' -name '*.sh' -print0 | xargs -0 shfmt --diff

# Integration (requires Docker + npm i -g @devcontainers/cli)
devcontainer features test --skip-scenarios -f <feature> -i mcr.microsoft.com/devcontainers/base:ubuntu-22.04 .
```

## Accessing External Documentation

When implementing a feature that relies on a third-party tool (e.g. devbox, Nix, Supabase CLI), always look up the official installation guide, GitHub Action, or source code first — these are the authoritative reference for the correct environment variables and flags to use.

**If a URL is blocked or unreachable**, say so explicitly in a PR comment or reply rather than guessing. For example:

> I need to read `https://github.com/jetify-com/devbox-install-action/blob/main/action.yml` to confirm the correct install flags, but the domain is blocked in my sandbox. Could you grant access to `github.com` or paste the relevant snippet?

This lets the repository owner unblock the domain or provide the content directly, which is much faster and more accurate than inferring the correct behaviour from indirect sources.

Key reference URLs for this repository's toolchain:
- **devbox install action**: `https://github.com/jetify-com/devbox-install-action/blob/main/action.yml`
- **devbox Nix install source**: `https://github.com/jetify-com/devbox/blob/main/internal/nix/install.go`
- **Nix installer docs**: `https://nixos.org/download`
- **devcontainer features spec**: `https://containers.dev/features`
