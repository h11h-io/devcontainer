
# Git Identity from GitHub (git-identity-from-github)

Automatically sets git user.name and user.email from the authenticated GitHub account at container start time. Works with GitHub Codespaces (GITHUB_TOKEN), Coder (external auth), and gh CLI.

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/git-identity-from-github:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| overwrite | If true, overwrite any existing git user.name and user.email configuration. If false (default), skip if identity is already set. | boolean | false |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/git-identity-from-github/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
