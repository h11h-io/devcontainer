# Local Testing with Docker

Test any feature against a real repository on your machine — no cloud, no VS Code required.

**Prerequisite:** Docker is installed and running.

---

## 1. Build the simulation image

Run this once from the root of this repository:

```bash
docker build -t devcontainer-sim .
```

---

## 2. Add a `.devcontainer/devcontainer.json` to your project

Inside the repository you want to test, create `.devcontainer/devcontainer.json` and add whichever features you want to try. Example:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "features": {
    "ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {},
    "ghcr.io/h11h-io/devcontainer/coder:1": {}
  }
}
```

> **Tip:** You can also test this repository's own `.devcontainer/devcontainer.json` by running from here.

### Optional: use the built-in hello-world fixture

This repository includes a reusable fixture at `test/fixtures/hello-world` with:

- A minimal Next.js app that serves `Hello World`
- `devbox.json` to exercise the Devbox feature
- `.devcontainer/devcontainer.json` using all local features
- `.devcontainer/devcontainer.with-docker.json` for Docker-in-Docker parity

From the repo root:

```bash
cd test/fixtures/hello-world
```

If you want to test the Docker-in-Docker profile instead, swap it in temporarily:

```bash
cp .devcontainer/devcontainer.with-docker.json .devcontainer/devcontainer.json
```

---

## 3. Run the container with your project mounted

From inside your project directory:

```bash
docker run --rm -it \
  -v "$(pwd):/workspaces/$(basename $(pwd))" \
  devcontainer-sim
```

From the devcontainer repo root, using the built-in fixture directly:

```bash
docker run --rm -it \
  -v "$(pwd)/test/fixtures/hello-world:/workspaces/hello-world" \
  devcontainer-sim
```

The container will:
1. Find your mounted project under `/workspaces/`
2. Read your `.devcontainer/devcontainer.json`
3. Run local feature installers from this repository's `src/` directory for matching feature IDs
4. Run feature lifecycle hooks (`onCreateCommand`, `postStartCommand`) when declared
5. Drop you into a shell so you can poke around

---

## 4. Verify everything worked

Inside the shell, check whatever the feature installs. For example:

```bash
# git-identity-from-github
git config --global user.name
git config --global user.email

# oh-my-zsh
which zsh
cat ~/.zshrc

# devbox
devbox version

# supabase-cli
supabase --version

# coder
coder version
```

Type `exit` when you're done. The container is discarded automatically (`--rm`).

---

## Troubleshooting
---

## Running Unit Tests

Unit tests exercise each feature's install script in isolation using shell mocks (no network, no root, no real installs).

```bash
# Run all unit tests at once
for f in test/unit/test_*.sh; do bash "$f"; done

# Run a specific feature's tests
bash test/unit/test_devbox_install.sh
bash test/unit/test_supabase_cli_install.sh
bash test/unit/test_git_identity.sh
bash test/unit/test_oh_my_zsh_install.sh
bash test/unit/test_coder_install.sh
```

### How mocks work

Each test creates a temporary directory (`TEST_BIN`) populated with mock executables that record calls and return
predictable output. `PATH="$TEST_BIN:$PATH"` is set before calling the installer so mocks shadow real tools.

Key mock patterns:
- **`curl` mock** — records the URL to a log file; emits a no-op installer script
- **`chmod` mock** — no-ops when the target path doesn't exist (e.g. `/usr/local/bin/devbox` in a clean env); delegates to real `chmod` for existing files
- **`install` mock** — copies src to `$TEST_BIN/$(basename $dst)` for inspection
- **`DOCKER_CMD="__no_docker_here__"`** — simulates Docker being absent for supabase-cli tests
- **`coder` / `gh` mocks (exit 1)** — prevent fallback token acquisition in git-identity no-token tests

---

## Integration Tests (devcontainer features test)

Integration tests build a real Docker image with the feature installed and verify the results.
Requires Docker to be running. Uses the [devcontainer CLI](https://github.com/devcontainers/cli).

```bash
# Install the CLI if needed
npm install -g @devcontainers/cli

# Test a single feature
devcontainer features test \
  --skip-scenarios \
  -f devbox \
  -i mcr.microsoft.com/devcontainers/base:ubuntu-22.04 \
  .

# Replace 'devbox' with any of: devbox, oh-my-zsh, supabase-cli, coder, git-identity-from-github
```

Test assertions for each feature live in `test/<feature-name>/test.sh`.

### DinD / privileged mode

If you need to test features that require Docker inside the container (e.g. `supabase-cli`), note that
`devcontainer features test` does **not** run containers in privileged mode. The supabase-cli integration
test handles this gracefully: the CLI is installed regardless, but the postStartCommand will warn if Docker
is unavailable and retry on the next container start.

---

## CI Simulation with act

Run the GitHub Actions workflows locally using [act](https://github.com/nektos/act).

```bash
# Lint (shellcheck + shfmt + JSON validation)
act push --workflows .github/workflows/lint.yml

# Unit tests
act push --workflows .github/workflows/test.yml --job unit-tests
```

The act configuration at `/root/.config/act/actrc` points to 
`catthehacker/ubuntu` medium images which are required for shell-based workflows.

> **Note:** Integration tests cannot run reliably through act because Docker-in-Docker
> requires privileged containers, and act's bind-mount paths are not resolvable from
> inside the inner Docker daemon. Run integration tests directly (see section above).

---


**`No workspace found in /workspaces/`** — make sure you ran the `docker run` command from inside your project directory.

**Feature install failed** — the container drops to a shell anyway so you can inspect what went wrong. Check that your `devcontainer.json` is valid JSON and your feature key maps to a local feature in `src/`.

**Feature image not found** — features are published to GHCR. Make sure Docker can reach the internet, or check `ghcr.io/h11h-io/devcontainer` for available tags.
