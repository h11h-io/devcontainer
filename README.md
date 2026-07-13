# h11h-io/devcontainer

Reusable Dev Container features published to GHCR. The collection intentionally
keeps only capabilities shared by Foundation repositories.

## Lightweight base

[`examples/base/devcontainer.json`](examples/base/devcontainer.json) is the
canonical configuration for GitHub Codespaces, Coder/envbuilder, and local VS
Code Dev Containers. It provides:

- a Docker CLI connected to the platform daemon;
- GitHub CLI plus automatic Git identity;
- Devbox/Nix for repository-owned tools;
- a small zsh environment.

The repository owns dependency setup through one `devbox run setup` command.

The base uses `docker-outside-of-docker`. Codespaces and local VS Code reuse
their VM/host daemon; Coder templates must expose a Docker socket. Projects
that bind-mount workspace files into child containers must preserve equivalent
host and container paths or avoid those bind mounts.

## Features

| Feature | Reference | Purpose |
|---|---|---|
| Git identity | `ghcr.io/h11h-io/devcontainer/git-identity-from-github:1` | Configure `git user.name` and `user.email` from GitHub authentication. |
| Devbox | `ghcr.io/h11h-io/devcontainer/devbox:1` | Install the Devbox CLI system-wide. |
| Oh My Zsh | `ghcr.io/h11h-io/devcontainer/oh-my-zsh:1` | Install a configurable zsh environment. |

### Git identity

```json
"ghcr.io/h11h-io/devcontainer/git-identity-from-github:1": {}
```

The start hook checks `GITHUB_TOKEN`, an available Coder CLI external-auth
token, and authenticated `gh` CLI state. It leaves an existing identity alone
unless `overwrite` is true and never blocks container startup.

### Devbox

```json
"ghcr.io/h11h-io/devcontainer/devbox:1": {}
```

Options:

| Option | Default | Purpose |
|---|---|---|
| `version` | `latest` | Devbox CLI version. |

The installer promotes Jetify's resolved executable into `/usr/local/bin` so
non-root users do not repeat the launcher download. Repositories own Nix package
installation and PATH setup through their Devbox scripts and devcontainer
configuration.

### Oh My Zsh

```json
"ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {
  "plugins": "git z zsh-autosuggestions zsh-syntax-highlighting"
}
```

The feature installs zsh and Oh My Zsh, writes a managed `.zshrc`, and supports
the `plugins`, `theme`, `extraRcFile`, `autosuggestStyle`, and
`autosuggestStrategy` options.

## Development

```bash
for test_file in test/unit/test_*.sh; do bash "$test_file"; done
shellcheck --severity=warning src/*/*.sh test/unit/*.sh
shfmt --diff src/*/*.sh test/unit/*.sh
devcontainer features test --skip-scenarios -f devbox \
  -i mcr.microsoft.com/devcontainers/base:ubuntu-22.04 .
```

See [`TESTING.md`](TESTING.md) and [`AGENT-INSTRUCTIONS.md`](AGENT-INSTRUCTIONS.md)
for repository conventions.
