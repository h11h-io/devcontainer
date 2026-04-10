#!/bin/bash
set -euo pipefail

CONFIGURE_PNPM="${CONFIGUREPNPM:-true}"
CONFIGURE_PIPX="${CONFIGUREPIPX:-true}"
CONFIGURE_NPM="${CONFIGURENPM:-false}"

REMOTE_USER="${_REMOTE_USER:-${USER:-root}}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-${HOME:-/root}}"

# Testability hooks — override these in unit tests to use temp paths
PROFILE_D_DIR="${PROFILE_D_DIR:-/etc/profile.d}"
ZSHRC_D_DIR="${ZSHRC_D_DIR:-/etc/zsh/zshrc.d}"
GLOBAL_ZSHRC="${GLOBAL_ZSHRC:-/etc/zsh/zshrc}"

MARKER_BEGIN="# >> userspace-pkg-homes config >>"
MARKER_END="# << userspace-pkg-homes config <<"

echo "userspace-pkg-homes: install.sh (built from git commit: @GIT_SHA@)"

# build_config_block assembles the shell snippet to inject into rc files.
build_config_block() {
	local exports=""
	local path_dirs=""

	if [ "${CONFIGURE_PNPM}" = "true" ]; then
		exports="${exports}export PNPM_HOME=\"\${HOME}/.local/share/pnpm\"
"
		path_dirs="${path_dirs} \${PNPM_HOME}"
	fi

	if [ "${CONFIGURE_PIPX}" = "true" ]; then
		exports="${exports}export PIPX_BIN_DIR=\"\${HOME}/.local/bin\"
"
		path_dirs="${path_dirs} \${PIPX_BIN_DIR}"
	fi

	if [ "${CONFIGURE_NPM}" = "true" ]; then
		exports="${exports}export NPM_CONFIG_PREFIX=\"\${HOME}/.npm-global\"
"
		path_dirs="${path_dirs} \${NPM_CONFIG_PREFIX}/bin"
	fi

	# Nothing to configure
	if [ -z "${exports}" ]; then
		return 0
	fi

	printf '%s\n' "${MARKER_BEGIN}"
	printf '%s' "${exports}"
	# Idempotent PATH guard — check each directory individually
	local dir
	for dir in ${path_dirs}; do
		printf 'case ":$PATH:" in\n'
		printf '  *":%s:"*) ;;\n' "${dir}"
		printf '  *) export PATH="%s:$PATH" ;;\n' "${dir}"
		printf 'esac\n'
	done
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

	# Fix ownership if not root — only chown directories this feature creates
	if [ "${REMOTE_USER}" != "root" ]; then
		if [ "${CONFIGURE_PNPM}" = "true" ]; then
			chown -R "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.local/share/pnpm" 2>/dev/null || true
		fi
		if [ "${CONFIGURE_PIPX}" = "true" ]; then
			chown -R "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.local/bin" 2>/dev/null || true
		fi
		if [ "${CONFIGURE_NPM}" = "true" ]; then
			chown -R "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.npm-global" 2>/dev/null || true
		fi
	fi
}

# ensure_zshrc_d creates /etc/zsh/zshrc.d and ensures /etc/zsh/zshrc sources it.
# This allows drop-in zsh config files that are loaded even when the user home
# directory is mounted over the image (e.g. Coder/envbuilder workspaces).
ensure_zshrc_d() {
	mkdir -p "${ZSHRC_D_DIR}"
	if [ ! -f "${GLOBAL_ZSHRC}" ]; then
		mkdir -p "$(dirname "${GLOBAL_ZSHRC}")"
		touch "${GLOBAL_ZSHRC}"
	fi
	local marker='# h11h-io: source /etc/zsh/zshrc.d'
	if ! grep -qF "${marker}" "${GLOBAL_ZSHRC}"; then
		printf '\n%s\nfor _h11h_f in %s/*.zsh(N); do [ -r "$_h11h_f" ] && . "$_h11h_f"; done; unset _h11h_f\n' \
			"${marker}" "${ZSHRC_D_DIR}" >>"${GLOBAL_ZSHRC}"
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	block=$(build_config_block)

	if [ -z "${block}" ]; then
		echo "userspace-pkg-homes: no tools selected, nothing to configure."
		exit 0
	fi

	ensure_dirs

	# Write to global locations first — these survive runtime home mounts
	# (e.g. Coder/envbuilder workspaces).
	mkdir -p "${PROFILE_D_DIR}"
	inject_config "${PROFILE_D_DIR}/userspace-pkg-homes.sh" "${block}"

	ensure_zshrc_d
	inject_config "${ZSHRC_D_DIR}/userspace-pkg-homes.zsh" "${block}"

	# Also write to user dotfiles as convenience for environments where the home
	# directory persists from the image (e.g. Codespaces).
	inject_config "${REMOTE_USER_HOME}/.bashrc" "${block}"
	inject_config "${REMOTE_USER_HOME}/.zshrc" "${block}"

	# Fix ownership of rc files
	if [ "${REMOTE_USER}" != "root" ]; then
		chown "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.bashrc" 2>/dev/null || true
		chown "${REMOTE_USER}:" "${REMOTE_USER_HOME}/.zshrc" 2>/dev/null || true
	fi

	echo "userspace-pkg-homes: configuration complete for user '${REMOTE_USER}'."
fi
