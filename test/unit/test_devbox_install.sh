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

# 5. install.sh exits successfully (smoke test, RUNINSTALL ignored since logic moved to on-create)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
WS=$(new_tmp)
echo '{"packages":[]}' >"${WS}/devbox.json"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="true" containerWorkspaceFolder="$WS" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "smoke: install.sh exits 0" ||
	fail "smoke: install.sh exits 0" "exit code was $rc"

# 6. install.sh does not call 'devbox install' directly (moved to devbox-on-create)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
WS=$(new_tmp)
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="true" containerWorkspaceFolder="$WS" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^install$" "${TEST_BIN}/devbox_calls.log" &&
	fail "install-sh: must not call devbox install directly" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")" ||
	pass "install-sh: devbox install not called directly (handled by on-create)"

# 7. devbox version is called after install (smoke-test that devbox binary works)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
grep -q "^version$" "${TEST_BIN}/devbox_calls.log" &&
	pass "install: devbox version called after install" ||
	fail "install: devbox version called after install" "devbox_calls: $(cat "${TEST_BIN}/devbox_calls.log")"

# 7b. install.sh emits a git-commit identifier line (for tracing the published artifact)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
OUT=$(PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" 2>&1)
echo "$OUT" | grep -q "git commit" &&
	pass "install: emits git commit identifier line" ||
	fail "install: emits git commit identifier line" "output: $OUT"

# 8. install.sh installs devbox-on-create helper
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
test -x "${TEST_BIN}/devbox-on-create" &&
	pass "install: devbox-on-create helper installed" ||
	fail "install: devbox-on-create helper installed" "not found in ${TEST_BIN}"

summary

# ── devbox-on-create.sh unit tests ────────────────────────────────────────────
ONCREATE_SCRIPT="${REPO_ROOT}/src/devbox/devbox-on-create.sh"

echo ""
echo "=== devbox-on-create.sh unit tests ==="
echo ""

# 8. devbox install IS called when devbox.json exists in workspace
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
CALL_LOG="${TEST_BIN}/devbox_calls.log"
printf '{"packages":[]}' >"${WS}/devbox.json"
cat >"${TEST_BIN}/devbox" <<EOF
#!/bin/sh
echo "\${1:-}" >> "${CALL_LOG}"
echo "mock devbox \$*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME=$(new_tmp) PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
grep -q "^install$" "${CALL_LOG}" &&
	pass "on-create: devbox install called when devbox.json exists" ||
	fail "on-create: devbox install called when devbox.json exists" \
		"calls: $(cat "${CALL_LOG}" 2>/dev/null)"

# 8b. devbox install is invoked with stdin redirected from /dev/null AND CI=1 set.
#     We use script(1) to allocate a real PTY so that stdin is a live terminal
#     for everything that doesn't explicitly redirect it.  The mock 'devbox install'
#     exits 1 when [ -t 0 ] is true (stdin is a TTY), so if devbox-on-create.sh
#     forgets the </dev/null redirect the mock will fail and the "complete" message
#     will be absent.  This test would therefore hang/fail even in non-interactive CI.
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
CAPTURED="${TEST_BIN}/oncreate.log"
printf '{"packages":[]}' >"${WS}/devbox.json"
# Mock exits 1 when stdin is a TTY; passes when stdin is /dev/null (EOF).
cat >"${TEST_BIN}/devbox" <<'EOF'
#!/bin/sh
if [ "$1" = "install" ] && [ -t 0 ]; then
	echo "mock devbox: stdin is a TTY — redirect missing" >&2
	exit 1
fi
echo "mock devbox $*"
EOF
chmod +x "${TEST_BIN}/devbox"
# Wrapper script so env vars are set cleanly inside the PTY.
WRAPPER="${TEST_BIN}/run-oncreate.sh"
cat >"${WRAPPER}" <<EOF
#!/bin/sh
export HOME="${TEST_HOME}"
export PATH="${TEST_BIN}:${PATH}"
export containerWorkspaceFolder="${WS}"
exec bash "${ONCREATE_SCRIPT}"
EOF
chmod +x "${WRAPPER}"
# Run under a PTY; transcript (PTY output) goes to CAPTURED.
script -q -e -c "${WRAPPER}" "${CAPTURED}" >/dev/null 2>&1 && rc=0 || rc=$?
grep -q "devbox install complete" "${CAPTURED}" &&
	pass "on-create: stdin redirected from /dev/null (verified under PTY)" ||
	fail "on-create: stdin redirected from /dev/null (verified under PTY)" \
		"exit code: ${rc}, output: $(tr -d '\r' <"${CAPTURED}" 2>/dev/null)"

# 8c. devbox install is invoked with CI=1 in the environment.
#     This is the primary guard against interactive Nix install prompts — devbox
#     detects CI=1 and suppresses all confirmation prompts regardless of TTY state.
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
CI_LOG="${TEST_BIN}/ci_env.log"
ONCREATE_OUT="${TEST_BIN}/oncreate_out.log"
printf '{"packages":[]}' >"${WS}/devbox.json"
# Mock records the CI value when called as 'install', exits 1 if CI != "1".
cat >"${TEST_BIN}/devbox" <<EOF
#!/bin/sh
if [ "\${1:-}" = "install" ]; then
	echo "\${CI:-unset}" >> "${CI_LOG}"
	if [ "\${CI:-}" != "1" ]; then
		echo "mock devbox: CI is not 1 (got: '\${CI:-unset}')" >&2
		exit 1
	fi
fi
echo "mock devbox \$*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${ONCREATE_SCRIPT}" >"${ONCREATE_OUT}" 2>&1
# Verify both: CI=1 reached the mock AND devbox install completed successfully.
grep -q "^1$" "${CI_LOG}" &&
	pass "on-create: CI=1 passed to devbox install (verified via CI log)" ||
	fail "on-create: CI=1 passed to devbox install (verified via CI log)" \
		"CI log: $(cat "${CI_LOG}" 2>/dev/null || echo '(empty)')"
grep -q "devbox install complete" "${ONCREATE_OUT}" &&
	pass "on-create: devbox install completed with CI=1" ||
	fail "on-create: devbox install completed with CI=1" \
		"output: $(cat "${ONCREATE_OUT}" 2>/dev/null)"

# 9. devbox install is NOT called when devbox.json is absent
TEST_BIN=$(new_tmp)
WS=$(new_tmp) # no devbox.json
CALL_LOG="${TEST_BIN}/devbox_calls.log"
cat >"${TEST_BIN}/devbox" <<EOF
#!/bin/sh
echo "\${1:-}" >> "${CALL_LOG}"
echo "mock devbox \$*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME=$(new_tmp) PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
grep -q "^install$" "${CALL_LOG}" 2>/dev/null &&
	fail "on-create: devbox install must not be called without devbox.json" \
		"calls: $(cat "${CALL_LOG}" 2>/dev/null)" ||
	pass "on-create: devbox install skipped when devbox.json absent"

# 10. PATH export block is added to .zshrc and .bashrc
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
cat >"${TEST_BIN}/devbox" <<'EOF'
#!/bin/sh
echo "mock devbox $*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
grep -q "devbox-project-path" "${TEST_HOME}/.zshrc" &&
	pass "on-create: PATH block added to .zshrc" ||
	fail "on-create: PATH block added to .zshrc" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"
grep -q "devbox-project-path" "${TEST_HOME}/.bashrc" &&
	pass "on-create: PATH block added to .bashrc" ||
	fail "on-create: PATH block added to .bashrc" \
		".bashrc: $(cat "${TEST_HOME}/.bashrc" 2>/dev/null)"

# 11. PATH export block contains the correct workspace path
grep -q "${WS}/.devbox/nix/profile/default/bin" "${TEST_HOME}/.zshrc" &&
	pass "on-create: .zshrc PATH contains workspace devbox profile" ||
	fail "on-create: .zshrc PATH contains workspace devbox profile" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 12. PATH export is idempotent — second run must not duplicate the block
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
BLOCK_COUNT=$(grep -c "BEGIN devbox-project-path" "${TEST_HOME}/.zshrc" 2>/dev/null || echo 0)
[ "${BLOCK_COUNT}" -eq 1 ] &&
	pass "on-create: PATH export is idempotent (block not duplicated)" ||
	fail "on-create: PATH export is idempotent (block not duplicated)" \
		"found ${BLOCK_COUNT} BEGIN markers in .zshrc"

# 13. Global devbox profile path is exported to .zshrc when EXPORTGLOBALPROFILE=true
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
cat >"${TEST_BIN}/devbox" <<'EOF'
#!/bin/sh
echo "mock devbox $*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	EXPORTGLOBALPROFILE="true" bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
grep -q "devbox-global-path" "${TEST_HOME}/.zshrc" &&
	pass "on-create: global devbox profile PATH block added to .zshrc" ||
	fail "on-create: global devbox profile PATH block added to .zshrc" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"
grep -q "devbox-global-path" "${TEST_HOME}/.bashrc" &&
	pass "on-create: global devbox profile PATH block added to .bashrc" ||
	fail "on-create: global devbox profile PATH block added to .bashrc" \
		".bashrc: $(cat "${TEST_HOME}/.bashrc" 2>/dev/null)"

# 14. Global devbox profile path contains the expected ~/.local/share/devbox path
grep -q ".local/share/devbox/global" "${TEST_HOME}/.zshrc" &&
	pass "on-create: .zshrc global PATH references ~/.local/share/devbox/global" ||
	fail "on-create: .zshrc global PATH references ~/.local/share/devbox/global" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 15. Global devbox profile export is skipped when EXPORTGLOBALPROFILE=false
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
cat >"${TEST_BIN}/devbox" <<'EOF'
#!/bin/sh
echo "mock devbox $*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	EXPORTGLOBALPROFILE="false" bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
grep -q "devbox-global-path" "${TEST_HOME}/.zshrc" 2>/dev/null &&
	fail "on-create: global devbox path must not be added when EXPORTGLOBALPROFILE=false" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)" ||
	pass "on-create: global devbox profile export skipped when EXPORTGLOBALPROFILE=false"

