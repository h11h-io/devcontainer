#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/coder/install.sh
#
# Usage:  bash test/unit/test_coder_install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/coder/install.sh"

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

echo ""
echo "=== coder/install.sh unit tests ==="
echo ""

# 1. Skips install when coder is already installed
TEST_BIN=$(new_tmp)
CURL_LOG="${TEST_BIN}/curl_calls.log"
cat >"${TEST_BIN}/coder" <<'EOF'
#!/bin/sh
case "${1:-}" in
	version) echo "Coder v2.0.0" ;;
	*) echo "mock coder $*" ;;
esac
EOF
chmod +x "${TEST_BIN}/coder"
cat >"${TEST_BIN}/curl" <<EOF
#!/bin/sh
echo "\$@" >> "${CURL_LOG}"
EOF
chmod +x "${TEST_BIN}/curl"
out=$(PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" 2>&1)
echo "$out" | grep -q "already installed" &&
	pass "already-installed: prints 'already installed' message" ||
	fail "already-installed: prints 'already installed' message" "output: $out"
test ! -f "${CURL_LOG}" &&
	pass "already-installed: curl not called" ||
	fail "already-installed: curl not called" "curl was called: $(cat "${CURL_LOG}")"

# 2. Calls installer with 'latest' by default (no CODER_VERSION env in pipe)
TEST_BIN=$(new_tmp)
CURL_LOG="${TEST_BIN}/curl_calls.log"
cat >"${TEST_BIN}/curl" <<EOF
#!/bin/sh
echo "\$@" >> "${CURL_LOG}"
printf '#!/bin/sh\necho "mock installer"\n'
EOF
chmod +x "${TEST_BIN}/curl"
# sh mock: intercept piped execution
cat >"${TEST_BIN}/sh" <<EOF
#!/bin/sh
# Record env and args
echo "CODER_VERSION=\${CODER_VERSION:-unset}" >> "${TEST_BIN}/sh_calls.log"
echo "\$@" >> "${TEST_BIN}/sh_calls.log"
EOF
chmod +x "${TEST_BIN}/sh"
PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 || true
grep -q "coder.com/install.sh" "${CURL_LOG}" &&
	pass "latest: curl fetches coder.com/install.sh" ||
	fail "latest: curl fetches coder.com/install.sh" "curl log: $(cat "${CURL_LOG}" 2>/dev/null)"

# 3. Passes CODER_VERSION when a specific version is requested
TEST_BIN=$(new_tmp)
CURL_LOG="${TEST_BIN}/curl_calls.log"
SH_LOG="${TEST_BIN}/sh_calls.log"
cat >"${TEST_BIN}/curl" <<EOF
#!/bin/sh
echo "\$@" >> "${CURL_LOG}"
printf '#!/bin/sh\necho "mock installer"\n'
EOF
chmod +x "${TEST_BIN}/curl"
cat >"${TEST_BIN}/sh" <<EOF
#!/bin/sh
echo "CODER_VERSION=\${CODER_VERSION:-unset}" >> "${SH_LOG}"
echo "\$@" >> "${SH_LOG}"
EOF
chmod +x "${TEST_BIN}/sh"
PATH="$TEST_BIN:$PATH" VERSION="2.5.0" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 || true
grep -q "CODER_VERSION=2.5.0" "${SH_LOG}" &&
	pass "versioned: CODER_VERSION=2.5.0 passed to installer" ||
	fail "versioned: CODER_VERSION=2.5.0 passed to installer" "sh log: $(cat "${SH_LOG}" 2>/dev/null)"

# 4. Continues (exit 0) when installer fails
TEST_BIN=$(new_tmp)
cat >"${TEST_BIN}/curl" <<'EOF'
#!/bin/sh
printf '#!/bin/sh\nexit 1\n'
EOF
chmod +x "${TEST_BIN}/curl"
PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] &&
	pass "installer-fails: exits 0 when installer fails (graceful)" ||
	fail "installer-fails: exits 0 when installer fails (graceful)" "exit code was $rc"

summary
