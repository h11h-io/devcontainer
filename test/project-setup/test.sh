#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "project-setup-post-create helper is installed" test -f /usr/local/bin/project-setup-post-create
check "project-setup-post-create helper is executable" test -x /usr/local/bin/project-setup-post-create
check "project-setup config directory exists" test -d /usr/local/share/project-setup
check "project-setup config file exists" test -f /usr/local/share/project-setup/config.sh

reportResults
