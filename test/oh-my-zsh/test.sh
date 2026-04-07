#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "zsh is installed" command -v zsh
check "git is installed" command -v git
check ".oh-my-zsh directory exists" test -d "${HOME}/.oh-my-zsh"
check ".zshrc exists" test -f "${HOME}/.zshrc"
check ".zshrc is managed by feature" grep -q 'managed by oh-my-zsh devcontainer feature' "${HOME}/.zshrc"
check "zsh-autosuggestions plugin cloned" test -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
check "zsh-syntax-highlighting plugin cloned" test -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
check "pnpm plugin cloned" test -d "${HOME}/.oh-my-zsh/custom/plugins/pnpm"

reportResults
