# nerdy-pro-dev-container

Base devcontainer image: **Node LTS + Claude Code + zsh/oh-my-zsh + fzf**, published to
`ghcr.io/nerdy-pro/nerdy-pro-dev-container`.

Projects consume the prebuilt image instead of building their own, so opening a
devcontainer is a pull rather than a multi-minute build.

## Use it in a project

Copy [template/devcontainer.json](template/devcontainer.json) to `.devcontainer/devcontainer.json`
and change `"name"`. Then "Reopen in Container".

Claude Code inside the container authenticates with `CLAUDE_CODE_OAUTH_TOKEN`, forwarded
from your machine by the `remoteEnv` block in the template — see below.

## Getting CLAUDE_CODE_OAUTH_TOKEN

Two steps: generate the token once, then make it visible to VS Code on your OS.

### 1. Generate it

On your **host** machine, not in the container, with Claude Code installed:

```sh
claude setup-token
```

This requires a Claude subscription and prints a long-lived token. Copy it — you can't
retrieve it again, though you can re-run the command to issue a new one.

> Paying per-token with an API key rather than a subscription? Use `ANTHROPIC_API_KEY`
> instead: put your key in that variable everywhere `CLAUDE_CODE_OAUTH_TOKEN` appears below,
> and rename it in the template's `remoteEnv` block. Nothing else changes.

### 2. Make it visible to VS Code

**This is the part that trips people up.** `${localEnv:CLAUDE_CODE_OAUTH_TOKEN}` is resolved
from the environment **VS Code itself was launched with** — not from the terminal you typed
in, and not from the container. Exporting it in an open shell does nothing for a VS Code
window that is already running. After setting it, fully quit and reopen VS Code, then
rebuild the container.

#### macOS

Add it to your shell profile:

```sh
echo 'export CLAUDE_CODE_OAUTH_TOKEN="<your-token>"' >> ~/.zshrc
```

macOS GUI apps do **not** read your shell profile, so a VS Code launched from the Dock or
Spotlight still won't see it. Either launch VS Code from a terminal, which inherits the
shell environment:

```sh
code /path/to/project
```

…or publish the variable to the GUI session, which makes Dock launches work too:

```sh
launchctl setenv CLAUDE_CODE_OAUTH_TOKEN "<your-token>"
```

`launchctl setenv` is cleared on reboot. Launching via `code .` is the less fragile habit;
if you want the Dock to work permanently, wrap that command in a LaunchAgent.

#### Linux

For terminal-launched VS Code, your shell profile is enough:

```sh
echo 'export CLAUDE_CODE_OAUTH_TOKEN="<your-token>"' >> ~/.zshrc   # or ~/.bashrc
```

Desktop launchers (GNOME, KDE) don't source shell profiles either. On systemd-based
distributions, set it for the whole graphical session:

```sh
mkdir -p ~/.config/environment.d
printf 'CLAUDE_CODE_OAUTH_TOKEN=<your-token>\n' > ~/.config/environment.d/claude.conf
chmod 600 ~/.config/environment.d/claude.conf
```

Note there are no quotes around the value — these files are not shell scripts, and quotes
would become part of the token. Log out and back in for it to take effect.

#### Windows

In PowerShell, persist it for your user account:

```powershell
[Environment]::SetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN', '<your-token>', 'User')
```

Or via the GUI: Start → "Edit environment variables for your account" → New. Either way,
restart VS Code afterwards; apps read environment variables at launch.

**Using WSL?** If you open the project inside WSL and then reopen it in a container, "local"
means the WSL side, so the Windows variable is not what gets read. Set it in the WSL
distribution's shell profile as in the Linux section above.

### 3. Verify

In a terminal **inside** the running container:

```sh
printenv CLAUDE_CODE_OAUTH_TOKEN | head -c 12
```

That prints the first few characters if the token arrived, and nothing at all if it didn't —
which means VS Code did not have the variable when it launched. Then just run `claude`; it
should start without prompting you to log in.

### A note on handling

Every method above stores the token as plaintext in a file owned by your user. Treat it like
a password: keep those files at mode `600`, and never commit one. The template reads the
token from the environment specifically so it stays out of the repo — don't paste it into
`devcontainer.json`, which is a tracked file.

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

## What persists across rebuilds

A devcontainer's filesystem is disposable — anything not on a volume is gone when the
container is rebuilt. The template mounts three:

| volume | path | holds |
|---|---|---|
| `claude-config-${devcontainerId}` | `/home/vscode/.claude` | Claude settings, session transcripts, project trust, MCP servers |
| `command-history-${devcontainerId}` | `/commandhistory` | zsh history |
| `npm-cache` | `/home/vscode/.npm` | npm cache |

Two details in the image make this work, and both are easy to get wrong:

- **`CLAUDE_CONFIG_DIR=/home/vscode/.claude`.** By default Claude Code writes `~/.claude.json`
  — project trust, MCP server config, onboarding state — *beside* `~/.claude`, not inside it,
  so a volume on `~/.claude` alone silently loses it. Setting the config dir consolidates
  everything under one mount.
- **The directories are created in the Dockerfile, owned by `vscode`.** A fresh Docker volume
  inherits the ownership of the image directory it covers; if the path doesn't exist in the
  image, the mount lands root-owned and the container can't write to it. Creating them up
  front is what removes the need for a `chown` in `postCreateCommand`.

The npm cache is deliberately **not** scoped by `${devcontainerId}` — it's content-addressed
and safe to share, and sharing across projects is where the speedup comes from. The other two
are per-project. Drop the `-${devcontainerId}` suffix on either to share it across all
projects (e.g. one Claude settings store everywhere); drop a whole line to start clean on
every rebuild.

Deliberately not persisted:

- **VS Code server and extensions** (`~/.vscode-server`) reinstall on each rebuild. Persisting
  them is possible but couples the container to a client version and breaks confusingly when
  they drift — not worth it for a ~20s reinstall.
- **Globally installed npm packages**, including Claude Code itself, come from the image. That
  is the point: the image tag determines the toolchain version, so a rebuild can't leave you
  on a version you can't reproduce.
- **Git identity and SSH keys** need no volume — Dev Containers copies your host `~/.gitconfig`
  in and forwards your SSH agent automatically.

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

The same applies to history: the image sets `HISTFILE` as an env var, which oh-my-zsh
respects because it only defaults `HISTFILE` when unset. But a `.zshrc` that assigns
`HISTFILE` outright wins over the env var, and history stops landing on the volume. If your
dotfiles set it, point them at `/commandhistory/.zsh_history`.

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
