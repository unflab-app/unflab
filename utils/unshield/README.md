# unshield (unflab build)

`unshield` lists and extracts the contents of InstallShield cabinet
files (`data1.cab` and friends), as found on old Windows installers.

This is a standalone build for macOS: one binary, its man page, and
nothing else. It depends only on libraries that ship with macOS, so
there is no package manager, no runtime dependency, and nothing else
installed alongside it.

Homebrew's build links OpenSSL, but only for MD5; this one uses
unshield's own MD5 implementation instead, which upstream provides for
that purpose. The `libunshield` library and headers are not shipped.

## Install

```sh
./install.sh                      # into ~/.local/bin
./install.sh --prefix /usr/local/bin
./install.sh --uninstall
```

Run `./install.sh --help` for the full set of options.

If `~/.local/bin` isn't on your `PATH`, the installer says so and offers
to add it — it won't edit your shell config without asking.

## Upstream

- Home: https://github.com/twogood/unshield
- Version: 1.6.2
- Licence: MIT (see `LICENSE`)

`unshield` is David Eriksson's work, not this project's. unflab only
compiles and packages it. The exact source tarball and its checksum are
recorded in the recipe this package was built from.
