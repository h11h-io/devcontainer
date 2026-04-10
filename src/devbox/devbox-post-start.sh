#!/bin/bash
# devbox-post-start — runs as the postStartCommand for the devbox feature.
#
# Starts the nix-daemon in the background if the daemon binary is present and
# it isn't already running.  Devcontainers don't have systemd, so the daemon
# must be started manually on every container start for multi-user Nix
# installations.
#
# Failures are logged but never propagate — a broken nix-daemon should not
# prevent the container from becoming usable.
set -uo pipefail

NIX_DAEMON_BIN="/nix/var/nix/profiles/default/bin/nix-daemon"
NIX_DAEMON_SOCKET="/nix/var/nix/daemon-socket/socket"
NIX_DAEMON_LOG="/tmp/nix-daemon.log"

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

if [ ! -x "${NIX_DAEMON_BIN}" ]; then
	echo "devbox-post-start: nix-daemon binary not found at ${NIX_DAEMON_BIN}; skipping."
	exit 0
fi

if [ -S "${NIX_DAEMON_SOCKET}" ]; then
	if pgrep -x nix-daemon >/dev/null 2>&1; then
		echo "devbox-post-start: nix-daemon socket already present and daemon is running; skipping."
		exit 0
	fi
	echo "devbox-post-start: nix-daemon socket exists but daemon is not running; removing stale socket."
	rm -f "${NIX_DAEMON_SOCKET}"
fi

# nix-daemon in multi-user Nix must be started as root
if [ "$(id -u)" -ne 0 ]; then
	echo "devbox-post-start: nix-daemon requires root; running as non-root (uid=$(id -u)), skipping."
	exit 0
fi

# Check if nix-daemon is already running
if pgrep -x nix-daemon >/dev/null 2>&1; then
	echo "devbox-post-start: nix-daemon already running; waiting for socket..."
else
	echo "devbox-post-start: starting nix-daemon (log: ${NIX_DAEMON_LOG})..."
	"${NIX_DAEMON_BIN}" --daemon &>"${NIX_DAEMON_LOG}" &
	echo "devbox-post-start: nix-daemon started (PID $!)."
fi

if wait_for_nix_daemon_socket 30; then
	echo "devbox-post-start: nix-daemon socket is ready."
else
	echo "devbox-post-start: warning: nix-daemon socket did not appear at ${NIX_DAEMON_SOCKET} within timeout."
fi
