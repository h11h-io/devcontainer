#!/bin/bash
# Helper: verifies the script exits cleanly and warns when no token is available.
set -euo pipefail

export HOME
HOME=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$HOME'" EXIT

# Unset all token sources
unset GITHUB_TOKEN || true

output=$(GITHUB_TOKEN="" /usr/local/bin/configure-git-identity 2>&1)
echo "$output" | grep -q "warning" || {
	echo "FAIL: expected warning in output, got: $output"
	exit 1
}

# Identity must not be set
git config --global user.name >/dev/null 2>&1 && {
	echo "FAIL: git user.name was set despite no token"
	exit 1
}
exit 0
