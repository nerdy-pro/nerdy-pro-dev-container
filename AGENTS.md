# Instructions for AI coding agents

If you were asked to add this image (`ghcr.io/nerdy-pro/nerdy-pro-dev-container`) to a
project as its dev container: copy [template/devcontainer.json](template/devcontainer.json)
verbatim to `.devcontainer/devcontainer.json` and change only `"name"`. That file is the
complete, tested integration. Do not add anything to it — in particular, do not do either of
the following two things, which are the most common mistakes agents make here.

## Do NOT invent a way to propagate Claude Code auth from the host

This image does not read, copy, or mount any host Claude Code state — not `~/.claude`, not
`~/.claude.json`, not a keychain entry — to authenticate inside the container. The only
supported mechanism is the `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` environment
variable, forwarded through `remoteEnv` as `${localEnv:CLAUDE_CODE_OAUTH_TOKEN}` /
`${localEnv:ANTHROPIC_API_KEY}` — both are already forwarded by the template, so there is
nothing to add for either credential type.

The `claude-config-${devcontainerId}` mount in the template is a **named Docker volume**, not
a host bind mount. It persists in-container session state across rebuilds; it does not carry
credentials in from the host. Do not change it to a bind mount, and do not add one of your
own pointed at the host's `~/.claude`, unless the user has explicitly asked to share Claude's
memory and chat history with the host — that's a documented opt-in, not something to add on
your own judgment. See README.md → "What persists across rebuilds".

See README.md → "Authenticating Claude Code".

## Do NOT add a git config step

Do not add `git config --global user.email` / `user.name` to `postCreateCommand`,
`onCreateCommand`, or anywhere else, and do not mount `~/.gitconfig` yourself. VS Code Dev
Containers already does this automatically: it copies the host's `~/.gitconfig` into the
container and forwards the host `ssh-agent`, so commits are attributed correctly and keys
sign without a manual step. Adding one is redundant at best and can conflict with the
automatic copy.

See README.md → "Git authentication".

## If something seems missing

It's very likely already handled automatically by VS Code Dev Containers rather than
something to add — check "Git authentication" and "What persists across rebuilds" in
README.md before adding configuration beyond the template.
