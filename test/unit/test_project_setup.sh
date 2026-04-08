#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/project-setup/install.sh and project-setup-post-create.sh
#
# Uses mocked pnpm, uv, lefthook, direnv to avoid requiring real tools.
#
# Usage:  bash test/unit/test_project_setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/project-setup/install.sh"
POST_CREATE_SCRIPT="${REPO_ROOT}/src/project-setup/project-setup-post-create.sh"

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

# make_install_mock_bin <dir>
# Populates a mock bin dir for install.sh tests.
make_install_mock_bin() {
	local d="$1"
	mkdir -p "$d"

	# install mock: non-root copy, parses -o/-g/-m flags
	cat >"$d/install" <<'EOF'
#!/bin/sh
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
}

# make_post_create_mock_bin <dir>
# Populates a mock bin dir for post-create tests.
make_post_create_mock_bin() {
	local d="$1"
	mkdir -p "$d"

	cat >"$d/pnpm" <<EOF
#!/bin/sh
echo "\$@" >> "${d}/pnpm_calls.log"
echo "mock pnpm \$*"
EOF
	chmod +x "$d/pnpm"

	cat >"$d/uv" <<EOF
#!/bin/sh
echo "\$@" >> "${d}/uv_calls.log"
echo "mock uv \$*"
EOF
	chmod +x "$d/uv"

	cat >"$d/lefthook" <<EOF
#!/bin/sh
echo "\$@" >> "${d}/lefthook_calls.log"
echo "mock lefthook \$*"
EOF
	chmod +x "$d/lefthook"

	cat >"$d/direnv" <<EOF
#!/bin/sh
echo "\$@" >> "${d}/direnv_calls.log"
echo "mock direnv \$*"
EOF
	chmod +x "$d/direnv"
}

# run_post_create <mock_bin> <workspace> [extra env vars...]
# Runs the post-create script with the given mock bin and workspace.
run_post_create() {
	local mock_bin="$1"
	local workspace="$2"
	shift 2
	env PATH="${mock_bin}:${PATH}" \
		containerWorkspaceFolder="$workspace" \
		"$@" \
		bash "$POST_CREATE_SCRIPT" 2>&1
}

echo ""
echo "=== project-setup/install.sh unit tests ==="
echo ""

# 1. install.sh exits 0 with default options
TEST_BIN=$(new_tmp)
SHARE_DIR=$(new_tmp)
make_install_mock_bin "$TEST_BIN"
rc=0
PATH="$TEST_BIN:$PATH" PROJECT_SETUP_SHARE_DIR="$SHARE_DIR" \
	NODESUBDIRS="" PYTHONSUBDIRS="" ENVFILES="" \
	LEFTHOOKINSTALL="true" DIRENVALLOW="true" \
	sh "$INSTALL_SCRIPT" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "install: exits 0 with default options" ||
	fail "install: exits 0 with default options" "exit code was $rc"

# 2. install.sh installs project-setup-post-create helper
TEST_BIN=$(new_tmp)
SHARE_DIR=$(new_tmp)
make_install_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" PROJECT_SETUP_SHARE_DIR="$SHARE_DIR" \
	NODESUBDIRS="ui" PYTHONSUBDIRS="" ENVFILES="" \
	LEFTHOOKINSTALL="true" DIRENVALLOW="true" \
	sh "$INSTALL_SCRIPT" >/dev/null 2>&1
test -x "${TEST_BIN}/project-setup-post-create" &&
	pass "install: project-setup-post-create helper installed in bin" ||
	fail "install: project-setup-post-create helper installed in bin" "not found in ${TEST_BIN}"

# 3. install.sh creates config.sh with baked values
TEST_BIN=$(new_tmp)
SHARE_DIR=$(new_tmp)
make_install_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" PROJECT_SETUP_SHARE_DIR="$SHARE_DIR" \
	NODESUBDIRS="ui api" PYTHONSUBDIRS="backend" ENVFILES="ui/.env.example:ui/.env" \
	LEFTHOOKINSTALL="true" DIRENVALLOW="false" \
	sh "$INSTALL_SCRIPT" >/dev/null 2>&1
test -f "${SHARE_DIR}/config.sh" &&
	pass "install: config.sh created" ||
	fail "install: config.sh created" "not found: ${SHARE_DIR}/config.sh"
grep -q "ui api" "${SHARE_DIR}/config.sh" &&
	pass "install: config.sh contains nodeSubdirs value" ||
	fail "install: config.sh contains nodeSubdirs value" "config: $(cat "${SHARE_DIR}/config.sh" 2>/dev/null)"
grep -q "backend" "${SHARE_DIR}/config.sh" &&
	pass "install: config.sh contains pythonSubdirs value" ||
	fail "install: config.sh contains pythonSubdirs value" "config: $(cat "${SHARE_DIR}/config.sh" 2>/dev/null)"
