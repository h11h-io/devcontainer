#!/bin/bash
set -euo pipefail

PLUGINS="${PLUGINS:-git sudo z history colored-man-pages zsh-autosuggestions zsh-syntax-highlighting pnpm}"
THEME="${THEME:-robbyrussell}"
EXTRARCFILE="${EXTRARCFILE:-}"
AUTOSUGGESTSTYLE="${AUTOSUGGESTSTYLE:-}"
AUTOSUGGESTSTRATEGY="${AUTOSUGGESTSTRATEGY:-}"
REMOTE_USER="${_REMOTE_USER:-${USER:-root}}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-${HOME:-/root}}"

# Install oh-my-zsh to a global, non-home location so it survives runtime home mounts
# (e.g. Coder/envbuilder workspaces that mount a fresh home over the image filesystem).
OMZ_DIR="${OMZ_DIR:-/usr/local/share/oh-my-zsh}"

# Testability hooks — override these in unit tests to use temp paths
ZSHRC_D_DIR="${ZSHRC_D_DIR:-/etc/zsh/zshrc.d}"
GLOBAL_ZSHRC="${GLOBAL_ZSHRC:-/etc/zsh/zshrc}"

echo "oh-my-zsh: install.sh (built from git commit: @GIT_SHA@)"

# Returns the git clone URL for a known external plugin, or empty string for built-in plugins.
get_external_plugin_url() {
	local name="$1"
	case "$name" in
	zsh-autosuggestions) printf 'https://github.com/zsh-users/zsh-autosuggestions' ;;
	zsh-syntax-highlighting) printf 'https://github.com/zsh-users/zsh-syntax-highlighting' ;;
	zsh-completions) printf 'https://github.com/zsh-users/zsh-completions' ;;
	zsh-history-substring-search) printf 'https://github.com/zsh-users/zsh-history-substring-search' ;;
	pnpm) printf 'https://github.com/ntnyq/omz-plugin-pnpm' ;;
	*) printf '' ;;
	esac
}

