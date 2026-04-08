
# Userspace Package Homes (userspace-pkg-homes)

Configures writable userspace directories for global package installs (pnpm, pipx, npm). Ensures global installs default to stable, writable locations under the user's home directory.

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/userspace-pkg-homes:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| configurePnpm | Configure PNPM_HOME to ~/.local/share/pnpm and add it to PATH. | boolean | true |
| configurePipx | Configure PIPX_BIN_DIR to ~/.local/bin and add it to PATH. | boolean | true |
| configureNpm | Configure NPM_CONFIG_PREFIX to ~/.npm-global and add its bin directory to PATH. | boolean | false |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/userspace-pkg-homes/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
