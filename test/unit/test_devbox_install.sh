#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/devbox/install.sh
#
# Mocks 'curl' and 'devbox' to avoid network calls or real installations.
# Tests verify version selection, non-interactive installation, and resolved binary promotion.
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
#   curl    – records called URL, pipes a no-op installer to stdout
#   devbox  – records each sub-command call; prints mock output
#   install – non-root mock that parses -o/-g/-m flags and copies src to mock bin dir
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

	# install mock: non-root, parse args to find src and dest, copy to mock bin dir
	cat >"$d/install" <<'EOF'
#!/bin/sh
# Non-root mock: parse args to find src and dest, copy to mock bin dir
src=""
dst=""
skip_next=false
for arg in "$@"; do
	case "$arg" in
	-o | -g | -m) skip_next=true ;;
	*)
		if $skip_next; then skip_next=false; continue; fi
		if [ -z "$src" ]; then src="$arg"; else dst="$arg"; fi
		;;
	esac
done
if [ -n "$src" ] && [ -n "$dst" ]; then
	real_dst="$(dirname "$0")/$(basename "$dst")"
	cp "$src" "$real_dst" && chmod +x "$real_dst"
fi
exit 0
EOF
	chmod +x "$d/install"

	# chmod mock: no-op only when the target file doesn't exist (e.g. /usr/local/bin/devbox
	# is absent in a clean test env). For existing files, run the real chmod so that
	# the install mock can still make helper scripts executable.
	cat >"$d/chmod" <<'EOF'
#!/bin/sh
# Find the last non-flag argument (the target path)
target=""
for a; do
        case "$a" in
        -*) ;;
        *) target="$a" ;;
        esac
done
if [ -e "$target" ]; then
        /bin/chmod "$@"
fi
exit 0
EOF
	chmod +x "$d/chmod"
}

# ── tests ──────────────────────────────────────────────────────────────────────

echo ""
echo "=== devbox/install.sh unit tests ==="
echo ""

# 1. Default (VERSION=latest) fetches from the Jetify URL
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "get.jetify.com/devbox" "${TEST_BIN}/curl_calls.log" &&
	pass "default: fetches from get.jetify.com/devbox" ||
	fail "default: fetches from get.jetify.com/devbox" "curl log: $(cat "${TEST_BIN}/curl_calls.log" 2>/dev/null)"

# 2. VERSION=latest passes '-f' flag to the installer (non-interactive)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q -- "-f" "${TEST_BIN}/curl_calls.log" &&
	pass "default: passes -f (force) flag" ||
	fail "default: passes -f (force) flag" "curl log: $(cat "${TEST_BIN}/curl_calls.log" 2>/dev/null)"

# 2b. FORCE=1 env var is set for the piped bash installer (matches devbox-install-action)
#     install.sh uses: curl ... | FORCE=1 bash -s -- -f
#     We intercept bash with a stub that records FORCE when invoked as the piped installer.
TEST_BIN=$(new_tmp)
FORCE_LOG="${TEST_BIN}/force_env.log"
make_mock_bin "$TEST_BIN"
cat >"$TEST_BIN/bash" <<BASHEOF
#!/bin/sh
case "\${1:-}" in
  -s) echo "\${FORCE:-unset}" >> "${FORCE_LOG}" ;;
  *)  /bin/bash "\$@" ;;
esac
BASHEOF
chmod +x "$TEST_BIN/bash"
PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^1$" "${FORCE_LOG}" &&
	pass "default: FORCE=1 env set for piped bash installer" ||
	fail "default: FORCE=1 env set for piped bash installer" "log: $(cat "${FORCE_LOG}" 2>/dev/null)"

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
PATH="$TEST_BIN:$PATH" VERSION="0.12.0" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "0.12.0" "${CALL_LOG}" &&
	pass "versioned: DEVBOX_VERSION env set for piped bash installer" ||
	fail "versioned: DEVBOX_VERSION env set for piped bash installer" "log: $(cat "${CALL_LOG}" 2>/dev/null)"

