
# Devbox (devbox)

Installs Devbox by Jetify — a Nix-based isolated development environment tool. Runs 'devbox install' on container creation and exports the project's Nix profile path into login shells so all devbox-managed tools are available without 'devbox run'.

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



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/devbox/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
