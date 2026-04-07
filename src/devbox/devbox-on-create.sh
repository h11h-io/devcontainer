#!/bin/bash
# devbox-on-create — runs as the onCreateCommand for the devbox feature.
#
# 1. Runs `devbox install` inside the workspace (if devbox.json is present).
# 2. Exports the project's devbox Nix profile into login shells (.zshrc and
#    .bashrc) so commands like `direnv` are available everywhere in the
#    container without requiring `devbox run` or a `devbox shell` wrapper.
#
# The workspace root is taken from $containerWorkspaceFolder (set by the
# devcontainer CLI) or falls back to the current working directory.
set -euo pipefail

WORKSPACE="${containerWorkspaceFolder:-$PWD}"

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

# ── devbox install ────────────────────────────────────────────────────────────

if [ -f "${WORKSPACE}/devbox.json" ]; then
	echo "devbox-on-create: running devbox install in ${WORKSPACE}..."
	(cd "${WORKSPACE}" && devbox install)
	echo "devbox-on-create: devbox install complete."
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
