#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/h11h-foundation/install.sh
#
# Validates: disable list parsing, env var mapping to sub-features,
# config file persistence, and lifecycle script installation.
#
# Usage:  bash test/unit/test_h11h_foundation.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/h11h-foundation/install.sh"

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
echo "=== h11h-foundation unit tests ==="
echo ""

# ── helper: create a mock install environment ────────────────────────────────
# Copies the install.sh into a temp directory and replaces sub-feature install
# scripts with stubs that just log which feature was called and its env vars.
create_mock_install_env() {
	local mock_root
	mock_root=$(new_tmp)

	# Copy the real install.sh
	cp "$INSTALL_SCRIPT" "${mock_root}/install.sh"

	# Create mock sub-feature install scripts
	local features="git-identity-from-github devbox oh-my-zsh project-setup supabase-cli coder userspace-pkg-homes"
	for feat in $features; do
		mkdir -p "${mock_root}/features/${feat}"
		cat >"${mock_root}/features/${feat}/install.sh" <<STUB
#!/bin/sh
echo "STUB:${feat}:installed"
STUB
		chmod +x "${mock_root}/features/${feat}/install.sh"
	done

	# Create stub lifecycle scripts (install.sh copies these to /usr/local/bin)
	for script in h11h-foundation-on-create.sh h11h-foundation-post-create.sh h11h-foundation-post-start.sh; do
		cp "${REPO_ROOT}/src/h11h-foundation/${script}" "${mock_root}/${script}"
	done

	# Create a mock install binary that just logs instead of writing to /usr/local/bin
	local mock_bin="${mock_root}/bin"
	mkdir -p "$mock_bin"
	cat >"${mock_bin}/install" <<'MOCK'
#!/bin/sh
echo "mock-install: $*" >&2
# Actually copy the file to the destination for lifecycle tests
src=""
dst=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o|-g|-m) shift ;; # skip flag values
    *) if [ -z "$src" ]; then src="$1"; elif [ -z "$dst" ]; then dst="$1"; fi ;;
  esac
  shift
done
if [ -n "$src" ] && [ -n "$dst" ]; then
  mkdir -p "$(dirname "$dst")" 2>/dev/null || true
  cp "$src" "$dst" 2>/dev/null || true
fi
MOCK
	chmod +x "${mock_bin}/install"

	echo "$mock_root"
}

# ── helper: run install.sh with mock features ────────────────────────────────
run_mock_install() {
	local mock_root="$1"
	shift
	# Run with mock install binary on PATH and override config dir
	PATH="${mock_root}/bin:${PATH}" sh "${mock_root}/install.sh" "$@" 2>&1
}

# ── Test 1: disable list parsing ─────────────────────────────────────────────
echo "--- Test: disable list is persisted to config file ---"
MOCK_ROOT=$(create_mock_install_env)
TMPDIR_1=$(new_tmp)
CONFIG_DIR="${TMPDIR_1}/config"

out=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR" \
	DISABLE="devbox,coder" \
	run_mock_install "$MOCK_ROOT") || true

[ -f "${CONFIG_DIR}/disable.conf" ] &&
	pass "disable.conf created" ||
	fail "disable.conf created" "file not found at ${CONFIG_DIR}/disable.conf"

if [ -f "${CONFIG_DIR}/disable.conf" ]; then
	content=$(cat "${CONFIG_DIR}/disable.conf")
	[ "$content" = "devbox,coder" ] &&
		pass "disable.conf contains correct value" ||
		fail "disable.conf contains correct value" "got: $content"
fi

# ── Test 2: disabled features are skipped ────────────────────────────────────
echo ""
echo "--- Test: disabled features are skipped ---"
echo "$out" | grep -q "skipping devbox (disabled)" &&
	pass "devbox reported as disabled" ||
	fail "devbox reported as disabled" "output missing 'skipping devbox (disabled)'"

echo "$out" | grep -q "skipping coder (disabled)" &&
	pass "coder reported as disabled" ||
	fail "coder reported as disabled" "output missing 'skipping coder (disabled)'"

# Verify the stubs for disabled features were NOT called
echo "$out" | grep -q "STUB:devbox:installed" &&
	fail "devbox stub should not run" "stub was executed" ||
	pass "devbox stub was not called"

