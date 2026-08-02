# nerdy-pro-dev-container

Base devcontainer image: **Node LTS + Claude Code + zsh/oh-my-zsh + fzf**, published to
`ghcr.io/nerdy-pro/nerdy-pro-dev-container`.

Projects consume the prebuilt image instead of building their own, so opening a
devcontainer is a pull rather than a multi-minute build.

## Use it in a project

Copy [template/devcontainer.json](template/devcontainer.json) to `.devcontainer/devcontainer.json`
and change `"name"`. Then "Reopen in Container".

Authentication is forwarded from the host shell via `CLAUDE_CODE_OAUTH_TOKEN`. Generate a
token once with `claude setup-token` and export it from your host `~/.zshrc`:

```sh
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat..."
```

VS Code reads that variable from the environment it was launched with — if you export it in
a shell after VS Code is already running, restart VS Code (or launch it with `code .` from
that shell) before rebuilding the container.

## What's in the image

Everything below is baked in, so nothing is downloaded at container-create time.

| | |
|---|---|
| Base | `mcr.microsoft.com/devcontainers/base:ubuntu26.04` |
| Node | LTS from NodeSource (v24 at time of writing) |
| Claude Code | `@anthropic-ai/claude-code`, global npm install |
| Shell | zsh as `vscode`'s login shell, oh-my-zsh with `git` + `fzf` plugins |
| Also | git, curl, wget, jq, gpg, fzf, passwordless sudo |

The base image already provides git, curl, wget, jq, gpg, zsh and oh-my-zsh, so the
Dockerfile only adds Node, Claude Code and fzf, and switches the login shell to zsh.

Global npm packages live in `/usr/local/share/npm-global`, owned by `vscode`. That means
`npm i -g` and `claude update` work without sudo, and the directory isn't shadowed if you
mount a volume over `$HOME`.

## Dotfiles

Dotfiles are a per-user VS Code setting, not part of this image — add to your **user**
`settings.json`:

```json
"dotfiles.repository": "thenixan/dotfiles",
"dotfiles.targetPath": "~/dotfiles",
"dotfiles.installCommand": "install.sh"
```

VS Code clones and runs this in every devcontainer you open. Note the ordering: if your
`install.sh` replaces `~/.zshrc`, it overrides the image's oh-my-zsh config — including the
`fzf` plugin line. Either keep the image's `.zshrc` and layer on top of it, or re-enable
`plugins=(git fzf)` in your own.

## Publishing

CI ([.github/workflows/build-image.yml](.github/workflows/build-image.yml)) builds
`linux/amd64` + `linux/arm64`. **Publishing happens on published GitHub releases only** —
the release tag is the image version. Pushes to `main`, pull requests touching the
Dockerfile, and manual dispatch build the image but do not push, so a broken Dockerfile
surfaces before you tag.

Cut a release to ship:

```sh
gh release create v1.0.0 --generate-notes
```

A `v1.0.0` release publishes four tags:

| tag | moves? |
|---|---|
| `1.0.0` | never — pin here for a fully frozen project |
| `1.0` | on patch releases |
| `1` | on minor and patch releases |
| `latest` | on every stable release |

Prereleases (`v2.0.0-rc1`) publish `2.0.0-rc1` and leave `latest` alone.

Because publishing is release-gated, the image no longer refreshes on its own — cutting a
release is how base-image security updates and new Claude Code versions reach users. To
rebuild an existing version against newer upstream layers without bumping it, re-run that
release's workflow run from the Actions tab; it republishes the same tags.

First-time setup:

```sh
git init -b main
git add -A && git commit -m "base devcontainer image"
git remote add origin git@github.com:nerdy-pro/nerdy-pro-dev-container.git
git push -u origin main
```

GHCR packages are created **private** on first push, even when the repo is public — so the
initial `docker pull` will 401 until you change it. Open the package under the
[nerdy-pro packages](https://github.com/orgs/nerdy-pro/packages) → Package settings →
Change visibility → Public. After that any machine can pull without authenticating.

The `org.opencontainers.image.source` label in the [Dockerfile](Dockerfile) is what
auto-links the package to the repo; it has to match the repo path, so update it if the repo
ever moves. The workflow itself derives the image name from `github.repository_owner`, so
that part follows the org automatically.

arm64 is built under QEMU emulation, which is the slow leg of the build. Since this repo is
public, GitHub's `ubuntu-24.04-arm` runners are free for it — splitting the build across
native amd64 and arm64 runners and merging the two manifests would cut build time
substantially.

## Local development

This repo has its own [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)
that builds the Dockerfile locally, so you can test changes before publishing. Or directly:

```sh
docker build -t nerdy-pro-dev-container:test .
docker run --rm -it nerdy-pro-dev-container:test zsh
```

## Bumping Ubuntu

The base is pinned to `ubuntu26.04` rather than the rolling `:ubuntu` tag so a new Ubuntu
release can't silently change the base under existing projects. Bump it deliberately in the
Dockerfile. Note the tag naming is inconsistent upstream — `ubuntu-24.04` and `ubuntu24.04`
both exist, but 26.04 is only published as `ubuntu26.04`. Check with:

```sh
curl -s https://mcr.microsoft.com/v2/devcontainers/base/tags/list | jq -r '.tags[]' | grep ubuntu
```
