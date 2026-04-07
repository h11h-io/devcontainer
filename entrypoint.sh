#!/bin/bash
# entrypoint.sh — devcontainer simulation entrypoint
set -euo pipefail

# Find the mounted workspace
WORKSPACE=""
for dir in /workspaces/*/; do
if [ -d "$dir" ]; then
WORKSPACE="$dir"
break
fi
done

if [ -z "$WORKSPACE" ]; then
echo "ERROR: No workspace found in /workspaces/."
echo "Mount your repository: docker run -v \"\$(pwd):/workspaces/\$(basename \$(pwd))\" ..."
exit 1
fi

echo "=== Devcontainer Simulation ==="
echo "Workspace: ${WORKSPACE}"
echo ""

# Check for devcontainer.json
if [ -f "${WORKSPACE}.devcontainer/devcontainer.json" ]; then
echo "Found .devcontainer/devcontainer.json"
echo "Running devcontainer features install..."
cd "$WORKSPACE"
devcontainer features install --workspace-folder . 2>&1 || {
echo "WARNING: devcontainer features install failed. Dropping to shell."
}
echo ""
echo "=== Feature installation complete ==="
else
echo "No .devcontainer/devcontainer.json found — dropping to shell."
fi

echo ""
echo "You are now inside the simulated devcontainer."
echo "Workspace is at: ${WORKSPACE}"
echo ""

exec "$@"
