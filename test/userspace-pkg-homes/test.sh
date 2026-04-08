#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "pnpm home dir exists" test -d "${HOME}/.local/share/pnpm"
check "pipx bin dir exists" test -d "${HOME}/.local/bin"

check "bashrc has userspace package homes begin marker" grep -q '# >> userspace-pkg-homes config >>' "${HOME}/.bashrc"
check "bashrc has PNPM_HOME export" grep -q 'export PNPM_HOME=' "${HOME}/.bashrc"
check "bashrc has PIPX_BIN_DIR export" grep -q 'export PIPX_BIN_DIR=' "${HOME}/.bashrc"
check "bashrc has userspace package homes end marker" grep -q '# << userspace-pkg-homes config <<' "${HOME}/.bashrc"

check "zshrc has userspace package homes begin marker" grep -q '# >> userspace-pkg-homes config >>' "${HOME}/.zshrc"
check "zshrc has PNPM_HOME export" grep -q 'export PNPM_HOME=' "${HOME}/.zshrc"
check "zshrc has PIPX_BIN_DIR export" grep -q 'export PIPX_BIN_DIR=' "${HOME}/.zshrc"
check "zshrc has userspace package homes end marker" grep -q '# << userspace-pkg-homes config <<' "${HOME}/.zshrc"

reportResults