install_deps() {
	local pkgs=""
	command -v zsh >/dev/null 2>&1 || pkgs="${pkgs} zsh"
	command -v git >/dev/null 2>&1 || pkgs="${pkgs} git"
	command -v curl >/dev/null 2>&1 || pkgs="${pkgs} curl"
	if [ -n "${pkgs}" ]; then
		apt-get update -y
		# shellcheck disable=SC2086
		apt-get install -y --no-install-recommends ${pkgs}
		rm -rf /var/lib/apt/lists/*
	fi
}

install_omz() {
	if [ -d "${OMZ_DIR}" ]; then
		echo "oh-my-zsh: already installed at ${OMZ_DIR}, skipping."
		return 0
	fi
	echo "oh-my-zsh: installing to ${OMZ_DIR}..."
	if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh |
		ZSH="${OMZ_DIR}" HOME="${REMOTE_USER_HOME}" RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
			sh -s --; then
		echo "oh-my-zsh: WARNING: installation failed (network issue?). Config will be written but OMZ won't be available." >&2
	fi
}

install_external_plugins() {
	local plugins_dir="${OMZ_DIR}/custom/plugins"
	mkdir -p "${plugins_dir}"
	local plugin url
	for plugin in ${PLUGINS}; do
		url=$(get_external_plugin_url "${plugin}")
		[ -z "${url}" ] && continue
		if [ ! -d "${plugins_dir}/${plugin}" ]; then
			echo "oh-my-zsh: installing plugin '${plugin}'..."
			if ! git clone --depth=1 "${url}" "${plugins_dir}/${plugin}"; then
				echo "oh-my-zsh: WARNING: plugin '${plugin}' clone failed; skipping." >&2
			fi
		else
			echo "oh-my-zsh: plugin '${plugin}' already present, skipping."
		fi
	done
}

write_zshrc() {
	local zshrc="${REMOTE_USER_HOME}/.zshrc"
	local plugin_list
	plugin_list=$(printf '%s' "${PLUGINS}" | tr ',' ' ' | tr -s ' ')

	# Back up any existing .zshrc that isn't already managed by this feature
	if [ -f "${zshrc}" ] && ! grep -qF '# managed by oh-my-zsh devcontainer feature' "${zshrc}"; then
		cp "${zshrc}" "${zshrc}.bak"
		echo "oh-my-zsh: backed up existing .zshrc to ${zshrc}.bak"
	fi

	# This file is a convenience that makes customisation easy in environments
	# where the user home survives (e.g. Codespaces). It is NOT the primary
	# activation path — the global /etc/zsh/zshrc.d/oh-my-zsh.zsh handles that.
	{
		printf '# managed by oh-my-zsh devcontainer feature\n'
		printf '[[ -n "${_H11H_OMZ_LOADED:-}" ]] && return 0\n'
		printf 'export _H11H_OMZ_LOADED=1\n'
		printf 'export ZSH="%s"\n' "${OMZ_DIR}"
		printf 'ZSH_THEME="%s"\n' "${THEME}"
		printf 'plugins=(%s)\n' "${plugin_list}"
		printf 'source "$ZSH/oh-my-zsh.sh"\n'
		if [ -n "${AUTOSUGGESTSTYLE}" ]; then
			printf 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="%s"\n' "${AUTOSUGGESTSTYLE}"
		fi
		if [ -n "${AUTOSUGGESTSTRATEGY}" ]; then
			printf 'ZSH_AUTOSUGGEST_STRATEGY=(%s)\n' "${AUTOSUGGESTSTRATEGY}"
		fi
		if [ -n "${EXTRARCFILE}" ]; then
			case "${EXTRARCFILE}" in
			*..*) echo "oh-my-zsh: WARNING: extraRcFile '${EXTRARCFILE}' contains '..'; ignoring." >&2 ;;
			*[!-a-zA-Z0-9_./]*)
				echo "oh-my-zsh: WARNING: extraRcFile '${EXTRARCFILE}' contains unsafe characters; ignoring." >&2
				;;
			/*)
				# Absolute path — source at runtime with existence guard
				printf '[ -f "%s" ] && source "%s"\n' "${EXTRARCFILE}" "${EXTRARCFILE}"
				;;
			*)
				# Workspace-relative path — resolve with env vars when available,
				# then fall back to scanning /workspaces/* for single-workspace runtimes.
				printf 'if [ -n "${WORKSPACE_FOLDER:-${_CONTAINER_WORKSPACE_FOLDER:-}}" ] && [ -f "${WORKSPACE_FOLDER:-${_CONTAINER_WORKSPACE_FOLDER:-}}/%s" ]; then\n' "${EXTRARCFILE}"
				printf '\tsource "${WORKSPACE_FOLDER:-${_CONTAINER_WORKSPACE_FOLDER:-}}/%s"\n' "${EXTRARCFILE}"
				printf 'else\n'
				printf '\tfor _h11h_ws in /workspaces/*; do\n'
				printf '\t\tif [ -f "$_h11h_ws/%s" ]; then\n' "${EXTRARCFILE}"
				printf '\t\t\tsource "$_h11h_ws/%s"\n' "${EXTRARCFILE}"
				printf '\t\t\tbreak\n'
				printf '\t\tfi\n'
				printf '\tdone\n'
				printf '\tunset _h11h_ws\n'
				printf 'fi\n'
				;;
			esac
		fi
	} >"${zshrc}"

	[ "${REMOTE_USER}" != "root" ] && chown "${REMOTE_USER}:" "${zshrc}" 2>/dev/null || true
}

# ensure_zshrc_d creates /etc/zsh/zshrc.d and ensures /etc/zsh/zshrc sources it.
# This is the global activation path that works regardless of whether the user
# home directory is mounted over the image (e.g. Coder/envbuilder workspaces).
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

# write_global_zshrc writes the primary oh-my-zsh activation snippet to
# /etc/zsh/zshrc.d/oh-my-zsh.zsh.  It is guarded against double-loading so
# that if the user also has a ~/.zshrc that sources oh-my-zsh the framework is
# only initialised once.
write_global_zshrc() {
	local plugin_list
	plugin_list=$(printf '%s' "${PLUGINS}" | tr ',' ' ' | tr -s ' ')
	local outfile="${ZSHRC_D_DIR}/oh-my-zsh.zsh"

	{
		printf '# oh-my-zsh devcontainer feature — global config\n'
		printf '# Skip if already loaded (e.g. user'"'"'s ~/.zshrc also sources oh-my-zsh)\n'
		printf '[[ -n "${_H11H_OMZ_LOADED:-}" ]] && return 0\n'
		printf 'export _H11H_OMZ_LOADED=1\n'
		printf 'export ZSH="%s"\n' "${OMZ_DIR}"
		printf 'ZSH_THEME="%s"\n' "${THEME}"
		printf 'plugins=(%s)\n' "${plugin_list}"
		if [ -n "${AUTOSUGGESTSTYLE}" ]; then
			printf 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="%s"\n' "${AUTOSUGGESTSTYLE}"
		fi
		if [ -n "${AUTOSUGGESTSTRATEGY}" ]; then
			printf 'ZSH_AUTOSUGGEST_STRATEGY=(%s)\n' "${AUTOSUGGESTSTRATEGY}"
		fi
		printf 'if [[ -d "$ZSH" ]]; then\n'
		printf '\tsource "$ZSH/oh-my-zsh.sh"\n'
		printf 'else\n'
		printf '\techo "oh-my-zsh: WARNING: OMZ dir not found ('"'"'$ZSH'"'"'), skipping." >&2\n'
		printf 'fi\n'
		if [ -n "${EXTRARCFILE}" ]; then
			case "${EXTRARCFILE}" in
			*..*) echo "oh-my-zsh: WARNING: extraRcFile '${EXTRARCFILE}' contains '..'; ignoring." >&2 ;;
			*[!-a-zA-Z0-9_./]*)
				echo "oh-my-zsh: WARNING: extraRcFile '${EXTRARCFILE}' contains unsafe characters; ignoring." >&2
				;;
			/*)
				printf '[ -f "%s" ] && source "%s"\n' "${EXTRARCFILE}" "${EXTRARCFILE}"
				;;
			*)
				printf 'if [ -n "${WORKSPACE_FOLDER:-${_CONTAINER_WORKSPACE_FOLDER:-}}" ] && [ -f "${WORKSPACE_FOLDER:-${_CONTAINER_WORKSPACE_FOLDER:-}}/%s" ]; then\n' "${EXTRARCFILE}"
				printf '\tsource "${WORKSPACE_FOLDER:-${_CONTAINER_WORKSPACE_FOLDER:-}}/%s"\n' "${EXTRARCFILE}"
				printf 'else\n'
				printf '\tfor _h11h_ws in /workspaces/*; do\n'
				printf '\t\tif [ -f "$_h11h_ws/%s" ]; then\n' "${EXTRARCFILE}"
				printf '\t\t\tsource "$_h11h_ws/%s"\n' "${EXTRARCFILE}"
				printf '\t\t\tbreak\n'
				printf '\t\tfi\n'
				printf '\tdone\n'
				printf '\tunset _h11h_ws\n'
				printf 'fi\n'
				;;
			esac
		fi
	} >"${outfile}"
}

set_default_shell() {
	local zsh_path
	zsh_path=$(command -v zsh 2>/dev/null) || return 0
	grep -qF "${zsh_path}" /etc/shells 2>/dev/null || echo "${zsh_path}" >>/etc/shells
	chsh -s "${zsh_path}" "${REMOTE_USER}" 2>/dev/null || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	install_deps
	install_omz
	install_external_plugins
	ensure_zshrc_d
	write_global_zshrc
	write_zshrc
	set_default_shell
	echo "oh-my-zsh: installation complete for user '${REMOTE_USER}'."
fi
