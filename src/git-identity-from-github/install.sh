#!/bin/sh
set -e

# shellcheck disable=SC2034
OVERWRITE="${OVERWRITE:-false}"

# Ensure curl and jq are available
if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "Installing curl and jq..."
    apt-get update -y
    apt-get install -y --no-install-recommends curl jq
    rm -rf /var/lib/apt/lists/*
fi

# Write the configure-git-identity helper script
cat > /usr/local/bin/configure-git-identity << 'SCRIPT'
#!/bin/sh
set -e

OVERWRITE="${OVERWRITE:-false}"

configure_git_identity() {
  # Skip if already configured (unless overwrite is requested)
  if [ "$OVERWRITE" != "true" ]; then
    if git config --global user.email >/dev/null 2>&1 && \
       git config --global user.name  >/dev/null 2>&1; then
      echo "configure-git-identity: git identity already set, skipping (set OVERWRITE=true to force)."
      return 0
    fi
  fi

  # Try token sources in priority order
  local token=""
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    token="$GITHUB_TOKEN"                                           # Codespaces
  elif command -v coder >/dev/null 2>&1; then
    token="$(coder external-auth access-token github 2>/dev/null)" || true  # Coder
  elif command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null)" || true                   # gh CLI fallback
  fi

  if [ -z "$token" ]; then
    echo "configure-git-identity: warning: no GitHub auth token found (GITHUB_TOKEN, coder, or gh CLI). Skipping git identity setup." >&2
    return 0
  fi

  local api_response
  api_response="$(curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user 2>/dev/null)" || true

  if [ -z "$api_response" ]; then
    echo "configure-git-identity: warning: GitHub API request failed. Skipping git identity setup." >&2
    return 0
  fi

  local gh_login gh_id gh_name gh_email
  gh_login="$(printf '%s' "$api_response" | jq -r '.login // empty')"
  gh_id="$(printf '%s' "$api_response"    | jq -r '.id    // empty')"
  gh_name="$(printf '%s' "$api_response"  | jq -r '.name  // empty')"
  gh_email="$(printf '%s' "$api_response" | jq -r '.email // empty')"

  if [ -z "$gh_login" ]; then
    echo "configure-git-identity: warning: could not parse GitHub login from API response. Skipping." >&2
    return 0
  fi

  # Fall back to noreply address if email is private
  [ -z "$gh_email" ] && gh_email="${gh_id}+${gh_login}@users.noreply.github.com"
  # Fall back to login if display name is unset
  [ -z "$gh_name"  ] && gh_name="$gh_login"

  git config --global user.name  "$gh_name"
  git config --global user.email "$gh_email"
  echo "configure-git-identity: git identity set to '${gh_name} <${gh_email}>'."
}

configure_git_identity
SCRIPT

chmod +x /usr/local/bin/configure-git-identity

echo "configure-git-identity: helper script installed at /usr/local/bin/configure-git-identity"