echo "$out" | grep -q "STUB:coder:installed" &&
	fail "coder stub should not run" "stub was executed" ||
	pass "coder stub was not called"

# ── Test 3: enabled features are installed ───────────────────────────────────
echo ""
echo "--- Test: enabled features are installed ---"
echo "$out" | grep -q "installing git-identity-from-github" &&
	pass "git-identity-from-github install message" ||
	fail "git-identity-from-github install message" "output missing install message"

echo "$out" | grep -q "STUB:git-identity-from-github:installed" &&
	pass "git-identity-from-github stub was called" ||
	fail "git-identity-from-github stub was called" "stub output not found"

echo "$out" | grep -q "installing oh-my-zsh" &&
	pass "oh-my-zsh install message" ||
	fail "oh-my-zsh install message" "output missing install message"

echo "$out" | grep -q "STUB:oh-my-zsh:installed" &&
	pass "oh-my-zsh stub was called" ||
	fail "oh-my-zsh stub was called" "stub output not found"

echo "$out" | grep -q "installing supabase-cli" &&
	pass "supabase-cli install message" ||
	fail "supabase-cli install message" "output missing install message"

echo "$out" | grep -q "installing project-setup" &&
	pass "project-setup install message" ||
	fail "project-setup install message" "output missing install message"

echo "$out" | grep -q "installing userspace-pkg-homes" &&
	pass "userspace-pkg-homes install message" ||
	fail "userspace-pkg-homes install message" "output missing install message"

echo "$out" | grep -q "installation complete" &&
	pass "installation completes successfully" ||
	fail "installation completes successfully" "missing completion message"

# ── Test 4: empty disable list installs everything ───────────────────────────
echo ""
echo "--- Test: empty disable list installs everything ---"
MOCK_ROOT_4=$(create_mock_install_env)
TMPDIR_4=$(new_tmp)
CONFIG_DIR_4="${TMPDIR_4}/config"

out4=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_4" \
	DISABLE="" \
	run_mock_install "$MOCK_ROOT_4") || true

echo "$out4" | grep -q "skipping" &&
	fail "no features skipped with empty disable" "found 'skipping' in output" ||
	pass "no features skipped with empty disable"

# All 7 stubs should have been called
stub_count=$(echo "$out4" | grep -c "STUB:.*:installed" || true)
[ "$stub_count" -eq 7 ] &&
	pass "all 7 sub-feature stubs called" ||
	fail "all 7 sub-feature stubs called" "expected 7, got $stub_count"

# ── Test 5: exportGlobalProfile is persisted ─────────────────────────────────
echo ""
echo "--- Test: exportGlobalProfile is persisted ---"
[ -f "${CONFIG_DIR}/export-global-profile.conf" ] &&
	pass "export-global-profile.conf created" ||
	fail "export-global-profile.conf created" "file not found"

# ── Test 6: disable all features ─────────────────────────────────────────────
echo ""
echo "--- Test: all features can be disabled ---"
MOCK_ROOT_6=$(create_mock_install_env)
TMPDIR_6=$(new_tmp)
CONFIG_DIR_6="${TMPDIR_6}/config"

out6=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_6" \
	DISABLE="git-identity-from-github,devbox,oh-my-zsh,project-setup,supabase-cli,coder,userspace-pkg-homes" \
	run_mock_install "$MOCK_ROOT_6") || true

# Count the number of "skipping" lines
skip_count=$(echo "$out6" | grep -c "skipping" || true)
[ "$skip_count" -eq 7 ] &&
	pass "all 7 features skipped" ||
	fail "all 7 features skipped" "expected 7 skips, got $skip_count"

echo "$out6" | grep -q "installation complete" &&
	pass "install completes even with all disabled" ||
	fail "install completes even with all disabled" "missing completion message"

# No stubs should have been called
stub_count_6=$(echo "$out6" | grep -c "STUB:.*:installed" || true)
[ "$stub_count_6" -eq 0 ] &&
	pass "no stubs called when all disabled" ||
	fail "no stubs called when all disabled" "expected 0, got $stub_count_6"

