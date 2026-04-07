#!/bin/bash
# entrypoint.sh — devcontainer simulation entrypoint
set -euo pipefail

FEATURES_ROOT="/opt/devcontainer-features"

log() {
	echo "[devcontainer-sim] $*"
}

feature_name_from_key() {
	local key="$1"
	local without_tag="${key%%:*}"
	echo "${without_tag##*/}"
}

json_option_to_env_name() {
	local option_name="$1"
	local env_name
	env_name="$(echo "$option_name" | sed -E 's/[^a-zA-Z0-9]+/_/g' | tr '[:lower:]' '[:upper:]')"
	echo "$env_name"
}

apply_feature_env_overrides() {
	local key="$1"
	local options_json="$2"
	local env_pairs=""
	local option_name env_name value

	while IFS= read -r option_name; do
		[ -z "$option_name" ] && continue
		env_name="$(json_option_to_env_name "$option_name")"
		value="$(echo "$options_json" | jq -r --arg name "$option_name" '.[$name]')"
		env_pairs+="${env_name}="
		env_pairs+="$(printf '%q' "$value")"
		env_pairs+=" "
	done < <(echo "$options_json" | jq -r 'keys[]')

	# Feature-specific compatibility aliases used by existing install.sh scripts.
	case "$key" in
	*"/supabase-cli"*)
		if echo "$options_json" | jq -e 'has("dockerWaitSeconds")' >/dev/null; then
			value="$(echo "$options_json" | jq -r '.dockerWaitSeconds')"
			env_pairs+="DOCKERWAITSECONDS=$(printf '%q' "$value") "
		fi
		;;
	esac

	echo "$env_pairs"
}

install_feature() {
	local key="$1"
	local options_json="$2"
	local feature_name feature_dir install_script env_assignments
	feature_name="$(feature_name_from_key "$key")"
	feature_dir="${FEATURES_ROOT}/${feature_name}"
	install_script="${feature_dir}/install.sh"

	if [ ! -f "$install_script" ]; then
		log "Skipping unsupported feature '${key}' (no local installer at ${install_script})."
		return 0
	fi

	env_assignments="$(apply_feature_env_overrides "$key" "$options_json")"
	log "Installing feature '${key}' via ${install_script}..."
	# shellcheck disable=SC2086
	eval "${env_assignments} bash $(printf '%q' "$install_script")"
}

run_lifecycle_hooks() {
	local key="$1"
	local feature_name feature_json on_create post_start
	feature_name="$(feature_name_from_key "$key")"
	feature_json="${FEATURES_ROOT}/${feature_name}/devcontainer-feature.json"

	if [ ! -f "$feature_json" ]; then
		return 0
	fi

	on_create="$(jq -r '.onCreateCommand // empty' "$feature_json")"
	post_start="$(jq -r '.postStartCommand // empty' "$feature_json")"

	if [ -n "$on_create" ]; then
		log "Running onCreateCommand for '${key}': ${on_create}"
		(cd "$WORKSPACE" && containerWorkspaceFolder="$WORKSPACE" bash -lc "$on_create") ||
			log "WARNING: onCreateCommand failed for '${key}'."
	fi

	if [ -n "$post_start" ]; then
		log "Running postStartCommand for '${key}': ${post_start}"
		(cd "$WORKSPACE" && containerWorkspaceFolder="$WORKSPACE" bash -lc "$post_start") ||
			log "WARNING: postStartCommand failed for '${key}'."
	fi
}

# Find the mounted workspace
WORKSPACE=""
for dir in /workspaces/*/; do
	if [ -d "$dir" ]; then
		WORKSPACE="${dir%/}"
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

DEVCONTAINER_JSON="${WORKSPACE}/.devcontainer/devcontainer.json"
if [ -f "$DEVCONTAINER_JSON" ]; then
	log "Found .devcontainer/devcontainer.json"

	if ! jq -e '.features | type == "object"' "$DEVCONTAINER_JSON" >/dev/null; then
		log "No features object in devcontainer.json."
	else
		while IFS= read -r key; do
			options_json="$(jq -c --arg key "$key" '.features[$key] // {}' "$DEVCONTAINER_JSON")"
			install_feature "$key" "$options_json"
			run_lifecycle_hooks "$key"
		done < <(jq -r '.features | keys[]' "$DEVCONTAINER_JSON")
	fi

	echo ""
	echo "=== Feature installation complete ==="
else
	log "No .devcontainer/devcontainer.json found — dropping to shell."
fi

echo ""
echo "You are now inside the simulated devcontainer."
echo "Workspace is at: ${WORKSPACE}"
echo ""

exec "$@"
