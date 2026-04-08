
# Oh My Zsh (oh-my-zsh)

Installs zsh and Oh My Zsh with a configurable set of plugins and theme. External plugins (zsh-autosuggestions, zsh-syntax-highlighting, pnpm, etc.) are cloned automatically. Writes a managed .zshrc and sets zsh as the default shell.

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| plugins | Space-separated list of Oh My Zsh plugins to activate. Built-in plugins are enabled directly; the following external plugins are recognised by name and cloned automatically: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, zsh-history-substring-search, pnpm. If this option is specified, it completely replaces the default list. | string | git sudo z history colored-man-pages zsh-autosuggestions zsh-syntax-highlighting pnpm |
| theme | Oh My Zsh theme name (e.g. 'robbyrussell', 'agnoster', 'clean'). | string | robbyrussell |
| extraRcFile | Path to a shell file (relative to the workspace root, e.g. '.devcontainer/zshrc-extras.sh') that is sourced after 'source oh-my-zsh.sh' in the generated .zshrc. Use this to inject project-specific customizations — NVM sourcing, direnv hooks, PATH additions, autosuggest config, etc. — from a readable, syntax-highlighted file. | string | - |
| autosuggestStyle | Sets ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE if non-empty (e.g. 'fg=60'). Only takes effect when the zsh-autosuggestions plugin is active. | string | - |
| autosuggestStrategy | Sets ZSH_AUTOSUGGEST_STRATEGY if non-empty (e.g. 'history completion'). Only takes effect when the zsh-autosuggestions plugin is active. | string | - |

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


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/oh-my-zsh/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