grep -q "ui/.env.example:ui/.env" "${SHARE_DIR}/config.sh" &&
	pass "install: config.sh contains envFiles value" ||
	fail "install: config.sh contains envFiles value" "config: $(cat "${SHARE_DIR}/config.sh" 2>/dev/null)"
grep -q "BAKED_LEFTHOOK_INSTALL='true'" "${SHARE_DIR}/config.sh" &&
	pass "install: config.sh bakes lefthookInstall=true" ||
	fail "install: config.sh bakes lefthookInstall=true" "config: $(cat "${SHARE_DIR}/config.sh" 2>/dev/null)"
grep -q "BAKED_DIRENV_ALLOW='false'" "${SHARE_DIR}/config.sh" &&
	pass "install: config.sh bakes direnvAllow=false" ||
	fail "install: config.sh bakes direnvAllow=false" "config: $(cat "${SHARE_DIR}/config.sh" 2>/dev/null)"

echo ""
echo "=== project-setup-post-create.sh unit tests ==="
echo ""

# Helper: create a config file in a temp dir and return the path
make_config() {
	local cfg_dir
	cfg_dir=$(new_tmp)
	local cfg_file="${cfg_dir}/config.sh"
	cat >"$cfg_file" <<EOF
BAKED_NODE_SUBDIRS='${1:-}'
BAKED_PYTHON_SUBDIRS='${2:-}'
BAKED_ENV_FILES='${3:-}'
BAKED_LEFTHOOK_INSTALL='${4:-true}'
BAKED_DIRENV_ALLOW='${5:-true}'
EOF
	echo "$cfg_file"
}

# 4. Script exits 0 with no options set (all empty/defaults)
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "false" "false")
rc=0
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "smoke: exits 0 with all options empty/disabled" ||
	fail "smoke: exits 0 with all options empty/disabled" "exit code was $rc"