# ── Test 7: env vars are mapped to sub-feature install scripts ───────────────
echo ""
echo "--- Test: env vars are mapped to sub-features ---"
MOCK_ROOT_7=$(create_mock_install_env)
TMPDIR_7=$(new_tmp)
CONFIG_DIR_7="${TMPDIR_7}/config"

# Replace the devbox stub to echo env vars
cat >"${MOCK_ROOT_7}/features/devbox/install.sh" <<'STUB'
#!/bin/sh
echo "DEVBOX_ENV:VERSION=${VERSION:-unset}"
STUB
chmod +x "${MOCK_ROOT_7}/features/devbox/install.sh"

# Replace the coder stub to echo env vars
cat >"${MOCK_ROOT_7}/features/coder/install.sh" <<'STUB'
#!/bin/sh
echo "CODER_ENV:VERSION=${VERSION:-unset}"
STUB
chmod +x "${MOCK_ROOT_7}/features/coder/install.sh"

# Replace the supabase stub to echo env vars
cat >"${MOCK_ROOT_7}/features/supabase-cli/install.sh" <<'STUB'
#!/bin/sh
echo "SUPABASE_ENV:VERSION=${VERSION:-unset}"
echo "SUPABASE_ENV:DOCKERWAITSECONDS=${DOCKERWAITSECONDS:-unset}"
STUB
chmod +x "${MOCK_ROOT_7}/features/supabase-cli/install.sh"

# Replace the oh-my-zsh stub to echo env vars
cat >"${MOCK_ROOT_7}/features/oh-my-zsh/install.sh" <<'STUB'
#!/bin/bash
echo "OMZ_ENV:THEME=${THEME:-unset}"
echo "OMZ_ENV:PLUGINS=${PLUGINS:-unset}"
echo "OMZ_ENV:AUTOSUGGESTSTYLE=${AUTOSUGGESTSTYLE:-unset}"
STUB
chmod +x "${MOCK_ROOT_7}/features/oh-my-zsh/install.sh"

out7=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_7" \
	DISABLE="" \
	DEVBOXVERSION="0.15.0" \
	CODERVERSION="2.5.0" \
	SUPABASEVERSION="2.90.0" \
	DOCKERWAITSECONDS="45" \
	OHMYZSHTHEME="clean" \
	OHMYZSHPLUGINS="git z" \
	AUTOSUGGESTSTYLE="fg=80" \
	run_mock_install "$MOCK_ROOT_7") || true

echo "$out7" | grep -q "DEVBOX_ENV:VERSION=0.15.0" &&
	pass "devboxVersion mapped to VERSION" ||
	fail "devboxVersion mapped to VERSION" "output: $(echo "$out7" | grep DEVBOX_ENV)"

echo "$out7" | grep -q "CODER_ENV:VERSION=2.5.0" &&
	pass "coderVersion mapped to VERSION" ||
	fail "coderVersion mapped to VERSION" "output: $(echo "$out7" | grep CODER_ENV)"

echo "$out7" | grep -q "SUPABASE_ENV:VERSION=2.90.0" &&
	pass "supabaseVersion mapped to VERSION" ||
	fail "supabaseVersion mapped to VERSION" "output: $(echo "$out7" | grep SUPABASE_ENV)"

echo "$out7" | grep -q "SUPABASE_ENV:DOCKERWAITSECONDS=45" &&
	pass "dockerWaitSeconds mapped to DOCKERWAITSECONDS" ||
	fail "dockerWaitSeconds mapped to DOCKERWAITSECONDS" "output: $(echo "$out7" | grep SUPABASE_ENV)"

echo "$out7" | grep -q "OMZ_ENV:THEME=clean" &&
	pass "ohmyzshTheme mapped to THEME" ||
	fail "ohmyzshTheme mapped to THEME" "output: $(echo "$out7" | grep OMZ_ENV)"

echo "$out7" | grep -q "OMZ_ENV:PLUGINS=git z" &&
	pass "ohmyzshPlugins mapped to PLUGINS" ||
	fail "ohmyzshPlugins mapped to PLUGINS" "output: $(echo "$out7" | grep OMZ_ENV)"