# 16. Nix-daemon sourcing is added to .zshrc when the daemon profile file exists
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
FAKE_NIX_PROFILE=$(new_tmp)
FAKE_NIX_DAEMON="${FAKE_NIX_PROFILE}/nix-daemon.sh"
touch "${FAKE_NIX_DAEMON}"
cat >"${TEST_BIN}/devbox" <<'EOF'
#!/bin/sh
echo "mock devbox $*"
EOF
chmod +x "${TEST_BIN}/devbox"
# Patch the script to use a fake nix-daemon path via a wrapper approach:
# We can't inject the path easily, so we create a temporary patched copy.
PATCHED_SCRIPT=$(mktemp)
sed "s|/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh|${FAKE_NIX_DAEMON}|g" \
	"${ONCREATE_SCRIPT}" >"${PATCHED_SCRIPT}"
chmod +x "${PATCHED_SCRIPT}"
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${PATCHED_SCRIPT}" >/dev/null 2>&1
rm -f "${PATCHED_SCRIPT}"
grep -q "devbox-nix-daemon" "${TEST_HOME}/.zshrc" &&
	pass "on-create: nix-daemon sourcing block added to .zshrc when profile exists" ||
	fail "on-create: nix-daemon sourcing block added to .zshrc when profile exists" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 17. Nix-daemon sourcing is NOT added when the daemon profile file is absent
