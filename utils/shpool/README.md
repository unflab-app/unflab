# shpool (unflab build)

`shpool` keeps shell sessions alive when the connection to them drops.
It is the part of tmux or screen most people use over ssh — detach,
reconnect, reattach — without the windowing, panes or key bindings, so
your terminal's own scrollback, selection and tabs keep working.

```sh
shpool attach main        # create session "main", or reattach to it
shpool list               # sessions and whether they're attached
shpool detach main        # force a stuck session to detach
shpool kill main          # end it
```

Detach from inside a session with `Ctrl-Space Ctrl-q`.

`shpool --help` covers the commands. `CONFIG.md`, installed alongside
this file, is upstream's reference for configuration.

## Where the config lives

This build differs from upstream here. Upstream's shpool reads
`~/Library/Application Support/shpool/config.toml` on macOS, even
though its own documentation says `~/.config/shpool/config.toml`. This
one reads from `~/.config/shpool/` (or `$XDG_CONFIG_DIR/shpool/`) if
that directory exists, and falls back to Application Support if it
doesn't — so an existing config keeps working, and creating
`~/.config/shpool/` is all it takes to move it.

The change is a small patch to upstream's source, offered back to
them; once a release includes it, this note goes away.

## Install

```sh
./install.sh                      # into ~/.local/bin
./install.sh --prefix /usr/local/bin
./install.sh --uninstall
```

## The daemon

Sessions are held by a background daemon. `shpool attach` starts one
if none is running, so there is nothing to set up.

Homebrew's package also offers a launchd service to start the daemon
at login. This one doesn't install a service, but ships a sample agent
at `~/.local/share/shpool/shpool.plist`. Its paths are placeholders,
since launchd expands neither `~` nor `$HOME`; the notes printed after
installing give the commands to fill them in and load it, with this
install's paths already substituted.

Stop any running daemon before loading the agent. A daemon started by
`shpool attach` holds the socket, so launchd's copy fails to start and
retries every ten seconds until the other one goes away.

If you uninstall shpool, unload the agent first
(`launchctl bootout gui/$(id -u)/app.unflab.shpool`) and delete
`~/Library/LaunchAgents/app.unflab.shpool.plist`; uninstalling doesn't
touch either.

## About this build

Pure Rust, linked against nothing but macOS's own system libraries.
It has no dependency problem to solve — Homebrew's formula needs only
the Rust compiler — and is here so it installs the same way as
everything else.

There is no man page or shell completion: upstream doesn't ship either.

## Upstream

- Home: https://github.com/shell-pool/shpool
- Source: https://github.com/shell-pool/shpool
- Version: 0.11.7
- Licence: Apache-2.0