echo "$out7" | grep -q "OMZ_ENV:AUTOSUGGESTSTYLE=fg=80" &&
	pass "autosuggestStyle mapped to AUTOSUGGESTSTYLE" ||
	fail "autosuggestStyle mapped to AUTOSUGGESTSTYLE" "output: $(echo "$out7" | grep OMZ_ENV)"

# ── Test 8: lifecycle on-create script checks disable list ───────────────────
echo ""
echo "--- Test: on-create lifecycle respects disable list ---"
ON_CREATE="${REPO_ROOT}/src/h11h-foundation/h11h-foundation-on-create.sh"

TMPDIR_8=$(new_tmp)
CONFIG_DIR_8="${TMPDIR_8}/config"
mkdir -p "$CONFIG_DIR_8"
echo "devbox" >"${CONFIG_DIR_8}/disable.conf"

out8=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_8" bash "$ON_CREATE" 2>&1) || true
echo "$out8" | grep -q "devbox disabled" &&
	pass "on-create: devbox disabled" ||
	fail "on-create: devbox disabled" "output: $out8"

# ── Test 9: lifecycle post-create script checks disable list ─────────────────
echo ""
echo "--- Test: post-create lifecycle respects disable list ---"
POST_CREATE="${REPO_ROOT}/src/h11h-foundation/h11h-foundation-post-create.sh"

TMPDIR_9=$(new_tmp)
CONFIG_DIR_9="${TMPDIR_9}/config"
mkdir -p "$CONFIG_DIR_9"
echo "project-setup" >"${CONFIG_DIR_9}/disable.conf"

out9=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_9" bash "$POST_CREATE" 2>&1) || true
echo "$out9" | grep -q "project-setup disabled" &&
	pass "post-create: project-setup disabled" ||
	fail "post-create: project-setup disabled" "output: $out9"

# ── Test 10: lifecycle post-start script checks disable list ─────────────────
echo ""
echo "--- Test: post-start lifecycle respects disable list ---"
POST_START="${REPO_ROOT}/src/h11h-foundation/h11h-foundation-post-start.sh"

TMPDIR_10=$(new_tmp)
CONFIG_DIR_10="${TMPDIR_10}/config"
mkdir -p "$CONFIG_DIR_10"
echo "git-identity-from-github,devbox,supabase-cli" >"${CONFIG_DIR_10}/disable.conf"

out10=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_10" bash "$POST_START" 2>&1) || true
echo "$out10" | grep -q "git-identity-from-github disabled" &&
	pass "post-start: git-identity-from-github disabled" ||
	fail "post-start: git-identity-from-github disabled" "output: $out10"
echo "$out10" | grep -q "devbox disabled" &&
	pass "post-start: devbox disabled" ||
	fail "post-start: devbox disabled" "output: $out10"
echo "$out10" | grep -q "supabase-cli disabled" &&
	pass "post-start: supabase-cli disabled" ||
	fail "post-start: supabase-cli disabled" "output: $out10"

# ── Test 11: lifecycle post-start runs enabled features (commands not found) ─
echo ""
echo "--- Test: post-start tries to run enabled features ---"
TMPDIR_11=$(new_tmp)
CONFIG_DIR_11="${TMPDIR_11}/config"
MOCK_BIN_11=$(new_tmp)
mkdir -p "$CONFIG_DIR_11"
echo "" >"${CONFIG_DIR_11}/disable.conf"

