
# Devbox (devbox)

Installs Devbox by Jetify — a Nix-based isolated development environment tool. Runs 'devbox install' on container creation and exports the project's Nix profile path into login shells so all devbox-managed tools are available without 'devbox run'. On every container start, starts nix-daemon in the background when present (needed for multi-user Nix in devcontainers where systemd doesn't run).

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/devbox:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of Devbox to install. Use 'latest' for the most recent release. | string | latest |
| exportGlobalProfile | When true (default), also exports the global devbox Nix profile (~/.local/share/devbox/global/…/bin) into login shells so globally-installed devbox packages are available everywhere. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/devbox/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
