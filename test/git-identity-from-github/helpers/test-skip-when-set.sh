#!/bin/bash
# Helper: verifies the script skips when identity is already set and OVERWRITE=false.
set -euo pipefail

export HOME
HOME=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$HOME'" EXIT

git config --global user.name "Existing User"
git config --global user.email "existing@example.com"

output=$(GITHUB_TOKEN="mock-token" OVERWRITE="false" /usr/local/bin/configure-git-identity 2>&1)

echo "$output" | grep -q "already set" || {
	echo "FAIL: expected 'already set' in output, got: $output"
	exit 1
}

actual_name=$(git config --global user.name)
[ "$actual_name" = "Existing User" ] || {
	echo "FAIL: identity was changed; got name '$actual_name'"
	exit 1
}
