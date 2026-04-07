#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/devbox/install.sh
#
# Mocks 'curl' and 'devbox' to avoid network calls or real installations.
# Tests verify option-handling logic (version selection, runInstall flag).
#
# Usage:  bash test/unit/test_devbox_install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/devbox/install.sh"

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
	rm -f /tmp/devbox_test_*.log
}
trap cleanup EXIT

# make_mock_bin <dir>
# Populates a mock bin dir with:
#   curl  – records called URL, pipes a no-op installer to stdout
#   devbox – records each sub-command call; prints mock output
make_mock_bin() {
	local d="$1"
	local curl_log="${d}/curl_calls.log"
	local devbox_log="${d}/devbox_calls.log"

	mkdir -p "$d"

	# curl mock: record URL, emit a minimal no-op shell script
	cat >"$d/curl" <<EOF
#!/bin/sh
echo "\$@" >> "${curl_log}"
printf '#!/bin/sh\necho "mock devbox installer"\n'
EOF
	chmod +x "$d/curl"

	# devbox mock: record sub-command name
	cat >"$d/devbox" <<EOF
#!/bin/sh
echo "\${1:-}" >> "${devbox_log}"
case "\${1:-}" in
  version)  echo "0.0.0-mock" ;;
  install)  echo "mock devbox install" ;;
  help)     echo "mock devbox help" ;;
  *)        echo "mock devbox \$*" ;;
esac
EOF
	chmod +x "$d/devbox"
}

# ── tests ──────────────────────────────────────────────────────────────────────

echo ""
echo "=== devbox/install.sh unit tests ==="
echo ""

# 1. Default (VERSION=latest) fetches from the Jetify URL
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "get.jetify.com/devbox" "${TEST_BIN}/curl_calls.log" &&
	pass "default: fetches from get.jetify.com/devbox" ||
	fail "default: fetches from get.jetify.com/devbox" "curl log: $(cat "${TEST_BIN}/curl_calls.log" 2>/dev/null)"

# 2. VERSION=latest passes '-f' flag to the installer (non-interactive)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q -- "-f" "${TEST_BIN}/curl_calls.log" &&
	pass "default: passes -f (force) flag" ||
	fail "default: passes -f (force) flag" "curl log: $(cat "${TEST_BIN}/curl_calls.log" 2>/dev/null)"

# 3. Specific version sets DEVBOX_VERSION env for the piped bash installer.
# install.sh runs:  curl ... | DEVBOX_VERSION="<ver>" bash -s -- -f
# We intercept the piped bash call with a mock 'bash' that records the env var.
TEST_BIN=$(new_tmp)
CALL_LOG="${TEST_BIN}/bash_env.log"
make_mock_bin "$TEST_BIN"
# Add a bash stub that records DEVBOX_VERSION when invoked as the piped installer
cat >"$TEST_BIN/bash" <<BASHEOF
#!/bin/sh
case "\${1:-}" in
  -s) echo "\${DEVBOX_VERSION:-unset}" >> "${CALL_LOG}" ;;
  *)  /bin/bash "\$@" ;;
esac
BASHEOF
chmod +x "$TEST_BIN/bash"
PATH="$TEST_BIN:$PATH" VERSION="0.12.0" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "0.12.0" "${CALL_LOG}" &&
	pass "versioned: DEVBOX_VERSION env set for piped bash installer" ||
	fail "versioned: DEVBOX_VERSION env set for piped bash installer" "log: $(cat "${CALL_LOG}" 2>/dev/null)"

# 4. RUNINSTALL=false → 'devbox install' sub-command is NOT called
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^install$" "${TEST_BIN}/devbox_calls.log" &&
	fail "runinstall=false: devbox install must not be called" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")" ||
	pass "runinstall=false: devbox install not called"

# 5. RUNINSTALL=true + devbox.json present → 'devbox install' IS called
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
WS=$(new_tmp)
echo '{"packages":[]}' >"${WS}/devbox.json"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="true" containerWorkspaceFolder="$WS" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^install$" "${TEST_BIN}/devbox_calls.log" &&
	pass "runinstall=true: devbox install is called when devbox.json exists" ||
	fail "runinstall=true: devbox install is called when devbox.json exists" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")"

# 6. RUNINSTALL=true but no devbox.json → 'devbox install' is NOT called, exits cleanly
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
WS=$(new_tmp) # no devbox.json
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="true" containerWorkspaceFolder="$WS" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^install$" "${TEST_BIN}/devbox_calls.log" &&
	fail "runinstall=true+no-json: devbox install must not be called" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")" ||
	pass "runinstall=true+no-json: devbox install skipped"

# 7. devbox version is called after install (smoke-test that devbox binary works)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^version$" "${TEST_BIN}/devbox_calls.log" &&
	pass "install: devbox version called after install" ||
	fail "install: devbox version called after install" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")"

summary
