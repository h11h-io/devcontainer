#!/bin/bash
# Integration tests for the git-identity-from-github feature.
# Runs inside the built devcontainer, after the feature's install.sh has run.
#
# Uses the devcontainer features test library (check / reportResults).
# See: https://github.com/devcontainers/cli/blob/main/docs/features/test.md
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

HELPERS="$(dirname "$0")/helpers"

# ── install-time checks ───────────────────────────────────────────────────────
check "configure-git-identity script is installed" \
	test -f /usr/local/bin/configure-git-identity

check "configure-git-identity script is executable" \
	test -x /usr/local/bin/configure-git-identity

check "curl is available" command -v curl
check "jq is available" command -v jq

# ── runtime behaviour ─────────────────────────────────────────────────────────
check "no-token: exits cleanly and prints a warning" \
	bash "$HELPERS/test-no-token.sh"

check "sets git identity from mocked API response" \
	bash "$HELPERS/test-sets-identity.sh"

check "skips when identity already set and overwrite=false" \
	bash "$HELPERS/test-skip-when-set.sh"

check "uses noreply email when GitHub email is private/null" \
	bash "$HELPERS/test-noreply-email.sh"

reportResults
