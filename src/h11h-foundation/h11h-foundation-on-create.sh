#!/bin/bash
# h11h-foundation-on-create — onCreateCommand lifecycle script.
#
# Runs the devbox on-create hook if devbox is not disabled.
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

# ── devbox on-create ─────────────────────────────────────────────────────────
if ! is_disabled "devbox"; then
	if command -v devbox-on-create >/dev/null 2>&1; then
		# Pass through the exportGlobalProfile setting
		EXPORT_GLOBAL_PROFILE="true"
		[ -f "${CONFIG_DIR}/export-global-profile.conf" ] && EXPORT_GLOBAL_PROFILE="$(cat "${CONFIG_DIR}/export-global-profile.conf")"
		EXPORTGLOBALPROFILE="$EXPORT_GLOBAL_PROFILE" devbox-on-create
	else
		echo "h11h-foundation-on-create: devbox-on-create not found; skipping."
	fi
else
	echo "h11h-foundation-on-create: devbox disabled; skipping on-create."
fi
