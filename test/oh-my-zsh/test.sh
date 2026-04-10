#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "zsh is installed" command -v zsh
check "git is installed" command -v git
check "oh-my-zsh installed at global location" test -d "/usr/local/share/oh-my-zsh"
check ".zshrc exists" test -f "${HOME}/.zshrc"
check ".zshrc is managed by feature" grep -q 'managed by oh-my-zsh devcontainer feature' "${HOME}/.zshrc"
check "global zshrc.d activation file exists" test -f "/etc/zsh/zshrc.d/oh-my-zsh.zsh"
check "zsh-autosuggestions plugin cloned" test -d "/usr/local/share/oh-my-zsh/custom/plugins/zsh-autosuggestions"
check "zsh-syntax-highlighting plugin cloned" test -d "/usr/local/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
check "pnpm plugin cloned" test -d "/usr/local/share/oh-my-zsh/custom/plugins/pnpm"

reportResults
