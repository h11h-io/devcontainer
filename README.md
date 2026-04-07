# h11h-io/devcontainer

> **For AI coding agents:** see [`AGENT-INSTRUCTIONS.md`](AGENT-INSTRUCTIONS.md) for a structured reference.

Reusable [devcontainer features](https://containers.dev/features) published to GHCR. Add any of these features to your `devcontainer.json` to get a fully-configured development environment out of the box.

## Available Features

| Feature | GHCR Reference | Description |
|---------|---------------|-------------|
| [Git Identity from GitHub](#git-identity-from-github) | `ghcr.io/h11h-io/devcontainer/git-identity-from-github:1` | Auto-configures `git user.name` / `user.email` from your GitHub account |
| [Devbox](#devbox) | `ghcr.io/h11h-io/devcontainer/devbox:1` | Installs [Devbox](https://www.jetify.com/devbox) and runs `devbox install` on container creation |
| [Oh My Zsh](#oh-my-zsh) | `ghcr.io/h11h-io/devcontainer/oh-my-zsh:1` | Installs zsh, Oh My Zsh, and a configurable set of plugins and themes |
| [Supabase CLI](#supabase-cli) | `ghcr.io/h11h-io/devcontainer/supabase-cli:1` | Installs the Supabase CLI with Docker image pre-pull |
| [Coder CLI](#coder) | `ghcr.io/h11h-io/devcontainer/coder:1` | Installs the [Coder](https://coder.com) CLI |

---

## Git Identity from GitHub

Automatically sets `git config --global user.name` and `git config --global user.email` by fetching the authenticated user's profile from the GitHub API at container start time. Works with:

- **GitHub Codespaces** (`GITHUB_TOKEN`)
- **Coder** (external auth)
- **gh CLI** fallback

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/git-identity-from-github:1": {}
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `overwrite` | `boolean` | `false` | If `true`, re-configure git identity even if already set |

### How it works

- **Build time (`install.sh`)**: installs `curl`, `jq`, and the `configure-git-identity` helper script to `/usr/local/bin/`.
- **Container start (`postStartCommand`)**: runs `configure-git-identity`, which probes for a GitHub token (Codespaces → Coder → gh CLI), calls the GitHub API, and configures git. If no token is found or the API call fails, a warning is printed but the container starts normally.

---

## Devbox

Installs [Devbox by Jetify](https://www.jetify.com/devbox) — a Nix-based tool for reproducible, isolated development environments. On container creation, it runs `devbox install` and exports the project's Nix profile so all devbox-managed tools are available in every shell without `devbox run`.

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/devbox:1": {}
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | `string` | `"latest"` | Devbox version to install |

### How it works

- **Build time (`install.sh`)**: downloads and installs the Devbox CLI using the official Jetify installer. Installs the `devbox-on-create` helper to `/usr/local/bin/`.
- **Container creation (`onCreateCommand`)**: runs `devbox-on-create`, which:
  1. Runs `devbox install` in the workspace (if `devbox.json` is present).
  2. Idempotently adds the project's `.devbox/nix/profile/default/bin` to `$PATH` in both `~/.zshrc` and `~/.bashrc`.

---

## Oh My Zsh

Installs zsh, [Oh My Zsh](https://ohmyz.sh/), and a configurable set of plugins and themes. External plugins are cloned automatically. Writes a managed `.zshrc` and sets zsh as the default shell.

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {}
  }
}
```

### Default plugins

When no `plugins` option is specified, these are included:

| Plugin | Type | Description |
|--------|------|-------------|
| `git` | built-in | Git aliases and helpers |
| `sudo` | built-in | Press `Esc` twice to prefix with `sudo` |
| `z` | built-in | Directory jumping |
| `history` | built-in | History search helpers |
| `colored-man-pages` | built-in | Coloured man pages |
| `zsh-autosuggestions` | external | Fish-like autosuggestions |
| `zsh-syntax-highlighting` | external | Syntax highlighting at the prompt |
| `pnpm` | external | pnpm completions |

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `plugins` | `string` | `"git sudo z history colored-man-pages zsh-autosuggestions zsh-syntax-highlighting pnpm"` | Space-separated list of plugins. **Completely replaces** the defaults when specified. |
| `theme` | `string` | `"robbyrussell"` | Oh My Zsh theme name |

### Supported external plugins

These are recognised by name and cloned from GitHub automatically:

- `zsh-autosuggestions` → [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- `zsh-syntax-highlighting` → [zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- `zsh-completions` → [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions)
- `zsh-history-substring-search` → [zsh-users/zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search)
- `pnpm` → [ntnyq/omz-plugin-pnpm](https://github.com/ntnyq/omz-plugin-pnpm)

---

## Supabase CLI

Installs the [Supabase CLI](https://supabase.com/docs/guides/cli). **Requires Docker** — add the `docker-in-docker` or `docker-outside-of-docker` feature before this one. Pre-pulls Supabase Docker images on first container start so `supabase start` is fast later.

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/h11h-io/devcontainer/supabase-cli:1": {}
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | `string` | `"2.84.2"` | Supabase CLI version (must match a GitHub release tag) |
| `dockerWaitSeconds` | `string` | `"30"` | Seconds to wait for Docker daemon readiness before pre-pulling images |

### How it works

- **Build time (`install.sh`)**: downloads the arch-aware tarball from GitHub releases. Fails if Docker is not available (hard dependency).
- **Container start (`postStartCommand`)**: runs `supabase-post-start`, which:
  1. Checks for a marker file — skips if images were already pulled.
  2. Waits for Docker to become ready (configurable timeout).
  3. Runs `supabase start && supabase stop` to pull all required images.
  4. Creates a marker file so subsequent starts are instant.

---

## Coder CLI

Installs the [Coder CLI](https://coder.com) for interacting with Coder workspaces.

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/coder:1": {}
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | `string` | `"latest"` | Coder CLI version (or `"latest"`) |

### How it works

- **Build time (`install.sh`)**: downloads and runs the official Coder installer. If the installation fails, a warning is printed but the build continues.

---

## Combining Features

Here's an example `devcontainer.json` that uses all features together:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/h11h-io/devcontainer/git-identity-from-github:1": {},
    "ghcr.io/h11h-io/devcontainer/devbox:1": {},
    "ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {
      "theme": "agnoster",
      "plugins": "git sudo z zsh-autosuggestions zsh-syntax-highlighting"
    },
    "ghcr.io/h11h-io/devcontainer/supabase-cli:1": {
      "version": "2.84.2"
    },
    "ghcr.io/h11h-io/devcontainer/coder:1": {}
  }
}
```

---

## Local Development

### Simulating a devcontainer locally

Build and run the simulation Dockerfile, which mounts your repo into `/workspaces/<repo>`, runs the devcontainer CLI, and drops you into a shell:

```bash
docker build -t devcontainer-sim .
docker run --rm -it \
  -v "$(pwd):/workspaces/$(basename $(pwd))" \
  devcontainer-sim
```

### Running unit tests (no Docker required)

```bash
bash test/unit/test_git_identity.sh
bash test/unit/test_devbox_install.sh
bash test/unit/test_oh_my_zsh_install.sh
bash test/unit/test_supabase_cli_install.sh
bash test/unit/test_coder_install.sh
```

### Linting

```bash
find . -not -path './.git/*' -name '*.sh' -print0 | xargs -0 shellcheck --severity=warning
find . -not -path './.git/*' -name '*.sh' -print0 | xargs -0 shfmt --diff
```

### Integration tests (requires Docker + devcontainer CLI)

```bash
npm install -g @devcontainers/cli
devcontainer features test --skip-scenarios -f <feature-name> -i mcr.microsoft.com/devcontainers/base:ubuntu-22.04 .
devcontainer features test --skip-autogenerated --skip-duplicated -f <feature-name> .
```

---

## CI / CD

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `lint.yml` | PR, push to main | shellcheck, shfmt, JSON validation |
| `test.yml` | PR, push to main | Unit tests + integration tests (matrix) |
| `release.yaml` | Push to main | Gates on lint + unit tests, then publishes changed features to GHCR |

Features are only published when their source files have actually changed in the triggering commit(s).

## License

[MIT](LICENSE)
