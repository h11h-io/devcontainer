# Dockerfile — local devcontainer simulation
#
# Build:
#   docker build -t devcontainer-sim .
#
# Run (mount your repo):
#   docker run --rm -it -v "$(pwd):/workspaces/$(basename $(pwd))" devcontainer-sim
#
# This image installs the devcontainer CLI, then at runtime it reads
# /workspaces/<repo>/.devcontainer/devcontainer.json and runs the feature
# install + lifecycle hooks just like VS Code / Codespaces would, then
# drops you into a shell so you can test the result.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
       curl git jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (needed for @devcontainers/cli)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @devcontainers/cli

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
