#!/bin/bash
set -e
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "zsh-autosuggestions is NOT cloned" test ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
check ".zshrc contains 'git sudo'" grep -q 'git sudo' "${HOME}/.zshrc"
check "ZSH_THEME is 'clean'" grep -q 'ZSH_THEME="clean"' "${HOME}/.zshrc"

reportResults
