#!/bin/sh
# h11h-foundation — meta feature install script.
#
# Orchestrates installation of all h11h-io devcontainer sub-features.
# Sub-features can be disabled via the DISABLE option (comma-separated list of
# feature IDs).
set -e

# ── map meta-feature options to sub-feature env vars ─────────────────────────
# The devcontainer runtime uppercases option names, so e.g. "devboxVersion"
# becomes DEVBOXVERSION in the environment.

DISABLE="${DISABLE:-}"
GIT_IDENTITY_OVERWRITE="${GITIDENTITYOVERWRITE:-false}"
DEVBOX_VERSION="${DEVBOXVERSION:-latest}"
EXPORT_GLOBAL_PROFILE="${EXPORTGLOBALPROFILE:-true}"
OHMYZSH_THEME="${OHMYZSHTHEME:-agnoster}"
OHMYZSH_PLUGINS="${OHMYZSHPLUGINS:-git sudo z history colored-man-pages docker python node pnpm direnv zsh-autosuggestions zsh-syntax-highlighting}"
EXTRA_RC_SNIPPETS="${EXTRARCSNIPPETS:-}"
EXTRA_RC_FILE="${EXTRARCFILE:-}"
AUTOSUGGEST_STYLE="${AUTOSUGGESTSTYLE:-fg=60}"
AUTOSUGGEST_STRATEGY="${AUTOSUGGESTSTRATEGY:-history completion}"
NODE_SUBDIRS="${NODESUBDIRS:-}"
PYTHON_SUBDIRS="${PYTHONSUBDIRS:-}"
ENV_FILES="${ENVFILES:-}"
LEFTHOOK_INSTALL="${LEFTHOOKINSTALL:-true}"
DIRENV_ALLOW="${DIRENVALLOW:-true}"
SUPABASE_VERSION="${SUPABASEVERSION:-2.84.2}"
DOCKER_WAIT_SECONDS="${DOCKERWAITSECONDS:-60}"
CODER_VERSION="${CODERVERSION:-latest}"
CONFIGURE_PNPM="${CONFIGUREPNPM:-true}"
CONFIGURE_PIPX="${CONFIGUREPIPX:-false}"
CONFIGURE_NPM="${CONFIGURENPM:-false}"

FEATURE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${H11H_FOUNDATION_CONFIG_DIR:-/usr/local/share/h11h-foundation}"

# ── helpers ──────────────────────────────────────────────────────────────────

# is_disabled <feature-id>
# Returns 0 (true) if the feature is in the disable list, 1 (false) otherwise.
is_disabled() {
	case ",$DISABLE," in
	*",$1,"*) return 0 ;;
	*) return 1 ;;
	esac
}

# ── persist configuration for lifecycle scripts ──────────────────────────────
mkdir -p "$CONFIG_DIR"
printf '%s\n' "$DISABLE" >"${CONFIG_DIR}/disable.conf"

# Save the exportGlobalProfile setting for the on-create script
printf '%s\n' "$EXPORT_GLOBAL_PROFILE" >"${CONFIG_DIR}/export-global-profile.conf"

echo "h11h-foundation: disable list: '${DISABLE:-<none>}'"

# ── install sub-features ─────────────────────────────────────────────────────

if ! is_disabled "git-identity-from-github"; then
	echo ""
	echo "h11h-foundation: ── installing git-identity-from-github ──"
	OVERWRITE="$GIT_IDENTITY_OVERWRITE" \
		sh "${FEATURE_DIR}/features/git-identity-from-github/install.sh"
else
	echo "h11h-foundation: skipping git-identity-from-github (disabled)"
fi

if ! is_disabled "devbox"; then
	echo ""
	echo "h11h-foundation: ── installing devbox ──"
	VERSION="$DEVBOX_VERSION" \
		sh "${FEATURE_DIR}/features/devbox/install.sh"
else
	echo "h11h-foundation: skipping devbox (disabled)"
fi

if ! is_disabled "oh-my-zsh"; then
	echo ""
	echo "h11h-foundation: ── installing oh-my-zsh ──"
	PLUGINS="$OHMYZSH_PLUGINS" \
		THEME="$OHMYZSH_THEME" \
		EXTRARCSNIPPETS="$EXTRA_RC_SNIPPETS" \
		EXTRARCFILE="$EXTRA_RC_FILE" \
		AUTOSUGGESTSTYLE="$AUTOSUGGEST_STYLE" \
		AUTOSUGGESTSTRATEGY="$AUTOSUGGEST_STRATEGY" \
		bash "${FEATURE_DIR}/features/oh-my-zsh/install.sh"
else
	echo "h11h-foundation: skipping oh-my-zsh (disabled)"
fi

if ! is_disabled "project-setup"; then
	echo ""
	echo "h11h-foundation: ── installing project-setup ──"
	NODESUBDIRS="$NODE_SUBDIRS" \
		PYTHONSUBDIRS="$PYTHON_SUBDIRS" \
		ENVFILES="$ENV_FILES" \
		LEFTHOOKINSTALL="$LEFTHOOK_INSTALL" \
		DIRENVALLOW="$DIRENV_ALLOW" \
		sh "${FEATURE_DIR}/features/project-setup/install.sh"
else
	echo "h11h-foundation: skipping project-setup (disabled)"
fi

if ! is_disabled "supabase-cli"; then
	echo ""
	echo "h11h-foundation: ── installing supabase-cli ──"
	VERSION="$SUPABASE_VERSION" \
		DOCKERWAITSECONDS="$DOCKER_WAIT_SECONDS" \
		sh "${FEATURE_DIR}/features/supabase-cli/install.sh"
else
	echo "h11h-foundation: skipping supabase-cli (disabled)"
fi

if ! is_disabled "coder"; then
	echo ""
	echo "h11h-foundation: ── installing coder ──"
	VERSION="$CODER_VERSION" \
		sh "${FEATURE_DIR}/features/coder/install.sh"
else
	echo "h11h-foundation: skipping coder (disabled)"
fi

if ! is_disabled "userspace-pkg-homes"; then
	echo ""
	echo "h11h-foundation: ── installing userspace-pkg-homes ──"
	CONFIGUREPNPM="$CONFIGURE_PNPM" \
		CONFIGUREPIPX="$CONFIGURE_PIPX" \
		CONFIGURENPM="$CONFIGURE_NPM" \
		bash "${FEATURE_DIR}/features/userspace-pkg-homes/install.sh"
else
	echo "h11h-foundation: skipping userspace-pkg-homes (disabled)"
fi

# ── install lifecycle helper scripts ─────────────────────────────────────────
install -o root -g root -m 0755 \
	"${FEATURE_DIR}/h11h-foundation-on-create.sh" \
	/usr/local/bin/h11h-foundation-on-create

install -o root -g root -m 0755 \
	"${FEATURE_DIR}/h11h-foundation-post-create.sh" \
	/usr/local/bin/h11h-foundation-post-create

install -o root -g root -m 0755 \
	"${FEATURE_DIR}/h11h-foundation-post-start.sh" \
	/usr/local/bin/h11h-foundation-post-start

echo ""
echo "h11h-foundation: installation complete."
