#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/userspace-pkg-homes/install.sh
#
# Sources the install script to test individual functions without side effects.
#
# Usage:  bash test/unit/test_userspace_pkg_homes.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/userspace-pkg-homes/install.sh"

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
echo "=== userspace-pkg-homes/install.sh unit tests ==="
echo ""

# ── Source the script (BASH_SOURCE guard prevents main from running) ──────────
# shellcheck source=src/userspace-pkg-homes/install.sh
source "$INSTALL_SCRIPT"

# ── 1. build_config_block with all tools enabled ─────────────────────────────
CONFIGURE_PNPM="true" CONFIGURE_PIPX="true" CONFIGURE_NPM="true"
block=$(build_config_block)
echo "$block" | grep -q 'PNPM_HOME' &&
	pass "build_config_block (all): contains PNPM_HOME" ||
	fail "build_config_block (all): contains PNPM_HOME" "block: $block"
echo "$block" | grep -q 'PIPX_BIN_DIR' &&
	pass "build_config_block (all): contains PIPX_BIN_DIR" ||
	fail "build_config_block (all): contains PIPX_BIN_DIR" "block: $block"
echo "$block" | grep -q 'NPM_CONFIG_PREFIX' &&
	pass "build_config_block (all): contains NPM_CONFIG_PREFIX" ||
	fail "build_config_block (all): contains NPM_CONFIG_PREFIX" "block: $block"
echo "$block" | grep -q 'case ":$PATH:"' &&
	pass "build_config_block (all): contains PATH guard" ||
	fail "build_config_block (all): contains PATH guard" "block: $block"

# ── 2. build_config_block with only pnpm ──────────────────────────────────────
CONFIGURE_PNPM="true" CONFIGURE_PIPX="false" CONFIGURE_NPM="false"
block=$(build_config_block)
echo "$block" | grep -q 'PNPM_HOME' &&
	pass "build_config_block (pnpm-only): contains PNPM_HOME" ||
	fail "build_config_block (pnpm-only): contains PNPM_HOME" "block: $block"
echo "$block" | grep -q 'PIPX_BIN_DIR' &&
	fail "build_config_block (pnpm-only): must not contain PIPX_BIN_DIR" "block: $block" ||
	pass "build_config_block (pnpm-only): does not contain PIPX_BIN_DIR"
echo "$block" | grep -q 'NPM_CONFIG_PREFIX' &&
	fail "build_config_block (pnpm-only): must not contain NPM_CONFIG_PREFIX" "block: $block" ||
	pass "build_config_block (pnpm-only): does not contain NPM_CONFIG_PREFIX"

# ── 3. build_config_block with nothing enabled ───────────────────────────────
CONFIGURE_PNPM="false" CONFIGURE_PIPX="false" CONFIGURE_NPM="false"
block=$(build_config_block)
[ -z "$block" ] &&
	pass "build_config_block (none): returns empty string" ||
	fail "build_config_block (none): returns empty string" "block: $block"

# ── 4. build_config_block markers ─────────────────────────────────────────────
CONFIGURE_PNPM="true" CONFIGURE_PIPX="false" CONFIGURE_NPM="false"
block=$(build_config_block)
echo "$block" | head -1 | grep -qF '# >> userspace-pkg-homes config >>' &&
	pass "build_config_block: begins with marker" ||
	fail "build_config_block: begins with marker" "first line: $(echo "$block" | head -1)"
echo "$block" | tail -1 | grep -qF '# << userspace-pkg-homes config <<' &&
	pass "build_config_block: ends with marker" ||
	fail "build_config_block: ends with marker" "last line: $(echo "$block" | tail -1)"

# ── 5. inject_config creates file if missing ──────────────────────────────────
TEST_HOME=$(new_tmp)
CONFIGURE_PNPM="true" CONFIGURE_PIPX="true" CONFIGURE_NPM="false"
block=$(build_config_block)
inject_config "${TEST_HOME}/.bashrc" "${block}"
test -f "${TEST_HOME}/.bashrc" &&
	pass "inject_config: creates .bashrc if missing" ||
	fail "inject_config: creates .bashrc if missing" "file not found"

# ── 6. inject_config writes the block ─────────────────────────────────────────
grep -qF 'PNPM_HOME' "${TEST_HOME}/.bashrc" &&
	pass "inject_config: .bashrc contains PNPM_HOME" ||
	fail "inject_config: .bashrc contains PNPM_HOME" "$(cat "${TEST_HOME}/.bashrc")"

# ── 7. inject_config is idempotent (no duplicate blocks) ─────────────────────
inject_config "${TEST_HOME}/.bashrc" "${block}"
count=$(grep -cF '# >> userspace-pkg-homes config >>' "${TEST_HOME}/.bashrc" || true)
[ "$count" -eq 1 ] &&
	pass "inject_config: idempotent (single marker block after double inject)" ||
	fail "inject_config: idempotent (single marker block after double inject)" "found ${count} marker blocks"

# ── 8. inject_config preserves existing content ──────────────────────────────
TEST_HOME=$(new_tmp)
echo "# existing content" >"${TEST_HOME}/.bashrc"
CONFIGURE_PNPM="true" CONFIGURE_PIPX="false" CONFIGURE_NPM="false"
block=$(build_config_block)
inject_config "${TEST_HOME}/.bashrc" "${block}"
grep -q '# existing content' "${TEST_HOME}/.bashrc" &&
	pass "inject_config: preserves existing content" ||
	fail "inject_config: preserves existing content" "$(cat "${TEST_HOME}/.bashrc")"

