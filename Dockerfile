# syntax=docker/dockerfile:1

# Pinned to an explicit Ubuntu release rather than the rolling `:ubuntu` tag, so a
# new Ubuntu can never silently change the base under a running project.
FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04

LABEL org.opencontainers.image.source=https://github.com/nerdy-pro/nerdy-pro-dev-container
LABEL org.opencontainers.image.description="Base devcontainer: Node LTS, Claude Code, zsh + oh-my-zsh, fzf"
LABEL org.opencontainers.image.licenses=MIT

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

# --- terminal banner -------------------------------------------------------
# Lives in /etc rather than ~/.zshrc so that a dotfiles install.sh replacing
# ~/.zshrc doesn't take it with it. Sourced by both shells, so it also shows for
# anyone who switches to bash.
COPY <<'EOF' /etc/nerdy-banner.sh
# Sourced from /etc/zsh/zshrc and /etc/bash.bashrc.
# Printed only on a real terminal, so it can never corrupt the output of a
# piped or scripted shell. Opt out with NERDY_NO_BANNER=1.
# Both lines stay under 80 columns so they don't wrap in a narrow terminal panel.
if [ -t 1 ] && [ -z "${NERDY_NO_BANNER:-}" ]; then
    if [ -n "${NO_COLOR:-}" ]; then
        printf '\nThanks for using the Nerdy Pro dev container - https://nerdy.pro\n'
        printf 'Stuck with vibecoding? -> https://nerdy.pro/services/ai-code-audit\n\n'
    else
        printf '\n\033[1;36m✦ Thanks for using the Nerdy Pro dev container\033[0m \033[2m— https://nerdy.pro\033[0m\n'
        printf '\033[2m  Stuck with vibecoding? → https://nerdy.pro/services/ai-code-audit\033[0m\n\n'
    fi
fi
EOF
RUN chmod 644 /etc/nerdy-banner.sh \
    && echo '[ -r /etc/nerdy-banner.sh ] && . /etc/nerdy-banner.sh' \
       | tee -a /etc/zsh/zshrc /etc/bash.bashrc > /dev/null

# --- git over SSH ----------------------------------------------------------
# Nothing is configured here on purpose. ssh keeps its default
# StrictHostKeyChecking=ask, so the first connection to a git server prints the
# host's fingerprint and waits for you to confirm it: no key is ever trusted
# without a human looking at it. No known_hosts is baked in or mounted either.
#
# The cost is that first contact has to happen in an interactive terminal. `ask`
# cannot prompt without a TTY, so if the first thing to reach a new host is
# VS Code's Source Control button, a postCreateCommand, a submodule fetch or
# Claude Code, it fails with "Host key verification failed" — which git then
# reports as "make sure you have the correct access rights", pointing at the
# wrong problem. Connect once from the container terminal to accept a new host;
# everything headless works from then on.
#
# Persisting ~/.ssh (see below) is what keeps that to one confirmation per host
# ever, rather than one per rebuild.

# --- persistable state -----------------------------------------------------
# Paths meant to be backed by named volumes in devcontainer.json. A fresh Docker
# volume inherits the ownership of the image directory it covers, so creating
# them here as `vscode` is what keeps the mounts from landing root-owned.

# oh-my-zsh only defaults HISTFILE when it is unset, so this wins. History size
# stays at oh-my-zsh's defaults (HISTSIZE 50000 / SAVEHIST 10000).
ENV HISTFILE=/commandhistory/.zsh_history

# Without this, Claude Code writes ~/.claude.json (project trust, MCP servers,
# onboarding state) *next to* ~/.claude rather than inside it, and a volume on
# ~/.claude alone would silently miss it. Pointing the config dir at ~/.claude
# consolidates everything under one mount.
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude

RUN mkdir -p /commandhistory /home/vscode/.claude /home/vscode/.npm /home/vscode/.ssh \
    && chown vscode:vscode /commandhistory /home/vscode/.claude /home/vscode/.npm \
                           /home/vscode/.ssh \
    && chmod 700 /home/vscode/.ssh

USER vscode
