#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="h11h.local-published-feature-smoke=$$"

cleanup() {
	local container_ids
	container_ids="$(docker ps -aq --filter "label=${LABEL}")"
	if [ -n "$container_ids" ]; then
		docker rm -f "$container_ids" >/dev/null
	fi
}

for dependency in devcontainer docker; do
	if ! command -v "$dependency" >/dev/null; then
		printf 'error: %s is required\n' "$dependency" >&2
		exit 1
	fi
done

if ! docker info >/dev/null 2>&1; then
	printf 'error: Docker is not running or is not reachable\n' >&2
	exit 1
fi

trap cleanup EXIT

printf 'Pulling and building published GHCR features...\n'
devcontainer up \
	--workspace-folder "$TEST_DIR" \
	--id-label "$LABEL" \
	--mount-workspace-git-root false \
	--remove-existing-container \
	--build-no-cache

printf 'Running assertions inside the devcontainer...\n'
devcontainer exec \
	--workspace-folder "$TEST_DIR" \
	--id-label "$LABEL" \
	bash /workspaces/published-features/assert.sh
