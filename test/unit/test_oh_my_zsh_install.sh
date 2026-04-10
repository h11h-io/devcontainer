#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/oh-my-zsh/install.sh
#
# Sources the install script to test individual functions without network calls.
#
# Usage:  bash test/unit/test_oh_my_zsh_install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/oh-my-zsh/install.sh"

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

# Source install.sh — BASH_SOURCE guard prevents main() from running
# shellcheck source=src/oh-my-zsh/install.sh
source "$INSTALL_SCRIPT"

echo ""
echo "=== oh-my-zsh/install.sh unit tests ==="
echo ""

# 1. get_external_plugin_url returns correct URL for zsh-autosuggestions
URL=$(get_external_plugin_url "zsh-autosuggestions")
[ "$URL" = "https://github.com/zsh-users/zsh-autosuggestions" ] &&
	pass "get_external_plugin_url: zsh-autosuggestions returns correct URL" ||
	fail "get_external_plugin_url: zsh-autosuggestions returns correct URL" "got '${URL}'"

# 2. get_external_plugin_url returns correct URL for pnpm
URL=$(get_external_plugin_url "pnpm")
[ "$URL" = "https://github.com/ntnyq/omz-plugin-pnpm" ] &&
	pass "get_external_plugin_url: pnpm returns correct URL" ||
	fail "get_external_plugin_url: pnpm returns correct URL" "got '${URL}'"

# 3. get_external_plugin_url returns empty string for built-in plugins
URL=$(get_external_plugin_url "git")
[ -z "$URL" ] &&
	pass "get_external_plugin_url: built-in 'git' returns empty string" ||
	fail "get_external_plugin_url: built-in 'git' returns empty string" "got '${URL}'"

# 4. get_external_plugin_url returns empty string for unknown plugin
URL=$(get_external_plugin_url "unknown-plugin-xyz")
[ -z "$URL" ] &&
	pass "get_external_plugin_url: unknown plugin returns empty string" ||
	fail "get_external_plugin_url: unknown plugin returns empty string" "got '${URL}'"

# 5. write_zshrc creates .zshrc with managed marker
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git sudo" THEME="robbyrussell" REMOTE_USER="root" \
	write_zshrc
grep -q '# managed by oh-my-zsh devcontainer feature' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: creates .zshrc with managed marker" ||
	fail "write_zshrc: creates .zshrc with managed marker" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 6. write_zshrc uses custom PLUGINS value
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git kubectl" THEME="robbyrussell" REMOTE_USER="root" \
	write_zshrc
grep -q 'plugins=(git kubectl)' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: uses custom PLUGINS value" ||
	fail "write_zshrc: uses custom PLUGINS value" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 7. write_zshrc uses custom THEME value
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="agnoster" REMOTE_USER="root" \
	write_zshrc
grep -q 'ZSH_THEME="agnoster"' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: uses custom THEME value" ||
	fail "write_zshrc: uses custom THEME value" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 8. write_zshrc backs up existing non-managed .zshrc
TEST_HOME=$(new_tmp)
echo "# existing zshrc content" >"${TEST_HOME}/.zshrc"
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	write_zshrc
test -f "${TEST_HOME}/.zshrc.bak" &&
	pass "write_zshrc: backs up existing non-managed .zshrc" ||
	fail "write_zshrc: backs up existing non-managed .zshrc" "no .zshrc.bak found"

# 9. write_zshrc does NOT back up already-managed .zshrc
TEST_HOME=$(new_tmp)
printf '# managed by oh-my-zsh devcontainer feature\nexport ZSH="$HOME/.oh-my-zsh"\n' >"${TEST_HOME}/.zshrc"
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	write_zshrc
test ! -f "${TEST_HOME}/.zshrc.bak" &&
	pass "write_zshrc: does not back up already-managed .zshrc" ||
	fail "write_zshrc: does not back up already-managed .zshrc" ".zshrc.bak should not exist"

