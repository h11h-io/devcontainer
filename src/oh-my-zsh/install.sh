#!/bin/bash
set -euo pipefail

PLUGINS="${PLUGINS:-git sudo z history colored-man-pages zsh-autosuggestions zsh-syntax-highlighting pnpm}"
THEME="${THEME:-robbyrussell}"
EXTRARCSNIPPETS="${EXTRARCSNIPPETS:-}"
AUTOSUGGESTSTYLE="${AUTOSUGGESTSTYLE:-}"
AUTOSUGGESTSTRATEGY="${AUTOSUGGESTSTRATEGY:-}"
REMOTE_USER="${_REMOTE_USER:-${USER:-root}}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-${HOME:-/root}}"

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
	local omz_dir="${REMOTE_USER_HOME}/.oh-my-zsh"
	if [ -d "${omz_dir}" ]; then
		echo "oh-my-zsh: already installed at ${omz_dir}, skipping."
		return 0
	fi
	echo "oh-my-zsh: installing to ${omz_dir}..."
	if ! ZSH="${omz_dir}" HOME="${REMOTE_USER_HOME}" RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
		echo "oh-my-zsh: WARNING: installation failed (network issue?). .zshrc will be written but OMZ won't be available." >&2
	fi
}

install_external_plugins() {
	local plugins_dir="${REMOTE_USER_HOME}/.oh-my-zsh/custom/plugins"
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

	{
		printf '# managed by oh-my-zsh devcontainer feature\n'
		printf 'export ZSH="$HOME/.oh-my-zsh"\n'
		printf 'ZSH_THEME="%s"\n' "${THEME}"
		printf 'plugins=(%s)\n' "${plugin_list}"
		printf 'source "$ZSH/oh-my-zsh.sh"\n'
		if [ -n "${AUTOSUGGESTSTYLE}" ]; then
			printf 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="%s"\n' "${AUTOSUGGESTSTYLE}"
		fi
		if [ -n "${AUTOSUGGESTSTRATEGY}" ]; then
			printf 'ZSH_AUTOSUGGEST_STRATEGY=(%s)\n' "${AUTOSUGGESTSTRATEGY}"
		fi
		if [ -n "${EXTRARCSNIPPETS}" ]; then
			printf '%s\n' "${EXTRARCSNIPPETS}"
		fi
	} >"${zshrc}"

	[ "${REMOTE_USER}" != "root" ] && chown "${REMOTE_USER}:" "${zshrc}" 2>/dev/null || true
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
	write_zshrc
	set_default_shell
	echo "oh-my-zsh: installation complete for user '${REMOTE_USER}'."
fi