# ── 9. ensure_dirs creates pnpm directory ────────────────────────────────────
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="${TEST_HOME}" REMOTE_USER="root" \
	CONFIGURE_PNPM="true" CONFIGURE_PIPX="false" CONFIGURE_NPM="false" \
	ensure_dirs
test -d "${TEST_HOME}/.local/share/pnpm" &&
	pass "ensure_dirs: creates pnpm directory" ||
	fail "ensure_dirs: creates pnpm directory" "directory not found"

# ── 10. ensure_dirs creates pipx directory ───────────────────────────────────
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="${TEST_HOME}" REMOTE_USER="root" \
	CONFIGURE_PNPM="false" CONFIGURE_PIPX="true" CONFIGURE_NPM="false" \
	ensure_dirs
test -d "${TEST_HOME}/.local/bin" &&
	pass "ensure_dirs: creates pipx directory" ||
	fail "ensure_dirs: creates pipx directory" "directory not found"

# ── 11. ensure_dirs creates npm directory ────────────────────────────────────
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="${TEST_HOME}" REMOTE_USER="root" \
	CONFIGURE_PNPM="false" CONFIGURE_PIPX="false" CONFIGURE_NPM="true" \
	ensure_dirs
test -d "${TEST_HOME}/.npm-global" &&
	pass "ensure_dirs: creates npm-global directory" ||
	fail "ensure_dirs: creates npm-global directory" "directory not found"

# ── 12. ensure_dirs does not create dirs when disabled ───────────────────────
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="${TEST_HOME}" REMOTE_USER="root" \
	CONFIGURE_PNPM="false" CONFIGURE_PIPX="false" CONFIGURE_NPM="false" \
	ensure_dirs
test ! -d "${TEST_HOME}/.local/share/pnpm" &&
	pass "ensure_dirs (none): no pnpm dir created" ||
	fail "ensure_dirs (none): no pnpm dir created" "directory exists"
test ! -d "${TEST_HOME}/.npm-global" &&
	pass "ensure_dirs (none): no npm-global dir created" ||
	fail "ensure_dirs (none): no npm-global dir created" "directory exists"

# ── 13. build_config_block PATH guard includes all enabled dirs ──────────────
CONFIGURE_PNPM="true" CONFIGURE_PIPX="true" CONFIGURE_NPM="true"
block=$(build_config_block)
echo "$block" | grep -q '\${PNPM_HOME}' &&
	pass "build_config_block (all): PATH includes PNPM_HOME" ||
	fail "build_config_block (all): PATH includes PNPM_HOME" "block: $block"
echo "$block" | grep -q '\${PIPX_BIN_DIR}' &&
	pass "build_config_block (all): PATH includes PIPX_BIN_DIR" ||
	fail "build_config_block (all): PATH includes PIPX_BIN_DIR" "block: $block"
echo "$block" | grep -q '\${NPM_CONFIG_PREFIX}/bin' &&
	pass "build_config_block (all): PATH includes NPM_CONFIG_PREFIX/bin" ||
	fail "build_config_block (all): PATH includes NPM_CONFIG_PREFIX/bin" "block: $block"

# ── 14. Full end-to-end: script configures both bashrc and zshrc ─────────────
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="${TEST_HOME}" REMOTE_USER="root" \
	CONFIGURE_PNPM="true" CONFIGURE_PIPX="true" CONFIGURE_NPM="true" \
	_REMOTE_USER="root" _REMOTE_USER_HOME="${TEST_HOME}" \
	CONFIGUREPNPM="true" CONFIGUREPIPX="true" CONFIGURENPM="true" \
	bash "$INSTALL_SCRIPT"
grep -qF 'PNPM_HOME' "${TEST_HOME}/.bashrc" &&
	pass "e2e: .bashrc has PNPM_HOME" ||
	fail "e2e: .bashrc has PNPM_HOME" "$(cat "${TEST_HOME}/.bashrc" 2>/dev/null)"
grep -qF 'PNPM_HOME' "${TEST_HOME}/.zshrc" &&
	pass "e2e: .zshrc has PNPM_HOME" ||
	fail "e2e: .zshrc has PNPM_HOME" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"
test -d "${TEST_HOME}/.local/share/pnpm" &&
	pass "e2e: pnpm dir created" ||
	fail "e2e: pnpm dir created" "directory missing"
test -d "${TEST_HOME}/.local/bin" &&
	pass "e2e: pipx dir created" ||
	fail "e2e: pipx dir created" "directory missing"
test -d "${TEST_HOME}/.npm-global" &&
	pass "e2e: npm-global dir created" ||
	fail "e2e: npm-global dir created" "directory missing"

# ── 15. e2e: nothing selected exits cleanly ──────────────────────────────────
TEST_HOME=$(new_tmp)
out=$(REMOTE_USER_HOME="${TEST_HOME}" REMOTE_USER="root" \
	_REMOTE_USER="root" _REMOTE_USER_HOME="${TEST_HOME}" \
	CONFIGUREPNPM="false" CONFIGUREPIPX="false" CONFIGURENPM="false" \
	bash "$INSTALL_SCRIPT" 2>&1)
echo "$out" | grep -q "nothing to configure" &&
	pass "e2e (none): prints 'nothing to configure'" ||
	fail "e2e (none): prints 'nothing to configure'" "output: $out"

summary
