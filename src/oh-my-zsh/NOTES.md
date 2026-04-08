## Custom shell snippets — use `extraRcFile`

The `extraRcFile` option is the correct way to inject arbitrary shell code into `.zshrc`. Point it at a file in your repo:

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

The file is sourced at **runtime** (when a new shell session starts), so command substitutions like `$(direnv hook zsh)` run inside the fully-configured container where all tools are available.

### Why not inline snippets?

The devcontainer CLI passes feature option values to the install script through an unquoted shell env file. Any shell metacharacters in an inline string option — including `$(…)`, `>`, `&&`, and whitespace — are evaluated by the shell at **build time**, before the container tools are installed. This causes builds to fail with errors like:

```
direnv: not found
exit code: 127
```

Using `extraRcFile` avoids this entirely: the feature stores only a **file path** (safe, no metacharacters) in the env file, and the file's contents are sourced at runtime.
