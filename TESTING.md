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

## Testing the Nix install prompt fix (devbox-on-create)

The blocking "Press enter to continue" prompt that this feature suppresses only triggers when
devbox detects that its **stdout is a real terminal** (`isatty.IsTerminal(os.Stdout.Fd())`).
Codespaces `onCreateCommand` runs with stdout wired to a PTY, so you need a container with a
PTY allocated (`docker run -it`) to reproduce and verify the fix.

Three options are provided below, ordered from fastest to most complete.

---

### Option A: Run the script directly against local source (fastest, ~10 min)

This approach is the most surgical — it mounts the `devbox-on-create.sh` source directly into
a container so you can test your working copy without a build step.

**Requires:** Docker with `--privileged` support (Docker Desktop on macOS works fine).
`--privileged` is needed because the Nix installer writes to `/nix` and manages system daemons.

```bash
# From the repository root:
docker run --rm -it --privileged \
  -v "$(pwd)/src/devbox/devbox-on-create.sh:/usr/local/bin/devbox-on-create" \
  -v "$(pwd)/test/fixtures/hello-world:/workspaces/hello-world" \
  mcr.microsoft.com/devcontainers/base:ubuntu-22.04 \
  bash -c '
    # Install the devbox CLI (FORCE=1 suppresses the CLI installer's own prompts)
    FORCE=1 curl -fsSL https://get.jetify.com/devbox | bash
    # Run the lifecycle hook — stdout is a TTY here, which is the exact Codespaces condition.
    # A working fix will stream output continuously and never pause for "Press Enter".
    containerWorkspaceFolder=/workspaces/hello-world devbox-on-create
  '
```

**Expected output** — the script runs unattended from start to finish:

```
devbox-on-create: running devbox install in /workspaces/hello-world...
Installing Nix...          ← streams without pausing
...
devbox-on-create: devbox install complete.
devbox-on-create: devbox profile path exported to shell configs.
devbox-on-create: global devbox profile path exported to shell configs.
devbox-on-create: nix-daemon profile sourcing added to shell configs.
```

**Without the fix** you would instead see this and the script would hang indefinitely:

```
Nix is not installed. Devbox will attempt to install it.

Press enter to continue or ctrl-c to exit.
```

---

### Option B: Use the sim image (exercises the full install + lifecycle)

The sim image installs the devbox feature exactly as `devcontainer.json` would, then runs
`onCreateCommand` automatically before dropping you into a shell.

```bash
# Build once from the repo root (re-run after changing src/)
docker build -t devcontainer-sim .

# Run against the built-in hello-world fixture
# --privileged is required for the Nix installer
docker run --rm -it --privileged \
  -v "$(pwd)/test/fixtures/hello-world:/workspaces/hello-world" \
  devcontainer-sim
```

The entrypoint will:
1. Install the devbox feature (runs `src/devbox/install.sh`)
2. Run `devbox-on-create` (the `onCreateCommand`)
3. Drop you into a Bash shell inside the container

Type `exit` when done. The container is discarded automatically.

---

### Option C: devcontainer features test CLI (Mac-friendly, no `--privileged` needed)

If you have the [devcontainer CLI](https://github.com/devcontainers/cli) installed
(`npm install -g @devcontainers/cli`) this is the closest approximation to the actual
Codespaces build pipeline:

```bash
# Test the devbox feature end-to-end
devcontainer features test \
  --skip-scenarios \
  -f devbox \
  -i mcr.microsoft.com/devcontainers/base:ubuntu-22.04 \
  .
```

The CLI builds a real Docker image with the feature installed and runs the assertions in
`test/devbox/test.sh`.

> **Note:** `devcontainer features test` does not run containers in privileged mode, so the
> Nix installer itself may fail. The devbox CLI will still be installed and the test
> assertions that do not depend on an active Nix store will pass. For full end-to-end Nix
> testing, use Option A or B with `--privileged`.

---

## Troubleshooting

**`No workspace found in /workspaces/`** — make sure you ran the `docker run` command from inside your project directory.

**Feature install failed** — the container drops to a shell anyway so you can inspect what went wrong. Check that your `devcontainer.json` is valid JSON and your feature key maps to a local feature in `src/`.

**Feature image not found** — features are published to GHCR. Make sure Docker can reach the internet, or check `ghcr.io/h11h-io/devcontainer` for available tags.
