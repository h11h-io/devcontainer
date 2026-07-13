
# Devbox (devbox)

Installs Devbox by Jetify — a Nix-based isolated development environment tool. Optionally installs project packages during container creation, exports Devbox profile paths into login shells, and keeps nix-daemon available across container starts.

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
| installProjectPackages | When true, run 'devbox install' during onCreate. Set false when the repository's postCreateCommand already uses 'devbox run setup' so packages are resolved only once. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/devbox/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
