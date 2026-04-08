
# Supabase CLI (supabase-cli)

Installs the Supabase CLI. Docker is required at runtime for 'supabase start' (add docker-in-docker or docker-outside-of-docker for local services) but is NOT required to install the CLI. Pre-pulls Supabase Docker images on first container start via postStartCommand when Docker is available.

## Example Usage

```json
"features": {
    "ghcr.io/h11h-io/devcontainer/supabase-cli:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of the Supabase CLI to install (e.g. '2.84.2'). Must match a tag on the supabase/cli GitHub releases page. | string | 2.84.2 |
| dockerWaitSeconds | Seconds to wait for the Docker daemon to become ready before pre-pulling Supabase images. | string | 30 |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/h11h-io/devcontainer/blob/main/src/supabase-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
