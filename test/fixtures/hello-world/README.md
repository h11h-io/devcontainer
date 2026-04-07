# hello-world fixture

This is a minimal Next.js app used for local devcontainer feature simulation.

## Included files

- `.devcontainer/devcontainer.json`: simulator-friendly feature set
- `.devcontainer/devcontainer.with-docker.json`: profile that includes Docker-in-Docker for parity with real devcontainers
- `devbox.json`: minimal Devbox config (`jq@latest`) so `devbox install` is exercised

## App behavior

Running `npm run dev` serves a page containing `Hello World` at `http://localhost:3000`.
