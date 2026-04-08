#!/bin/sh
set -e

NODE_SUBDIRS="${NODESUBDIRS:-}"
PYTHON_SUBDIRS="${PYTHONSUBDIRS:-}"
ENV_FILES="${ENVFILES:-}"
LEFTHOOK_INSTALL="${LEFTHOOKINSTALL:-true}"
DIRENV_ALLOW="${DIRENVALLOW:-true}"

FEATURE_DIR="$(dirname "$0")"
# _SHARE_DIR can be overridden in tests to avoid writing to /usr/local/share.
_SHARE_DIR="${PROJECT_SETUP_SHARE_DIR:-/usr/local/share/project-setup}"

# Escape a value for embedding inside a single-quoted shell string.
# Replaces each ' with '\'' so config.sh remains syntactically valid even when
# option values contain single quotes or other special characters.
sq_escape() {
	printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

# Install the postCreate runtime helper.
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/project-setup-post-create.sh" \
	/usr/local/bin/project-setup-post-create

# Write baked-in configuration so the runtime helper knows which options were
# chosen at feature-install time (feature options are not available at runtime).
mkdir -p "$_SHARE_DIR"
{
	printf "BAKED_NODE_SUBDIRS='%s'\n" "$(sq_escape "$NODE_SUBDIRS")"
	printf "BAKED_PYTHON_SUBDIRS='%s'\n" "$(sq_escape "$PYTHON_SUBDIRS")"
	printf "BAKED_ENV_FILES='%s'\n" "$(sq_escape "$ENV_FILES")"
	printf "BAKED_LEFTHOOK_INSTALL='%s'\n" "$(sq_escape "$LEFTHOOK_INSTALL")"
	printf "BAKED_DIRENV_ALLOW='%s'\n" "$(sq_escape "$DIRENV_ALLOW")"
} >"${_SHARE_DIR}/config.sh"

echo "project-setup: post-create helper installed."
