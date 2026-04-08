# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### oh-my-zsh

#### Removed

- **`extraRcSnippets` option** — this option has been removed because it was
  fundamentally broken for any snippet containing shell metacharacters.

  **Why:** The devcontainer CLI writes feature option values into a shell env
  file (`devcontainer-features.env`) *without quoting*. That file is sourced
  by the install wrapper at image build time, so any `$(…)` command
  substitution embedded in an option value is expanded immediately by the
  shell — before container tools are installed. A common pattern such as:

  ```jsonc
  "extraRcSnippets": "command -v direnv >/dev/null 2>&1 && eval \"$(direnv hook zsh)\""
  ```

  caused the build to fail with:

  ```
  ./devcontainer-features-install.sh: 7: ./devcontainer-features.env: direnv: not found
  ERROR: Feature "Oh My Zsh" failed to install
  exit code: 127
  ```

  The `command -v` guard cannot help because `$(direnv hook zsh)` is expanded
  by the shell *before* the guard can be evaluated.

#### Migration

Use `extraRcFile` instead. Point it at a shell file tracked in your repo:

```jsonc
// .devcontainer/devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {
      "extraRcFile": ".devcontainer/zshrc-extras.sh"
    }
  }
}
```

```sh
# .devcontainer/zshrc-extras.sh
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

The file path (not its contents) is what ends up in the env file, so shell
metacharacters are never evaluated at build time. The file is sourced at
**runtime** when a new shell session starts, with all container tools
available.
