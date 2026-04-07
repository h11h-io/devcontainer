#!/bin/sh
set -e

DEVBOX_VERSION="${VERSION:-latest}"
RUN_INSTALL="${RUNINSTALL:-false}"

# Ensure curl is available
if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    apt-get update -y
    apt-get install -y --no-install-recommends curl
    rm -rf /var/lib/apt/lists/*
fi

echo "Installing Devbox (version: ${DEVBOX_VERSION})..."

if [ "$DEVBOX_VERSION" = "latest" ]; then
    curl -fsSL https://get.jetify.com/devbox | bash -s -- -f
else
    curl -fsSL https://get.jetify.com/devbox | DEVBOX_VERSION="${DEVBOX_VERSION}" bash -s -- -f
fi

echo "Devbox installed successfully."
devbox version

# Optionally run devbox install for the workspace
if [ "$RUN_INSTALL" = "true" ]; then
    WORKSPACE_FOLDER="${containerWorkspaceFolder:-/workspaces}"
    if [ -f "${WORKSPACE_FOLDER}/devbox.json" ]; then
        echo "Running 'devbox install' in ${WORKSPACE_FOLDER}..."
        cd "${WORKSPACE_FOLDER}"
        devbox install
    else
        echo "No devbox.json found in ${WORKSPACE_FOLDER}, skipping 'devbox install'."
    fi
fi
