# moor (unflab build)

`moor` is a pager, like `less`, meant to do the right thing with no
configuration: it syntax-highlights source code, shows ANSI-coloured
output such as `git diff` as it should look, searches and filters as you
type, and reads compressed files directly. It was called `moar` until
version 2.0.0.

```sh
moor file.txt
git log | moor
moor --help                  # options, and the keys it responds to
```

## Using it as your pager

Installing it doesn't make anything use it. To set it as your default
pager, and for man pages, add to your shell's rc file:

```sh
export PAGER=~/.local/bin/moor
export MANPAGER=~/.local/bin/moor
```

Use whichever directory you installed into. macOS's `man` uses `PAGER`
when `MANPAGER` is unset, so the first line alone covers both, unless
`MANCOLOR` is set, in which case `man` uses `less -sR` instead.

## Install

```sh
./install.sh                      # into ~/.local/bin
./install.sh --prefix /usr/local/bin
./install.sh --uninstall
```

## About this build

A single static binary built with `CGO_ENABLED=0`, so it links against
nothing but `libSystem`. The man page is included, as upstream asks of
packagers.

`moar` is installed as an alias for `moor`, if nothing else on your
machine already has that name, so existing `PAGER=moar` settings and
scripts keep working. Upstream's own `moar` is a wrapper script that
prints a rename notice every time it runs; this alias is just the
binary.

Upstream publishes prebuilt macOS binaries too. This package exists so
`moor` installs the same way as everything else here, not because it
was hard to get.

## Upstream

- Home: https://github.com/walles/moor
- Version: 2.19.7
- Licence: BSD-2-Clause (see `LICENSE`)

`moor` is Johan Walles's work. unflab only compiles and packages it.
