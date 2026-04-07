#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "devbox CLI is installed" command -v devbox
check "devbox version runs" devbox version
check "devbox-on-create helper is installed" test -f /usr/local/bin/devbox-on-create
check "devbox-on-create helper is executable" test -x /usr/local/bin/devbox-on-create

reportResults