TEST_BIN=$(new_tmp)
WS=$(new_tmp)
TEST_HOME=$(new_tmp)
cat >"${TEST_BIN}/devbox" <<'EOF'
#!/bin/sh
echo "mock devbox $*"
EOF
chmod +x "${TEST_BIN}/devbox"
HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" containerWorkspaceFolder="${WS}" \
	bash "${ONCREATE_SCRIPT}" >/dev/null 2>&1
grep -q "devbox-nix-daemon" "${TEST_HOME}/.zshrc" 2>/dev/null &&
	fail "on-create: nix-daemon block must not be added when profile absent" \
		".zshrc: $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)" ||
	pass "on-create: nix-daemon sourcing skipped when profile file absent"

summary

# ── devbox-post-start.sh unit tests ───────────────────────────────────────────
POSTSTART_SCRIPT="${REPO_ROOT}/src/devbox/devbox-post-start.sh"

echo ""
echo "=== devbox-post-start.sh unit tests ==="
echo ""

# 18. post-start exits 0 and skips when nix-daemon binary is absent
TEST_BIN=$(new_tmp)
MISSING_DAEMON_ROOT=$(new_tmp)
PATCHED_POSTSTART=$(mktemp)
sed "s|/nix/var/nix/profiles/default/bin/nix-daemon|${MISSING_DAEMON_ROOT}/nix-daemon|g" \
	"${POSTSTART_SCRIPT}" >"${PATCHED_POSTSTART}"
chmod +x "${PATCHED_POSTSTART}"
# PATH has no nix-daemon binary, and the script's absolute nix-daemon path is patched to a nonexistent location
HOME=$(new_tmp) PATH="${TEST_BIN}:${PATH}" \
	bash "${PATCHED_POSTSTART}" >/dev/null 2>&1 && rc=0 || rc=$?
rm -f "${PATCHED_POSTSTART}"
[ "${rc}" -eq 0 ] &&
	pass "post-start: exits 0 when nix-daemon binary absent" ||
	fail "post-start: exits 0 when nix-daemon binary absent" "exit code: ${rc}"

# 19. post-start starts nix-daemon when binary is present and not running
TEST_BIN=$(new_tmp)
DAEMON_LOG=$(mktemp)
# Fake nix-daemon binary that records invocation and exits immediately
cat >"${TEST_BIN}/nix-daemon" <<EOF
#!/bin/sh
echo "mock nix-daemon \$*" >> "${DAEMON_LOG}"
exit 0
EOF
chmod +x "${TEST_BIN}/nix-daemon"
# Fake pgrep that always says not running
cat >"${TEST_BIN}/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/pgrep"
# Fake id that reports root (uid=0) so the root check passes
cat >"${TEST_BIN}/id" <<'EOF'
#!/bin/sh
echo "0"
EOF
chmod +x "${TEST_BIN}/id"
# Patch the binary path to point at our fake binary
PATCHED_SCRIPT=$(mktemp)
sed "s|/nix/var/nix/profiles/default/bin/nix-daemon|${TEST_BIN}/nix-daemon|g" \
	"${POSTSTART_SCRIPT}" >"${PATCHED_SCRIPT}"
