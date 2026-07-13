#!/bin/sh
set -e

DEVBOX_VERSION="${VERSION:-latest}"
DEVBOX_INSTALL_PATH="${DEVBOX_INSTALL_PATH:-/usr/local/bin/devbox}"
DEVBOX_CACHE_BIN_DIR="${DEVBOX_CACHE_BIN_DIR:-${HOME}/.cache/devbox/bin}"

echo "devbox: install.sh (built from git commit: @GIT_SHA@)"

# Ensure curl is available
if ! command -v curl >/dev/null 2>&1; then
	echo "devbox: installing curl..."
	apt-get update -y
	apt-get install -y --no-install-recommends curl
	rm -rf /var/lib/apt/lists/*
fi

echo "devbox: installing Devbox CLI (version: ${DEVBOX_VERSION})..."

if [ "$DEVBOX_VERSION" = "latest" ]; then
	curl -fsSL https://get.jetify.com/devbox | FORCE=1 bash -s -- -f
else
	curl -fsSL https://get.jetify.com/devbox | FORCE=1 DEVBOX_VERSION="${DEVBOX_VERSION}" bash -s -- -f
fi

# The Jetify installer sets devbox to rwx--x--x (751). Ensure it is world-readable
# so non-root users (e.g. the 'vscode' user in devcontainer base images) can exec it.
chmod 755 "${DEVBOX_INSTALL_PATH}"

echo "devbox: Devbox CLI installed successfully."
devbox version

# The Jetify installer places a small launcher at /usr/local/bin/devbox and
# downloads the resolved executable into the invoking user's cache on first run.
# Feature installation runs as root, while devcontainer tests and interactive
# shells commonly run as a non-root remote user. Leaving the launcher in place
# makes every user download Devbox again and can fail in restricted networks.
# Promote the executable resolved by `devbox version` to the system-wide path,
# matching the approach used by the official devbox-install-action.
RESOLVED_DEVBOX="$(find "${DEVBOX_CACHE_BIN_DIR}" -type f -name devbox 2>/dev/null | head -n 1)"
if [ -n "${RESOLVED_DEVBOX}" ] && [ "${RESOLVED_DEVBOX}" != "${DEVBOX_INSTALL_PATH}" ]; then
	echo "devbox: promoting resolved CLI from ${RESOLVED_DEVBOX} to ${DEVBOX_INSTALL_PATH}..."
	install -o root -g root -m 0755 "${RESOLVED_DEVBOX}" "${DEVBOX_INSTALL_PATH}"
	"${DEVBOX_INSTALL_PATH}" version
fi

# Install the onCreate helper so the devcontainer lifecycle hook can find it.
FEATURE_DIR="$(dirname "$0")"
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/devbox-on-create.sh" \
	/usr/local/bin/devbox-on-create

echo "devbox: onCreate helper installed at /usr/local/bin/devbox-on-create."

# Install the postStart helper.
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/devbox-post-start.sh" \
	/usr/local/bin/devbox-post-start

echo "devbox: postStart helper installed at /usr/local/bin/devbox-post-start."
