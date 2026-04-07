# Dockerfile — local devcontainer simulation
#
# Build:
#   docker build -t devcontainer-sim .
#
# Run (mount your repo):
#   docker run --rm -it -v "$(pwd):/workspaces/$(basename $(pwd))" devcontainer-sim
#
# This image includes local feature implementations from src/, then at runtime
# it reads /workspaces/<repo>/.devcontainer/devcontainer.json and runs matching
# feature installers + lifecycle hooks before dropping into a shell.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
       curl git jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (needed for modern web project checks in the simulator shell)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Provide a minimal Docker CLI shim so features that require `docker` can be
# installed in simulation mode even when no daemon is available in-container.
RUN printf '%s\n' \
    '#!/bin/sh' \
    'if [ "${1:-}" = "info" ]; then' \
    '  echo "Cannot connect to the Docker daemon" >&2' \
    '  exit 1' \
    'fi' \
    'echo "docker shim: unsupported command in simulator: $*" >&2' \
    'exit 1' \
    > /usr/local/bin/docker \
    && chmod +x /usr/local/bin/docker

COPY src /opt/devcontainer-features

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
