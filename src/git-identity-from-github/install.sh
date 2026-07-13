#!/bin/sh
set -e

OVERWRITE="${OVERWRITE:-false}"

echo "git-identity-from-github: install.sh (built from git commit: @GIT_SHA@)"

# Install everything the runtime helper requires. Do not rely on richer
# Dev Containers base images to provide Git implicitly.
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
	echo "configure-git-identity: installing git, curl, and jq..."
	apt-get update -y
	apt-get install -y --no-install-recommends git curl jq
	rm -rf /var/lib/apt/lists/*
fi

# Copy the runtime helper script into the system PATH
FEATURE_DIR="$(dirname "$0")"
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/configure-git-identity.sh" \
	/usr/local/bin/configure-git-identity

# Bake the feature-option value for OVERWRITE into the installed script so
# postStartCommand picks it up without needing a runtime environment variable.
sed -i "s|OVERWRITE=\"\${OVERWRITE:-false}\"|OVERWRITE=\"\${OVERWRITE:-${OVERWRITE}}\"|" \
	/usr/local/bin/configure-git-identity

echo "configure-git-identity: helper installed at /usr/local/bin/configure-git-identity (OVERWRITE=${OVERWRITE})."