# 10. install_external_plugins clones external plugins via git
TEST_HOME=$(new_tmp)
TEST_OMZ=$(new_tmp)
TEST_BIN=$(new_tmp)
CLONE_LOG="${TEST_BIN}/git_calls.log"
cat >"${TEST_BIN}/git" <<EOF
#!/bin/sh
echo "\$@" >> "${CLONE_LOG}"
# simulate successful clone: create the target directory
case "\$1" in
  clone) mkdir -p "\${4:-\$3}" ;;
esac
EOF
chmod +x "${TEST_BIN}/git"
OMZ_DIR="$TEST_OMZ" PATH="${TEST_BIN}:${PATH}" PLUGINS="zsh-autosuggestions git" \
	install_external_plugins
grep -q "zsh-autosuggestions" "${CLONE_LOG}" &&
	pass "install_external_plugins: clones zsh-autosuggestions" ||
	fail "install_external_plugins: clones zsh-autosuggestions" "git log: $(cat "${CLONE_LOG}" 2>/dev/null)"

# 11. install_external_plugins skips built-in plugins (no clone for 'git')
grep -q "https://github.com/git" "${CLONE_LOG}" 2>/dev/null &&
	fail "install_external_plugins: must not clone built-in 'git' plugin" "git log: $(cat "${CLONE_LOG}")" ||
	pass "install_external_plugins: skips built-in 'git' plugin"

# 12. install_external_plugins skips already-installed plugins
TEST_OMZ2=$(new_tmp)
mkdir -p "${TEST_OMZ2}/custom/plugins/zsh-autosuggestions"
TEST_BIN=$(new_tmp)
CLONE_LOG2="${TEST_BIN}/git_calls.log"
cat >"${TEST_BIN}/git" <<EOF
#!/bin/sh
echo "\$@" >> "${CLONE_LOG2}"
EOF
chmod +x "${TEST_BIN}/git"
OMZ_DIR="$TEST_OMZ2" PATH="${TEST_BIN}:${PATH}" PLUGINS="zsh-autosuggestions" \
	install_external_plugins
grep -q "clone" "${CLONE_LOG2}" 2>/dev/null &&
	fail "install_external_plugins: must not clone already-present plugin" "git log: $(cat "${CLONE_LOG2}" 2>/dev/null)" ||
	pass "install_external_plugins: skips already-installed plugin"

# 13. write_zshrc produces exactly 7 standard lines when no extras are configured
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE="" \
	write_zshrc
# Exactly 7 standard lines should be present:
#   1. # managed by oh-my-zsh devcontainer feature
#   2. [[ -n "${_H11H_OMZ_LOADED:-}" ]] && return 0
#   3. export _H11H_OMZ_LOADED=1
#   4. export ZSH="<OMZ_DIR>"
#   5. ZSH_THEME="robbyrussell"
#   6. plugins=(git)
#   7. source "$ZSH/oh-my-zsh.sh"
LINE_COUNT=$(grep -c . "${TEST_HOME}/.zshrc" 2>/dev/null || echo 0)
[ "${LINE_COUNT}" -eq 7 ] &&
	pass "write_zshrc: exactly 7 standard lines when no extras configured" ||
	fail "write_zshrc: exactly 7 standard lines when no extras configured" "line count=${LINE_COUNT}; $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 14. write_zshrc appends ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when autosuggestStyle is set
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	AUTOSUGGESTSTYLE="fg=60" AUTOSUGGESTSTRATEGY="" \
	write_zshrc
grep -q 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=60"' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: appends ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when autosuggestStyle set" ||
	fail "write_zshrc: appends ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when autosuggestStyle set" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 15. write_zshrc does NOT add ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when autosuggestStyle is empty
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	AUTOSUGGESTSTYLE="" AUTOSUGGESTSTRATEGY="" \
	write_zshrc
grep -q 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE' "${TEST_HOME}/.zshrc" 2>/dev/null &&
	fail "write_zshrc: must not add ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when autosuggestStyle empty" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)" ||
	pass "write_zshrc: no ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE when autosuggestStyle empty"

# 16. write_zshrc appends ZSH_AUTOSUGGEST_STRATEGY when autosuggestStrategy is set
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	AUTOSUGGESTSTYLE="" AUTOSUGGESTSTRATEGY="history completion" \
	write_zshrc
