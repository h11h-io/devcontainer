#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "coder CLI is installed" command -v coder

reportResults
