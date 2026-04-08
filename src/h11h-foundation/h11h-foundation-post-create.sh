#!/bin/bash
# h11h-foundation-post-create — postCreateCommand lifecycle script.
#
# Runs the project-setup post-create hook if project-setup is not disabled.
set -euo pipefail

CONFIG_DIR="${H11H_FOUNDATION_CONFIG_DIR:-/usr/local/share/h11h-foundation}"
DISABLE=""
[ -f "${CONFIG_DIR}/disable.conf" ] && DISABLE="$(cat "${CONFIG_DIR}/disable.conf")"

is_disabled() {
	case ",$DISABLE," in
	*",$1,"*) return 0 ;;
	*) return 1 ;;
	esac
}

# ── project-setup post-create ────────────────────────────────────────────────
if ! is_disabled "project-setup"; then
	if command -v project-setup-post-create >/dev/null 2>&1; then
		project-setup-post-create
	else
		echo "h11h-foundation-post-create: project-setup-post-create not found; skipping."
	fi
else
	echo "h11h-foundation-post-create: project-setup disabled; skipping post-create."
fi