# Use a PATH with no lifecycle commands to verify "not found" messages
out11=$(PATH="$MOCK_BIN_11:/usr/bin:/bin" \
	H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_11" bash "$POST_START" 2>&1) || true
echo "$out11" | grep -q "configure-git-identity not found" &&
	pass "post-start: reports configure-git-identity not found" ||
	fail "post-start: reports configure-git-identity not found" "output: $out11"
echo "$out11" | grep -q "devbox-post-start not found" &&
	pass "post-start: reports devbox-post-start not found" ||
	fail "post-start: reports devbox-post-start not found" "output: $out11"
echo "$out11" | grep -q "supabase-post-start not found" &&
	pass "post-start: reports supabase-post-start not found" ||
	fail "post-start: reports supabase-post-start not found" "output: $out11"

# ── Test 12: on-create with enabled devbox (command not found) ───────────────
echo ""
echo "--- Test: on-create tries to run devbox-on-create when enabled ---"
TMPDIR_12=$(new_tmp)
CONFIG_DIR_12="${TMPDIR_12}/config"
MOCK_BIN_12=$(new_tmp)
mkdir -p "$CONFIG_DIR_12"
echo "" >"${CONFIG_DIR_12}/disable.conf"
echo "true" >"${CONFIG_DIR_12}/export-global-profile.conf"

out12=$(PATH="$MOCK_BIN_12:/usr/bin:/bin" \
	H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_12" bash "$ON_CREATE" 2>&1) || true
echo "$out12" | grep -q "devbox-on-create not found" &&
	pass "on-create: reports devbox-on-create not found" ||
	fail "on-create: reports devbox-on-create not found" "output: $out12"

# ── Test 13: devcontainer-feature.json is valid JSON ─────────────────────────
echo ""
echo "--- Test: devcontainer-feature.json is valid ---"
FEATURE_JSON="${REPO_ROOT}/src/h11h-foundation/devcontainer-feature.json"
if command -v jq >/dev/null 2>&1; then
	jq empty "$FEATURE_JSON" 2>/dev/null &&
		pass "devcontainer-feature.json is valid JSON" ||
		fail "devcontainer-feature.json is valid JSON" "jq parse failed"

	feature_id=$(jq -r '.id' "$FEATURE_JSON")
	[ "$feature_id" = "h11h-foundation" ] &&
		pass "feature id is h11h-foundation" ||
		fail "feature id is h11h-foundation" "got: $feature_id"

	disable_opt=$(jq -r '.options.disable.type' "$FEATURE_JSON")
	[ "$disable_opt" = "string" ] &&
		pass "disable option exists with type string" ||
		fail "disable option exists with type string" "got: $disable_opt"

	# Verify all lifecycle commands are declared
	on_create=$(jq -r '.onCreateCommand' "$FEATURE_JSON")
	[ "$on_create" = "h11h-foundation-on-create" ] &&
		pass "onCreateCommand declared" ||
		fail "onCreateCommand declared" "got: $on_create"

	post_create=$(jq -r '.postCreateCommand' "$FEATURE_JSON")
	[ "$post_create" = "h11h-foundation-post-create" ] &&
		pass "postCreateCommand declared" ||
		fail "postCreateCommand declared" "got: $post_create"

	post_start=$(jq -r '.postStartCommand' "$FEATURE_JSON")
	[ "$post_start" = "h11h-foundation-post-start" ] &&
		pass "postStartCommand declared" ||
		fail "postStartCommand declared" "got: $post_start"

	# Verify option count (20 sub-feature options + disable = 21 total)
	opt_count=$(jq '.options | keys | length' "$FEATURE_JSON")
	[ "$opt_count" -eq 21 ] &&
		pass "21 options declared" ||
		fail "21 options declared" "got: $opt_count"
else
	echo "  SKIP  jq not available, skipping JSON validation"
fi

# ── Test 14: single feature disable ──────────────────────────────────────────
echo ""
echo "--- Test: single feature in disable list ---"
MOCK_ROOT_14=$(create_mock_install_env)
TMPDIR_14=$(new_tmp)
CONFIG_DIR_14="${TMPDIR_14}/config"

out14=$(H11H_FOUNDATION_CONFIG_DIR="$CONFIG_DIR_14" \
	DISABLE="oh-my-zsh" \
	run_mock_install "$MOCK_ROOT_14") || true

echo "$out14" | grep -q "skipping oh-my-zsh (disabled)" &&
	pass "single disable: oh-my-zsh skipped" ||
	fail "single disable: oh-my-zsh skipped" "output missing skip message"

echo "$out14" | grep -q "STUB:oh-my-zsh:installed" &&
	fail "single disable: oh-my-zsh stub should not run" "stub was executed" ||
	pass "single disable: oh-my-zsh stub was not called"

# Other features should still be installed
echo "$out14" | grep -q "STUB:devbox:installed" &&
	pass "single disable: devbox still installed" ||
	fail "single disable: devbox still installed" "stub output not found"

summary
