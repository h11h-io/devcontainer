#!/bin/bash
# devbox-post-start — runs as the postStartCommand for the devbox feature.
#
# Starts the nix-daemon in the background if the daemon binary is present and
# it isn't already running.  Devcontainers don't have systemd, so the daemon
# must be started manually on every container start for multi-user Nix
# installations.
#
# When running as a non-root user (e.g. in Codespaces), the script attempts to
# start the daemon via sudo.  This is essential for pre-built Codespaces where
# nix-daemon is not preserved in the pre-build snapshot and must be restarted
# when the user opens the codespace.
#
# Failures are logged but never propagate — a broken nix-daemon should not
# prevent the container from becoming usable.
set -uo pipefail

NIX_DAEMON_BIN="/nix/var/nix/profiles/default/bin/nix-daemon"
NIX_DAEMON_LOG="/tmp/nix-daemon.log"
SUDO_CMD="${SUDO_CMD:-sudo}"

if [ ! -x "${NIX_DAEMON_BIN}" ]; then
	echo "devbox-post-start: nix-daemon binary not found at ${NIX_DAEMON_BIN}; skipping."
	exit 0
fi

# nix-daemon in multi-user Nix must be started as root.
# When running as a non-root user (e.g. in Codespaces), use sudo non-interactively
# (-n flag prevents password prompts that would hang postStartCommand).
USE_SUDO=false
if [ "$(id -u)" -ne 0 ]; then
	if command -v "$SUDO_CMD" >/dev/null 2>&1; then
		USE_SUDO=true
	else
		echo "devbox-post-start: nix-daemon requires root; running as non-root (uid=$(id -u)) and sudo not available, skipping."
		exit 0
	fi
fi

# Check if nix-daemon is already running
if pgrep -x nix-daemon >/dev/null 2>&1; then
	echo "devbox-post-start: nix-daemon already running; skipping."
	exit 0
fi

echo "devbox-post-start: starting nix-daemon (log: ${NIX_DAEMON_LOG})..."
if [ "$USE_SUDO" = true ]; then
	"$SUDO_CMD" -n "${NIX_DAEMON_BIN}" --daemon &>"${NIX_DAEMON_LOG}" &
else
	"${NIX_DAEMON_BIN}" --daemon &>"${NIX_DAEMON_LOG}" &
fi
start_pid=$!
sleep 1
if daemon_pid="$(pgrep -x nix-daemon | head -n 1)"; then
	echo "devbox-post-start: nix-daemon started (PID ${daemon_pid}; launcher PID ${start_pid})."
else
	echo "devbox-post-start: failed to start nix-daemon; see ${NIX_DAEMON_LOG} for details."
fi
