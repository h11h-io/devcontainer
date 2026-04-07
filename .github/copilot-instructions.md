# Copilot Instructions

See [`AGENT-INSTRUCTIONS.md`](../AGENT-INSTRUCTIONS.md) in the repository root for the full structured reference.

## Quick Reference

### Repository Structure

```
src/<feature-id>/                    # Feature source code
  devcontainer-feature.json          # Metadata and options
  install.sh                         # Build-time install (runs as root)
  [runtime-helper.sh]                # Optional lifecycle scripts

test/<feature-id>/                   # Integration tests
  test.sh                            # Runs inside a container
  scenarios.json                     # Parameterised test matrix

test/unit/
  test_<feature_id>.sh               # Unit tests (no Docker, fast)
```

### Mandatory Rules

1. Every feature **must** have unit tests in `test/unit/`
2. **Indentation**: tabs (shfmt)
3. **Linting**: `shellcheck --severity=warning`
4. **Error handling**: `set -e` (sh) or `set -euo pipefail` (bash)
5. **BASH_SOURCE guard** for sourceable scripts
6. Use `DOCKER_CMD`, `SUPABASE_CMD`, `CODER_CMD` env-var hooks for testability

### Running Checks

```bash
# Unit tests
for t in test/unit/test_*.sh; do bash "$t"; done

# Lint
find . -not -path './.git/*' -name '*.sh' -print0 | xargs -0 shellcheck --severity=warning
find . -not -path './.git/*' -name '*.sh' -print0 | xargs -0 shfmt --diff
```
