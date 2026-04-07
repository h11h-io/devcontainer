#!/bin/sh
set -e

SUPABASE_CLI_VERSION="${VERSION:-2.84.2}"
DOCKER_CMD="${DOCKER_CMD:-docker}"
DOCKER_WAIT_SECONDS="${DOCKERWAITSECONDS:-30}"
SUPABASE_BIN="/usr/local/bin/supabase"

# hard dependency: Docker must be available
if ! command -v "$DOCKER_CMD" >/dev/null 2>&1; then
	echo "supabase-cli: ERROR: Docker is not available."
	echo "supabase-cli: Add the 'docker-in-docker' or 'docker-outside-of-docker' feature before 'supabase-cli'."
	exit 1
fi

# skip if already at the requested version
if [ -x "$SUPABASE_BIN" ] && "$SUPABASE_BIN" --version 2>/dev/null | grep -qF "$SUPABASE_CLI_VERSION"; then
	echo "supabase-cli: Supabase CLI v${SUPABASE_CLI_VERSION} already installed; skipping."
else
	echo "supabase-cli: installing Supabase CLI v${SUPABASE_CLI_VERSION}..."
	ARCH="$(uname -m)"
	case "$ARCH" in
	x86_64) ARCH_SUFFIX="linux_amd64" ;;
	aarch64) ARCH_SUFFIX="linux_arm64" ;;
	*)
		echo "supabase-cli: ERROR: unsupported architecture '${ARCH}'."
		exit 1
		;;
	esac
	curl -fsSL \
		"https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_${ARCH_SUFFIX}.tar.gz" |
		tar xz -C /usr/local/bin supabase
	chmod +x "$SUPABASE_BIN"
	echo "supabase-cli: Supabase CLI v${SUPABASE_CLI_VERSION} installed."
fi

# install post-start helper
FEATURE_DIR="$(dirname "$0")"
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/supabase-post-start.sh" \
	/usr/local/bin/supabase-post-start

# Bake the configured wait timeout into the installed script
sed -i "s|DOCKER_WAIT_SECONDS=\"\${SUPABASE_DOCKER_WAIT_SECONDS:-30}\"|DOCKER_WAIT_SECONDS=\"\${SUPABASE_DOCKER_WAIT_SECONDS:-${DOCKER_WAIT_SECONDS}}\"|" \
	/usr/local/bin/supabase-post-start

echo "supabase-cli: post-start helper installed."
