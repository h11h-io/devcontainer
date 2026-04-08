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

# Install the postCreate runtime helper.
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/project-setup-post-create.sh" \
	/usr/local/bin/project-setup-post-create

# Write baked-in configuration so the runtime helper knows which options were
# chosen at feature-install time (feature options are not available at runtime).
mkdir -p "$_SHARE_DIR"
{
	printf "BAKED_NODE_SUBDIRS='%s'\n" "${NODE_SUBDIRS}"
	printf "BAKED_PYTHON_SUBDIRS='%s'\n" "${PYTHON_SUBDIRS}"
	printf "BAKED_ENV_FILES='%s'\n" "${ENV_FILES}"
	printf "BAKED_LEFTHOOK_INSTALL='%s'\n" "${LEFTHOOK_INSTALL}"
	printf "BAKED_DIRENV_ALLOW='%s'\n" "${DIRENV_ALLOW}"
} >"${_SHARE_DIR}/config.sh"

echo "project-setup: post-create helper installed."
