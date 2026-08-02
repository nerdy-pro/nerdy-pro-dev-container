# nerdy-pro-dev-container

[![Build status](https://github.com/nerdy-pro/nerdy-pro-dev-container/actions/workflows/build-image.yml/badge.svg)](https://github.com/nerdy-pro/nerdy-pro-dev-container/actions/workflows/build-image.yml)
[![Latest release](https://img.shields.io/github/v/release/nerdy-pro/nerdy-pro-dev-container)](https://github.com/nerdy-pro/nerdy-pro-dev-container/releases/latest)
[![License: MIT](https://img.shields.io/github/license/nerdy-pro/nerdy-pro-dev-container)](LICENSE)
[![Container image on ghcr.io](https://img.shields.io/badge/ghcr.io-nerdy--pro%2Fnerdy--pro--dev--container-2496ED?logo=docker&logoColor=white)](https://github.com/nerdy-pro/nerdy-pro-dev-container/pkgs/container/nerdy-pro-dev-container)
[![Open in Dev Containers](https://img.shields.io/static/v1?label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode%3A%2F%2Fms-vscode-remote.remote-containers%2FcloneInVolume%3Furl%3Dhttps%3A%2F%2Fgithub.com%2Fnerdy-pro%2Fnerdy-pro-dev-container)

**A prebuilt VS Code dev container image for AI-assisted development.**
`nerdy-pro-dev-container` is a Docker image built on Ubuntu 26.04 that ships Node.js LTS,
[Claude Code](https://www.claude.com/product/claude-code), zsh with oh-my-zsh, and fzf. It is
published for both `linux/amd64` and `linux/arm64` (Apple Silicon) to the GitHub Container
Registry as `ghcr.io/nerdy-pro/nerdy-pro-dev-container`.

Projects reference the published image instead of maintaining their own Dockerfile, so opening
a dev container is a pull rather than a multi-minute build.

**Requirements:** Docker, [Visual Studio Code](https://code.visualstudio.com/), and the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

📦 **Project page:**
[nerdy.pro/open-source/nerdy-pro-dev-container](https://nerdy.pro/open-source/nerdy-pro-dev-container)

| | |
|---|---|
| **Image** | `ghcr.io/nerdy-pro/nerdy-pro-dev-container` |
| **Base** | Ubuntu 26.04 (`mcr.microsoft.com/devcontainers/base`) |
| **Architectures** | `linux/amd64`, `linux/arm64` |
| **Includes** | Node.js LTS, Claude Code, zsh + oh-my-zsh, fzf, git, openssh-client |
| **User** | `vscode` (uid 1000, passwordless sudo) |
| **Project page** | [nerdy.pro/open-source/nerdy-pro-dev-container](https://nerdy.pro/open-source/nerdy-pro-dev-container) |
| **License** | MIT |

### Contents

- [Quick start](#quick-start-add-the-image-to-a-project) — see also [AGENTS.md](AGENTS.md) if an agent is doing it for you
- [Authenticating Claude Code](#authenticating-claude-code) — OAuth token or API key, macOS/Linux/Windows
- [Git authentication](#git-authentication) — commit and push from the container
- [What's in the image](#whats-in-the-image)
- [What persists across rebuilds](#what-persists-across-rebuilds)
- [Dotfiles](#dotfiles)
- [FAQ](#faq)
- [Publishing](#publishing) · [Local development](#local-development) · [Bumping Ubuntu](#bumping-ubuntu)

## Quick start: add the image to a project

Copy [template/devcontainer.json](template/devcontainer.json) to `.devcontainer/devcontainer.json`
and change `"name"`. Then "Reopen in Container". The minimal version is one line:

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "my-project",
  "image": "ghcr.io/nerdy-pro/nerdy-pro-dev-container:latest"
}
```

Claude Code inside the container authenticates with `CLAUDE_CODE_OAUTH_TOKEN` or
`ANTHROPIC_API_KEY`, forwarded from your machine by the `remoteEnv` block in the template —
see below.

> **Having an AI agent do this step for you?** Point it at
> [template/devcontainer.json](template/devcontainer.json) and tell it to copy that file
> verbatim. Left to its own judgment, an agent will often invent a way to propagate Claude
> Code auth from the host via file mounts, or add a `git config` step to `postCreateCommand`
> — neither is needed, and both are wrong for this image. See
> [AGENTS.md](AGENTS.md) for specifics.

## Authenticating Claude Code

Claude Code inside the container needs a credential from the host, forwarded through VS Code.
Two kinds work, and the template forwards both automatically — set whichever one you have and
nothing else changes:

| | env var | comes from | requires |
|---|---|---|---|
| OAuth token | `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` | Claude subscription |
| API key | `ANTHROPIC_API_KEY` | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) | pay-per-token billing |

The rest of this section walks through the OAuth token, since it's the more common path. Every
step applies equally to `ANTHROPIC_API_KEY` — substitute the variable name, and see the callout
after step 2 for the per-OS label substitutions.

### 1. Generate it

On your **host** machine, not in the container, with Claude Code installed:

```sh
claude setup-token
```

This requires a Claude subscription and prints a long-lived token. Copy it — you can't
retrieve it again, though you can re-run the command to issue a new one.

> Using an API key instead? Create one at
> [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) and skip
> to step 2 — you already have your credential.

### 2. Make it visible to VS Code

**This is the part that trips people up.** `${localEnv:CLAUDE_CODE_OAUTH_TOKEN}` (or
`${localEnv:ANTHROPIC_API_KEY}`) is resolved from the environment **VS Code itself was
launched with** — not from the terminal you typed in, and not from the container. Exporting
it in an open shell does nothing for a VS Code window that is already running. After setting
it, fully quit and reopen VS Code, then rebuild the container.

#### macOS

Keep the token in the login Keychain instead of pasting it into a dotfile:

```sh
security add-generic-password -a "$USER" -s CLAUDE_CODE_OAUTH_TOKEN -w "<your-token>" -U
```

`-U` updates the entry if it already exists, so re-run the exact same command to rotate the
token later.

Then have your shell read it out at startup:

```sh
echo 'export CLAUDE_CODE_OAUTH_TOKEN="$(security find-generic-password -a "$USER" -s CLAUDE_CODE_OAUTH_TOKEN -w)"' >> ~/.zshrc
```

The **single** quotes matter. They write the command substitution into `~/.zshrc` literally,
so it runs each time a shell starts. With double quotes your shell would expand it right now
and append the token itself, putting you back to storing it in plaintext.

macOS GUI apps do **not** read your shell profile, so a VS Code launched from the Dock or
Spotlight still won't see it. Either launch VS Code from a terminal, which inherits the shell
environment:

```sh
code /path/to/project
```

This is the recommended path — it needs nothing beyond the `export` above.

<details>
<summary>…or make Dock and Spotlight launches work too (LaunchAgent)</summary>

GUI apps inherit their environment from launchd, so the variable has to be published there
with `launchctl setenv`. That has to happen at login, before you launch anything, which means
a LaunchAgent. Save as `~/Library/LaunchAgents/com.nerdy-pro.claude-token.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.nerdy-pro.claude-token</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>launchctl setenv CLAUDE_CODE_OAUTH_TOKEN "$(security find-generic-password -a "$(id -un)" -s CLAUDE_CODE_OAUTH_TOKEN -w)"</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

Load it once; it runs at every login thereafter:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.nerdy-pro.claude-token.plist
```

It uses `id -un` rather than `$USER` deliberately: LaunchAgents run with a minimal
environment in which `$USER` is unset, so the `$USER` spelling looks correct and silently
resolves to the wrong account.

> **Do not put `launchctl setenv` in `~/.zshrc` as a shortcut.** It writes only to the
> launchd domain, never to the shell that ran it — so the variable ends up unset in your
> terminal *and* in anything launched from it, breaking `code .` while only half-fixing Dock
> launches: after a reboot the launchd domain stays empty until you happen to open a
> terminal. If you want it in `~/.zshrc` anyway, it has to be *in addition to* the `export`
> line, not instead of it.

Either `launchctl` route copies the token out of the Keychain into your launchd session,
where any process running as you can read it back with `launchctl getenv`. Launching via
`code .` keeps it scoped to your shell and its children.

</details>

#### Linux

Use the desktop keyring — GNOME Keyring and KWallet both implement the freedesktop Secret
Service API, so `secret-tool` talks to either:

```sh
sudo apt install libsecret-tools    # Debian/Ubuntu
sudo dnf install libsecret          # Fedora
sudo pacman -S libsecret            # Arch
```

Store the token. It is read from stdin, so it never reaches your shell history — paste it,
then press Enter and Ctrl-D:

```sh
secret-tool store --label="Claude Code token" service claude-code key oauth-token
```

Then read it back in your shell profile:

```sh
echo 'export CLAUDE_CODE_OAUTH_TOKEN="$(secret-tool lookup service claude-code key oauth-token)"' >> ~/.zshrc   # or ~/.bashrc
```

Single quotes, for the same reason as macOS. Then launch VS Code from that terminal with
`code .`.

The keyring has to be unlocked for the lookup to succeed. It is in a normal graphical
session, but over a plain SSH login it will fail or hang — so if you share this profile with
headless machines, guard the line. `pass` (GPG-backed, unlocked by `gpg-agent`) is the usual
choice when it has to work headless.

<details>
<summary>…or make desktop-launcher launches work (plaintext)</summary>

Desktop launchers (GNOME, KDE) don't source shell profiles. On systemd-based distributions
you can set the variable for the whole graphical session instead:

```sh
mkdir -p ~/.config/environment.d
printf 'CLAUDE_CODE_OAUTH_TOKEN=<your-token>\n' > ~/.config/environment.d/claude.conf
chmod 600 ~/.config/environment.d/claude.conf
```

No quotes around the value — these files are not shell scripts, and quotes would become part
of the token. Log out and back in for it to take effect.

There is no keyring version of this: systemd builds the session environment from these files
before any keyring is unlocked, so a `secret-tool` lookup there could not succeed. The
tradeoff is real — this route means the token sits in cleartext on disk.

</details>

#### Windows

Store the token in a DPAPI-encrypted file. DPAPI derives its key from your Windows account,
so the file is useless to another account or on another machine, and it needs no extra
modules. Prompted input keeps the token out of your console history:

```powershell
Read-Host -AsSecureString -Prompt 'Paste token' |
  ConvertFrom-SecureString | Set-Content "$HOME\.claude-token"
```

Read it back from your PowerShell profile (`notepad $PROFILE`):

```powershell
$env:CLAUDE_CODE_OAUTH_TOKEN =
  Get-Content "$HOME\.claude-token" | ConvertTo-SecureString | ConvertFrom-SecureString -AsPlainText
```

Then launch VS Code from that PowerShell session with `code .`.

`ConvertFrom-SecureString -AsPlainText` requires PowerShell 7+. On Windows PowerShell 5.1:

```powershell
$sec = Get-Content "$HOME\.claude-token" | ConvertTo-SecureString
$env:CLAUDE_CODE_OAUTH_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
```

If you prefer a managed vault, `Microsoft.PowerShell.SecretManagement` with the `SecretStore`
backend does the same job via `Set-Secret` / `Get-Secret`, at the cost of installing two
modules and unlocking the vault once per session.

<details>
<summary>…or make Start Menu launches work (plaintext)</summary>

```powershell
[Environment]::SetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN', '<your-token>', 'User')
```

Or via the GUI: Start → "Edit environment variables for your account" → New. Either way,
restart VS Code afterwards; apps read environment variables at launch.

This writes the token in cleartext to your user registry hive (`HKCU\Environment`), where any
process running as you can read it.

</details>

**Using WSL?** If you open the project inside WSL and then reopen it in a container, "local"
means the WSL side, so the Windows variable is not what gets read. Set it up inside the WSL
distribution instead, following the Linux section above.

> **Using an API key instead of an OAuth token?** Same mechanism throughout on every
> platform — substitute `ANTHROPIC_API_KEY` for `CLAUDE_CODE_OAUTH_TOKEN` in every
> `export`/`$env:` line above, and swap the label used to store it:
>
> | platform | OAuth token label above | API key label |
> |---|---|---|
> | macOS Keychain | `-s CLAUDE_CODE_OAUTH_TOKEN` | `-s ANTHROPIC_API_KEY` |
> | Linux secret-tool | `key oauth-token` | `key api-key` |
> | Windows file | `.claude-token` | `.anthropic-api-key` |

### 3. Verify

In a terminal **inside** the running container:

```sh
printenv CLAUDE_CODE_OAUTH_TOKEN | head -c 12    # or ANTHROPIC_API_KEY, whichever you set
```

That prints the first few characters if the credential arrived, and nothing at all if it
didn't — which means VS Code did not have the variable when it launched. Then just run
`claude`; it should start without prompting you to log in.

### A note on handling

Everything below says "token" for brevity, but applies identically to an API key. Each
platform's primary route keeps it encrypted at rest and out of your dotfiles —
Keychain on macOS, the desktop keyring on Linux, DPAPI on Windows. All three share the same
shape: the secret store holds the token, the shell profile reads it out at startup, and you
launch VS Code with `code .` so it inherits that environment.

The collapsible fallbacks trade that away. Each one exists because GUI launchers — Dock,
Spotlight, the GNOME/KDE app grid, the Start Menu — don't inherit a shell environment, and
the mechanisms that reach them run before any keyring is unlocked. If you use one, the token
is in cleartext: keep the file at mode `600`, and never commit it.

Whichever route you pick, the token stays out of your shell history: the macOS and Windows
commands take it via prompt or stdin, and `secret-tool store` reads from stdin too.

Regardless of platform, the template reads the token from the environment specifically so it
stays out of the repo — don't paste it into `devcontainer.json`, which is a tracked file.

## Git authentication

Yes — you can commit and push from inside the container, and there is nothing to configure
for the common case. VS Code Dev Containers handles two things automatically:

- **Your identity.** Your host `~/.gitconfig` is copied in, so `user.name` and `user.email`
  are already set and commits are attributed correctly.
- **Your SSH keys.** Your host `ssh-agent` is forwarded into the container. The keys
  themselves never enter it — signing happens on your machine, over the forwarded socket.
  Check what will be available with `ssh-add -l` on the host; if that is empty, run
  `ssh-add` (macOS: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`) before opening.

For HTTPS remotes rather than SSH, VS Code supplies a credential helper backed by its own
GitHub sign-in, so those work without a token in the container too.

**Host keys are the part that isn't automatic.** No `known_hosts` is baked into the image or
mounted from your machine, so first contact with a git server has nothing to verify against.
ssh's default `StrictHostKeyChecking=ask` cannot prompt without a TTY, so it fails outright —
and git reports it in a way that sends you hunting for the wrong problem:

```
Host key verification failed.
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

Your keys are fine there; it never got as far as offering them.

**The fix is to make first contact yourself, from the container's terminal.** ssh keeps its
default `ask`, so it shows you the fingerprint and waits:

```
The authenticity of host 'github.com (140.82.121.4)' can't be established.
ED25519 key fingerprint is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Nothing is trusted without a human looking at it. Because the template puts **`~/.ssh` on a
shared volume**, that confirmation is recorded once and reused — one `yes` per host *ever*,
not one per rebuild. Every headless operation against that host works from then on: Source
Control buttons, scripts, Claude Code.

The volume is deliberately not scoped per project. Host keys aren't project state, and one
shared store means one confirmation rather than one per project.

> **Ordering is the thing to remember.** `ask` cannot prompt without a TTY, so whatever
> touches a *new* host first has to be you, in a terminal. If a `postCreateCommand`, a
> submodule fetch, or Claude Code gets there first, it fails with the misleading error above.
> `git ls-remote` in the container terminal is enough to accept a host up front.
>
> If you would rather not think about ordering, `StrictHostKeyChecking accept-new` in
> `/etc/ssh/ssh_config.d/` records the key on first contact instead of asking. That's
> trust-on-first-use — it trusts the network at that moment rather than your eyes — and it is
> the deliberate tradeoff this image does *not* make.

> **`~/.ssh/config` is not copied in.** Only the agent is forwarded. If a repo's remote uses
> a `Host` alias defined in your config — say `git@my-alias:org/repo.git` where the config
> maps `my-alias` to a real hostname and a specific key — that alias does not exist inside
> the container and the remote will fail to resolve. Use the real hostname in remotes you
> intend to push from a container, or mount your config in as well.

## What's in the image

Everything below is baked in, so nothing is downloaded at container-create time.

| | |
|---|---|
| Base | `mcr.microsoft.com/devcontainers/base:ubuntu26.04` |
| Node | LTS from NodeSource (v24 at time of writing) |
| Claude Code | `@anthropic-ai/claude-code`, global npm install |
| Shell | zsh as `vscode`'s login shell, oh-my-zsh with `git` + `fzf` plugins |
| SSH | openssh-client, stock host-key checking (see [Git authentication](#git-authentication)) |
| Also | git, curl, wget, jq, gpg, fzf, openssh-client, passwordless sudo |

The base image already provides git, curl, wget, jq, gpg, zsh and oh-my-zsh, so the
Dockerfile only adds Node, Claude Code and fzf, and switches the login shell to zsh.

Global npm packages live in `/usr/local/share/npm-global`, owned by `vscode`. That means
`npm i -g` and `claude update` work without sudo, and the directory isn't shadowed if you
mount a volume over `$HOME`.

## What persists across rebuilds

A devcontainer's filesystem is disposable — anything not on a volume is gone when the
container is rebuilt. The template mounts four:

| volume | path | holds |
|---|---|---|
| `claude-config-${devcontainerId}` | `/home/vscode/.claude` | Claude settings, session transcripts, project trust, MCP servers |
| `command-history-${devcontainerId}` | `/commandhistory` | zsh history |
| `npm-cache` | `/home/vscode/.npm` | npm cache |
| `ssh-known-hosts` | `/home/vscode/.ssh` | git server host keys accepted on first contact |

Two details in the image make this work, and both are easy to get wrong:

- **`CLAUDE_CONFIG_DIR=/home/vscode/.claude`.** By default Claude Code writes `~/.claude.json`
  — project trust, MCP server config, onboarding state — *beside* `~/.claude`, not inside it,
  so a volume on `~/.claude` alone silently loses it. Setting the config dir consolidates
  everything under one mount.
- **The directories are created in the Dockerfile, owned by `vscode`.** A fresh Docker volume
  inherits the ownership *and mode* of the image directory it covers; if the path doesn't
  exist in the image, the mount lands root-owned and the container can't write to it. Creating
  them up front is what removes the need for a `chown` in `postCreateCommand` — and for
  `~/.ssh` it also carries the `700` that ssh refuses to work without.

Two of the volumes are deliberately **not** scoped by `${devcontainerId}`. The npm cache is
content-addressed and safe to share, and sharing across projects is where the speedup comes
from. Host keys aren't project state either, and one shared store means one trust-on-first-use
window rather than a fresh one per project. The other two are per-project — drop the
`-${devcontainerId}` suffix to share those too (e.g. one Claude settings store everywhere), or
drop a whole line to start clean on every rebuild.

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

## FAQ

### What is a dev container?

A dev container is a Docker container used as a full-featured development environment, defined
by a `devcontainer.json` file in your repository. VS Code starts the container, installs its
server inside it, and runs your editor against that environment instead of your local machine,
so every contributor gets the same toolchain regardless of their OS.

### Which architectures does this image support?

Both `linux/amd64` and `linux/arm64`. CI builds a multi-architecture manifest, so a single tag
such as `ghcr.io/nerdy-pro/nerdy-pro-dev-container:1.0.0` resolves to native layers on Apple
Silicon and on x86 machines alike — nothing to configure per platform.

### Do I need a Claude subscription?

No — either works. A subscription gets you `claude setup-token`'s `CLAUDE_CODE_OAUTH_TOKEN`;
pay-per-token billing gets you an `ANTHROPIC_API_KEY` from
[console.anthropic.com](https://console.anthropic.com/settings/keys). The template forwards
both env vars, so set whichever one you have — nothing to configure. See
[Authenticating Claude Code](#authenticating-claude-code).

### Can I commit and push from inside the container?

Yes. VS Code copies your host `~/.gitconfig` into the container and forwards your SSH agent, so
commits are attributed correctly and your keys sign without ever entering the container. The
one manual step is host-key trust: connect once from the container's terminal to accept a new
git server. See [Git authentication](#git-authentication).

### Does my shell history survive a rebuild?

Yes. `HISTFILE` points at `/commandhistory`, which the template backs with a Docker volume.
Claude Code's settings and session transcripts, the npm cache, and accepted SSH host keys
persist the same way. See [What persists across rebuilds](#what-persists-across-rebuilds).

### How do I pin the image to a specific version?

Replace `:latest` with a release tag — `:1.0.0` never moves, `:1.0` moves on patch releases,
and `:1` moves on minor and patch releases. Pin to `:1.0.0` when you want a project frozen to a
known-good toolchain.

### How do I update Claude Code inside the container?

Cut a new release, which rebuilds the image against the current npm package. For a one-off
update in a running container, `claude update` works without sudo, because global npm packages
live in `/usr/local/share/npm-global`, owned by `vscode`. That change is lost on rebuild by
design — the image tag determines the version.

### Can I use it without VS Code?

Yes. The image is an ordinary OCI image: `docker run -it ghcr.io/nerdy-pro/nerdy-pro-dev-container:latest zsh`.
The [`devcontainer` CLI](https://github.com/devcontainers/cli) also reads the same
`devcontainer.json` (`devcontainer up --workspace-folder .`). You lose the automatic gitconfig
copy and SSH agent forwarding, which are features of the VS Code extension rather than the
image.

### Why is my `docker pull` failing with unauthorized?

The GitHub Container Registry publishes packages as private by default, even from a public
repository. Open the package under
[nerdy-pro packages](https://github.com/orgs/nerdy-pro/packages) → Package settings → Change
visibility → Public.

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

## License

[MIT](LICENSE) — © 2026 Nerdy Pro.

Covers this repository: the Dockerfile, the devcontainer templates and the docs. Software
installed *into* the image keeps its own license — Ubuntu, Node.js, zsh, fzf, and Claude
Code, whose terms are Anthropic's.
