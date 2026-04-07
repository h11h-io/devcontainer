#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "configure-git-identity script is installed" \
	test -f /usr/local/bin/configure-git-identity
check "configure-git-identity script is executable" \
	test -x /usr/local/bin/configure-git-identity
check "curl is available" command -v curl
check "jq is available" command -v jq

reportResults
