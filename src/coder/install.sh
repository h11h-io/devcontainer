#!/bin/sh
set -e

CODER_VERSION="${VERSION:-latest}"
CODER_CMD="${CODER_CMD:-coder}"

if command -v "$CODER_CMD" >/dev/null 2>&1; then
	echo "coder: Coder CLI already installed ($(coder version 2>/dev/null | head -1)); skipping."
	exit 0
fi

echo "coder: installing Coder CLI..."
if [ "$CODER_VERSION" = "latest" ]; then
	curl -fsSL https://coder.com/install.sh | sh || echo "coder: WARNING: Coder CLI install failed. Continuing."
else
	curl -fsSL https://coder.com/install.sh | CODER_VERSION="$CODER_VERSION" sh || echo "coder: WARNING: Coder CLI install failed. Continuing."
fi

if command -v "$CODER_CMD" >/dev/null 2>&1; then
	echo "coder: Coder CLI installed successfully."
else
	echo "coder: WARNING: coder CLI not found after install attempt."
fi
