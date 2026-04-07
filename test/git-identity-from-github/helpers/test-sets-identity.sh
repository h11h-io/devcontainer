#!/bin/bash
# Helper: sets git identity from a mock API response (no real token needed).
# Expects the configure-git-identity script to be at /usr/local/bin/configure-git-identity.
set -euo pipefail

MOCK_BIN=$(mktemp -d)
export HOME
HOME=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$MOCK_BIN' '$HOME'" EXIT

cat >"$MOCK_BIN/curl" <<'EOF'
#!/bin/sh
printf '{"login":"testuser","id":12345,"name":"Test User","email":"test@example.com"}'
EOF
chmod +x "$MOCK_BIN/curl"
export PATH="$MOCK_BIN:$PATH"

export GITHUB_TOKEN="mock-token"
export OVERWRITE="true"

/usr/local/bin/configure-git-identity

actual_name=$(git config --global user.name)
actual_email=$(git config --global user.email)

[ "$actual_name" = "Test User" ] || {
	echo "FAIL: expected name 'Test User', got '$actual_name'"
	exit 1
}
[ "$actual_email" = "test@example.com" ] || {
	echo "FAIL: expected email 'test@example.com', got '$actual_email'"
	exit 1
}
