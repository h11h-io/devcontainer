#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/git-identity-from-github/configure-git-identity.sh
#
# Tests run WITHOUT Docker, mocking external commands via PATH manipulation
# and isolating git config through a temporary HOME directory.
#
# Usage:  bash test/unit/test_git_identity.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/src/git-identity-from-github/configure-git-identity.sh"

# ── tiny test harness ─────────────────────────────────────────────────────────
PASS=0
FAIL=0
_ERRORS=()

pass() {
	echo "  PASS  $1"
	PASS=$((PASS + 1))
}
fail() {
	echo "  FAIL  $1"
	echo "        $2"
	_ERRORS+=("$1: $2")
	FAIL=$((FAIL + 1))
}

assert_ok() {
	local label="$1"
	shift
	local out
	if out=$("$@" 2>&1); then
		pass "$label"
	else
		fail "$label" "$out"
	fi
}

summary() {
	echo ""
	echo "Results: ${PASS} passed, ${FAIL} failed"
	if [ "${FAIL}" -gt 0 ]; then
		echo ""
		echo "Failures:"
		for e in "${_ERRORS[@]}"; do echo "  - $e"; done
		exit 1
	fi
}

# ── shared setup ─────────────────────────────────────────────────────────────
_TMPDIRS=()
new_tmp() {
	local d
	d=$(mktemp -d)
	_TMPDIRS+=("$d")
	echo "$d"
}
cleanup() {
	for d in "${_TMPDIRS[@]+"${_TMPDIRS[@]}"}"; do rm -rf "$d"; done
}
trap cleanup EXIT

# write_mock_curl <bin_dir> <json_response>
# Creates a curl stub that prints the given JSON string to stdout.
write_mock_curl() {
	local bin_dir="$1" json="$2"
	mkdir -p "$bin_dir"
	# Write JSON to a data file so the stub script can cat it without quoting issues.
	printf '%s' "$json" >"$bin_dir/curl.data"
	printf '#!/bin/sh\ncat "%s/curl.data"\n' "$bin_dir" >"$bin_dir/curl"
	chmod +x "$bin_dir/curl"
}

# write_failing_curl <bin_dir>
# Creates a curl stub that exits non-zero (simulates network failure).
write_failing_curl() {
	local bin_dir="$1"
	mkdir -p "$bin_dir"
	printf '#!/bin/sh\nexit 1\n' >"$bin_dir/curl"
	chmod +x "$bin_dir/curl"
}

# run_script_with <home_dir> <mock_bin_dir> [VAR=val ...]
# Runs the script in an isolated environment.
run_script_with() {
	local home_dir="$1" bin_dir="$2"
	shift 2
	HOME="$home_dir" PATH="$bin_dir:$PATH" bash "$SCRIPT"
}

# ── tests ──────────────────────────────────────────────────────────────────────

echo ""
echo "=== configure-git-identity.sh unit tests ==="
echo ""

# 1. Script is sourceable without auto-executing configure_git_identity
(
	# shellcheck source=src/git-identity-from-github/configure-git-identity.sh
	source "$SCRIPT"
	type configure_git_identity >/dev/null
) && pass "script is sourceable without side-effects" || fail "script is sourceable without side-effects" "source failed"

# 2. No token → exits 0, prints warning to stderr
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
OUT=$(HOME="$TEST_HOME" GITHUB_TOKEN="" bash "$SCRIPT" 2>&1) || true
echo "$OUT" | grep -q "warning" && pass "no-token: prints warning to stderr" || fail "no-token: prints warning to stderr" "$OUT"

# 3. No token → git identity NOT set
TEST_HOME=$(new_tmp)
git -C "$TEST_HOME" config --global user.name >/dev/null 2>&1 &&
	fail "no-token: identity should not be set" "user.name was set" ||
	pass "no-token: does not set git identity"

# 4. Valid token + working API → sets name and email
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_mock_curl "$TEST_BIN" '{"login":"alice","id":42,"name":"Alice Example","email":"alice@example.com"}'
HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="true" bash "$SCRIPT" >/dev/null 2>&1
RESULT_NAME=$(HOME="$TEST_HOME" git config --global user.name 2>/dev/null)
RESULT_EMAIL=$(HOME="$TEST_HOME" git config --global user.email 2>/dev/null)
[ "$RESULT_NAME" = "Alice Example" ] &&
	pass "valid-token: sets user.name" ||
	fail "valid-token: sets user.name" "got '${RESULT_NAME}'"
