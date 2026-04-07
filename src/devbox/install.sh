#!/bin/sh
set -e

DEVBOX_VERSION="${VERSION:-latest}"

# Ensure curl is available
if ! command -v curl >/dev/null 2>&1; then
	echo "devbox: installing curl..."
	apt-get update -y
	apt-get install -y --no-install-recommends curl
	rm -rf /var/lib/apt/lists/*
fi

echo "devbox: installing Devbox CLI (version: ${DEVBOX_VERSION})..."

if [ "$DEVBOX_VERSION" = "latest" ]; then
	curl -fsSL https://get.jetify.com/devbox | bash -s -- -f
else
	curl -fsSL https://get.jetify.com/devbox | DEVBOX_VERSION="${DEVBOX_VERSION}" bash -s -- -f
fi

# The Jetify installer sets devbox to rwx--x--x (751). Ensure it is world-readable
# so non-root users (e.g. the 'vscode' user in devcontainer base images) can exec it.
chmod 755 /usr/local/bin/devbox

echo "devbox: Devbox CLI installed successfully."
devbox version

# Install the onCreate helper so the devcontainer lifecycle hook can find it.
FEATURE_DIR="$(dirname "$0")"
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/devbox-on-create.sh" \
	/usr/local/bin/devbox-on-create

echo "devbox: onCreate helper installed at /usr/local/bin/devbox-on-create."
