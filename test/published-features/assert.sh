#!/bin/bash
set -euo pipefail

assert_command() {
	local command_name="$1"
	command -v "$command_name" >/dev/null
	printf 'ok - %s is available\n' "$command_name"
}

assert_path() {
	local description="$1"
	local path="$2"
	test -e "$path"
	printf 'ok - %s\n' "$description"
}

assert_executable() {
	local description="$1"
	local path="$2"
	test -x "$path"
	printf 'ok - %s\n' "$description"
}

assert_command devbox
assert_command git
assert_command zsh

devbox version
git --version
zsh --version

assert_executable "Git identity helper is executable" "/usr/local/bin/configure-git-identity"
assert_executable "Devbox lifecycle helper is executable" "/usr/local/bin/devbox-on-create"
assert_path "Oh My Zsh is installed globally" "/usr/local/share/oh-my-zsh"
assert_path "managed zsh configuration exists" "${HOME}/.zshrc"
grep -q 'managed by oh-my-zsh devcontainer feature' "${HOME}/.zshrc"
printf 'ok - zsh configuration is managed by the published feature\n'

printf 'Published feature smoke test passed.\n'
