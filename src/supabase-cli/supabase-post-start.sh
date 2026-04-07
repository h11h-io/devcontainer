#!/bin/bash
# supabase-post-start — pre-pulls Supabase Docker images once per workspace.
# Runs as postStartCommand. Failures are logged but never propagate.
set -uo pipefail

WORKSPACE="${containerWorkspaceFolder:-$PWD}"
DOCKER_WAIT_SECONDS="${SUPABASE_DOCKER_WAIT_SECONDS:-30}"
PREPULL_MARKER="${HOME}/.cache/devcontainer/supabase-prepull.done"

log() { echo "supabase-post-start: $*"; }

mkdir -p "$(dirname "$PREPULL_MARKER")"

# Skip if already done
if [ -f "$PREPULL_MARKER" ]; then
	log "Supabase image pre-pull already completed; skipping."
	exit 0
fi

# Require supabase CLI
if ! command -v supabase >/dev/null 2>&1; then
	log "supabase CLI not found; skipping image pre-pull."
	exit 0
fi

# Wait for Docker daemon
log "waiting for Docker daemon (timeout ${DOCKER_WAIT_SECONDS}s)..."
ready=false
for _ in $(seq 1 "$DOCKER_WAIT_SECONDS"); do
	if docker info >/dev/null 2>&1; then
		ready=true
		break
	fi
	sleep 1
done

if [ "$ready" != "true" ]; then
	log "Docker daemon not reachable after ${DOCKER_WAIT_SECONDS}s; will retry on next container start."
	exit 0
fi

log "Docker is ready; pre-pulling Supabase images..."
if (cd "$WORKSPACE" && supabase start && supabase stop); then
	touch "$PREPULL_MARKER"
	log "Supabase image pre-pull complete."
else
	log "Supabase pre-pull failed; will retry on next container start."
fi