# 5. pnpm install is called for a nodeSubdir with package.json
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui"
touch "${WS}/ui/package.json"
CFG=$(make_config "ui" "" "" "false" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" PNPM_CMD=pnpm >/dev/null 2>&1
grep -q "install" "${TEST_BIN}/pnpm_calls.log" &&
	pass "pnpm: pnpm install called for ui/ with package.json" ||
	fail "pnpm: pnpm install called for ui/ with package.json" "pnpm_calls: $(cat "${TEST_BIN}/pnpm_calls.log" 2>/dev/null)"

# 6. pnpm install is skipped when package.json is absent
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui"
# no package.json
CFG=$(make_config "ui" "" "" "false" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" PNPM_CMD=pnpm 2>&1)
test ! -f "${TEST_BIN}/pnpm_calls.log" &&
	pass "pnpm: pnpm install skipped when package.json absent" ||
	fail "pnpm: pnpm install skipped when package.json absent" "pnpm was called: $(cat "${TEST_BIN}/pnpm_calls.log" 2>/dev/null)"
echo "$out" | grep -q "WARNING" &&
	pass "pnpm: WARNING printed when package.json absent" ||
	fail "pnpm: WARNING printed when package.json absent" "output: $out"

# 7. pnpm install is skipped when pnpm is not available
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui"
touch "${WS}/ui/package.json"
CFG=$(make_config "ui" "" "" "false" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" PNPM_CMD="__no_pnpm_here__" 2>&1)
echo "$out" | grep -q "WARNING" &&
	pass "pnpm: WARNING printed when pnpm not found" ||
	fail "pnpm: WARNING printed when pnpm not found" "output: $out"

# 8. pnpm install called for multiple node subdirs
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui" "${WS}/api"
touch "${WS}/ui/package.json" "${WS}/api/package.json"
CFG=$(make_config "ui api" "" "" "false" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" PNPM_CMD=pnpm >/dev/null 2>&1
CALL_COUNT=$(wc -l <"${TEST_BIN}/pnpm_calls.log" 2>/dev/null || echo 0)
[ "$CALL_COUNT" -eq 2 ] &&
	pass "pnpm: pnpm install called twice for two node subdirs" ||
	fail "pnpm: pnpm install called twice for two node subdirs" "call count: ${CALL_COUNT}"

# 9. uv sync is called for a pythonSubdir with pyproject.toml
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/backend"
touch "${WS}/backend/pyproject.toml"
CFG=$(make_config "" "backend" "" "false" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" UV_CMD=uv >/dev/null 2>&1
grep -q "sync" "${TEST_BIN}/uv_calls.log" &&
	pass "uv: uv sync called for backend/ with pyproject.toml" ||
	fail "uv: uv sync called for backend/ with pyproject.toml" "uv_calls: $(cat "${TEST_BIN}/uv_calls.log" 2>/dev/null)"

# 10. uv sync is skipped when pyproject.toml is absent
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/backend"
# no pyproject.toml
CFG=$(make_config "" "backend" "" "false" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" UV_CMD=uv 2>&1)
test ! -f "${TEST_BIN}/uv_calls.log" &&
	pass "uv: uv sync skipped when pyproject.toml absent" ||
	fail "uv: uv sync skipped when pyproject.toml absent" "uv was called: $(cat "${TEST_BIN}/uv_calls.log" 2>/dev/null)"
echo "$out" | grep -q "WARNING" &&
	pass "uv: WARNING printed when pyproject.toml absent" ||
	fail "uv: WARNING printed when pyproject.toml absent" "output: $out"

# 11. uv sync is skipped when uv is not available
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/backend"
touch "${WS}/backend/pyproject.toml"
CFG=$(make_config "" "backend" "" "false" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" UV_CMD="__no_uv_here__" 2>&1)
echo "$out" | grep -q "WARNING" &&
	pass "uv: WARNING printed when uv not found" ||
	fail "uv: WARNING printed when uv not found" "output: $out"

# 12. env file is copied when example exists and target does not
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui"
echo "EXAMPLE=1" >"${WS}/ui/.env.local.example"
CFG=$(make_config "" "" "ui/.env.local.example:ui/.env.local" "false" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" >/dev/null 2>&1
test -f "${WS}/ui/.env.local" &&
	pass "envfiles: target file created from example" ||
	fail "envfiles: target file created from example" "file not found: ${WS}/ui/.env.local"
grep -q "EXAMPLE=1" "${WS}/ui/.env.local" &&
	pass "envfiles: target file has correct contents" ||
	fail "envfiles: target file has correct contents" "contents: $(cat "${WS}/ui/.env.local" 2>/dev/null)"

# 13. env file copy is skipped when target already exists
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui"
echo "EXAMPLE=1" >"${WS}/ui/.env.local.example"
echo "EXISTING=1" >"${WS}/ui/.env.local"
CFG=$(make_config "" "" "ui/.env.local.example:ui/.env.local" "false" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" 2>&1)
grep -q "EXISTING=1" "${WS}/ui/.env.local" &&
	pass "envfiles: existing target not overwritten" ||
	fail "envfiles: existing target not overwritten" "contents: $(cat "${WS}/ui/.env.local" 2>/dev/null)"
echo "$out" | grep -q "already exists" &&
	pass "envfiles: 'already exists' message printed for existing target" ||
	fail "envfiles: 'already exists' message printed for existing target" "output: $out"

# 14. env file copy warns when example file does not exist
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
# no example file
CFG=$(make_config "" "" "ui/.env.local.example:ui/.env.local" "false" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" 2>&1)
echo "$out" | grep -q "WARNING" &&
	pass "envfiles: WARNING printed when example not found" ||
	fail "envfiles: WARNING printed when example not found" "output: $out"
test ! -f "${WS}/ui/.env.local" &&
	pass "envfiles: target not created when example missing" ||
	fail "envfiles: target not created when example missing" "target was unexpectedly created"

# 15. lefthook install is called when lefthookInstall=true
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "true" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" LEFTHOOK_CMD=lefthook >/dev/null 2>&1
grep -q "install" "${TEST_BIN}/lefthook_calls.log" &&
	pass "lefthook: lefthook install called when lefthookInstall=true" ||
	fail "lefthook: lefthook install called when lefthookInstall=true" "calls: $(cat "${TEST_BIN}/lefthook_calls.log" 2>/dev/null)"

# 16. lefthook install is NOT called when lefthookInstall=false
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "false" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" LEFTHOOK_CMD=lefthook >/dev/null 2>&1
test ! -f "${TEST_BIN}/lefthook_calls.log" &&
	pass "lefthook: lefthook install skipped when lefthookInstall=false" ||
	fail "lefthook: lefthook install skipped when lefthookInstall=false" "calls: $(cat "${TEST_BIN}/lefthook_calls.log" 2>/dev/null)"

# 17. lefthook warns when lefthook not found but lefthookInstall=true
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "true" "false")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" LEFTHOOK_CMD="__no_lefthook_here__" 2>&1)
echo "$out" | grep -q "WARNING" &&
	pass "lefthook: WARNING printed when lefthook not found" ||
	fail "lefthook: WARNING printed when lefthook not found" "output: $out"

# 18. direnv allow is called when direnvAllow=true
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "false" "true")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" DIRENV_CMD=direnv >/dev/null 2>&1
grep -q "allow" "${TEST_BIN}/direnv_calls.log" &&
	pass "direnv: direnv allow called when direnvAllow=true" ||
	fail "direnv: direnv allow called when direnvAllow=true" "calls: $(cat "${TEST_BIN}/direnv_calls.log" 2>/dev/null)"

# 19. direnv allow is NOT called when direnvAllow=false
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "false" "false")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" DIRENV_CMD=direnv >/dev/null 2>&1
test ! -f "${TEST_BIN}/direnv_calls.log" &&
	pass "direnv: direnv allow skipped when direnvAllow=false" ||
	fail "direnv: direnv allow skipped when direnvAllow=false" "calls: $(cat "${TEST_BIN}/direnv_calls.log" 2>/dev/null)"

# 20. direnv warns when direnv not found but direnvAllow=true
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "false" "true")
out=$(run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" DIRENV_CMD="__no_direnv_here__" 2>&1)
echo "$out" | grep -q "WARNING" &&
	pass "direnv: WARNING printed when direnv not found" ||
	fail "direnv: WARNING printed when direnv not found" "output: $out"

# 21. Script continues (exit 0) when pnpm install fails
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
# Override pnpm to fail
cat >"${TEST_BIN}/pnpm" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/pnpm"
WS=$(new_tmp)
mkdir -p "${WS}/ui"
touch "${WS}/ui/package.json"
CFG=$(make_config "ui" "" "" "false" "false")
rc=0
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" PNPM_CMD=pnpm >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "graceful: script exits 0 when pnpm install fails" ||
	fail "graceful: script exits 0 when pnpm install fails" "exit code was $rc"

# 22. Script continues (exit 0) when uv sync fails
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
cat >"${TEST_BIN}/uv" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/uv"
WS=$(new_tmp)
mkdir -p "${WS}/backend"
touch "${WS}/backend/pyproject.toml"
CFG=$(make_config "" "backend" "" "false" "false")
rc=0
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" UV_CMD=uv >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "graceful: script exits 0 when uv sync fails" ||
	fail "graceful: script exits 0 when uv sync fails" "exit code was $rc"

# 23. Script continues (exit 0) when lefthook install fails
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
cat >"${TEST_BIN}/lefthook" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/lefthook"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "true" "false")
rc=0
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" LEFTHOOK_CMD=lefthook >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "graceful: script exits 0 when lefthook install fails" ||
	fail "graceful: script exits 0 when lefthook install fails" "exit code was $rc"

# 24. Script continues (exit 0) when direnv allow fails
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
cat >"${TEST_BIN}/direnv" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/direnv"
WS=$(new_tmp)
CFG=$(make_config "" "" "" "false" "true")
rc=0
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" DIRENV_CMD=direnv >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "graceful: script exits 0 when direnv allow fails" ||
	fail "graceful: script exits 0 when direnv allow fails" "exit code was $rc"

# 25. All steps run together in a combined scenario
TEST_BIN=$(new_tmp)
make_post_create_mock_bin "$TEST_BIN"
WS=$(new_tmp)
mkdir -p "${WS}/ui" "${WS}/backend"
touch "${WS}/ui/package.json" "${WS}/backend/pyproject.toml"
echo "KEY=val" >"${WS}/.env.example"
CFG=$(make_config "ui" "backend" ".env.example:.env" "true" "true")
run_post_create "$TEST_BIN" "$WS" PROJECT_SETUP_CONFIG_FILE="$CFG" \
	PNPM_CMD=pnpm UV_CMD=uv LEFTHOOK_CMD=lefthook DIRENV_CMD=direnv >/dev/null 2>&1
grep -q "install" "${TEST_BIN}/pnpm_calls.log" &&
	pass "combined: pnpm install called" ||
	fail "combined: pnpm install called" "pnpm_calls: $(cat "${TEST_BIN}/pnpm_calls.log" 2>/dev/null)"
grep -q "sync" "${TEST_BIN}/uv_calls.log" &&
	pass "combined: uv sync called" ||
	fail "combined: uv sync called" "uv_calls: $(cat "${TEST_BIN}/uv_calls.log" 2>/dev/null)"
test -f "${WS}/.env" &&
	pass "combined: .env created from .env.example" ||
	fail "combined: .env created from .env.example" ".env not found"
grep -q "install" "${TEST_BIN}/lefthook_calls.log" &&
	pass "combined: lefthook install called" ||
	fail "combined: lefthook install called" "lefthook_calls: $(cat "${TEST_BIN}/lefthook_calls.log" 2>/dev/null)"
grep -q "allow" "${TEST_BIN}/direnv_calls.log" &&
	pass "combined: direnv allow called" ||
	fail "combined: direnv allow called" "direnv_calls: $(cat "${TEST_BIN}/direnv_calls.log" 2>/dev/null)"

summary
