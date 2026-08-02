# syntax=docker/dockerfile:1

# Pinned to an explicit Ubuntu release rather than the rolling `:ubuntu` tag, so a
# new Ubuntu can never silently change the base under a running project.
FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04

LABEL org.opencontainers.image.source=https://github.com/nerdy-pro/nerdy-pro-dev-container
LABEL org.opencontainers.image.description="Base devcontainer: Node LTS, Claude Code, zsh + oh-my-zsh, fzf"

# The base image already provides git, curl, wget, jq, gpg, zsh, oh-my-zsh (for the
# vscode user), passwordless sudo and the uid/gid 1000 `vscode` user. Only the
# genuinely missing pieces are installed below.

ENV DEBIAN_FRONTEND=noninteractive

# --- Node.js LTS -----------------------------------------------------------
# The NodeSource setup script runs `apt-get update` itself.
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- extra CLI tooling -----------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends fzf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- Claude Code -----------------------------------------------------------
# Global npm prefix outside $HOME: writable by `vscode` (so `claude update` and
# `npm i -g` work without sudo) but not shadowed if $HOME is mounted as a volume.
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/usr/local/share/npm-global/bin:$PATH
RUN mkdir -p "$NPM_CONFIG_PREFIX" && chown -R vscode:vscode "$NPM_CONFIG_PREFIX"

USER vscode
# npm >= 11.16 blocks install scripts unless the package is allow-listed, and
# claude-code needs its postinstall to fetch the native binary.
RUN npm install -g @anthropic-ai/claude-code --allow-scripts @anthropic-ai/claude-code

# --- shell -----------------------------------------------------------------
# Enable the oh-my-zsh fzf plugin (wires up ctrl-r / ctrl-t / alt-c).
RUN sed -i 's/^plugins=(git)$/plugins=(git fzf)/' /home/vscode/.zshrc

USER root
RUN chsh -s /usr/bin/zsh vscode

USER vscode
