
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
| extraRcSnippets | Additional shell code appended after 'source oh-my-zsh.sh' in the generated .zshrc. Use this to inject project-specific customizations (NVM sourcing, direnv hooks, autosuggest config, etc.) without a separate post-create script. | string | - |
| extraRcFile | Path to a shell file (relative to the workspace root, e.g. '.devcontainer/zshrc-extras.sh') whose contents are appended to .zshrc after 'source oh-my-zsh.sh'. Use this to keep extra snippets in a readable, syntax-highlighted file instead of a JSON string. If both extraRcSnippets and extraRcFile are provided, snippets are appended first, then the file contents. | string | - |
| autosuggestStyle | Sets ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE if non-empty (e.g. 'fg=60'). Only takes effect when the zsh-autosuggestions plugin is active. | string | - |
| autosuggestStrategy | Sets ZSH_AUTOSUGGEST_STRATEGY if non-empty (e.g. 'history completion'). Only takes effect when the zsh-autosuggestions plugin is active. | string | - |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/oh-my-zsh/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
