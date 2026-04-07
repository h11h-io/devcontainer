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

**`No workspace found in /workspaces/`** — make sure you ran the `docker run` command from inside your project directory.

**Feature install failed** — the container drops to a shell anyway so you can inspect what went wrong. Check that your `devcontainer.json` is valid JSON and your feature key maps to a local feature in `src/`.

**Feature image not found** — features are published to GHCR. Make sure Docker can reach the internet, or check `ghcr.io/h11h-io/devcontainer` for available tags.
