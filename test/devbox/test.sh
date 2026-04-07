#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# Verify devbox is installed and executable
check "devbox is installed" command -v devbox
check "devbox version runs" devbox version

# Verify it's usable
check "devbox help runs" bash -c "devbox help >/dev/null 2>&1"

reportResults
