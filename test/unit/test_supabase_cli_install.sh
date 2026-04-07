#!/bin/bash
# shellcheck disable=SC2015  # A && pass || fail is safe: pass/fail always exit 0
# Unit tests for src/supabase-cli/install.sh and supabase-post-start.sh
#
# Uses mocked docker, curl, tar, uname, supabase to avoid network/root.
#
# Usage:  bash test/unit/test_supabase_cli_install.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="${REPO_ROOT}/src/supabase-cli/install.sh"
POST_START_SCRIPT="${REPO_ROOT}/src/supabase-cli/supabase-post-start.sh"

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

# make_mock_bin <dir>
# Populates a mock bin dir with docker, curl, tar, uname, supabase, install, sed
make_mock_bin() {
	local d="$1"
	local curl_log="${d}/curl_calls.log"
	mkdir -p "$d"

	# docker mock: present and working
	cat >"$d/docker" <<'EOF'
#!/bin/sh
echo "mock docker $*"
EOF
	chmod +x "$d/docker"

	# curl mock: record URL
	cat >"$d/curl" <<EOF
#!/bin/sh
echo "\$@" >> "${curl_log}"
# write a fake tarball name to stdout (pipe target expects tar to consume it)
printf 'fake-tarball-content'
EOF
	chmod +x "$d/curl"

	# tar mock: record call, create the supabase binary in /usr/local/bin (or wherever)
	cat >"$d/tar" <<EOF
#!/bin/sh
echo "\$@" >> "${d}/tar_calls.log"
# parse -C <dir> from args and create a fake supabase binary there
dir="/usr/local/bin"
while [ \$# -gt 0 ]; do
	case "\$1" in
	-C) dir="\$2"; shift 2 ;;
	*) shift ;;
	esac
done
touch "\${dir}/supabase" 2>/dev/null || true
EOF
	chmod +x "$d/tar"

	# uname mock: default to x86_64
	cat >"$d/uname" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-m" ]; then echo "x86_64"; else /bin/uname "$@"; fi
EOF
	chmod +x "$d/uname"

	# supabase mock: already installed at a specific version
	cat >"$d/supabase" <<'EOF'
#!/bin/sh
case "${1:-}" in
	--version) echo "2.0.0" ;;
	start) echo "mock supabase start" ;;
	stop) echo "mock supabase stop" ;;
	*) echo "mock supabase $*" ;;
esac
EOF
	chmod +x "$d/supabase"

	# install mock: non-root, copies to mock bin dir
	cat >"$d/install" <<EOF
#!/bin/sh
src=""
dst=""
skip_next=false
for arg in "\$@"; do
	case "\$arg" in
	-o | -g | -m) skip_next=true ;;
	*)
		if \$skip_next; then skip_next=false; continue; fi
		if [ -z "\$src" ]; then src="\$arg"; else dst="\$arg"; fi
		;;
	esac
done
if [ -n "\$src" ] && [ -n "\$dst" ]; then
	real_dst="${d}/\$(basename "\$dst")"
	cp "\$src" "\$real_dst" && chmod +x "\$real_dst"
fi
exit 0
EOF
	chmod +x "$d/install"

	# sed mock: record call, succeed
	cat >"$d/sed" <<EOF
#!/bin/sh
echo "\$@" >> "${d}/sed_calls.log"
exit 0
EOF
	chmod +x "$d/sed"
}

echo ""
echo "=== supabase-cli/install.sh unit tests ==="
echo ""

# 1. Fails when docker is not available
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
rm -f "${TEST_BIN}/docker"
out=$(PATH="$TEST_BIN:$PATH" VERSION="2.84.2" DOCKERWAITSECONDS="30" sh "$INSTALL_SCRIPT" 2>&1) && rc=0 || rc=$?
[ "$rc" -ne 0 ] &&
	pass "no-docker: exits non-zero when docker unavailable" ||
	fail "no-docker: exits non-zero when docker unavailable" "exit code was 0"
echo "$out" | grep -q "ERROR" &&
	pass "no-docker: prints ERROR message" ||
	fail "no-docker: prints ERROR message" "output: $out"

# 2. Completes successfully with all mocks present (smoke test)
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="2.84.2" DOCKERWAITSECONDS="30" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" -eq 0 ] &&
	pass "smoke: install exits 0 with all mocks present" ||
	fail "smoke: install exits 0 with all mocks present" "exit code was $rc"

# 3. Constructs correct URL for x86_64
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
PATH="$TEST_BIN:$PATH" VERSION="2.84.2" DOCKERWAITSECONDS="30" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 || true
grep -q "linux_amd64" "${TEST_BIN}/curl_calls.log" &&
	pass "arch-amd64: URL contains linux_amd64" ||
	fail "arch-amd64: URL contains linux_amd64" "curl log: $(cat "${TEST_BIN}/curl_calls.log" 2>/dev/null)"

# 4. Constructs correct URL for aarch64
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
cat >"${TEST_BIN}/uname" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-m" ]; then echo "aarch64"; else /bin/uname "$@"; fi
EOF
chmod +x "${TEST_BIN}/uname"
PATH="$TEST_BIN:$PATH" VERSION="2.84.2" DOCKERWAITSECONDS="30" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 || true
grep -q "linux_arm64" "${TEST_BIN}/curl_calls.log" &&
	pass "arch-arm64: URL contains linux_arm64" ||
	fail "arch-arm64: URL contains linux_arm64" "curl log: $(cat "${TEST_BIN}/curl_calls.log" 2>/dev/null)"