grep -q 'ZSH_AUTOSUGGEST_STRATEGY=(history completion)' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: appends ZSH_AUTOSUGGEST_STRATEGY when autosuggestStrategy set" ||
	fail "write_zshrc: appends ZSH_AUTOSUGGEST_STRATEGY when autosuggestStrategy set" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 17. write_zshrc does NOT add ZSH_AUTOSUGGEST_STRATEGY when autosuggestStrategy is empty
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	AUTOSUGGESTSTYLE="" AUTOSUGGESTSTRATEGY="" \
	write_zshrc
grep -q 'ZSH_AUTOSUGGEST_STRATEGY' "${TEST_HOME}/.zshrc" 2>/dev/null &&
	fail "write_zshrc: must not add ZSH_AUTOSUGGEST_STRATEGY when autosuggestStrategy empty" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)" ||
	pass "write_zshrc: no ZSH_AUTOSUGGEST_STRATEGY when autosuggestStrategy empty"

# 18. install_omz continues when curl/sh fails (network error resilience)
TEST_HOME=$(new_tmp)
TEST_OMZ=$(new_tmp)/oh-my-zsh
TEST_BIN=$(new_tmp)
# Provide a failing curl stub
cat >"${TEST_BIN}/curl" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/curl"
# install_omz must not propagate the failure (returns 0 with a warning)
OMZ_DIR="${TEST_OMZ}" PATH="${TEST_BIN}:${PATH}" REMOTE_USER_HOME="$TEST_HOME" \
	install_omz 2>/dev/null
pass "install_omz: does not abort on network failure (curl returns 1)"

# 19. install_external_plugins continues when git clone fails
TEST_OMZ3=$(new_tmp)
TEST_BIN=$(new_tmp)
cat >"${TEST_BIN}/git" <<'EOF'
#!/bin/sh
case "${1:-}" in
  clone) exit 1 ;;
  *)     exit 0 ;;
esac
EOF
chmod +x "${TEST_BIN}/git"
# install_external_plugins must not propagate the failure
OMZ_DIR="${TEST_OMZ3}" PATH="${TEST_BIN}:${PATH}" PLUGINS="zsh-autosuggestions" \
	install_external_plugins 2>/dev/null
pass "install_external_plugins: does not abort when git clone fails"

# 20. write_zshrc emits a runtime source line for a relative extraRcFile (file need not exist at build time)
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE=".devcontainer/zshrc-extras.sh" \
	write_zshrc
grep -q 'zshrc-extras.sh' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: emits runtime source line for relative extraRcFile" ||
	fail "write_zshrc: emits runtime source line for relative extraRcFile" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 21. write_zshrc still emits source line when extraRcFile does not exist at build time
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE=".devcontainer/nonexistent.sh" \
	write_zshrc
grep -q 'nonexistent.sh' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: emits source line for extraRcFile even when file absent at build time" ||
	fail "write_zshrc: emits source line for extraRcFile even when file absent at build time" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 22. write_zshrc ignores extraRcFile when it is empty
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE="" \
	write_zshrc
LINE_COUNT=$(grep -c . "${TEST_HOME}/.zshrc" 2>/dev/null || echo 0)
[ "${LINE_COUNT}" -eq 7 ] &&
	pass "write_zshrc: no extra lines when EXTRARCFILE is empty" ||
	fail "write_zshrc: no extra lines when EXTRARCFILE is empty" "line count=${LINE_COUNT}; $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 23. write_zshrc rejects extraRcFile with path traversal (..)
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE="../etc/passwd" \
	write_zshrc 2>/dev/null
LINE_COUNT=$(grep -c . "${TEST_HOME}/.zshrc" 2>/dev/null || echo 0)
[ "${LINE_COUNT}" -eq 7 ] &&
	pass "write_zshrc: rejects extraRcFile with path traversal (..)" ||
	fail "write_zshrc: rejects extraRcFile with path traversal (..)" "line count=${LINE_COUNT}; $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 24. write_zshrc rejects extraRcFile with unsafe characters (e.g. quotes)
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE='foo"bar.sh' \
	write_zshrc 2>/dev/null
