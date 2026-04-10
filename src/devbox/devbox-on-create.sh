#!/bin/bash
# devbox-on-create — runs as the onCreateCommand for the devbox feature.
#
# 1. Runs `devbox install` inside the workspace (if devbox.json is present).
# 2. Exports the project's devbox Nix profile into login shells (.zshrc and
#    .bashrc) so commands like `direnv` are available everywhere in the
#    container without requiring `devbox run` or a `devbox shell` wrapper.
# 3. Optionally exports the global devbox Nix profile (controlled by the
#    exportGlobalProfile feature option, default: true).
# 4. Sources the nix-daemon profile in login shells when present (needed for
#    multi-user Nix installations in devcontainers where systemd doesn't run).
#
# The workspace root is taken from $containerWorkspaceFolder (set by the
# devcontainer CLI) or falls back to the current working directory.
set -euo pipefail

WORKSPACE="${containerWorkspaceFolder:-$PWD}"
EXPORTGLOBALPROFILE="${EXPORTGLOBALPROFILE:-true}"

NIX_DAEMON_BIN="/nix/var/nix/profiles/default/bin/nix-daemon"
NIX_DAEMON_SOCKET="/nix/var/nix/daemon-socket/socket"
NIX_DAEMON_LOG="/tmp/nix-daemon.log"

# ── helpers ───────────────────────────────────────────────────────────────────

# add_to_shell <marker> <content> <file>
# Idempotently inserts a named block into a shell config file.
# Safe to call on every container start; the block is a no-op if already added.
add_to_shell() {
	local marker="$1" content="$2" file="$3"
	[ -f "$file" ] || touch "$file"
	grep -qF "# BEGIN ${marker}" "$file" && return 0
	printf '\n# BEGIN %s\n%s\n# END %s\n' "$marker" "$content" "$marker" >>"$file"
}

wait_for_nix_daemon_socket() {
	local attempts="${1:-30}"
	local i=0

	while [ "$i" -lt "$attempts" ]; do
		if [ -S "${NIX_DAEMON_SOCKET}" ]; then
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done

	return 1
}

ensure_nix_daemon_ready() {
	if [ -S "${NIX_DAEMON_SOCKET}" ]; then
		echo "devbox-on-create: nix-daemon socket already present."
		return 0
	fi

	if [ ! -x "${NIX_DAEMON_BIN}" ]; then
		echo "devbox-on-create: nix-daemon binary not found at ${NIX_DAEMON_BIN}; continuing without daemon start."
		return 0
	fi

	if pgrep -x nix-daemon >/dev/null 2>&1; then
		echo "devbox-on-create: nix-daemon process is running; waiting for socket..."
	else
		if [ "$(id -u)" -eq 0 ]; then
			echo "devbox-on-create: starting nix-daemon (log: ${NIX_DAEMON_LOG})..."
			"${NIX_DAEMON_BIN}" --daemon &>"${NIX_DAEMON_LOG}" &
		else
			echo "devbox-on-create: running as non-root (uid=$(id -u)); cannot start nix-daemon."
		fi
	fi

	if wait_for_nix_daemon_socket 30; then
		echo "devbox-on-create: nix-daemon socket is ready."
		return 0
	fi

	echo "devbox-on-create: warning: nix-daemon socket did not appear at ${NIX_DAEMON_SOCKET} within timeout."
	return 0
}

# ── devbox install ────────────────────────────────────────────────────────────

