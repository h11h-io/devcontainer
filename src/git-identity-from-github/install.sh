#!/bin/sh
set -e

OVERWRITE="${OVERWRITE:-false}"

echo "git-identity-from-github: install.sh (built from git commit: @GIT_SHA@)"

# Ensure curl and jq are available (typically pre-installed on devcontainer base images)
if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
	echo "configure-git-identity: installing curl and jq..."
	apt-get update -y
	apt-get install -y --no-install-recommends curl jq
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