LINE_COUNT=$(grep -c . "${TEST_HOME}/.zshrc" 2>/dev/null || echo 0)
[ "${LINE_COUNT}" -eq 7 ] &&
	pass "write_zshrc: rejects extraRcFile with unsafe characters" ||
	fail "write_zshrc: rejects extraRcFile with unsafe characters" "line count=${LINE_COUNT}; $(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 25. write_zshrc defers snippet evaluation to runtime: .zshrc contains a source reference,
# not command substitution syntax — safe for direnv hooks and other $(…) patterns.
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE=".devcontainer/direnv-hook.zsh" \
	write_zshrc
grep -q 'direnv-hook.zsh' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: extraRcFile writes a source reference, not inlined content" ||
	fail "write_zshrc: extraRcFile writes a source reference, not inlined content" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"
# The .zshrc must not contain any command substitution syntax ($(…)) — file content is
# never read at build time; command substitutions remain deferred to runtime.
grep -q '\$(' "${TEST_HOME}/.zshrc" 2>/dev/null &&
	fail "write_zshrc: .zshrc must not contain command substitution syntax at build time" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)" ||
	pass "write_zshrc: .zshrc contains no command substitution syntax at build time"

# 26. write_zshrc includes the _H11H_OMZ_LOADED guard to prevent double-loading
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE="" \
	write_zshrc
grep -q '_H11H_OMZ_LOADED' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: contains _H11H_OMZ_LOADED double-load guard" ||
	fail "write_zshrc: contains _H11H_OMZ_LOADED double-load guard" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 27. write_zshrc points ZSH to the global install dir (not ~/.oh-my-zsh)
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE="" \
	write_zshrc
grep -q "\.oh-my-zsh" "${TEST_HOME}/.zshrc" 2>/dev/null &&
	fail "write_zshrc: must not reference \$HOME/.oh-my-zsh (use global OMZ_DIR)" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)" ||
	pass "write_zshrc: does not reference ~/.oh-my-zsh"

# 28. ensure_zshrc_d creates the zshrc.d directory
TEST_ZSHRC_D=$(new_tmp)/zshrc.d
TEST_GLOBAL_ZSHRC=$(new_tmp)/zshrc
ZSHRC_D_DIR="${TEST_ZSHRC_D}" GLOBAL_ZSHRC="${TEST_GLOBAL_ZSHRC}" \
	ensure_zshrc_d
test -d "${TEST_ZSHRC_D}" &&
	pass "ensure_zshrc_d: creates zshrc.d directory" ||
	fail "ensure_zshrc_d: creates zshrc.d directory" "directory not found"

# 29. ensure_zshrc_d creates /etc/zsh/zshrc if it does not exist
test -f "${TEST_GLOBAL_ZSHRC}" &&
	pass "ensure_zshrc_d: creates global zshrc file if missing" ||
	fail "ensure_zshrc_d: creates global zshrc file if missing" "file not found"

# 30. ensure_zshrc_d appends sourcing loop to global zshrc
grep -q "${TEST_ZSHRC_D}" "${TEST_GLOBAL_ZSHRC}" &&
	pass "ensure_zshrc_d: appends zshrc.d sourcing loop to global zshrc" ||
	fail "ensure_zshrc_d: appends zshrc.d sourcing loop to global zshrc" "$(cat "${TEST_GLOBAL_ZSHRC}" 2>/dev/null)"

# 31. ensure_zshrc_d is idempotent (no duplicate sourcing loops)
ZSHRC_D_DIR="${TEST_ZSHRC_D}" GLOBAL_ZSHRC="${TEST_GLOBAL_ZSHRC}" \
	ensure_zshrc_d
count=$(grep -c 'h11h-io: source' "${TEST_GLOBAL_ZSHRC}" || true)
[ "${count}" -eq 1 ] &&
	pass "ensure_zshrc_d: idempotent (single sourcing loop after double call)" ||
	fail "ensure_zshrc_d: idempotent (single sourcing loop after double call)" "found ${count} markers"

