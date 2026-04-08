#!/bin/bash
set -euo pipefail

CONFIGURE_PNPM="${CONFIGUREPNPM:-true}"
CONFIGURE_PIPX="${CONFIGUREPIPX:-true}"
CONFIGURE_NPM="${CONFIGURENPM:-false}"

REMOTE_USER="${_REMOTE_USER:-${USER:-root}}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-${HOME:-/root}}"

MARKER_BEGIN="# >> userspace-pkg-homes config >>"
MARKER_END="# << userspace-pkg-homes config <<"

# build_config_block assembles the shell snippet to inject into rc files.
build_config_block() {
	local exports=""
	local path_dirs=""

	if [ "${CONFIGURE_PNPM}" = "true" ]; then
		exports="${exports}export PNPM_HOME=\"\${HOME}/.local/share/pnpm\"
"
		path_dirs="${path_dirs}\${PNPM_HOME}:"
	fi

	if [ "${CONFIGURE_PIPX}" = "true" ]; then
		exports="${exports}export PIPX_BIN_DIR=\"\${HOME}/.local/bin\"
"
		path_dirs="${path_dirs}\${PIPX_BIN_DIR}:"
	fi

	if [ "${CONFIGURE_NPM}" = "true" ]; then
		exports="${exports}export NPM_CONFIG_PREFIX=\"\${HOME}/.npm-global\"
"
		path_dirs="${path_dirs}\${NPM_CONFIG_PREFIX}/bin:"
	fi

	# Nothing to configure
	if [ -z "${exports}" ]; then
		return 0
	fi

	printf '%s\n' "${MARKER_BEGIN}"
	printf '%s' "${exports}"
	# Idempotent PATH guard — only prepend if not already present
	printf 'case ":$PATH:" in\n'
	printf '  *":%s"*) ;;\n' "${path_dirs%:}"
	printf '  *) export PATH="%s$PATH" ;;\n' "${path_dirs}"
	printf 'esac\n'
	printf '%s\n' "${MARKER_END}"
}

# inject_config writes (or replaces) the config block into an rc file.
inject_config() {
	local rc_file="$1"
	local block="$2"

	# Create the rc file if it doesn't exist
	if [ ! -f "${rc_file}" ]; then
		touch "${rc_file}"
	fi

	# Remove any existing marker block (idempotent)
	if grep -qF "${MARKER_BEGIN}" "${rc_file}"; then
		sed -i "/${MARKER_BEGIN//\//\\/}/,/${MARKER_END//\//\\/}/d" "${rc_file}"
	fi

	# Append the new block
	printf '\n%s\n' "${block}" >>"${rc_file}"
}

# ensure_dirs creates the target directories and sets ownership.
ensure_dirs() {
	if [ "${CONFIGURE_PNPM}" = "true" ]; then
		mkdir -p "${REMOTE_USER_HOME}/.local/share/pnpm"
	fi

	if [ "${CONFIGURE_PIPX}" = "true" ]; then
		mkdir -p "${REMOTE_USER_HOME}/.local/bin"
	fi

	if [ "${CONFIGURE_NPM}" = "true" ]; then
		mkdir -p "${REMOTE_USER_HOME}/.npm-global"
	fi

	# Fix ownership if not root
	if [ "${REMOTE_USER}" != "root" ]; then
		chown -R "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.local" 2>/dev/null || true
		if [ "${CONFIGURE_NPM}" = "true" ]; then
			chown -R "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.npm-global" 2>/dev/null || true
		fi
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	block=$(build_config_block)

	if [ -z "${block}" ]; then
		echo "userspace-pkg-homes: no tools selected, nothing to configure."
		exit 0
	fi

	ensure_dirs

	inject_config "${REMOTE_USER_HOME}/.bashrc" "${block}"
	inject_config "${REMOTE_USER_HOME}/.zshrc" "${block}"

	# Fix ownership of rc files
	if [ "${REMOTE_USER}" != "root" ]; then
		chown "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.bashrc" 2>/dev/null || true
		chown "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.zshrc" 2>/dev/null || true
	fi

	echo "userspace-pkg-homes: configuration complete for user '${REMOTE_USER}'."
fi
