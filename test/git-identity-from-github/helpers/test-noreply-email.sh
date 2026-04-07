#!/bin/bash
# Helper: verifies the script uses noreply email when GitHub email is null.
set -euo pipefail

MOCK_BIN=$(mktemp -d)
export HOME
HOME=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$MOCK_BIN' '$HOME'" EXIT

cat >"$MOCK_BIN/curl" <<'EOF'
#!/bin/sh
printf '{"login":"privateuser","id":55555,"name":"Private User","email":null}'
EOF
chmod +x "$MOCK_BIN/curl"
export PATH="$MOCK_BIN:$PATH"

export GITHUB_TOKEN="mock-token"
export OVERWRITE="true"

/usr/local/bin/configure-git-identity

actual_email=$(git config --global user.email)
[ "$actual_email" = "55555+privateuser@users.noreply.github.com" ] || {
	echo "FAIL: expected noreply email, got '$actual_email'"
	exit 1
}
