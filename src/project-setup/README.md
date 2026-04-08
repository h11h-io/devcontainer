
# Project Setup (project-setup)

Runs project setup tasks on container creation: auto-detected package manager install for Node subdirectories, uv sync for Python subdirectories, copies .env example files, runs lefthook install, and runs direnv allow. Tools must already be available in the container.

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/project-setup:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| nodeSubdirs | Space-separated list of subdirectories containing package.json to run the detected package manager's 'install' command in (relative to the workspace root). The package manager is auto-detected from the 'packageManager' field in package.json, walking up to the workspace root; defaults to npm. | string | - |
| pythonSubdirs | Space-separated list of subdirectories containing pyproject.toml to run 'uv sync' in (relative to the workspace root). | string | - |
| envFiles | Space-separated list of example:target pairs (e.g. 'ui/.env.local.example:ui/.env.local') to copy when the target does not yet exist. | string | - |
| lefthookInstall | Run 'lefthook install' in the workspace root during container creation. Requires lefthook to be available. | boolean | true |
| direnvAllow | Run 'direnv allow .' in the workspace root during container creation. Requires direnv to be available. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/project-setup/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
