#!/bin/bash
# configure-git-identity — sets git user.name and user.email from the
# authenticated GitHub account.  Runs at container start via postStartCommand.
#
# Environment variables:
#   OVERWRITE   – set to "true" to overwrite an existing git identity (default: false)
#   GITHUB_TOKEN – GitHub token (set automatically in Codespaces)
#
# Token resolution order: GITHUB_TOKEN → coder external-auth → gh CLI
set -euo pipefail

OVERWRITE="${OVERWRITE:-false}"

configure_git_identity() {
	# Skip if already configured (unless overwrite is requested)
	if [ "$OVERWRITE" != "true" ]; then
		if git config --global user.email >/dev/null 2>&1 &&
			git config --global user.name >/dev/null 2>&1; then
			echo "configure-git-identity: git identity already set, skipping (set OVERWRITE=true to force)."
			return 0
		fi
	fi

	# Try token sources in priority order
	local token=""
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		token="$GITHUB_TOKEN" # Codespaces
	elif command -v coder >/dev/null 2>&1; then
		token="$(coder external-auth access-token github 2>/dev/null)" || true # Coder
	elif command -v gh >/dev/null 2>&1; then
		token="$(gh auth token 2>/dev/null)" || true # gh CLI fallback
	fi

	if [ -z "$token" ]; then
		echo "configure-git-identity: warning: no GitHub auth token found (checked: GITHUB_TOKEN, coder, gh CLI). Skipping git identity setup." >&2
		return 0
	fi

	local api_response
	api_response="$(curl -fsSL \
		-H "Authorization: Bearer $token" \
		-H "Accept: application/vnd.github+json" \
		https://api.github.com/user 2>/dev/null)" || true

	if [ -z "$api_response" ]; then
		echo "configure-git-identity: warning: GitHub API request failed or returned empty response. Skipping git identity setup." >&2
		return 0
	fi

	local gh_login gh_id gh_name gh_email
	gh_login="$(printf '%s' "$api_response" | jq -r '.login // empty')"
	gh_id="$(printf '%s' "$api_response" | jq -r '.id    // empty')"
	gh_name="$(printf '%s' "$api_response" | jq -r '.name  // empty')"
	gh_email="$(printf '%s' "$api_response" | jq -r '.email // empty')"

	if [ -z "$gh_login" ]; then
		echo "configure-git-identity: warning: could not parse GitHub login from API response. Skipping." >&2
		return 0
	fi

	# Fall back to noreply address if email is private / not set
	[ -z "$gh_email" ] && gh_email="${gh_id}+${gh_login}@users.noreply.github.com"
	# Fall back to login if display name is not set
	[ -z "$gh_name" ] && gh_name="$gh_login"

	git config --global user.name "$gh_name"
	git config --global user.email "$gh_email"
	echo "configure-git-identity: git identity set to '${gh_name} <${gh_email}>'."
}

# Allow sourcing this file (e.g. for unit tests) without auto-executing.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	configure_git_identity
fi