chmod +x "${PATCHED_SCRIPT}"
HOME=$(new_tmp) PATH="${TEST_BIN}:${PATH}" bash "${PATCHED_SCRIPT}" >/dev/null 2>&1
rm -f "${PATCHED_SCRIPT}"
grep -q "mock nix-daemon" "${DAEMON_LOG}" &&
	pass "post-start: starts nix-daemon when binary present and not running" ||
	fail "post-start: starts nix-daemon when binary present and not running" \
		"log: $(cat "${DAEMON_LOG}" 2>/dev/null)"
rm -f "${DAEMON_LOG}"

# 20. post-start skips starting nix-daemon when it is already running
TEST_BIN=$(new_tmp)
DAEMON_LOG=$(mktemp)
cat >"${TEST_BIN}/nix-daemon" <<EOF
#!/bin/sh
echo "mock nix-daemon \$*" >> "${DAEMON_LOG}"
exit 0
EOF
chmod +x "${TEST_BIN}/nix-daemon"
# Fake pgrep that reports nix-daemon as already running
cat >"${TEST_BIN}/pgrep" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "${TEST_BIN}/pgrep"
# Fake id that reports root (uid=0) so the root check passes
cat >"${TEST_BIN}/id" <<'EOF'
#!/bin/sh
echo "0"
EOF
chmod +x "${TEST_BIN}/id"
PATCHED_SCRIPT=$(mktemp)
sed "s|/nix/var/nix/profiles/default/bin/nix-daemon|${TEST_BIN}/nix-daemon|g" \
	"${POSTSTART_SCRIPT}" >"${PATCHED_SCRIPT}"
chmod +x "${PATCHED_SCRIPT}"
HOME=$(new_tmp) PATH="${TEST_BIN}:${PATH}" bash "${PATCHED_SCRIPT}" >/dev/null 2>&1
rm -f "${PATCHED_SCRIPT}"
grep -q "mock nix-daemon" "${DAEMON_LOG}" 2>/dev/null &&
	fail "post-start: must not start nix-daemon when already running" \
		"log: $(cat "${DAEMON_LOG}" 2>/dev/null)" ||
	pass "post-start: skips nix-daemon start when already running"
rm -f "${DAEMON_LOG}"

# 21. post-start exits 0 and skips when running as non-root
TEST_BIN=$(new_tmp)
DAEMON_LOG=$(mktemp)
cat >"${TEST_BIN}/nix-daemon" <<EOF
#!/bin/sh
echo "mock nix-daemon \$*" >> "${DAEMON_LOG}"
exit 0
EOF
chmod +x "${TEST_BIN}/nix-daemon"
cat >"${TEST_BIN}/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/pgrep"
# Fake id that reports non-root (uid=1000)
cat >"${TEST_BIN}/id" <<'EOF'
#!/bin/sh
echo "1000"
EOF
chmod +x "${TEST_BIN}/id"
PATCHED_SCRIPT=$(mktemp)
sed "s|/nix/var/nix/profiles/default/bin/nix-daemon|${TEST_BIN}/nix-daemon|g" \
	"${POSTSTART_SCRIPT}" >"${PATCHED_SCRIPT}"
chmod +x "${PATCHED_SCRIPT}"
HOME=$(new_tmp) PATH="${TEST_BIN}:${PATH}" bash "${PATCHED_SCRIPT}" >/dev/null 2>&1 && rc=0 || rc=$?
rm -f "${PATCHED_SCRIPT}"
[ "${rc}" -eq 0 ] &&
	pass "post-start: exits 0 when running as non-root" ||
	fail "post-start: exits 0 when running as non-root" "exit code: ${rc}"
grep -q "mock nix-daemon" "${DAEMON_LOG}" 2>/dev/null &&
	fail "post-start: must not start nix-daemon when non-root" \
		"log: $(cat "${DAEMON_LOG}" 2>/dev/null)" ||
	pass "post-start: skips nix-daemon start when non-root"
rm -f "${DAEMON_LOG}"

# 22. install.sh installs devbox-post-start helper
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="latest" RUNINSTALL="false" sh "$INSTALL_SCRIPT" >/dev/null 2>&1
test -x "${TEST_BIN}/devbox-post-start" &&
	pass "install: devbox-post-start helper installed" ||
	fail "install: devbox-post-start helper installed" "not found in ${TEST_BIN}"

summary
