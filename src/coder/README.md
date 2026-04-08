
# Coder CLI (coder)

Installs the Coder CLI (https://coder.com). Used to interact with Coder workspaces, including authenticating and managing workspace lifecycle from within a devcontainer.

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/coder:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version to install, or 'latest'. Passed as CODER_VERSION to the official installer script. | string | latest |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/coder/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
