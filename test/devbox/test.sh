#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# ── install-time checks ───────────────────────────────────────────────────────
check "devbox CLI is installed" command -v devbox
check "devbox version runs" devbox version
check "devbox help runs" bash -c "devbox help >/dev/null 2>&1"
reportResults
