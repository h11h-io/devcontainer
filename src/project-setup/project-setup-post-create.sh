#!/bin/bash
# project-setup-post-create — runs project setup tasks as the postCreateCommand.
#
# Options are baked in by install.sh into /usr/local/share/project-setup/config.sh
# and can be overridden at runtime with PROJECT_SETUP_* environment variables.
#
# Graceful failures: every step warns and continues so the container always starts.
set -uo pipefail

WORKSPACE="${containerWorkspaceFolder:-$PWD}"

# ── configuration ──────────────────────────────────────────────────────────────

# Source baked-in defaults written by install.sh.
# The path can be overridden for testing via PROJECT_SETUP_CONFIG_FILE.
_CONFIG_FILE="${PROJECT_SETUP_CONFIG_FILE:-/usr/local/share/project-setup/config.sh}"
# shellcheck source=/dev/null
[ -f "$_CONFIG_FILE" ] && . "$_CONFIG_FILE"

# Effective values: baked defaults, overridable at runtime via env vars.
NODE_SUBDIRS="${PROJECT_SETUP_NODE_SUBDIRS:-${BAKED_NODE_SUBDIRS:-}}"
PYTHON_SUBDIRS="${PROJECT_SETUP_PYTHON_SUBDIRS:-${BAKED_PYTHON_SUBDIRS:-}}"
ENV_FILES="${PROJECT_SETUP_ENV_FILES:-${BAKED_ENV_FILES:-}}"
LEFTHOOK_INSTALL="${PROJECT_SETUP_LEFTHOOK_INSTALL:-${BAKED_LEFTHOOK_INSTALL:-true}}"
DIRENV_ALLOW="${PROJECT_SETUP_DIRENV_ALLOW:-${BAKED_DIRENV_ALLOW:-true}}"

# Command hooks — override in tests to avoid requiring real tools on PATH.
_PNPM_CMD="${PNPM_CMD:-pnpm}"
_UV_CMD="${UV_CMD:-uv}"
_LEFTHOOK_CMD="${LEFTHOOK_CMD:-lefthook}"
_DIRENV_CMD="${DIRENV_CMD:-direnv}"

# ── helpers ────────────────────────────────────────────────────────────────────

log() { echo "project-setup: $*"; }

# ── node subdirectories ────────────────────────────────────────────────────────

if [ -n "$NODE_SUBDIRS" ]; then
	for subdir in $NODE_SUBDIRS; do
		dir="${WORKSPACE}/${subdir}"
		if [ ! -f "${dir}/package.json" ]; then
			log "WARNING: no package.json in ${subdir}; skipping pnpm install."
			continue
		fi
		if ! command -v "$_PNPM_CMD" >/dev/null 2>&1; then
			log "WARNING: pnpm not found; skipping pnpm install in ${subdir}."
			continue
		fi
		log "running pnpm install in ${subdir}..."
		if (cd "$dir" && "$_PNPM_CMD" install); then
			log "pnpm install complete in ${subdir}."
		else
			log "WARNING: pnpm install failed in ${subdir}; continuing."
		fi
	done
fi

# ── python subdirectories ──────────────────────────────────────────────────────

if [ -n "$PYTHON_SUBDIRS" ]; then
	for subdir in $PYTHON_SUBDIRS; do
		dir="${WORKSPACE}/${subdir}"
		if [ ! -f "${dir}/pyproject.toml" ]; then
			log "WARNING: no pyproject.toml in ${subdir}; skipping uv sync."
			continue
		fi
		if ! command -v "$_UV_CMD" >/dev/null 2>&1; then
			log "WARNING: uv not found; skipping uv sync in ${subdir}."
			continue
		fi
		log "running uv sync in ${subdir}..."
		if (cd "$dir" && "$_UV_CMD" sync); then
			log "uv sync complete in ${subdir}."
		else
			log "WARNING: uv sync failed in ${subdir}; continuing."
		fi
	done
fi

# ── env files ─────────────────────────────────────────────────────────────────

if [ -n "$ENV_FILES" ]; then
	for pair in $ENV_FILES; do
		example="${WORKSPACE}/${pair%%:*}"
		target="${WORKSPACE}/${pair##*:}"
		if [ -f "$target" ]; then
			log "$(basename "$target") already exists; skipping copy."
		elif [ -f "$example" ]; then
			cp "$example" "$target"
			log "copied $(basename "$example") → $(basename "$target")."
		else
			log "WARNING: example file ${pair%%:*} not found; skipping."
		fi
	done
fi

# ── lefthook install ───────────────────────────────────────────────────────────

if [ "$LEFTHOOK_INSTALL" = "true" ]; then
	if ! command -v "$_LEFTHOOK_CMD" >/dev/null 2>&1; then
		log "WARNING: lefthook not found; skipping lefthook install."
	else
		log "running lefthook install..."
		if (cd "$WORKSPACE" && "$_LEFTHOOK_CMD" install); then
			log "lefthook install complete."
		else
			log "WARNING: lefthook install failed; continuing."
		fi
	fi
fi

# ── direnv allow ───────────────────────────────────────────────────────────────

if [ "$DIRENV_ALLOW" = "true" ]; then
	if ! command -v "$_DIRENV_CMD" >/dev/null 2>&1; then
		log "WARNING: direnv not found; skipping direnv allow."
	else
		log "running direnv allow..."
		if (cd "$WORKSPACE" && "$_DIRENV_CMD" allow .); then
			log "direnv allow complete."
		else
			log "WARNING: direnv allow failed; continuing."
		fi
	fi
fi

log "done."