[ "$RESULT_EMAIL" = "alice@example.com" ] &&
	pass "valid-token: sets user.email" ||
	fail "valid-token: sets user.email" "got '${RESULT_EMAIL}'"

# 5. Private/null email → falls back to noreply address
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_mock_curl "$TEST_BIN" '{"login":"bob","id":99,"name":"Bob","email":null}'
HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="true" bash "$SCRIPT" >/dev/null 2>&1
RESULT_EMAIL=$(HOME="$TEST_HOME" git config --global user.email 2>/dev/null)
[ "$RESULT_EMAIL" = "99+bob@users.noreply.github.com" ] &&
	pass "private-email: uses noreply fallback" ||
	fail "private-email: uses noreply fallback" "got '${RESULT_EMAIL}'"

# 6. Null/missing display name → falls back to login
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_mock_curl "$TEST_BIN" '{"login":"carol","id":7,"name":null,"email":"carol@example.com"}'
HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="true" bash "$SCRIPT" >/dev/null 2>&1
RESULT_NAME=$(HOME="$TEST_HOME" git config --global user.name 2>/dev/null)
[ "$RESULT_NAME" = "carol" ] &&
	pass "empty-name: falls back to login" ||
	fail "empty-name: falls back to login" "got '${RESULT_NAME}'"

# 7. OVERWRITE=false → skips when identity already set
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_mock_curl "$TEST_BIN" '{"login":"new","id":1,"name":"New Name","email":"new@example.com"}'
HOME="$TEST_HOME" git config --global user.name "Existing"
HOME="$TEST_HOME" git config --global user.email "existing@example.com"
OUT=$(HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="false" bash "$SCRIPT" 2>&1)
echo "$OUT" | grep -q "already set" &&
	pass "overwrite=false: prints 'already set' message" ||
	fail "overwrite=false: prints 'already set' message" "$OUT"
RESULT_NAME=$(HOME="$TEST_HOME" git config --global user.name 2>/dev/null)
[ "$RESULT_NAME" = "Existing" ] &&
	pass "overwrite=false: identity unchanged" ||
	fail "overwrite=false: identity unchanged" "got '${RESULT_NAME}'"

# 8. OVERWRITE=true → re-sets even when identity is already set
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_mock_curl "$TEST_BIN" '{"login":"new","id":1,"name":"New Name","email":"new@example.com"}'
HOME="$TEST_HOME" git config --global user.name "Old Name"
HOME="$TEST_HOME" git config --global user.email "old@example.com"
HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="true" bash "$SCRIPT" >/dev/null 2>&1
RESULT_NAME=$(HOME="$TEST_HOME" git config --global user.name 2>/dev/null)
RESULT_EMAIL=$(HOME="$TEST_HOME" git config --global user.email 2>/dev/null)
[ "$RESULT_NAME" = "New Name" ] &&
	pass "overwrite=true: overwrites user.name" ||
	fail "overwrite=true: overwrites user.name" "got '${RESULT_NAME}'"
[ "$RESULT_EMAIL" = "new@example.com" ] &&
	pass "overwrite=true: overwrites user.email" ||
	fail "overwrite=true: overwrites user.email" "got '${RESULT_EMAIL}'"

# 9. curl fails (network error) → exits 0, warning, no identity set
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_failing_curl "$TEST_BIN"
OUT=$(HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="true" bash "$SCRIPT" 2>&1) || true
echo "$OUT" | grep -q "warning" &&
	pass "api-failure: prints warning" ||
	fail "api-failure: prints warning" "$OUT"
HOME="$TEST_HOME" git config --global user.name >/dev/null 2>&1 &&
	fail "api-failure: should not set identity" "user.name was set" ||
	pass "api-failure: does not set identity"

# 10. API returns JSON without a login field → exits 0, prints warning
TEST_HOME=$(new_tmp)
TEST_BIN=$(new_tmp)
write_mock_curl "$TEST_BIN" '{"error":"bad request"}'
OUT=$(HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" GITHUB_TOKEN="tok" OVERWRITE="true" bash "$SCRIPT" 2>&1)
echo "$OUT" | grep -q "warning" &&
	pass "bad-json: missing login prints warning" ||
	fail "bad-json: missing login prints warning" "$OUT"

summary
