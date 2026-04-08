#!/bin/bash
# h11h-foundation-post-start — postStartCommand lifecycle script.
#
# Runs the post-start hooks for enabled sub-features:
#   - configure-git-identity  (git-identity-from-github)
#   - devbox-post-start        (devbox)
#   - supabase-post-start      (supabase-cli)
#
# Failures in individual hooks are logged but do not prevent other hooks from
# running, matching the convention used by the standalone features.
set -uo pipefail

CONFIG_DIR="${H11H_FOUNDATION_CONFIG_DIR:-/usr/local/share/h11h-foundation}"
DISABLE=""
[ -f "${CONFIG_DIR}/disable.conf" ] && DISABLE="$(cat "${CONFIG_DIR}/disable.conf")"

is_disabled() {
	case ",$DISABLE," in
	*",$1,"*) return 0 ;;
	*) return 1 ;;
	esac
}

# ── git-identity-from-github post-start ──────────────────────────────────────
if ! is_disabled "git-identity-from-github"; then
	if command -v configure-git-identity >/dev/null 2>&1; then
		echo "h11h-foundation-post-start: running configure-git-identity..."
		configure-git-identity || echo "h11h-foundation-post-start: WARNING: configure-git-identity failed; continuing."
	else
		echo "h11h-foundation-post-start: configure-git-identity not found; skipping."
	fi
else
	echo "h11h-foundation-post-start: git-identity-from-github disabled; skipping."
fi

# ── devbox post-start ────────────────────────────────────────────────────────
if ! is_disabled "devbox"; then
	if command -v devbox-post-start >/dev/null 2>&1; then
		echo "h11h-foundation-post-start: running devbox-post-start..."
		devbox-post-start || echo "h11h-foundation-post-start: WARNING: devbox-post-start failed; continuing."
	else
		echo "h11h-foundation-post-start: devbox-post-start not found; skipping."
	fi
else
	echo "h11h-foundation-post-start: devbox disabled; skipping."
fi

# ── supabase-cli post-start ──────────────────────────────────────────────────
if ! is_disabled "supabase-cli"; then
	if command -v supabase-post-start >/dev/null 2>&1; then
		echo "h11h-foundation-post-start: running supabase-post-start..."
		supabase-post-start || echo "h11h-foundation-post-start: WARNING: supabase-post-start failed; continuing."
	else
		echo "h11h-foundation-post-start: supabase-post-start not found; skipping."
	fi
else
	echo "h11h-foundation-post-start: supabase-cli disabled; skipping."
fi

echo "h11h-foundation-post-start: done."