# Devbox version is called after install as an executable smoke test.
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^version$" "${TEST_BIN}/devbox_calls.log" &&
	pass "install: devbox version called after install" ||
	fail "install: devbox version called after install" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")"

# Promote the resolved executable from Jetify's per-user cache so runtime
# users do not invoke the launcher and download Devbox again.
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
TEST_CACHE=$(new_tmp)
mkdir -p "${TEST_CACHE}/0.0.0-mock_linux_amd64"
cat >"${TEST_CACHE}/0.0.0-mock_linux_amd64/devbox" <<'EOF'
#!/bin/sh
echo "resolved-devbox-binary"
EOF
chmod +x "${TEST_CACHE}/0.0.0-mock_linux_amd64/devbox"
PATH="$TEST_BIN:$PATH" VERSION="latest" \
	DEVBOX_INSTALL_PATH="${TEST_BIN}/devbox" DEVBOX_CACHE_BIN_DIR="$TEST_CACHE" \
	sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "resolved-devbox-binary" "${TEST_BIN}/devbox" &&
	pass "install: promotes resolved cached binary over launcher" ||
	fail "install: promotes resolved cached binary over launcher" "installed devbox was not the resolved binary"

# A stale cached binary must not be promoted when the just-resolved version is
# also present.
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
TEST_CACHE=$(new_tmp)
mkdir -p "${TEST_CACHE}/9.9.9_linux_amd64" "${TEST_CACHE}/0.0.0-mock_linux_amd64"
cat >"${TEST_CACHE}/9.9.9_linux_amd64/devbox" <<'EOF'
#!/bin/sh
echo "stale-devbox-binary"
EOF
cat >"${TEST_CACHE}/0.0.0-mock_linux_amd64/devbox" <<'EOF'
#!/bin/sh
echo "resolved-devbox-binary"
EOF
chmod +x "${TEST_CACHE}/9.9.9_linux_amd64/devbox" "${TEST_CACHE}/0.0.0-mock_linux_amd64/devbox"
PATH="$TEST_BIN:$PATH" VERSION="latest" \
	DEVBOX_INSTALL_PATH="${TEST_BIN}/devbox" DEVBOX_CACHE_BIN_DIR="$TEST_CACHE" \
	sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "resolved-devbox-binary" "${TEST_BIN}/devbox" &&
	pass "install: promotes the resolved version when stale caches exist" ||
	fail "install: promotes the resolved version when stale caches exist" "installed devbox did not match resolved version"

# Multiple cache entries for the resolved version must be selected in a stable
# lexical order rather than filesystem traversal order.
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
TEST_CACHE=$(new_tmp)
mkdir -p "${TEST_CACHE}/0.0.0-mock_z_candidate" "${TEST_CACHE}/0.0.0-mock_a_candidate"
cat >"${TEST_CACHE}/0.0.0-mock_z_candidate/devbox" <<'EOF'
#!/bin/sh
echo "later-resolved-devbox-binary"
EOF
cat >"${TEST_CACHE}/0.0.0-mock_a_candidate/devbox" <<'EOF'
#!/bin/sh
echo "first-resolved-devbox-binary"
EOF
chmod +x "${TEST_CACHE}/0.0.0-mock_z_candidate/devbox" "${TEST_CACHE}/0.0.0-mock_a_candidate/devbox"
PATH="$TEST_BIN:$PATH" VERSION="latest" \
	DEVBOX_INSTALL_PATH="${TEST_BIN}/devbox" DEVBOX_CACHE_BIN_DIR="$TEST_CACHE" \
	sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "first-resolved-devbox-binary" "${TEST_BIN}/devbox" &&
	pass "install: selects same-version cache entries deterministically" ||
	fail "install: selects same-version cache entries deterministically" "installed devbox was not the first sorted candidate"

# The installer emits a git-commit identifier for tracing published artifacts.
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
OUT=$(PATH="$TEST_BIN:$PATH" VERSION="latest" sh "$INSTALL_SCRIPT" 2>&1)
echo "$OUT" | grep -q "git commit" &&
	pass "install: emits git commit identifier line" ||
	fail "install: emits git commit identifier line" "output: $OUT"

summary
