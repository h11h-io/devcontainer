#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source dev-container-features-test-lib

assert_overwrites_existing_git_identity() {
	local mock_bin home_dir
	mock_bin="$(mktemp -d)"
	home_dir="$(mktemp -d)"
	# shellcheck disable=SC2064
	trap "rm -rf '${mock_bin}' '${home_dir}'" RETURN

	cat >"${mock_bin}/curl" <<'EOF'
#!/bin/sh
printf '{"login":"newuser","id":99999,"name":"New User","email":"new@example.com"}'
EOF
	chmod +x "${mock_bin}/curl"

	HOME="${home_dir}" PATH="${mock_bin}:${PATH}" GITHUB_TOKEN="mock-token" OVERWRITE="true" \
		git -c user.name="Existing User" -c user.email="existing@example.com" \
		config --global user.name "Existing User"
	HOME="${home_dir}" PATH="${mock_bin}:${PATH}" GITHUB_TOKEN="mock-token" OVERWRITE="true" \
		git config --global user.email "existing@example.com"

	HOME="${home_dir}" PATH="${mock_bin}:${PATH}" GITHUB_TOKEN="mock-token" OVERWRITE="true" \
		/usr/local/bin/configure-git-identity

	actual_name="$(HOME="${home_dir}" git config --global user.name)"
	actual_email="$(HOME="${home_dir}" git config --global user.email)"

	test -n "${actual_name}" &&
		test -n "${actual_email}" &&
		test "${actual_name}" != "Existing User" &&
		test "${actual_email}" != "existing@example.com"
}

check "configure-git-identity script is installed" \
	test -f /usr/local/bin/configure-git-identity
check "configure-git-identity script is executable" \
	test -x /usr/local/bin/configure-git-identity
check "curl is available" command -v curl
check "jq is available" command -v jq
check "overwrite=true replaces an existing git identity" \
	assert_overwrites_existing_git_identity

reportResults