# 32. write_global_zshrc writes oh-my-zsh.zsh to zshrc.d
TEST_ZSHRC_D_GLOBAL=$(new_tmp)/zshrc.d
mkdir -p "${TEST_ZSHRC_D_GLOBAL}"
ZSHRC_D_DIR="${TEST_ZSHRC_D_GLOBAL}" PLUGINS="git kubectl" THEME="agnoster" \
	EXTRARCFILE="" AUTOSUGGESTSTYLE="" AUTOSUGGESTSTRATEGY="" \
	write_global_zshrc
test -f "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" &&
	pass "write_global_zshrc: creates oh-my-zsh.zsh in zshrc.d" ||
	fail "write_global_zshrc: creates oh-my-zsh.zsh in zshrc.d" "file not found"

# 33. write_global_zshrc includes the double-load guard
grep -q '_H11H_OMZ_LOADED' "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" &&
	pass "write_global_zshrc: contains _H11H_OMZ_LOADED guard" ||
	fail "write_global_zshrc: contains _H11H_OMZ_LOADED guard" "$(cat "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null)"

# 34. write_global_zshrc uses the configured theme
grep -q 'ZSH_THEME="agnoster"' "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" &&
	pass "write_global_zshrc: uses configured theme" ||
	fail "write_global_zshrc: uses configured theme" "$(cat "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null)"

# 35. write_global_zshrc includes the configured plugins
grep -q 'plugins=(git kubectl)' "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" &&
	pass "write_global_zshrc: includes configured plugins" ||
	fail "write_global_zshrc: includes configured plugins" "$(cat "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null)"

# 36. write_zshrc includes /workspaces fallback for relative extraRcFile
TEST_HOME=$(new_tmp)
REMOTE_USER_HOME="$TEST_HOME" PLUGINS="git" THEME="robbyrussell" REMOTE_USER="root" \
	EXTRARCFILE=".devcontainer/zshrc-extras.sh" \
	write_zshrc
grep -q '/workspaces/\*' "${TEST_HOME}/.zshrc" &&
	pass "write_zshrc: includes /workspaces fallback for relative extraRcFile" ||
	fail "write_zshrc: includes /workspaces fallback for relative extraRcFile" "$(cat "${TEST_HOME}/.zshrc" 2>/dev/null)"

# 37. write_global_zshrc includes /workspaces fallback for relative extraRcFile
TEST_ZSHRC_D_GLOBAL=$(new_tmp)/zshrc.d
mkdir -p "${TEST_ZSHRC_D_GLOBAL}"
ZSHRC_D_DIR="${TEST_ZSHRC_D_GLOBAL}" PLUGINS="git" THEME="robbyrussell" \
	EXTRARCFILE=".devcontainer/zshrc-extras.sh" AUTOSUGGESTSTYLE="" AUTOSUGGESTSTRATEGY="" \
	write_global_zshrc
grep -q '/workspaces/\*' "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" &&
	pass "write_global_zshrc: includes /workspaces fallback for relative extraRcFile" ||
	fail "write_global_zshrc: includes /workspaces fallback for relative extraRcFile" "$(cat "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null)"

# 38. ensure_zshrc_d uses null-glob (N) qualifier to avoid NOMATCH errors in zsh
grep -q '(N)' "${TEST_GLOBAL_ZSHRC}" &&
	pass "ensure_zshrc_d: sourcing loop uses null-glob (N) qualifier" ||
	fail "ensure_zshrc_d: sourcing loop uses null-glob (N) qualifier" "$(cat "${TEST_GLOBAL_ZSHRC}" 2>/dev/null)"

# 39. write_global_zshrc guards source with [[ -d "$ZSH" ]] existence check
grep -q '\[\[ -d "\$ZSH" \]\]' "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" &&
	pass "write_global_zshrc: guards source with [[ -d \"\$ZSH\" ]] existence check" ||
	fail "write_global_zshrc: guards source with [[ -d \"\$ZSH\" ]] existence check" "$(cat "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null)"

# 40. write_global_zshrc does NOT emit bare unguarded source line
grep -qE '^source "\$ZSH/oh-my-zsh.sh"' "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null &&
	fail "write_global_zshrc: must not emit bare unguarded source line" "$(cat "${TEST_ZSHRC_D_GLOBAL}/oh-my-zsh.zsh" 2>/dev/null)" ||
	pass "write_global_zshrc: no bare unguarded source line"

summary
