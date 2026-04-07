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
    "ghcr.io/h11h-io/devcontainer/git-identity-from-github:1": {},
    "ghcr.io/h11h-io/devcontainer/oh-my-zsh:1": {}
  }
}
```

> **Tip:** You can also test this repository's own `.devcontainer/devcontainer.json` by running from here.

---

## 3. Run the container with your project mounted

From inside your project directory:

```bash
docker run --rm -it \
  -v "$(pwd):/workspaces/$(basename $(pwd))" \
  devcontainer-sim
```

The container will:
1. Find your mounted project under `/workspaces/`
2. Run `devcontainer features install` using your `.devcontainer/devcontainer.json`
3. Drop you into a shell so you can poke around

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

**`devcontainer features install failed`** — the container drops to a shell anyway so you can inspect what went wrong. Check that your `devcontainer.json` is valid JSON and the feature reference is correct.

**Feature image not found** — features are published to GHCR. Make sure Docker can reach the internet, or check `ghcr.io/h11h-io/devcontainer` for available tags.
