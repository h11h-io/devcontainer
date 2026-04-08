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
NIX_DAEMON_LOG="/tmp/nix-daemon.log"

if [ ! -x "${NIX_DAEMON_BIN}" ]; then
	echo "devbox-post-start: nix-daemon binary not found at ${NIX_DAEMON_BIN}; skipping."
	exit 0
fi

# Check if nix-daemon is already running
if pgrep -x nix-daemon >/dev/null 2>&1; then
	echo "devbox-post-start: nix-daemon already running; skipping."
	exit 0
fi

echo "devbox-post-start: starting nix-daemon (log: ${NIX_DAEMON_LOG})..."
"${NIX_DAEMON_BIN}" --daemon &>"${NIX_DAEMON_LOG}" &
echo "devbox-post-start: nix-daemon started (PID $!)."