if [ -f "${WORKSPACE}/devbox.json" ]; then
	ensure_nix_daemon_ready

	echo "devbox-on-create: running devbox install in ${WORKSPACE}..."
	# Run devbox install in fully non-interactive mode.
	#
	# Three complementary guards (following the same approach used by the
	# official jetify-com/devbox-install-action):
	#
	# 1. CI=1  — tells devbox we are in a CI/automated environment, which
	#    suppresses some interactive behaviour.
	#
	# 2. FORCE=1 — the environment variable checked by the devbox CLI
	#    installer script (get.jetify.com/devbox) and sub-scripts to skip
	#    confirmation prompts; matches what the official devbox-install-action
	#    uses (`curl ... | FORCE=1 bash`).
	#
	# 3. </dev/null — belt-and-suspenders stdin redirect.  Any remaining
	#    fmt.Scanln / bufio.ReadByte call receives EOF immediately rather than
	#    blocking on a TTY.
	#
	# 4. 2>&1 | cat — THE critical guard for the isatty prompt in devbox's
	#    EnsureNixInstalled.  Devbox gates the "Press enter to continue" Nix
	#    install prompt on isatty.IsTerminal(os.Stdout.Fd()).  In Codespaces,
	#    onCreateCommand runs with stdout wired to a terminal, so this check
	#    would be true.  Piping stdout (and stderr) through `cat` turns the
	#    write end of the pipe into devbox's stdout, which is NOT a terminal,
	#    so IsTerminal returns false and the prompt is never shown.  Output is
	#    still visible because cat forwards it.  With `set -o pipefail`
	#    (inherited by the subshell), a non-zero devbox exit propagates
	#    correctly through the pipeline.
	if (cd "${WORKSPACE}" && CI=1 FORCE=1 devbox install </dev/null 2>&1 | cat); then
		echo "devbox-on-create: devbox install complete."
	else
		echo "devbox-on-create: warning: devbox install failed; continuing so the container can start. Retry manually with 'cd ${WORKSPACE} && devbox install'."
	fi
else
	echo "devbox-on-create: no devbox.json found in ${WORKSPACE}, skipping devbox install."
fi

# ── export project devbox profile into login shells ──────────────────────────
# Project packages from `devbox install` live in the repo-local Nix profile,
# not the global devbox profile. Exporting this profile makes devbox-managed
# tools available in every shell session without `devbox run`.

DEVBOX_PROFILE="${WORKSPACE}/.devbox/nix/profile/default/bin"

# Idempotent guard: only prepends the path when it isn't already in $PATH.
PATH_INIT="case \":\$PATH:\" in"
PATH_INIT="${PATH_INIT} *\":${DEVBOX_PROFILE}:\"*) ;;"
PATH_INIT="${PATH_INIT} *) export PATH=\"${DEVBOX_PROFILE}:\$PATH\" ;;"
PATH_INIT="${PATH_INIT} esac"

for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
	add_to_shell "devbox-project-path" "$PATH_INIT" "$rc"
done

echo "devbox-on-create: devbox profile path exported to shell configs."

# ── export global devbox profile into login shells ───────────────────────────

if [ "${EXPORTGLOBALPROFILE}" = "true" ]; then
	DEVBOX_GLOBAL_PROFILE="${HOME}/.local/share/devbox/global/default/.devbox/nix/profile/default/bin"

	GLOBAL_PATH_INIT="case \":\$PATH:\" in"
	GLOBAL_PATH_INIT="${GLOBAL_PATH_INIT} *\":${DEVBOX_GLOBAL_PROFILE}:\"*) ;;"
	GLOBAL_PATH_INIT="${GLOBAL_PATH_INIT} *) export PATH=\"${DEVBOX_GLOBAL_PROFILE}:\$PATH\" ;;"
	GLOBAL_PATH_INIT="${GLOBAL_PATH_INIT} esac"

	for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
		add_to_shell "devbox-global-path" "$GLOBAL_PATH_INIT" "$rc"
	done

	echo "devbox-on-create: global devbox profile path exported to shell configs."
fi

# ── source nix-daemon profile in login shells ────────────────────────────────
# Needed for multi-user Nix installations in devcontainers where systemd
# doesn't run and nix-daemon isn't started automatically.

NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

if [ -f "${NIX_DAEMON_PROFILE}" ]; then
	NIX_INIT=". ${NIX_DAEMON_PROFILE} 2>/dev/null || true"
	for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
		add_to_shell "devbox-nix-daemon" "$NIX_INIT" "$rc"
	done
	echo "devbox-on-create: nix-daemon profile sourcing added to shell configs."
fi
