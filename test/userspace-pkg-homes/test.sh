#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "pnpm home dir exists" test -d "${HOME}/.local/share/pnpm"
check "pipx bin dir exists" test -d "${HOME}/.local/bin"
check "PNPM_HOME in bashrc" grep -q 'PNPM_HOME' "${HOME}/.bashrc"
check "PIPX_BIN_DIR in bashrc" grep -q 'PIPX_BIN_DIR' "${HOME}/.bashrc"

reportResults