# 5. Fails on unsupported architecture
TEST_BIN=$(new_tmp)
make_mock_bin "$TEST_BIN"
cat >"${TEST_BIN}/uname" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-m" ]; then echo "riscv64"; else /bin/uname "$@"; fi
EOF
chmod +x "${TEST_BIN}/uname"
PATH="$TEST_BIN:$PATH" VERSION="2.84.2" DOCKERWAITSECONDS="30" sh "$INSTALL_SCRIPT" >/dev/null 2>&1 && rc=0 || rc=$?
[ "$rc" -ne 0 ] &&
	pass "unsupported-arch: exits non-zero on unsupported architecture" ||
	fail "unsupported-arch: exits non-zero on unsupported architecture" "exit code was 0"

echo ""
echo "=== supabase-post-start.sh unit tests ==="
echo ""

# Helper to make post-start mock bin
make_post_start_mock() {
	local d="$1"
	mkdir -p "$d"
	cat >"$d/docker" <<'EOF'
#!/bin/sh
case "${1:-}" in
	info) echo "mock docker info"; exit 0 ;;
	*) echo "mock docker $*" ;;
esac
EOF
	chmod +x "$d/docker"
	cat >"$d/supabase" <<'EOF'
#!/bin/sh
case "${1:-}" in
	start) echo "mock supabase start" ;;
	stop) echo "mock supabase stop" ;;
	*) echo "mock supabase $*" ;;
esac
EOF
	chmod +x "$d/supabase"
	cat >"$d/seq" <<'EOF'
#!/bin/sh
i=1; while [ "$i" -le "${1:-1}" ]; do echo "$i"; i=$((i + 1)); done
EOF
	chmod +x "$d/seq"
}

# 6. Skips when marker file exists
TEST_BIN=$(new_tmp)
make_post_start_mock "$TEST_BIN"
TEST_HOME=$(new_tmp)
mkdir -p "${TEST_HOME}/.cache/devcontainer"
touch "${TEST_HOME}/.cache/devcontainer/supabase-prepull.done"
out=$(HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" containerWorkspaceFolder="$TEST_HOME" \
	bash "$POST_START_SCRIPT" 2>&1)
echo "$out" | grep -q "already completed" &&
	pass "marker-exists: skips when marker present" ||
	fail "marker-exists: skips when marker present" "output: $out"

# 7. Skips when supabase CLI not found
TEST_BIN=$(new_tmp)
make_post_start_mock "$TEST_BIN"
rm -f "${TEST_BIN}/supabase"
TEST_HOME=$(new_tmp)
out=$(HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" containerWorkspaceFolder="$TEST_HOME" \
	bash "$POST_START_SCRIPT" 2>&1)
echo "$out" | grep -q "not found" &&
	pass "no-supabase: skips when supabase CLI not found" ||
	fail "no-supabase: skips when supabase CLI not found" "output: $out"

# 8. Skips when Docker not ready after timeout
TEST_BIN=$(new_tmp)
make_post_start_mock "$TEST_BIN"
cat >"${TEST_BIN}/docker" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/docker"
TEST_HOME=$(new_tmp)
# Use SUPABASE_DOCKER_WAIT_SECONDS=1 to avoid waiting 30s in the test
out=$(HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" containerWorkspaceFolder="$TEST_HOME" \
	SUPABASE_DOCKER_WAIT_SECONDS=1 bash "$POST_START_SCRIPT" 2>&1)
echo "$out" | grep -q "not reachable" &&
	pass "docker-timeout: reports timeout when Docker not ready" ||
	fail "docker-timeout: reports timeout when Docker not ready" "output: $out"
test ! -f "${TEST_HOME}/.cache/devcontainer/supabase-prepull.done" &&
	pass "docker-timeout: marker NOT created when Docker not ready" ||
	fail "docker-timeout: marker NOT created when Docker not ready" "marker file exists"

# 9. Creates marker after successful pre-pull
TEST_BIN=$(new_tmp)
make_post_start_mock "$TEST_BIN"
TEST_HOME=$(new_tmp)
SUPABASE_DOCKER_WAIT_SECONDS=2 HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" \
	containerWorkspaceFolder="$TEST_HOME" bash "$POST_START_SCRIPT" >/dev/null 2>&1
test -f "${TEST_HOME}/.cache/devcontainer/supabase-prepull.done" &&
	pass "success: marker created after successful pre-pull" ||
	fail "success: marker created after successful pre-pull" "marker file missing"

# 10. Does NOT create marker after failed pre-pull
TEST_BIN=$(new_tmp)
make_post_start_mock "$TEST_BIN"
cat >"${TEST_BIN}/supabase" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "${TEST_BIN}/supabase"
TEST_HOME=$(new_tmp)
SUPABASE_DOCKER_WAIT_SECONDS=2 HOME="$TEST_HOME" PATH="$TEST_BIN:$PATH" \
	containerWorkspaceFolder="$TEST_HOME" bash "$POST_START_SCRIPT" >/dev/null 2>&1 || true
test ! -f "${TEST_HOME}/.cache/devcontainer/supabase-prepull.done" &&
	pass "failure: marker NOT created after failed pre-pull" ||
	fail "failure: marker NOT created after failed pre-pull" "marker file should not exist"

summary
