# h11h-io/devcontainer

> **For AI coding agents:** see [`AGENT-INSTRUCTIONS.md`](AGENT-INSTRUCTIONS.md) for a structured reference.

Reusable [devcontainer features](https://containers.dev/features) published to GHCR. Add any of these features to your `devcontainer.json` to get a fully-configured development environment out of the box.

## Available Features

| Feature | GHCR Reference | Description |
|---------|---------------|-------------|
| [**h11h Foundation**](#h11h-foundation) | `ghcr.io/h11h-io/devcontainer/h11h-foundation:1` | **Meta feature** — all h11h-io features in one line with sensible defaults |
| [Git Identity from GitHub](#git-identity-from-github) | `ghcr.io/h11h-io/devcontainer/git-identity-from-github:1` | Auto-configures `git user.name` / `user.email` from your GitHub account |
| [Devbox](#devbox) | `ghcr.io/h11h-io/devcontainer/devbox:1` | Installs [Devbox](https://www.jetify.com/devbox) and runs `devbox install` on container creation |
| [Oh My Zsh](#oh-my-zsh) | `ghcr.io/h11h-io/devcontainer/oh-my-zsh:1` | Installs zsh, Oh My Zsh, and a configurable set of plugins and themes |
| [Project Setup](#project-setup) | `ghcr.io/h11h-io/devcontainer/project-setup:1` | Runs project setup tasks on container creation (dependency installs, env files, lefthook, direnv) |
| [Supabase CLI](#supabase-cli) | `ghcr.io/h11h-io/devcontainer/supabase-cli:1` | Installs the Supabase CLI with Docker image pre-pull |
| [Coder CLI](#coder) | `ghcr.io/h11h-io/devcontainer/coder:1` | Installs the [Coder](https://coder.com) CLI |
| [Userspace Package Homes](#userspace-package-homes) | `ghcr.io/h11h-io/devcontainer/userspace-pkg-homes:1` | Configures writable userspace directories for global package installs (pnpm, pipx, npm) |

---

## h11h Foundation

**One feature to rule them all.** Instead of listing every h11h-io feature individually, add a single `h11h-foundation` feature and get everything with sensible defaults. Disable any sub-feature you don't need with the `disable` option.

### Quick start (zero config)

```jsonc
// devcontainer.json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/node:1": { "version": "22" },
    "ghcr.io/h11h-io/devcontainer/h11h-foundation:1": {}
  }
}
```

This installs all seven sub-features with their defaults (inspired by the Trellis project config):

| Sub-feature | Default behaviour |
|-------------|-------------------|
| git-identity-from-github | Auto-configures git identity at start |
| devbox | Installs Devbox CLI, runs `devbox install`, exports global profile |
| oh-my-zsh | Installs zsh + Oh My Zsh with `agnoster` theme and common plugins |
| project-setup | Lefthook install + direnv allow on create |
| supabase-cli | Installs Supabase CLI v2.84.2, waits 60s for Docker |
| coder | Installs the Coder CLI |
| userspace-pkg-homes | Configures PNPM_HOME on PATH |

### Disabling sub-features

Pass a comma-separated list of sub-feature IDs to `disable` to get everything *except* what's listed:

```jsonc
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/h11h-foundation:1": {
      "disable": "supabase-cli,coder"
    }
  }
}
```

Valid IDs: `git-identity-from-github`, `devbox`, `oh-my-zsh`, `project-setup`, `supabase-cli`, `coder`, `userspace-pkg-homes`.

### Customising sub-feature options

Options are passed through to the corresponding sub-feature. Option names are prefixed to avoid collisions where necessary (e.g. three features have a "version" option):

```jsonc
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/h11h-foundation:1": {
      "ohmyzshTheme": "robbyrussell",
      "ohmyzshPlugins": "git sudo z zsh-autosuggestions zsh-syntax-highlighting",
      "devboxVersion": "0.15.0",
      "supabaseVersion": "2.90.0",
      "nodeSubdirs": "ui api",
      "pythonSubdirs": "backend",
      "envFiles": "ui/.env.local.example:ui/.env.local",
      "configurePipx": true
    }
  }
}
```

### All options

| Option | Type | Default | Sub-feature |
|--------|------|---------|-------------|
| `disable` | `string` | `""` | — |
| `gitIdentityOverwrite` | `boolean` | `false` | git-identity-from-github |
| `devboxVersion` | `string` | `"latest"` | devbox |
| `exportGlobalProfile` | `boolean` | `true` | devbox |
| `ohmyzshTheme` | `string` | `"agnoster"` | oh-my-zsh |
| `ohmyzshPlugins` | `string` | `"git sudo z history colored-man-pages docker python node pnpm direnv zsh-autosuggestions zsh-syntax-highlighting"` | oh-my-zsh |
| `extraRcSnippets` | `string` | `""` | oh-my-zsh |
| `extraRcFile` | `string` | `""` | oh-my-zsh |
| `autosuggestStyle` | `string` | `"fg=60"` | oh-my-zsh |
| `autosuggestStrategy` | `string` | `"history completion"` | oh-my-zsh |
| `nodeSubdirs` | `string` | `""` | project-setup |
| `pythonSubdirs` | `string` | `""` | project-setup |
| `envFiles` | `string` | `""` | project-setup |
| `lefthookInstall` | `boolean` | `true` | project-setup |
| `direnvAllow` | `boolean` | `true` | project-setup |
| `supabaseVersion` | `string` | `"2.84.2"` | supabase-cli |
| `dockerWaitSeconds` | `string` | `"60"` | supabase-cli |
| `coderVersion` | `string` | `"latest"` | coder |
| `configurePnpm` | `boolean` | `true` | userspace-pkg-homes |
| `configurePipx` | `boolean` | `false` | userspace-pkg-homes |
| `configureNpm` | `boolean` | `false` | userspace-pkg-homes |

### How it works

- **Build time (`install.sh`)**: parses the `disable` list, then runs each enabled sub-feature's `install.sh` with the appropriate option values mapped to the env vars expected by that sub-feature. Persists the disable list and other config to `/usr/local/share/h11h-foundation/` for use by lifecycle scripts.
- **Container creation (`onCreateCommand`)**: runs `devbox-on-create` (if devbox is enabled).
- **Container creation (`postCreateCommand`)**: runs `project-setup-post-create` (if project-setup is enabled).
- **Container start (`postStartCommand`)**: runs `configure-git-identity`, `devbox-post-start`, and `supabase-post-start` for each enabled sub-feature.

### h11h Foundation vs individual features

Use `h11h-foundation` when you want the full h11h-io stack with minimal boilerplate. Use individual features when you only need one or two specific tools, or when you need to control the installation order between h11h-io features and other third-party features.

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

## Project Setup

Runs common project setup tasks as the `postCreateCommand`, replacing ad-hoc `scripts/setup.sh` patterns with a reusable, declarative feature. Each step is graceful — a failure prints a warning but the container always starts.

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/project-setup:1": {
      "nodeSubdirs": "ui api",
      "pythonSubdirs": "backend",
      "envFiles": "ui/.env.local.example:ui/.env.local",
      "lefthookInstall": true,
      "direnvAllow": true
    }
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nodeSubdirs` | `string` | `""` | Space-separated subdirectories containing `package.json`. Runs the detected package manager's `install` command in each. |
| `pythonSubdirs` | `string` | `""` | Space-separated subdirectories containing `pyproject.toml`. Runs `uv sync` in each. |
| `envFiles` | `string` | `""` | Space-separated `example:target` pairs. Copies the example file to the target path when the target does not yet exist (e.g. `ui/.env.local.example:ui/.env.local`). |
| `lefthookInstall` | `boolean` | `true` | Run `lefthook install` in the workspace root. Requires `lefthook` to be on `PATH`. |
| `direnvAllow` | `boolean` | `true` | Run `direnv allow .` in the workspace root. Requires `direnv` to be on `PATH`. |

### Node package manager detection

For each `nodeSubdirs` entry the feature automatically detects which package manager to use:

1. Reads the `"packageManager"` field from the subdir's own `package.json` (e.g. `"pnpm@10.33.0"` → `pnpm`).
2. If the field is absent, walks up the directory tree toward the workspace root, checking each `package.json` it finds along the way.
3. Falls back to `npm` if no `packageManager` field is found anywhere in the tree.

This means a mono-repo can declare `"packageManager": "pnpm@10.33.0"` once in the root `package.json` and every subdir will automatically use pnpm without any per-subdir configuration.

### Prerequisites

The tools referenced by your options must already be installed in the container image or by an earlier feature. This feature does **not** install them itself.

| Step | Required tool |
|------|--------------|
| Node installs | `npm` / `pnpm` / `yarn` / `bun` (whichever is declared in `package.json`) |
| Python installs | `uv` |
| Git hooks | `lefthook` |
| Directory environment | `direnv` |

If a required tool is not found on `PATH`, the step is skipped with a warning and the remaining steps continue.

### How it works

- **Build time (`install.sh`)**: installs the `project-setup-post-create` helper to `/usr/local/bin/` and bakes the feature option values into `/usr/local/share/project-setup/config.sh`. Options are only available at build time (devcontainer spec), so they must be persisted to disk here.
- **Container creation (`postCreateCommand`)**: runs `project-setup-post-create`, which:
  1. Sources the baked config from `/usr/local/share/project-setup/config.sh`.
  2. For each `nodeSubdirs` entry: detects the package manager, then runs `<pm> install`.
  3. For each `pythonSubdirs` entry: runs `uv sync`.
  4. For each `envFiles` pair: copies the example file to the target if the target does not already exist.
  5. If `lefthookInstall=true`: runs `lefthook install` in the workspace root.
  6. If `direnvAllow=true`: runs `direnv allow .` in the workspace root.

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

## Userspace Package Homes

Configures writable userspace directories for global package installs so tools like [pnpm](https://pnpm.io), [pipx](https://pipx.pypa.io), and [npm](https://docs.npmjs.com/) route global installs to stable, writable locations under the user's home directory instead of immutable system paths (e.g., `/usr/local`).

At build time the feature creates the target directories and sets ownership to `$_REMOTE_USER`. It then injects an idempotent, marker-delimited configuration block into both `~/.bashrc` and `~/.zshrc`. The block exports the relevant environment variables and adds their directories to `$PATH` with per-directory guards to prevent duplicates.

### Usage

```jsonc
// devcontainer.json
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/userspace-pkg-homes:1": {}
  }
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `configurePnpm` | `boolean` | `true` | Set `PNPM_HOME` to `~/.local/share/pnpm` and add it to `PATH` |
| `configurePipx` | `boolean` | `true` | Set `PIPX_BIN_DIR` to `~/.local/bin` and add it to `PATH` |
| `configureNpm` | `boolean` | `false` | Set `NPM_CONFIG_PREFIX` to `~/.npm-global` and add its `bin/` directory to `PATH` |

### How it works

- **Build time (`install.sh`)**:
  1. Creates target directories (`~/.local/share/pnpm`, `~/.local/bin`, `~/.npm-global`) based on selected options.
  2. Sets directory ownership to `$_REMOTE_USER` (only the directories this feature creates — unrelated content under `~/.local` is left untouched).
  3. Injects a managed config block into both `~/.bashrc` and `~/.zshrc`, delimited by marker lines (`# >> userspace-pkg-homes config >>` / `# << userspace-pkg-homes config <<`).
  4. The injection is **idempotent** — re-running replaces any existing block rather than duplicating it.

### Generated shell config (all options enabled)

```bash
# >> userspace-pkg-homes config >>
export PNPM_HOME="${HOME}/.local/share/pnpm"
export PIPX_BIN_DIR="${HOME}/.local/bin"
export NPM_CONFIG_PREFIX="${HOME}/.npm-global"
case ":$PATH:" in
  *":${PNPM_HOME}:"*) ;;
  *) export PATH="${PNPM_HOME}:$PATH" ;;
esac
case ":$PATH:" in
  *":${PIPX_BIN_DIR}:"*) ;;
  *) export PATH="${PIPX_BIN_DIR}:$PATH" ;;
esac
case ":$PATH:" in
  *":${NPM_CONFIG_PREFIX}/bin:"*) ;;
  *) export PATH="${NPM_CONFIG_PREFIX}/bin:$PATH" ;;
esac
# << userspace-pkg-homes config <<
```

### Enabling npm global installs

npm global installs are **disabled by default** because most projects use pnpm or project-local installs. Pass `configureNpm` to enable:

```jsonc
{
  "features": {
    "ghcr.io/h11h-io/devcontainer/userspace-pkg-homes:1": {
      "configureNpm": true
    }
  }
}
```

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
    "ghcr.io/h11h-io/devcontainer/project-setup:1": {
      "nodeSubdirs": "ui api",
      "pythonSubdirs": "backend",
      "envFiles": "ui/.env.local.example:ui/.env.local",
      "lefthookInstall": true,
      "direnvAllow": true
    },
    "ghcr.io/h11h-io/devcontainer/supabase-cli:1": {
      "version": "2.84.2"
    },
    "ghcr.io/h11h-io/devcontainer/coder:1": {},
    "ghcr.io/h11h-io/devcontainer/userspace-pkg-homes:1": {}
  }
}
```

Or equivalently, using `h11h-foundation` for all the h11h-io features in a single line:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/h11h-io/devcontainer/h11h-foundation:1": {
      "ohmyzshPlugins": "git sudo z zsh-autosuggestions zsh-syntax-highlighting",
      "nodeSubdirs": "ui api",
      "pythonSubdirs": "backend",
      "envFiles": "ui/.env.local.example:ui/.env.local"
    }
  }
}
```

---

## Local Development

### Simulating a devcontainer locally

Build and run the simulation Dockerfile, which mounts your repo into `/workspaces/<repo>`, applies matching local features from `src/`, runs lifecycle hooks, and drops you into a shell:

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
bash test/unit/test_project_setup.sh
bash test/unit/test_supabase_cli_install.sh
bash test/unit/test_coder_install.sh
bash test/unit/test_userspace_pkg_homes.sh
bash test/unit/test_h11h_foundation.sh
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
